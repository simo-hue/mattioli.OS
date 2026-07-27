/// Shared import-merge helpers for the desktop client, ported from the mobile
/// gold standard (`mobile/lib/core/import_merge.dart`) so both clients apply
/// identical semantics:
///
///   1. [validateCanonical] sanitizes a canonical backup and DROPS (never
///      invents values for) rows that cannot satisfy the local schema,
///      counting them per entity so the UI can report "N skipped".
///   2. [reconcileCategoriesByName] is the single category-identity brain —
///      match by id, else case-insensitive name — used by BOTH the private
///      merge ([DesktopPrivateDb.applyImport]) and the cloud plan
///      ([planCloudImport]), so `UNIQUE(user_id, name)` can never abort an
///      import and no macro goal is left pointing at a dangling category.
///   3. [recomputeStreaksForGoals] rebuilds the signed `goal_logs.streak` from
///      the merged history — the denormalized streak in a backup file is never
///      trusted.
///   4. [planCloudImport] computes a full cloud (Supabase) import as pure data
///      — identity + last-write-wins, mirroring the private merge — so it can
///      be unit-tested without a network and a malformed file can never wipe
///      data and then fail halfway.
library;

import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import 'import_merge_stats.dart';
import 'streak_utils.dart';

/// Canonical container keys the merge engine consumes (identical to mobile's).
const kGoalsKey = 'goals';
const kLogsKey = 'goal_logs';
const kProgressKey = 'goal_progress';
const kMacrosKey = 'long_term_goals';
const kCategoriesKey = 'macro_goal_categories';
const kMoodsKey = 'daily_moods';

/// Non-entity key carried through the canonical model on desktop only: the
/// profile/settings block restored under `sanitizeSettings`' allow-list.
const kProfileKey = 'profile';

List<Map<String, dynamic>> _asList(dynamic v) =>
    (v as List?)
        ?.whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList() ??
    <Map<String, dynamic>>[];

// ─────────────────────────────────────────────────────────────────────────────
// Validation (skip-and-report)
// ─────────────────────────────────────────────────────────────────────────────

/// A validated backup: [canonical] contains only rows that satisfy the local
/// schema's NOT-NULL / CHECK constraints (so neither store can hit a constraint
/// abort), and [skipped] counts how many rows of each entity were dropped as
/// invalid, keyed by 'habits' | 'logs' | 'macroGoals' | 'categories' | 'moods'.
class ValidatedBackup {
  final Map<String, dynamic> canonical;
  final Map<String, int> skipped;
  const ValidatedBackup(this.canonical, this.skipped);

  /// Total invalid rows across all entities.
  int get totalSkipped => skipped.values.fold(0, (a, b) => a + b);
}

const _logStatuses = {'done', 'missed', 'skipped'};
const _macroStatuses = {'active', 'completed', 'failed'};
const _macroTypes = {'lifetime', 'annual', 'quarterly', 'monthly', 'weekly'};

/// Coerce any JSON scalar to a trimmed non-empty String, or null. This is the
/// defensive read that prevents `as String` from throwing on a number/bool the
/// file happens to carry (e.g. an id exported as an integer).
String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// Coerce to num|null. `goal_logs.value` is a nullable REAL; anything that isn't
/// a number (a JSON object/array, a non-numeric string) becomes null so it can't
/// throw an "invalid sql argument type" bind error and abort the whole import.
num? _num(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  return null;
}

bool _inRange(int? v, int lo, int hi) => v == null || (v >= lo && v <= hi);

