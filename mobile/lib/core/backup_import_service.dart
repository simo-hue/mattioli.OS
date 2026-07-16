import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'app_logger.dart';
import 'import_merge.dart';
import 'import_merge_stats.dart';
import 'private_data_store.dart';
import 'streak_utils.dart';

/// Counts shown in the pre-import preview: how many records the file contains,
/// per entity, plus the normalized (canonical) data ready to import.
class BackupImportPreview {
  final int habitsCount;
  final int logsCount;
  final int macroGoalsCount;
  final int categoriesCount;
  final int moodsCount;

  /// Canonical, VALIDATED backup — feed straight to [BackupImportService.executeImport].
  final Map<String, dynamic> canonicalData;

  /// How many rows were dropped as invalid during validation, keyed by
  /// 'habits' | 'logs' | 'macroGoals' | 'categories' | 'moods'.
  final Map<String, int> skipped;

  const BackupImportPreview({
    required this.habitsCount,
    required this.logsCount,
    required this.macroGoalsCount,
    required this.categoriesCount,
    required this.moodsCount,
    required this.canonicalData,
    required this.skipped,
  });

  /// Total invalid rows across all entities.
  int get totalSkipped => skipped.values.fold(0, (a, b) => a + b);
}

/// Returns [logs] with the HealthKit-measured quantity removed from every log
/// that belongs to a HealthKit-verified goal, ready to upload to Supabase.
///
/// A HealthKit measurement may live in the private (SQLCipher + end-to-end
/// encrypted CloudKit) store but must never reach Supabase. It rides in
/// `goal_logs.value`, which a Private-mode backup carries, so restoring such a
/// file into a Cloud account would upload it. The verdict (status, streak, date)
/// still restores — only the quantity behind it is dropped. `value` is written
/// as an explicit null rather than omitted so a measurement an older build
/// uploaded is cleared by the restore instead of surviving under it.
///
/// [backupGoals] is the canonical `kGoalsKey` list, and a goal it does not
/// resolve is treated as HealthKit-verified — mirroring the `?? true` fallback
/// in HabitLogsNotifier.applyAutoVerdict, the only other Supabase writer of this
/// column. The file is the only source consulted: a measured value can only
/// reach a backup through a Private-mode export, which always writes
/// `verify_provider` (null when manual), so the rule always travels with the
/// value it governs. Reading the rule back from Supabase instead would make
/// every cloud import depend on the verification migration having been applied,
/// which `Goal.toJson` deliberately avoids.
List<Map<String, dynamic>> stripHealthMeasurements({
  required List<Map<String, dynamic>> logs,
  required Object? backupGoals,
}) {
  final healthKit = VerificationProvider.healthKit.wireName;
  final knownGoalIds = <String>{};
  final healthGoalIds = <String>{};

  if (backupGoals is List) {
    for (final goal in backupGoals) {
      if (goal is! Map) continue;
      final id = goal['id'];
      if (id is! String) continue;
      knownGoalIds.add(id);
      if (goal['verify_provider'] == healthKit) healthGoalIds.add(id);
    }
  }

  bool isHealthDerived(Object? goalId) =>
      healthGoalIds.contains(goalId) || !knownGoalIds.contains(goalId);

  return [
    for (final log in logs)
      if (log['value'] != null && isHealthDerived(log['goal_id']))
        {...log, 'value': null}
      else
        log,
  ];
}

/// Page size for the windowed existing-state reads of the cloud import. A single
/// unbounded PostgREST `select` is capped by the project's `db-max-rows` (1000
/// by default), so a read built from one silently returns a PARTIAL view of the
/// account: Replace would then prune only the rows it happened to see, and the
/// streak recompute would derive streaks from a truncated history and write them
/// back over the correct values.
const int kImportPageSize = 1000;

/// Fetches one window of rows. Abstracted so the paging loop is unit-testable
/// without a live Supabase client.
typedef ImportPageFetcher =
    Future<List<Map<String, dynamic>>> Function(int offset, int limit);

