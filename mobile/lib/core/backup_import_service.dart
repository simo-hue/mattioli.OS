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

  /// Canonical, normalized backup — feed straight to [BackupImportService.executeImport].
  final Map<String, dynamic> canonicalData;

  const BackupImportPreview({
    required this.habitsCount,
    required this.logsCount,
    required this.macroGoalsCount,
    required this.categoriesCount,
    required this.moodsCount,
    required this.canonicalData,
  });
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
    final canonical = normalizeBackup(raw);
    return BackupImportPreview(
      habitsCount: (canonical[kGoalsKey] as List).length,
      logsCount: (canonical[kLogsKey] as List).length,
      macroGoalsCount: (canonical[kMacrosKey] as List).length,
      categoriesCount: (canonical[kCategoriesKey] as List).length,
      moodsCount: (canonical[kMoodsKey] as List).length,
      canonicalData: canonical,
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

  /// Imports already-normalized [canonicalData] into the active store and returns
  /// the per-entity merge outcome.
  Future<ImportMergeStats> executeImport({
    required Map<String, dynamic> canonicalData,
    required bool replaceExisting,
    required bool isPrivateMode,
  }) async {
    if (isPrivateMode) {
      return _privateStore.importData(
        backupData: canonicalData,
        replaceExisting: replaceExisting,
      );
    }
    return _executeCloudImport(canonicalData, replaceExisting);
  }

  // ── Cloud (Supabase) import ────────────────────────────────────────────────
  //
  // Mirrors the Private-mode merge semantics (identity + last-write-wins) but
  // over Supabase: existing rows are fetched to decide add/update/skip, then
  // only the rows that should win are upserted. Streaks are recomputed for the
  // goals whose logs changed.

  Future<ImportMergeStats> _executeCloudImport(
      Map<String, dynamic> canonical, bool replaceExisting) async {
    final client = _supabase;
    if (client == null) {
      throw Exception('Supabase is not initialized but cloud import requested.');
    }
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in to cloud');

    final stats = ImportMergeStats(replaced: replaceExisting);
    final now = DateTime.now().toUtc().toIso8601String();

    final categories = _rows(canonical[kCategoriesKey]);
    final goals = _rows(canonical[kGoalsKey]);
    final logs = _rows(canonical[kLogsKey]);
    final macros = _rows(canonical[kMacrosKey]);
    final moods = _rows(canonical[kMoodsKey]);

    if (replaceExisting) {
      await client.from('goal_logs').delete().eq('user_id', userId);
      await client.from('daily_moods').delete().eq('user_id', userId);
      await client.from('long_term_goals').delete().eq('user_id', userId);
      await client.from('macro_goal_categories').delete().eq('user_id', userId);
      await client.from('goals').delete().eq('user_id', userId);
    }

    Future<List<Map<String, dynamic>>> existing(
        String table, String columns) async {
      if (replaceExisting) return const [];
      final res =
          await client.from(table).select(columns).eq('user_id', userId);
      return (res as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    }

    // ── Categories: id, else name (existing wins). ──
    final exCats = await existing('macro_goal_categories', 'id,name,archived_at');
    final catById = {for (final c in exCats) c['id'] as String: c};
    final catByName = {
      for (final c in exCats) (c['name'] as String).trim().toLowerCase(): c,
    };
    final catRemap = <String, String>{};
    final validCatIds = <String>{for (final c in exCats) c['id'] as String};
    final catsToWrite = <Map<String, dynamic>>[];

    for (final cat in categories) {
      final importedId = (cat['id'] as String?) ?? _uuid.v4();
      final name = (cat['name'] as String? ?? '').trim();
      final match = catById[importedId] ?? catByName[name.toLowerCase()];
      if (match != null) {
        final finalId = match['id'] as String;
        catRemap[importedId] = finalId;
        validCatIds.add(finalId);
        final importedArchived = cat['archived_at'] as String?;
        if (match['archived_at'] == null && importedArchived != null) {
          await client
              .from('macro_goal_categories')
              .update({'archived_at': importedArchived, 'updated_at': now}).eq(
                  'id', finalId);
          stats.categories.updated++;
        } else {
          stats.categories.unchanged++;
        }
      } else {
        catRemap[importedId] = importedId;
        validCatIds.add(importedId);
        catsToWrite.add({
          'id': importedId,
          'user_id': userId,
          'name': cat['name'],
          'color': cat['color'],
          'created_at': cat['created_at'] ?? now,
          'updated_at': cat['updated_at'] ?? now,
          'archived_at': cat['archived_at'],
        });
        catByName[name.toLowerCase()] = {
          'id': importedId,
          'name': cat['name'],
          'archived_at': cat['archived_at'],
        };
        stats.categories.added++;
      }
    }

    // ── Goals ──
    final exGoals = {
      for (final r in await existing('goals', 'id,updated_at'))
        r['id'] as String: r['updated_at'] as String?,
    };
    final knownGoalIds = <String>{...exGoals.keys};
    final goalsToWrite = <Map<String, dynamic>>[];
    for (final g in goals) {
      final id = (g['id'] as String?) ?? _uuid.v4();
      final decision = _decide(
          id: id, incoming: g['updated_at'] as String?, existing: exGoals, has: exGoals.containsKey(id));
      if (decision == _Decision.skip) {
        stats.habits.unchanged++;
        continue;
      }
      knownGoalIds.add(id);
      goalsToWrite.add({
        'id': id,
        'user_id': userId,
        'title': g['title'],
        'description': g['description'],
        'icon': g['icon'],
        'color': g['color'] ?? '#3B82F6',
        'frequency_days': g['frequency_days'],
        'start_date': g['start_date'],
        'end_date': g['end_date'],
        'display_order': g['display_order'],
        'created_at': g['created_at'] ?? now,
        'updated_at': g['updated_at'] ?? now,
        'reminder_time': g['reminder_time'],
      });
      decision == _Decision.add ? stats.habits.added++ : stats.habits.updated++;
    }

    // ── Macro goals ──
    final exMacros = {
      for (final r in await existing('long_term_goals', 'id,updated_at'))
        r['id'] as String: r['updated_at'] as String?,
    };
    final macrosToWrite = <Map<String, dynamic>>[];
    for (final g in macros) {
      final id = (g['id'] as String?) ?? _uuid.v4();
      final importedCatId = g['category_id'] as String?;
      final remapped = importedCatId == null
          ? null
          : (catRemap[importedCatId] ?? importedCatId);
      final categoryId =
          (remapped != null && validCatIds.contains(remapped)) ? remapped : null;
      final decision = _decide(
          id: id, incoming: g['updated_at'] as String?, existing: exMacros, has: exMacros.containsKey(id));
      if (decision == _Decision.skip) {
        stats.macroGoals.unchanged++;
        continue;
      }
      macrosToWrite.add({
        'id': id,
        'user_id': userId,
        'title': g['title'],
        'status': g['status'],
        'type': g['type'],
        'year': g['year'],
        'month': g['month'],
        'week_number': g['week_number'],
        'quarter': g['quarter'],
        'category_key': g['category_key'],
        'category_id': categoryId,
        'created_at': g['created_at'] ?? now,
        'updated_at': g['updated_at'] ?? now,
      });
      decision == _Decision.add
          ? stats.macroGoals.added++
          : stats.macroGoals.updated++;
    }

    // ── Goal logs: natural key (goal_id, date); reuse existing id on update. ──
    final exLogs = {
      for (final r in await existing('goal_logs', 'id,goal_id,date,updated_at'))
        '${r['goal_id']}|${r['date']}': r,
    };
    final affectedGoals = <String>{};
    final logsToWrite = <Map<String, dynamic>>[];
    for (final l in logs) {
      final goalId = l['goal_id'] as String?;
      final date = l['date'] as String?;
      if (goalId == null || date == null || !knownGoalIds.contains(goalId)) {
        continue;
      }
      final match = exLogs['$goalId|$date'];
      if (match == null) {
        logsToWrite.add({
          'id': (l['id'] as String?) ?? _uuid.v4(),
          'user_id': userId,
          'goal_id': goalId,
          'date': date,
          'status': l['status'],
          'value': l['value'],
          'created_at': l['created_at'] ?? now,
          'updated_at': l['updated_at'] ?? now,
          'streak': l['streak'] ?? 0,
        });
        affectedGoals.add(goalId);
        stats.logs.added++;
      } else if (incomingWins(
          incoming: l['updated_at'] as String?,
          existing: match['updated_at'] as String?)) {
        logsToWrite.add({
          'id': match['id'], // reuse to update in place, not duplicate
          'user_id': userId,
          'goal_id': goalId,
          'date': date,
          'status': l['status'],
          'value': l['value'],
          'created_at': l['created_at'] ?? now,
          'updated_at': l['updated_at'] ?? now,
          'streak': l['streak'] ?? 0,
        });
        affectedGoals.add(goalId);
        stats.logs.updated++;
      } else {
        stats.logs.unchanged++;
      }
    }

    // ── Daily moods: natural key date; reuse existing id on update. ──
    final exMoods = {
      for (final r in await existing('daily_moods', 'id,date,updated_at'))
        r['date'] as String: r,
    };
    final moodsToWrite = <Map<String, dynamic>>[];
    for (final m in moods) {
      final date = m['date'] as String?;
      if (date == null) continue;
      final match = exMoods[date];
      if (match == null) {
        moodsToWrite.add({
          'id': (m['id'] as String?) ?? _uuid.v4(),
          'user_id': userId,
          'date': date,
          'mood_score': m['mood_score'],
          'energy_score': m['energy_score'],
          'created_at': m['created_at'] ?? now,
          'updated_at': m['updated_at'] ?? now,
        });
        stats.moods.added++;
      } else if (incomingWins(
          incoming: m['updated_at'] as String?,
          existing: match['updated_at'] as String?)) {
        moodsToWrite.add({
          'id': match['id'],
          'user_id': userId,
          'date': date,
          'mood_score': m['mood_score'],
          'energy_score': m['energy_score'],
          'created_at': m['created_at'] ?? now,
          'updated_at': m['updated_at'] ?? now,
        });
        stats.moods.updated++;
      } else {
        stats.moods.unchanged++;
      }
    }

    // Write parents before children so foreign keys resolve.
    await _bulkUpsert(client, 'macro_goal_categories', catsToWrite);
    await _bulkUpsert(client, 'goals', goalsToWrite);
    await _bulkUpsert(client, 'long_term_goals', macrosToWrite);
    await _bulkUpsert(client, 'goal_logs', logsToWrite);
    await _bulkUpsert(client, 'daily_moods', moodsToWrite);

    await _recomputeCloudStreaks(client, userId, affectedGoals);

    return stats;
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

  List<Map<String, dynamic>> _rows(dynamic v) =>
      (v as List?)?.map((e) => (e as Map).cast<String, dynamic>()).toList() ??
      const [];

  _Decision _decide({
    required String id,
    required String? incoming,
    required Map<String, String?> existing,
    required bool has,
  }) {
    if (!has) return _Decision.add;
    return incomingWins(incoming: incoming, existing: existing[id])
        ? _Decision.update
        : _Decision.skip;
  }
}

enum _Decision { add, update, skip }
