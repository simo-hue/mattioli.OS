/// Data-import normalization + merge engine, shared by Private mode (SQLCipher,
/// via [applyPrivateImportMerge]) and Cloud mode (Supabase, via
/// `BackupImportService`). Extracted from the store so the logic can run — and
/// be unit-tested — against a plain in-memory SQLite database, independent of
/// encryption and of the network.
///
/// Two concerns live here:
///   1. [normalizeBackup] turns any supported backup shape (web ZIP export OR
///      the app's own JSON export, current or legacy) into ONE canonical
///      structure with stable IDs and hex colors.
///   2. [applyPrivateImportMerge] reconciles that canonical data into a local
///      database, either by replacing everything or by a true identity-based
///      merge with last-write-wins conflict resolution.
library;

import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'import_merge_stats.dart';
import 'streak_utils.dart';

const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// Normalization
// ─────────────────────────────────────────────────────────────────────────────

/// Canonical keys the merge engine consumes. Both source shapes map onto these.
const kGoalsKey = 'goals';
const kLogsKey = 'goal_logs';
const kMacrosKey = 'long_term_goals';
const kCategoriesKey = 'macro_goal_categories';
const kMoodsKey = 'daily_moods';

/// True if [raw] is the app's own export shape (`habits`/`macroGoals`/…) rather
/// than the web app's backup shape (`goals`/`goal_logs`/`goal_category_settings`).
bool _isNativeShape(Map<String, dynamic> raw) =>
    raw['mode'] == 'private' ||
    raw.containsKey('habits') ||
    raw.containsKey('macroGoals') ||
    raw.containsKey('habitLogs') ||
    raw.containsKey('dailyMoods') ||
    raw.containsKey('macroGoalCategories');

/// Normalizes any supported backup into the canonical structure:
/// `{ goals, goal_logs, long_term_goals, macro_goal_categories, daily_moods }`
/// where every list is `List<Map<String, dynamic>>`, colors are hex, category
/// rows are materialized (with ids), and every record keeps its **original**
/// id so a re-import can be deduplicated by identity rather than duplicated.
Map<String, dynamic> normalizeBackup(Map<String, dynamic> raw) {
  return _isNativeShape(raw) ? _normalizeNative(raw) : _normalizeWeb(raw);
}

List<Map<String, dynamic>> _asList(dynamic v) =>
    (v as List?)?.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() ??
    <Map<String, dynamic>>[];