/// Validates + sanitizes a canonical backup. Rows that cannot be made to
/// satisfy the local schema are DROPPED (never coerced with invented values)
/// and counted in [ValidatedBackup.skipped], so a single bad row can never
/// abort the whole import and the user gets an honest "N skipped" report.
/// Identity/text fields are string-coerced; timestamps are left as-is (a
/// missing/odd timestamp is handled as "oldest" by the merge). The desktop
/// `profile` block passes through untouched — it is applied under its own
/// allow-list by the stores.
ValidatedBackup validateCanonical(Map<String, dynamic> canonical) {
  final skipped = {
    'habits': 0,
    'logs': 0,
    'macroGoals': 0,
    'categories': 0,
    'moods': 0,
  };
  void drop(String k) => skipped[k] = skipped[k]! + 1;

  final categories = <Map<String, dynamic>>[];
  for (final c in _asList(canonical[kCategoriesKey])) {
    final name = _str(c['name']);
    final color = _str(c['color']);
    if (name == null || color == null) {
      drop('categories');
      continue;
    }
    categories.add({
      'id': _str(c['id']),
      'name': name,
      'color': color,
      'created_at': _str(c['created_at']),
      'updated_at': _str(c['updated_at']),
      'archived_at': _str(c['archived_at']),
    });
  }

  final goals = <Map<String, dynamic>>[];
  for (final g in _asList(canonical[kGoalsKey])) {
    final title = _str(g['title']);
    final color = _str(g['color']);
    final start = _str(g['start_date']);
    if (title == null || color == null || start == null) {
      drop('habits');
      continue;
    }
    goals.add({
      'id': _str(g['id']),
      'title': title,
      'description': _str(g['description']),
      'icon': _str(g['icon']),
      'color': color,
      'frequency_days': g['frequency_days'],
      'start_date': start,
      'end_date': _str(g['end_date']),
      'display_order': _int(g['display_order']),
      'created_at': _str(g['created_at']),
      'updated_at': _str(g['updated_at']),
      'reminder_time': _str(g['reminder_time']),
      'verify_provider': _str(g['verify_provider']),
      'verify_metric': _str(g['verify_metric']),
      'verify_comparator': _str(g['verify_comparator']),
      'verify_threshold': (g['verify_threshold'] as num?)?.toDouble(),
      'verify_unit': _str(g['verify_unit']),
      'verify_effective_from': _str(g['verify_effective_from']),
      'verify_conditions': _str(g['verify_conditions']),
      // Quantitative target (v9) — opaque JSON, validated in the client, so a
      // backup→restore keeps the target instead of reverting to a checkbox.
      'target': _str(g['target']),
      // The target's forward-only anchor (v11), a date string, round-tripped
      // like verify_effective_from.
      'target_effective_from': _str(g['target_effective_from']),
    });
  }

  final logs = <Map<String, dynamic>>[];
  for (final l in _asList(canonical[kLogsKey])) {
    final goalId = _str(l['goal_id']);
    final date = _str(l['date']);
    final status = _str(l['status']);
    if (goalId == null ||
        date == null ||
        status == null ||
        !_logStatuses.contains(status)) {
      drop('logs');
      continue;
    }
    logs.add({
      'id': _str(l['id']),
      'goal_id': goalId,
      'date': date,
      'status': status,
      'value': _num(l['value']),
      'created_at': _str(l['created_at']),
      'updated_at': _str(l['updated_at']),
      'streak': _int(l['streak']),
    });
  }

  // Goal progress (quantitative-habit daily numbers). Dropped-but-not-counted
  // (a sub-detail of a habit-day, not a reported entity). Requires a positive
  // amount.
  final progress = <Map<String, dynamic>>[];
  for (final p in _asList(canonical[kProgressKey])) {
    final goalId = _str(p['goal_id']);
    final date = _str(p['date']);
    final amount = _num(p['amount']);
    if (goalId == null || date == null || amount == null || amount <= 0) {
      continue;
    }
    progress.add({
      'id': _str(p['id']),
      'goal_id': goalId,
      'date': date,
      'amount': amount,
      'source': _str(p['source']) ?? 'manual',
      'created_at': _str(p['created_at']),
      'updated_at': _str(p['updated_at']),
    });
  }

  final macros = <Map<String, dynamic>>[];
  for (final g in _asList(canonical[kMacrosKey])) {
    final title = _str(g['title']);
    final status = _str(g['status']);
    final type = _str(g['type']);
    final month = _int(g['month']);
    final quarter = _int(g['quarter']);
    final week = _int(g['week_number']);
    if (title == null ||
        status == null ||
        type == null ||
        !_macroStatuses.contains(status) ||
        !_macroTypes.contains(type) ||
        !_inRange(month, 1, 12) ||
        !_inRange(quarter, 1, 4) ||
        !_inRange(week, 1, 53)) {
      drop('macroGoals');
      continue;
    }
    // Cumulative numeric macro goals (v10). A non-positive/absent target_amount
    // is nulled (⇒ boolean goal) rather than dropping the whole goal.
    // linked_goal_id's referential validity is enforced at merge time against
    // knownGoalIds, since the FK would otherwise abort the insert.
    final targetAmount = _num(g['target_amount']);
    macros.add({
      'id': _str(g['id']),
      'title': title,
      'status': status,
      'type': type,
      'year': _int(g['year']),
      'month': month,
      'quarter': quarter,
      'week_number': week,
      'category_key': _str(g['category_key']),
      'category_id': _str(g['category_id']),
      'created_at': _str(g['created_at']),
      'updated_at': _str(g['updated_at']),
      'target_amount':
          (targetAmount != null && targetAmount > 0) ? targetAmount : null,
      'target_unit': _str(g['target_unit']),
      'progress_amount': _num(g['progress_amount']),
      'linked_goal_id': _str(g['linked_goal_id']),
    });
  }

  final moods = <Map<String, dynamic>>[];
  for (final m in _asList(canonical[kMoodsKey])) {
    final date = _str(m['date']);
    final mood = _int(m['mood_score']);
    final energy = _int(m['energy_score']);
    if (date == null ||
        mood == null ||
        energy == null ||
        !_inRange(mood, 0, 10) ||
        !_inRange(energy, 0, 10)) {
      drop('moods');
      continue;
    }
    moods.add({
      'id': _str(m['id']),
      'date': date,
      'mood_score': mood,
      'energy_score': energy,
      'created_at': _str(m['created_at']),
      'updated_at': _str(m['updated_at']),
    });
  }

  return ValidatedBackup({
    kGoalsKey: goals,
    kLogsKey: logs,
    kProgressKey: progress,
    kMacrosKey: macros,
    kCategoriesKey: categories,
    kMoodsKey: moods,
    // Desktop extra: the profile/settings block survives validation untouched
    // (it is filtered by sanitizeSettings / the cloud allow-list downstream).
    if (canonical[kProfileKey] is Map) kProfileKey: canonical[kProfileKey],
  }, skipped);
}