/// Concatenates every page from [fetchPage], requesting successive windows
/// until a short (final) page comes back. [fetchPage] must impose a stable
/// total order, otherwise windows can repeat or skip rows.
///
/// Mirrors `fetchAllRowsPaginated` in the desktop app's settings page, which
/// windows the export reads for the same reason.
Future<List<Map<String, dynamic>>> fetchAllRowsPaginated(
  ImportPageFetcher fetchPage, {
  int pageSize = kImportPageSize,
}) async {
  final rows = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    final page = await fetchPage(offset, pageSize);
    rows.addAll(page);
    if (page.length < pageSize) break;
    offset += pageSize;
  }
  return rows;
}

/// Reads a backup file (the app's own `.json` export OR a web `.zip` backup),
/// normalizes it, and imports it into the active store (Private or Cloud) either
/// by replacing existing data or by a true identity-based merge.
class BackupImportService {
  final PrivateDataStore _privateStore;
  final SupabaseClient? _supabase;
  static const _uuid = Uuid();

  BackupImportService(this._privateStore, this._supabase);

  /// Parses + normalizes the file at [filePath] and returns a preview with the
  /// per-entity counts and the canonical data to import. Accepts a `.zip`
  /// (web backup, containing `backup.json`) or a raw `.json` (app export).
  Future<BackupImportPreview> parsePreview(String filePath) async {
    final raw = await _readBackupFile(filePath);
    final validated = validateCanonical(normalizeBackup(raw));
    final canonical = validated.canonical;
    return BackupImportPreview(
      habitsCount: (canonical[kGoalsKey] as List).length,
      logsCount: (canonical[kLogsKey] as List).length,
      macroGoalsCount: (canonical[kMacrosKey] as List).length,
      categoriesCount: (canonical[kCategoriesKey] as List).length,
      moodsCount: (canonical[kMoodsKey] as List).length,
      canonicalData: canonical,
      skipped: validated.skipped,
    );
  }