/// Web app backup shape. Categories live in `goal_category_settings.mappings`
/// keyed by color slug (no stable id), colors are `hsl(...)`, and macro goals
/// reference a category by its color slug.
Map<String, dynamic> _normalizeWeb(Map<String, dynamic> raw) {
  final categorySettings = raw['goal_category_settings'] as Map<String, dynamic>?;
  final mappings =
      categorySettings?['mappings'] as Map<String, dynamic>? ?? const {};
  final createdAt = categorySettings?['created_at'] as String?;

  // Synthesize a category id per color slug. Cross-source identity for these is
  // by NAME at merge time (there is no stable web category id), so a fresh id
  // here is fine — the merge dedups it against an existing same-named category.
  final colorSlugToId = <String, String>{};
  final categories = <Map<String, dynamic>>[];
  mappings.forEach((slug, value) {
    final id = _uuid.v4();
    colorSlugToId[slug] = id;
    String name = slug;
    String color = '#6B7280';
    if (value is String) {
      name = value;
    } else if (value is Map) {
      name = value['label'] as String? ?? slug;
      final c = value['color'] as String?;
      if (c != null) color = _hslToHex(c);
    }
    categories.add({
      'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt,
      'updated_at': null,
      'archived_at': null,
    });
  });

  final goals = <Map<String, dynamic>>[];
  for (final g in _asList(raw['goals'])) {
    goals.add({
      'id': g['id'],
      'title': g['title'],
      'description': g['description'],
      'icon': g['icon'],
      'color': g['color'] != null ? _hslToHex(g['color'] as String) : '#3B82F6',
      'frequency_days': g['frequency_days'],
      'start_date': g['start_date'],
      'end_date': g['end_date'],
      'display_order': g['display_order'],
      'created_at': g['created_at'],
      'updated_at': g['updated_at'],
      'reminder_time': g['reminder_time'],
    });
  }

  final logs = <Map<String, dynamic>>[];
  for (final l in _asList(raw['goal_logs'])) {
    logs.add({
      'id': l['id'],
      'goal_id': l['goal_id'],
      'date': l['date'],
      'status': l['status'],
      'value': l['value'],
      'created_at': l['created_at'],
      'updated_at': l['updated_at'],
    });
  }

  final macros = <Map<String, dynamic>>[];
  for (final g in _asList(raw['long_term_goals'])) {
    final slug = g['color'] as String?;
    macros.add({
      'id': g['id'],
      'title': g['title'],
      'status': g['status'],
      'type': g['type'],
      'year': g['year'],
      'month': g['month'],
      'week_number': g['week_number'],
      'quarter': g['quarter'],
      'category_key': null,
      'category_id': slug != null ? colorSlugToId[slug] : null,
      'created_at': g['created_at'],
      'updated_at': g['updated_at'],
    });
  }

  final moods = <Map<String, dynamic>>[];
  for (final m in _asList(raw['daily_moods'])) {
    moods.add({
      'id': m['id'],
      'date': m['date'],
      'mood_score': m['mood_score'],
      'energy_score': m['energy_score'],
      'created_at': m['created_at'],
      'updated_at': m['updated_at'],
    });
  }

  return {
    kGoalsKey: goals,
    kLogsKey: logs,
    kMacrosKey: macros,
    kCategoriesKey: categories,
    kMoodsKey: moods,
  };
}

/// The app's own export shape. Colors are already hex and categories are real
/// rows. Tolerates BOTH the current export (logs/moods as lists of full rows,
/// with timestamps) and legacy exports (logs/moods as `date -> {...}` maps).
Map<String, dynamic> _normalizeNative(Map<String, dynamic> raw) {
  final goals = <Map<String, dynamic>>[];
  for (final g in _asList(raw['habits'])) {
    goals.add({
      'id': g['id'],
      'title': g['title'],
      'description': g['description'],
      'icon': g['icon'],
      'color': g['color'] ?? '#3B82F6',
      'frequency_days': g['frequency_days'],
      'start_date': g['start_date'],
      'end_date': g['end_date'],
      'display_order': g['display_order'],
      'created_at': g['created_at'],
      'updated_at': g['updated_at'],
      'reminder_time': g['reminder_time'],
    });
  }

  final logs = <Map<String, dynamic>>[];
  final rawLogs = raw['habitLogs'];
  if (rawLogs is List) {
    for (final l in _asList(rawLogs)) {
      logs.add({
        'id': l['id'],
        'goal_id': l['goal_id'],
        'date': l['date'],
        'status': l['status'],
        'value': l['value'],
        'created_at': l['created_at'],
        'updated_at': l['updated_at'],
        'streak': l['streak'],
      });
    }
  } else if (rawLogs is Map) {
    // Legacy shape: { 'yyyy-MM-dd': { goalId: status } } — no per-log id or
    // timestamps, so synthesize an id and leave timestamps null (treated as
    // oldest on merge, which is correct for a lossy legacy file).
    rawLogs.forEach((date, byGoal) {
      if (byGoal is! Map) return;
      byGoal.forEach((goalId, status) {
        logs.add({
          'id': null,
          'goal_id': goalId,
          'date': date,
          'status': status,
          'value': null,
          'created_at': null,
          'updated_at': null,
        });
      });
    });
  }

  final macros = <Map<String, dynamic>>[];
  for (final g in _asList(raw['macroGoals'])) {
    macros.add({
      'id': g['id'],
      'title': g['title'],
      'status': g['status'],
      'type': g['type'],
      'year': g['year'],
      'month': g['month'],
      'week_number': g['week_number'],
      'quarter': g['quarter'],
      'category_key': g['category_key'],
      'category_id': g['category_id'],
      'created_at': g['created_at'],
      'updated_at': g['updated_at'],
    });
  }

  final categories = <Map<String, dynamic>>[];
  for (final c in _asList(raw['macroGoalCategories'])) {
    categories.add({
      'id': c['id'],
      'name': c['name'],
      'color': c['color'] ?? '#6B7280',
      'created_at': c['created_at'],
      'updated_at': c['updated_at'],
      'archived_at': c['archived_at'],
    });
  }

  final moods = <Map<String, dynamic>>[];
  final rawMoods = raw['dailyMoods'];
  if (rawMoods is List) {
    for (final m in _asList(rawMoods)) {
      moods.add({
        'id': m['id'],
        'date': m['date'],
        'mood_score': m['mood_score'],
        'energy_score': m['energy_score'],
        'created_at': m['created_at'],
        'updated_at': m['updated_at'],
      });
    }
  } else if (rawMoods is Map) {
    rawMoods.forEach((date, m) {
      if (m is! Map) return;
      moods.add({
        'id': m['id'],
        'date': m['date'] ?? date,
        'mood_score': m['mood_score'],
        'energy_score': m['energy_score'],
        'created_at': m['created_at'],
        'updated_at': m['updated_at'],
      });
    });
  }

  return {
    kGoalsKey: goals,
    kLogsKey: logs,
    kMacrosKey: macros,
    kCategoriesKey: categories,
    kMoodsKey: moods,
  };
}

