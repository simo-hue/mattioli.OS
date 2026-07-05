import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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
    Future<List<Map<String, dynamic>>> fetch(String table, String cols) async {
      if (replaceExisting) return const [];
      final res = await client.from(table).select(cols).eq('user_id', userId);
      return (res as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
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

    // Only now mutate the server.
    if (replaceExisting) {
      await client.from('goal_logs').delete().eq('user_id', userId);
      await client.from('daily_moods').delete().eq('user_id', userId);
      await client.from('long_term_goals').delete().eq('user_id', userId);
      await client.from('macro_goal_categories').delete().eq('user_id', userId);
      await client.from('goals').delete().eq('user_id', userId);
    }

    // Fill archived_at on existing categories — bare update, no updated_at
    // (the cloud macro_goal_categories table has no such column).
    for (final f in plan.categoryArchiveFills) {
      await client
          .from('macro_goal_categories')
          .update({'archived_at': f.archivedAt}).eq('id', f.id);
    }

    // Write parents before children so foreign keys resolve.
    await _bulkUpsert(client, 'macro_goal_categories', plan.categories);
    await _bulkUpsert(client, 'goals', plan.goals);
    await _bulkUpsert(client, 'long_term_goals', plan.macros);
    await _bulkUpsert(client, 'goal_logs', plan.logs);
    await _bulkUpsert(client, 'daily_moods', plan.moods);

    await _recomputeCloudStreaks(client, userId, plan.affectedGoals);

    return plan.stats;
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
  Future<void> _recomputeCloudStreaks(
      SupabaseClient client, String userId, Set<String> goalIds) async {
    if (goalIds.isEmpty) return;
    try {
      for (final goalId in goalIds) {
        final goalRes = await client
            .from('goals')
            .select('start_date')
            .eq('id', goalId)
            .maybeSingle();
        final startDate = DateTime.tryParse(
                (goalRes?['start_date'] as String?) ?? '') ??
            DateTime(2000);

        final logRes = await client
            .from('goal_logs')
            .select('id,date,status,streak')
            .eq('goal_id', goalId);
        final logRows =
            (logRes as List).map((e) => (e as Map).cast<String, dynamic>());

        final map = <String, Map<String, String>>{};
        final dateById = <String, DateTime>{};
        for (final r in logRows) {
          final d = DateTime.tryParse(r['date'] as String);
          if (d == null) continue;
          final key =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          (map[key] ??= <String, String>{})[goalId] = r['status'] as String;
          dateById[r['id'] as String] = d;
        }

        for (final r in logRows) {
          final id = r['id'] as String;
          final d = dateById[id];
          if (d == null) continue;
          final newStreak = computeStreak(
              habitId: goalId, date: d, logs: map, startDate: startDate);
          if (newStreak != ((r['streak'] as num?)?.toInt() ?? 0)) {
            await client.from('goal_logs').update({'streak': newStreak}).eq('id', id);
          }
        }
      }
    } catch (e, s) {
      AppLogger.warning('[Import] cloud streak recompute failed', e, s);
    }
  }

}