  Future<Map<String, dynamic>> _readBackupFile(String filePath) async {
    final file = File(filePath);
    final lower = filePath.toLowerCase();

    if (lower.endsWith('.zip')) {
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      // Prefer backup.json (web export), else the first JSON in the archive.
      ArchiveFile? entry;
      for (final f in archive) {
        if (f.isFile && f.name.endsWith('backup.json')) {
          entry = f;
          break;
        }
      }
      entry ??= archive.files.cast<ArchiveFile?>().firstWhere(
            (f) => f!.isFile && f.name.toLowerCase().endsWith('.json'),
            orElse: () => null,
          );
      if (entry == null) {
        throw const FormatException('No backup.json found in ZIP');
      }
      return jsonDecode(utf8.decode(entry.content as List<int>))
          as Map<String, dynamic>;
    }

    // Raw JSON (the app's own export).
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  /// Imports already-validated [canonicalData] into the active store and returns
  /// the per-entity merge outcome. [skipped] (from [parsePreview]) is folded into
  /// the result so the summary can report how many rows were dropped as invalid.
  Future<ImportMergeStats> executeImport({
    required Map<String, dynamic> canonicalData,
    required bool replaceExisting,
    required bool isPrivateMode,
    Map<String, int> skipped = const {},
  }) async {
    final stats = isPrivateMode
        ? await _privateStore.importData(
            backupData: canonicalData,
            replaceExisting: replaceExisting,
          )
        : await _executeCloudImport(canonicalData, replaceExisting);

    stats.habits.skipped = skipped['habits'] ?? 0;
    stats.logs.skipped = skipped['logs'] ?? 0;
    stats.macroGoals.skipped = skipped['macroGoals'] ?? 0;
    stats.categories.skipped = skipped['categories'] ?? 0;
    stats.moods.skipped = skipped['moods'] ?? 0;
    return stats;
  }

  // ── Cloud (Supabase) import ────────────────────────────────────────────────
  //
  // Mirrors the Private-mode merge (identity + last-write-wins), but since
  // Supabase has no client-side transaction, the entire plan is computed from
  // the fetched existing state FIRST — so a malformed file can never delete data
  // and then fail. Only once the plan is built do we mutate the server.

  Future<ImportMergeStats> _executeCloudImport(
      Map<String, dynamic> canonical, bool replaceExisting) async {
    final client = _supabase;
    if (client == null) {
      throw Exception('Supabase is not initialized but cloud import requested.');
    }
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in to cloud');

    final now = DateTime.now().toUtc().toIso8601String();

    // Fetch existing state (empty in replace mode) BEFORE building the plan.
    // Windowed: the plan classifies an incoming row as new when it finds no
    // match here, so a row hidden past the row cap would be re-inserted under a
    // fresh id and collide with the table's natural-key UNIQUE constraint.
    Future<List<Map<String, dynamic>>> fetch(String table, String cols) async {
      if (replaceExisting) return const [];
      return fetchAllRowsPaginated((offset, limit) async {
        final res = await client
            .from(table)
            .select(cols)
            .eq('user_id', userId)
            .order('id')
            .range(offset, offset + limit - 1);
        return (res as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      });
    }

    final existingCategories =
        await fetch('macro_goal_categories', 'id,name,archived_at');
    final existingGoals = {
      for (final r in await fetch('goals', 'id,updated_at'))
        r['id'] as String: r['updated_at'] as String?,
    };
    final existingMacros = {
      for (final r in await fetch('long_term_goals', 'id,updated_at'))
        r['id'] as String: r['updated_at'] as String?,
    };
    final existingLogs = {
      for (final r in await fetch('goal_logs', 'id,goal_id,date,updated_at'))
        '${r['goal_id']}|${r['date']}': r,
    };
    final existingMoods = {
      for (final r in await fetch('daily_moods', 'id,date,updated_at'))
        r['date'] as String: r,
    };

    // Build the whole plan with NO writes — validate-before-delete.
    final plan = planCloudImport(
      userId: userId,
      canonical: canonical,
      replaceExisting: replaceExisting,
      now: now,
      existingCategories: existingCategories,
      existingGoals: existingGoals,
      existingMacros: existingMacros,
      existingLogs: existingLogs,
      existingMoods: existingMoods,
      newId: () => _uuid.v4(),
    );

    // Fill archived_at on existing categories — bare update, no updated_at
    // (the cloud macro_goal_categories table has no such column).
    for (final f in plan.categoryArchiveFills) {
      await client
          .from('macro_goal_categories')
          .update({'archived_at': f.archivedAt}).eq('id', f.id);
    }

    // Write parents before children so foreign keys resolve. In REPLACE mode we
    // upsert the backup rows FIRST and only AFTERWARDS delete the rows the backup
    // doesn't contain — so a mid-import failure (network drop, RLS error, app
    // kill) leaves a superset (a few stale rows), never an emptied account.
    // The previous order deleted everything first, so any failure before the
    // re-insert wiped the data with no client-side transaction to roll it back.
    await _bulkUpsert(client, 'macro_goal_categories', plan.categories);
    await _bulkUpsert(client, 'goals', plan.goals);
    await _bulkUpsert(client, 'long_term_goals', plan.macros);
    await _bulkUpsert(
      client,
      'goal_logs',
      stripHealthMeasurements(
        logs: plan.logs,
        backupGoals: canonical[kGoalsKey],
      ),
    );
    await _bulkUpsert(client, 'daily_moods', plan.moods);

    if (replaceExisting) {
      // Remove this user's rows that aren't part of the backup, children before
      // parents so foreign keys resolve. Each table is pruned to exactly the
      // backup's rows without ever passing through an empty state.
      await _deleteComplement(client, 'goal_logs', userId, plan.logs);
      await _deleteComplement(client, 'daily_moods', userId, plan.moods);
      await _deleteComplement(client, 'long_term_goals', userId, plan.macros);
      await _deleteComplement(client, 'goals', userId, plan.goals);
      await _deleteComplement(
          client, 'macro_goal_categories', userId, plan.categories);
    }

    await _recomputeCloudStreaks(client, userId, plan.affectedGoals);

    return plan.stats;
  }

  /// Deletes the user's rows in [table] whose id is NOT among the just-upserted
  /// backup rows [keep]. Fetches the existing ids and deletes only the
  /// difference (in id chunks), so replacing never empties the table first — the
  /// atomicity guarantee the delete-then-upsert order lacked.
  ///
  /// The id read is windowed: the complement is only as complete as the set it
  /// is computed against, so a single capped read would silently leave every
  /// row past the cap in place — the opposite of what Replace promises.
  Future<void> _deleteComplement(
    SupabaseClient client,
    String table,
    String userId,
    List<Map<String, dynamic>> keep,
  ) async {
    final keepIds = keep.map((r) => r['id'] as String).toSet();
    final existing = await fetchAllRowsPaginated((offset, limit) async {
      final res = await client
          .from(table)
          .select('id')
          .eq('user_id', userId)
          .order('id')
          .range(offset, offset + limit - 1);
      return (res as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    });
    final toDelete = existing
        .map((r) => r['id'] as String)
        .where((id) => !keepIds.contains(id))
        .toList();
    if (toDelete.isEmpty) return;
    const chunk = 200;
    for (var i = 0; i < toDelete.length; i += chunk) {
      final end = (i + chunk < toDelete.length) ? i + chunk : toDelete.length;
      await client
          .from(table)
          .delete()
          .eq('user_id', userId)
          .inFilter('id', toDelete.sublist(i, end));
    }
  }

  Future<void> _bulkUpsert(
    SupabaseClient client,
    String table,
    List<Map<String, dynamic>> rows, {
    String onConflict = 'id',
  }) async {
    if (rows.isEmpty) return;
    const chunk = 500;
    for (var i = 0; i < rows.length; i += chunk) {
      final end = (i + chunk < rows.length) ? i + chunk : rows.length;
      await client.from(table).upsert(rows.sublist(i, end), onConflict: onConflict);
    }
  }

  /// Recomputes `goal_logs.streak` over the merged history for [goalIds] and
  /// writes back the rows that changed. Best-effort: a failure here never fails
  /// the import (the data landed; only the denormalized streak may be stale).
  ///
  /// Bounded network cost: two reads (start dates + all affected logs) and one
  /// chunked bulk upsert of the changed rows — not one UPDATE per log.
  Future<void> _recomputeCloudStreaks(
      SupabaseClient client, String userId, Set<String> goalIds) async {
    if (goalIds.isEmpty) return;
    try {
      final ids = goalIds.toList();

      final goalRes = await client.from('goals').select('id,start_date').inFilter(
          'id', ids);
      final startById = {
        for (final r in (goalRes as List)
            .map((e) => (e as Map).cast<String, dynamic>()))
          r['id'] as String:
              DateTime.tryParse((r['start_date'] as String?) ?? '') ??
                  DateTime(2000),
      };

      // Windowed: a streak computed from a truncated history is wrong, and it
      // gets written back over the correct value — so the full log set for the
      // affected goals has to be read past the row cap.
      final logRes = await fetchAllRowsPaginated((offset, limit) async {
        final res = await client
            .from('goal_logs')
            .select()
            .inFilter('goal_id', ids)
            .order('id')
            .range(offset, offset + limit - 1);
        return (res as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      });
      final byGoal = <String, List<Map<String, dynamic>>>{};
      for (final r in logRes) {
        (byGoal[r['goal_id'] as String] ??= []).add(r);
      }

      final changed = <Map<String, dynamic>>[];
      for (final goalId in ids) {
        final rows = byGoal[goalId] ?? const [];
        final startDate = startById[goalId] ?? DateTime(2000);
        final map = <String, Map<String, String>>{};
        final dateByRow = <Map<String, dynamic>, DateTime>{};
        for (final r in rows) {
          final d = DateTime.tryParse(r['date'] as String);
          if (d == null) continue;
          final key =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          (map[key] ??= <String, String>{})[goalId] = r['status'] as String;
          dateByRow[r] = d;
        }
        for (final r in rows) {
          final d = dateByRow[r];
          if (d == null) continue;
          final newStreak = computeStreak(
              habitId: goalId, date: d, logs: map, startDate: startDate);
          if (newStreak != ((r['streak'] as num?)?.toInt() ?? 0)) {
            changed.add({...r, 'streak': newStreak});
          }
        }
      }

      await _bulkUpsert(client, 'goal_logs', changed);
    } catch (e, s) {
      AppLogger.warning('[Import] cloud streak recompute failed', e, s);
    }
  }

}