/// Best-effort `hsl(H S% L%)` → `#RRGGBB`. Passes through non-HSL strings (they
/// are already hex) and falls back to a neutral blue on parse failure.
String _hslToHex(String hsl) {
  try {
    if (!hsl.startsWith('hsl')) return hsl;
    final match = RegExp(r'hsl\(\s*([\d.]+)\s+([\d.]+)%\s+([\d.]+)%\s*\)')
        .firstMatch(hsl);
    if (match == null) return '#3B82F6';
    final h = double.parse(match.group(1)!);
    final s = double.parse(match.group(2)!) / 100.0;
    final l = double.parse(match.group(3)!) / 100.0;

    final c = (1.0 - (2.0 * l - 1.0).abs()) * s;
    final x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
    final m = l - c / 2.0;

    double r = 0, g = 0, b = 0;
    if (h < 60) {
      r = c;
      g = x;
    } else if (h < 120) {
      r = x;
      g = c;
    } else if (h < 180) {
      g = c;
      b = x;
    } else if (h < 240) {
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }

    String hex(double v) => (((v + m) * 255).round())
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();
    return '#${hex(r)}${hex(g)}${hex(b)}';
  } catch (_) {
    return '#3B82F6';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private-mode merge (SQLite / SQLCipher)
// ─────────────────────────────────────────────────────────────────────────────

/// Applies canonical [canonical] backup data to the local database via [txn].
///
/// When [replaceExisting] is true, wipes the five user-data tables first and
/// inserts everything fresh (profile/settings are left untouched). When false,
/// performs a **true merge**: records are matched by identity and reconciled
/// with last-write-wins —
///   - goals & macro goals by `id`;
///   - goal logs by their natural key `(goal_id, date)`;
///   - daily moods by their natural key `date`;
///   - categories by `id`, else by case-insensitive name (existing wins on a
///     match; only a missing `archived_at` is filled from the import).
///
/// Streaks are recomputed from the merged log history for every goal whose logs
/// changed, so denormalized `goal_logs.streak` is never trusted from the file.
///
/// Must be called inside a transaction. [now] is the ISO timestamp for records
/// that lack one; [newId] mints ids for records imported without one.
Future<ImportMergeStats> applyPrivateImportMerge({
  required Transaction txn,
  required String owner,
  required Map<String, dynamic> canonical,
  required bool replaceExisting,
  required String now,
  required String Function() newId,
}) async {
  final stats = ImportMergeStats(replaced: replaceExisting);

  final categories = _asList(canonical[kCategoriesKey]);
  final goals = _asList(canonical[kGoalsKey]);
  final logs = _asList(canonical[kLogsKey]);
  final macros = _asList(canonical[kMacrosKey]);
  final moods = _asList(canonical[kMoodsKey]);

  if (replaceExisting) {
    await txn.delete('goal_logs');
    await txn.delete('daily_moods');
    await txn.delete('long_term_goals');
    await txn.delete('macro_goal_categories');
    await txn.delete('goals');
  }

  // ── Categories: id, else name. macro_goal_categories has UNIQUE(user_id,name)
  // so a same-name insert would collide; matching by name and remapping the
  // referencing macro goals is mandatory, not just nice-to-have. ──
  final existingCats = replaceExisting
      ? const <Map<String, Object?>>[]
      : await txn.query('macro_goal_categories',
          columns: ['id', 'name', 'archived_at'],
          where: 'user_id = ?',
          whereArgs: [owner]);
  final catById = {for (final c in existingCats) c['id'] as String: c};
  final catByName = {
    for (final c in existingCats)
      (c['name'] as String).trim().toLowerCase(): c,
  };
  final catRemap = <String, String>{}; // imported id -> final (existing) id
  final validCatIds = <String>{for (final c in existingCats) c['id'] as String};

  for (final cat in categories) {
    final importedId = (cat['id'] as String?) ?? newId();
    final name = (cat['name'] as String? ?? '').trim();
    final existing = catById[importedId] ?? catByName[name.toLowerCase()];
    if (existing != null) {
      final finalId = existing['id'] as String;
      catRemap[importedId] = finalId;
      validCatIds.add(finalId);
      final importedArchived = cat['archived_at'] as String?;
      if (existing['archived_at'] == null && importedArchived != null) {
        await txn.update('macro_goal_categories',
            {'archived_at': importedArchived, 'updated_at': now},
            where: 'id = ?', whereArgs: [finalId]);
        stats.categories.updated++;
      } else {
        stats.categories.unchanged++;
      }
    } else {
      catRemap[importedId] = importedId;
      validCatIds.add(importedId);
      await txn.insert('macro_goal_categories', {
        'id': importedId,
        'user_id': owner,
        'name': cat['name'],
        'color': cat['color'],
        'created_at': cat['created_at'] ?? now,
        'updated_at': cat['updated_at'] ?? now,
        'archived_at': cat['archived_at'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      // Record it so a later same-name imported category dedups onto it.
      catByName[name.toLowerCase()] = {
        'id': importedId,
        'name': cat['name'],
        'archived_at': cat['archived_at'],
      };
      stats.categories.added++;
    }
  }

  // ── Goals: identity by id, last-write-wins by updated_at. ──
  final existingGoals = replaceExisting
      ? const <String, Map<String, Object?>>{}
      : {
          for (final r in await txn.query('goals',
              columns: ['id', 'created_at', 'updated_at'],
              where: 'user_id = ?',
              whereArgs: [owner]))
            r['id'] as String: r,
        };
  final knownGoalIds = <String>{...existingGoals.keys};

  for (final g in goals) {
    final id = (g['id'] as String?) ?? newId();
    final existing = existingGoals[id];
    if (existing == null) {
      await txn.insert('goals', _goalRow(g, id, owner, now, now),
          conflictAlgorithm: ConflictAlgorithm.ignore);
      knownGoalIds.add(id);
      stats.habits.added++;
    } else if (incomingWins(
        incoming: g['updated_at'] as String?,
        existing: existing['updated_at'] as String?)) {
      await txn.update(
          'goals',
          _goalRow(g, id, owner, existing['created_at'] as String? ?? now, now),
          where: 'id = ?',
          whereArgs: [id]);
      stats.habits.updated++;
    } else {
      stats.habits.unchanged++;
    }
  }

  // ── Macro goals: identity by id, LWW; category_id remapped onto the merged
  // category, nulled if it would dangle (FK is ON DELETE SET NULL). ──
  final existingMacros = replaceExisting
      ? const <String, Map<String, Object?>>{}
      : {
          for (final r in await txn.query('long_term_goals',
              columns: ['id', 'created_at', 'updated_at'],
              where: 'user_id = ?',
              whereArgs: [owner]))
            r['id'] as String: r,
        };

  for (final g in macros) {
    final id = (g['id'] as String?) ?? newId();
    final importedCatId = g['category_id'] as String?;
    final remapped = importedCatId == null
        ? null
        : (catRemap[importedCatId] ?? importedCatId);
    final categoryId =
        (remapped != null && validCatIds.contains(remapped)) ? remapped : null;
    final existing = existingMacros[id];
    if (existing == null) {
      await txn.insert('long_term_goals',
          _macroRow(g, id, owner, categoryId, now, now),
          conflictAlgorithm: ConflictAlgorithm.ignore);
      stats.macroGoals.added++;
    } else if (incomingWins(
        incoming: g['updated_at'] as String?,
        existing: existing['updated_at'] as String?)) {
      await txn.update(
          'long_term_goals',
          _macroRow(g, id, owner, categoryId,
              existing['created_at'] as String? ?? now, now),
          where: 'id = ?',
          whereArgs: [id]);
      stats.macroGoals.updated++;
    } else {
      stats.macroGoals.unchanged++;
    }
  }

  // ── Goal logs: identity by (goal_id, date), LWW. Orphan logs (no goal) are
  // skipped to respect the FK. ──
  final existingLogs = replaceExisting
      ? const <String, Map<String, Object?>>{}
      : {
          for (final r in await txn.query('goal_logs',
              columns: ['id', 'goal_id', 'date', 'updated_at'],
              where: 'user_id = ?',
              whereArgs: [owner]))
            '${r['goal_id']}|${r['date']}': r,
        };
  final affectedGoals = <String>{};

  for (final l in logs) {
    final goalId = l['goal_id'] as String?;
    final date = l['date'] as String?;
    if (goalId == null || date == null || !knownGoalIds.contains(goalId)) {
      continue;
    }
    final key = '$goalId|$date';
    final existing = existingLogs[key];
    if (existing == null) {
      await txn.insert('goal_logs', {
        'id': (l['id'] as String?) ?? newId(),
        'user_id': owner,
        'goal_id': goalId,
        'date': date,
        'status': l['status'],
        'value': l['value'],
        'created_at': l['created_at'] ?? now,
        'updated_at': l['updated_at'] ?? now,
        'streak': l['streak'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      affectedGoals.add(goalId);
      stats.logs.added++;
    } else if (incomingWins(
        incoming: l['updated_at'] as String?,
        existing: existing['updated_at'] as String?)) {
      await txn.update('goal_logs', {
        'status': l['status'],
        'value': l['value'],
        'updated_at': l['updated_at'] ?? now,
      }, where: 'id = ?', whereArgs: [existing['id']]);
      affectedGoals.add(goalId);
      stats.logs.updated++;
    } else {
      stats.logs.unchanged++;
    }
  }

  // ── Daily moods: identity by date, LWW. ──
  final existingMoods = replaceExisting
      ? const <String, Map<String, Object?>>{}
      : {
          for (final r in await txn.query('daily_moods',
              columns: ['id', 'date', 'updated_at'],
              where: 'user_id = ?',
              whereArgs: [owner]))
            r['date'] as String: r,
        };

  for (final m in moods) {
    final date = m['date'] as String?;
    if (date == null) continue;
    final existing = existingMoods[date];
    if (existing == null) {
      await txn.insert('daily_moods', {
        'id': (m['id'] as String?) ?? newId(),
        'user_id': owner,
        'date': date,
        'mood_score': m['mood_score'],
        'energy_score': m['energy_score'],
        'created_at': m['created_at'] ?? now,
        'updated_at': m['updated_at'] ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      stats.moods.added++;
    } else if (incomingWins(
        incoming: m['updated_at'] as String?,
        existing: existing['updated_at'] as String?)) {
      await txn.update('daily_moods', {
        'mood_score': m['mood_score'],
        'energy_score': m['energy_score'],
        'updated_at': m['updated_at'] ?? now,
      }, where: 'id = ?', whereArgs: [existing['id']]);
      stats.moods.updated++;
    } else {
      stats.moods.unchanged++;
    }
  }

  // ── Recompute streaks over the merged history for every touched goal. ──
  await _recomputeStreaks(txn, affectedGoals);

  return stats;
}

Map<String, Object?> _goalRow(
  Map<String, dynamic> g,
  String id,
  String owner,
  String createdAt,
  String updatedAt,
) {
  final freq = g['frequency_days'];
  return {
    'id': id,
    'user_id': owner,
    'title': g['title'],
    'description': g['description'],
    'icon': g['icon'],
    'color': g['color'] ?? '#3B82F6',
    'frequency_days': freq == null ? null : jsonEncode(freq),
    'start_date': g['start_date'],
    'end_date': g['end_date'],
    'display_order': g['display_order'],
    'created_at': g['created_at'] ?? createdAt,
    'updated_at': g['updated_at'] ?? updatedAt,
    'reminder_time': g['reminder_time'],
  };
}

Map<String, Object?> _macroRow(
  Map<String, dynamic> g,
  String id,
  String owner,
  String? categoryId,
  String createdAt,
  String updatedAt,
) {
  return {
    'id': id,
    'user_id': owner,
    'title': g['title'],
    'status': g['status'],
    'type': g['type'],
    'year': g['year'],
    'month': g['month'],
    'week_number': g['week_number'],
    'quarter': g['quarter'],
    'category_key': g['category_key'],
    'category_id': categoryId,
    'created_at': g['created_at'] ?? createdAt,
    'updated_at': g['updated_at'] ?? updatedAt,
  };
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Recomputes the signed `streak` for every log of each goal in [goalIds] from
/// the full persisted history, and writes back only the rows whose streak
/// actually changed (minimizing sync churn).
Future<void> _recomputeStreaks(Transaction txn, Set<String> goalIds) async {
  for (final goalId in goalIds) {
    final goalRows = await txn.query('goals',
        columns: ['start_date'], where: 'id = ?', whereArgs: [goalId], limit: 1);
    if (goalRows.isEmpty) continue;
    final startDate =
        DateTime.tryParse(goalRows.first['start_date'] as String? ?? '') ??
            DateTime(2000);

    final logRows = await txn.query('goal_logs',
        columns: ['id', 'date', 'status', 'streak'],
        where: 'goal_id = ?',
        whereArgs: [goalId]);

    final map = <String, Map<String, String>>{};
    final dateById = <String, DateTime>{};
    for (final r in logRows) {
      final d = DateTime.tryParse(r['date'] as String);
      if (d == null) continue;
      (map[_dateKey(d)] ??= <String, String>{})[goalId] = r['status'] as String;
      dateById[r['id'] as String] = d;
    }

    for (final r in logRows) {
      final id = r['id'] as String;
      final d = dateById[id];
      if (d == null) continue;
      final newStreak = computeStreak(
          habitId: goalId, date: d, logs: map, startDate: startDate);
      final old = (r['streak'] as num?)?.toInt() ?? 0;
      if (newStreak != old) {
        await txn.update('goal_logs', {'streak': newStreak},
            where: 'id = ?', whereArgs: [id]);
      }
    }
  }
}