// ─────────────────────────────────────────────────────────────────────────────
// Category reconciliation (shared by the private merge and the cloud plan)
// ─────────────────────────────────────────────────────────────────────────────

/// The outcome of matching imported categories against the existing ones.
class CategoryReconciliation {
  /// Imported categories with no existing match — these need inserting. Each
  /// map is the canonical category with its final `id` resolved.
  final List<Map<String, dynamic>> toInsert;

  /// imported id -> final id (the existing row's id on a match, else its own).
  final Map<String, String> remap;

  /// Every id that is safe for a macro goal to reference after the import
  /// (existing ids + ids in [toInsert]). A remapped `category_id` outside this
  /// set must be nulled or the insert would violate the FK.
  final Set<String> validIds;

  /// Existing categories whose missing `archived_at` is filled from the import
  /// (the only field an existing category accepts from a backup).
  final List<({String id, String archivedAt})> archiveFills;

  /// Matched categories that needed no change (counted as "unchanged").
  final int unchanged;

  const CategoryReconciliation({
    required this.toInsert,
    required this.remap,
    required this.validIds,
    required this.archiveFills,
    required this.unchanged,
  });
}

/// Matches imported [categories] against [existing] rows (`id`, `name`,
/// `archived_at`) by id first, else by case-insensitive trimmed name —
/// `macro_goal_categories` has `UNIQUE(user_id, name)`, so a same-name insert
/// would collide; matching by name and remapping the referencing macro goals
/// is mandatory, not just nice-to-have. Newly-inserted names are registered as
/// they are seen so intra-file duplicates dedup onto the first occurrence.
/// Existing rows always win on a match; only a missing `archived_at` is filled
/// from the import.
CategoryReconciliation reconcileCategoriesByName({
  required List<Map<String, dynamic>> categories,
  required List<Map<String, Object?>> existing,
  required String Function() newId,
}) {
  final catById = {for (final c in existing) c['id'] as String: c};
  final catByName = {
    for (final c in existing)
      ((c['name'] as String?) ?? '').trim().toLowerCase(): c,
  };
  final remap = <String, String>{};
  final validIds = <String>{for (final c in existing) c['id'] as String};
  final toInsert = <Map<String, dynamic>>[];
  final archiveFills = <({String id, String archivedAt})>[];
  var unchanged = 0;

  for (final cat in categories) {
    final importedId = (cat['id'] as String?) ?? newId();
    final name = ((cat['name'] as String?) ?? '').trim();
    final match = catById[importedId] ?? catByName[name.toLowerCase()];
    if (match != null) {
      final finalId = match['id'] as String;
      remap[importedId] = finalId;
      validIds.add(finalId);
      final importedArchived = cat['archived_at'] as String?;
      if (match['archived_at'] == null && importedArchived != null) {
        archiveFills.add((id: finalId, archivedAt: importedArchived));
      } else {
        unchanged++;
      }
    } else {
      remap[importedId] = importedId;
      validIds.add(importedId);
      toInsert.add({...cat, 'id': importedId});
      // Register it so a later same-name imported category dedups onto it.
      catByName[name.toLowerCase()] = {
        'id': importedId,
        'name': cat['name'],
        'archived_at': cat['archived_at'],
      };
    }
  }

  return CategoryReconciliation(
    toInsert: toInsert,
    remap: remap,
    validIds: validIds,
    archiveFills: archiveFills,
    unchanged: unchanged,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak recomputation (private store)
// ─────────────────────────────────────────────────────────────────────────────

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Decode a stored `frequency_days` value (JSON string in the private DB, or a
/// raw list) to canonical ISO weekdays 1-7, or null for "every day". An empty
/// or unusable value becomes null — never an empty list (which would mean "no
/// day" and spin the streak's scheduled-day search).
List<int>? _decodeFrequencyDays(Object? stored) {
  Object? value = stored;
  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return null;
    }
  }
  if (value is! List) return null;
  final days = value
      .map((e) => e is int ? e : (e is num ? e.toInt() : int.tryParse('$e')))
      .whereType<int>()
      .where((d) => d >= 1 && d <= 7)
      .toList();
  return days.isEmpty ? null : days;
}

/// Recomputes the signed `streak` for every log of each goal in [goalIds] from
/// the full persisted history, and writes back only the rows whose streak
/// actually changed (minimizing sync churn — every write here re-dirties the
/// row for iCloud push, which is correct: its content really changed).
Future<void> recomputeStreaksForGoals(
  DatabaseExecutor txn,
  Set<String> goalIds,
) async {
  for (final goalId in goalIds) {
    final goalRows = await txn.query(
      'goals',
      columns: ['start_date', 'frequency_days'],
      where: 'id = ?',
      whereArgs: [goalId],
      limit: 1,
    );
    if (goalRows.isEmpty) continue;
    final startDate =
        DateTime.tryParse(goalRows.first['start_date'] as String? ?? '') ??
        DateTime(2000);
    // Private DB stores frequency_days as a JSON string ("[1,3,5]"); decode it
    // so a recomputed streak skips off-days like the live one.
    final frequencyDays = _decodeFrequencyDays(goalRows.first['frequency_days']);

    final logRows = await txn.query(
      'goal_logs',
      columns: ['id', 'date', 'status', 'streak'],
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );

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
        habitId: goalId,
        date: d,
        logs: map,
        startDate: startDate,
        frequencyDays: frequencyDays,
      );
      final old = (r['streak'] as num?)?.toInt() ?? 0;
      if (newStreak != old) {
        await txn.update(
          'goal_logs',
          {'streak': newStreak},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cloud-mode plan (Supabase)
// ─────────────────────────────────────────────────────────────────────────────

/// A fully-computed cloud import: the exact rows to write and delete, decided
/// from the fetched existing state — with NO network calls.
/// `DesktopBackupImportService` builds this BEFORE it deletes anything (so a
/// bad plan can never wipe data), then executes it. Being pure, it is
/// unit-testable without Supabase.
class CloudImportPlan {
  /// New category rows to insert. NOTE: deliberately carry no `updated_at` —
  /// the cloud `macro_goal_categories` table has no such column.
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> macros;
  final List<Map<String, dynamic>> logs;
  final List<Map<String, dynamic>> progress;
  final List<Map<String, dynamic>> moods;

  /// Existing categories to fill an `archived_at` on (id -> archived_at).
  /// Applied as a bare `archived_at` update — again, never touching
  /// `updated_at`.
  final List<({String id, String archivedAt})> categoryArchiveFills;

  final Set<String> affectedGoals;
  final ImportMergeStats stats;

  const CloudImportPlan({
    required this.categories,
    required this.goals,
    required this.macros,
    required this.logs,
    this.progress = const [],
    required this.moods,
    required this.categoryArchiveFills,
    required this.affectedGoals,
    required this.stats,
  });
}

/// Computes a [CloudImportPlan] from canonical data + the fetched existing
/// state. Mirrors [DesktopPrivateDb.applyImport]'s identity + last-write-wins
/// semantics. Pass empty existing-state collections for replace mode
/// (everything is added).
CloudImportPlan planCloudImport({
  required String userId,
  required Map<String, dynamic> canonical,
  required bool replaceExisting,
  required String now,
  required List<Map<String, dynamic>> existingCategories, // id,name,archived_at
  required Map<String, String?> existingGoals, // id -> updated_at
  required Map<String, String?> existingMacros, // id -> updated_at
  required Map<String, Map<String, dynamic>>
  existingLogs, // gid|date -> {id,updated_at}
  required Map<String, Map<String, dynamic>>
  existingMoods, // date -> {id,updated_at}
  Map<String, Map<String, dynamic>> existingProgress =
      const {}, // gid|date -> {id,updated_at}
  required String Function() newId,
}) {
  final stats = ImportMergeStats(replaced: replaceExisting);

  final categories = _asList(canonical[kCategoriesKey]);
  final goals = _asList(canonical[kGoalsKey]);
  final logs = _asList(canonical[kLogsKey]);
  final macros = _asList(canonical[kMacrosKey]);
  final moods = _asList(canonical[kMoodsKey]);

  // ── Categories: one shared brain with the private merge. ──
  final rec = reconcileCategoriesByName(
    categories: categories,
    existing: existingCategories,
    newId: newId,
  );
  stats.categories.added += rec.toInsert.length;
  stats.categories.updated += rec.archiveFills.length;
  stats.categories.unchanged += rec.unchanged;
  final catsToWrite = [
    for (final cat in rec.toInsert)
      {
        'id': cat['id'],
        'user_id': userId,
        'name': cat['name'],
        'color': cat['color'],
        'created_at': cat['created_at'] ?? now,
        'archived_at': cat['archived_at'],
      },
  ];

  // ── Goals ──
  final knownGoalIds = <String>{...existingGoals.keys};
  final goalsToWrite = <Map<String, dynamic>>[];
  for (final g in goals) {
    final id = (g['id'] as String?) ?? newId();
    final has = existingGoals.containsKey(id);
    if (has &&
        !incomingWins(
          incoming: g['updated_at'] as String?,
          existing: existingGoals[id],
        )) {
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
      'verify_provider': g['verify_provider'],
      'verify_metric': g['verify_metric'],
      'verify_comparator': g['verify_comparator'],
      'verify_threshold': g['verify_threshold'],
      'verify_unit': g['verify_unit'],
      'verify_effective_from': g['verify_effective_from'],
      'verify_conditions': g['verify_conditions'],
      'target': g['target'],
      'target_effective_from': g['target_effective_from'],
    });
    has ? stats.habits.updated++ : stats.habits.added++;
  }

  // ── Macro goals ──
  final macrosToWrite = <Map<String, dynamic>>[];
  for (final g in macros) {
    final id = (g['id'] as String?) ?? newId();
    final importedCatId = g['category_id'] as String?;
    final remapped = importedCatId == null
        ? null
        : (rec.remap[importedCatId] ?? importedCatId);
    final categoryId = (remapped != null && rec.validIds.contains(remapped))
        ? remapped
        : null;
    final rawLinked = g['linked_goal_id'] as String?;
    final linkedGoalId =
        (rawLinked != null && knownGoalIds.contains(rawLinked))
            ? rawLinked
            : null;
    final has = existingMacros.containsKey(id);
    if (has &&
        !incomingWins(
          incoming: g['updated_at'] as String?,
          existing: existingMacros[id],
        )) {
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
      // Cumulative numeric macro goals (v10). linked_goal_id FK-validated.
      'target_amount': g['target_amount'],
      'target_unit': g['target_unit'],
      'progress_amount': g['progress_amount'],
      'linked_goal_id': linkedGoalId,
    });
    has ? stats.macroGoals.updated++ : stats.macroGoals.added++;
  }

  // ── Goal logs: natural key (goal_id, date); reuse existing id on update.
  // Intra-file duplicates of a NEW (goal_id,date) are dropped so onConflict:'id'
  // upserts can't collide on the UNIQUE(goal_id,date) constraint. ──
  final affectedGoals = <String>{};
  final logsToWrite = <Map<String, dynamic>>[];
  final seenNewLogKeys = <String>{};
  for (final l in logs) {
    final goalId = l['goal_id'] as String?;
    final date = l['date'] as String?;
    if (goalId == null || date == null || !knownGoalIds.contains(goalId)) {
      continue;
    }
    final key = '$goalId|$date';
    final match = existingLogs[key];
    if (match == null) {
      if (!seenNewLogKeys.add(key)) continue; // intra-file dup
      logsToWrite.add({
        'id': (l['id'] as String?) ?? newId(),
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
      existing: match['updated_at'] as String?,
    )) {
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

  // ── Goal progress: natural key (goal_id, date); deterministic id. Folded in
  // with no stats counter. Orphans skipped for the FK; intra-file dups dropped. ──
  final progress = _asList(canonical[kProgressKey]);
  final progressToWrite = <Map<String, dynamic>>[];
  final seenProgressKeys = <String>{};
  for (final p in progress) {
    final goalId = p['goal_id'] as String?;
    final date = p['date'] as String?;
    if (goalId == null || date == null || !knownGoalIds.contains(goalId)) {
      continue;
    }
    final key = '$goalId|$date';
    if (!seenProgressKeys.add(key)) continue;
    final existing = existingProgress[key];
    if (existing != null &&
        !incomingWins(
            incoming: p['updated_at'] as String?,
            existing: existing['updated_at'] as String?)) {
      continue;
    }
    progressToWrite.add({
      'id': '$goalId:$date',
      'user_id': userId,
      'goal_id': goalId,
      'date': date,
      'amount': p['amount'],
      'source': p['source'] ?? 'manual',
      'created_at': p['created_at'] ?? now,
      'updated_at': p['updated_at'] ?? now,
    });
  }

  // ── Daily moods: natural key date; reuse existing id on update. ──
  final moodsToWrite = <Map<String, dynamic>>[];
  final seenNewMoodDates = <String>{};
  for (final m in moods) {
    final date = m['date'] as String?;
    if (date == null) continue;
    final match = existingMoods[date];
    if (match == null) {
      if (!seenNewMoodDates.add(date)) continue; // intra-file dup
      moodsToWrite.add({
        'id': (m['id'] as String?) ?? newId(),
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
      existing: match['updated_at'] as String?,
    )) {
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

  return CloudImportPlan(
    categories: catsToWrite,
    goals: goalsToWrite,
    macros: macrosToWrite,
    logs: logsToWrite,
    progress: progressToWrite,
    moods: moodsToWrite,
    categoryArchiveFills: rec.archiveFills,
    affectedGoals: affectedGoals,
    stats: stats,
  );
}
