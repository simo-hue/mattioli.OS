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
const kProgressKey = 'goal_progress';
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
      // Cumulative numeric macro goals (v10). Present on a native backup; a web
      // export simply omits them (they read back as null).
      'target_amount': g['target_amount'],
      'target_unit': g['target_unit'],
      'progress_amount': g['progress_amount'],
      'linked_goal_id': g['linked_goal_id'],
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
    kProgressKey: _normalizeProgressRows(raw['goal_progress']),
    kMacrosKey: macros,
    kCategoriesKey: categories,
    kMoodsKey: moods,
  };
}

/// Canonicalises `goal_progress` rows (the quantitative-habit daily numbers)
/// from either source shape — same fields on both, so one helper. Absent ⇒ an
/// empty list (a pre-targets backup has no progress).
List<Map<String, dynamic>> _normalizeProgressRows(Object? raw) => [
      for (final p in _asList(raw))
        {
          'id': p['id'],
          'goal_id': p['goal_id'],
          'date': p['date'],
          'amount': p['amount'],
          'source': p['source'],
          'created_at': p['created_at'],
          'updated_at': p['updated_at'],
        },
    ];

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
      // Cumulative numeric macro goals (v10).
      'target_amount': g['target_amount'],
      'target_unit': g['target_unit'],
      'progress_amount': g['progress_amount'],
      'linked_goal_id': g['linked_goal_id'],
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
    // The app's own export uses `habitProgress`; a raw table dump would use
    // `goal_progress`. Accept either.
    kProgressKey:
        _normalizeProgressRows(raw['habitProgress'] ?? raw['goal_progress']),
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

/// Coerce to a date string the read path can parse, or null. `goals.start_date`
/// / `end_date` are TEXT columns that accept anything, but `Goal.fromJson` reads
/// them back with a strict `DateTime.parse` inside an eager `rows.map(...)`, so
/// one unparseable date hides EVERY goal, not just its own row. The original
/// string is kept (not normalized) so a `yyyy-MM-dd` value stays a bare date for
/// the cloud plan's `date` column.
String? _date(dynamic v) {
  final s = _str(v);
  if (s == null) return null;
  return DateTime.tryParse(s) == null ? null : s;
}

/// Coerce `goals.frequency_days` to ISO weekdays (1-7), or null. The column is
/// read back with a strict `List<int>.from(jsonDecode(...))`, so a list of
/// strings/doubles, a bare string or a map would throw for the whole goal list.
/// A present-but-entirely-unusable value becomes null — i.e. the documented
/// "every day" default — rather than an empty list, which means "no day".
List<int>? _frequencyDays(dynamic v) {
  if (v is! List) return null;
  final days =
      v.map(_int).whereType<int>().where((d) => d >= 1 && d <= 7).toList();
  if (days.isEmpty && v.isNotEmpty) return null;
  return days;
}

final _reminderTimeRe = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

/// Coerce `goals.reminder_time` to a strict zero-padded "HH:mm", or null.
/// Consumers parse it with `AppTimeFormatting.parseTimeOfDay`, which throws by
/// design — including inside a widget `build()`, where no provider try/catch can
/// catch it — so anything malformed is dropped to null here.
String? _reminderTime(dynamic v) {
  final s = _str(v);
  if (s == null) return null;
  return _reminderTimeRe.hasMatch(s) ? s : null;
}

final _hexColorRe = RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

/// Normalize a hex colour to `#RRGGBB`, or null when the value is not a hex
/// colour. Shorthand is expanded because `GoalCategory.fromJson` parses `#FFF`
/// to a near-transparent colour without throwing.
String? _hexColor(dynamic v) {
  final s = _str(v);
  if (s == null) return null;
  final m = _hexColorRe.firstMatch(s);
  if (m == null) return null;
  final digits = m.group(1)!;
  final rrggbb = digits.length == 3
      ? digits.split('').map((c) => '$c$c').join()
      : digits;
  return '#${rrggbb.toUpperCase()}';
}

/// Validates + sanitizes a canonical backup (output of [normalizeBackup]).
/// Rows that cannot be made to satisfy the local schema are DROPPED (never
/// coerced with invented values) and counted in [ValidatedBackup.skipped], so a
/// single bad row can never abort the whole import and the user gets an honest
/// "N skipped" report. Identity/text fields are string-coerced; timestamps are
/// left as-is (a missing/odd timestamp is handled as "oldest" by the merge).
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
    final color = _hexColor(c['color']);
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
    final start = _date(g['start_date']);
    final rawEnd = _str(g['end_date']);
    final end = _date(rawEnd);
    // A present-but-unparseable end_date drops the row rather than importing the
    // habit without its end: `Goal.fromJson` parses end_date just as strictly as
    // start_date, so silently nulling it would hide a real constraint.
    if (title == null || color == null || start == null ||
        (rawEnd != null && end == null)) {
      drop('habits');
      continue;
    }
    goals.add({
      'id': _str(g['id']),
      'title': title,
      'description': _str(g['description']),
      'icon': _str(g['icon']),
      'color': color,
      'frequency_days': _frequencyDays(g['frequency_days']),
      'start_date': start,
      'end_date': end,
      'display_order': _int(g['display_order']),
      'created_at': _str(g['created_at']),
      'updated_at': _str(g['updated_at']),
      'reminder_time': _reminderTime(g['reminder_time']),
      'verify_provider': _str(g['verify_provider']),
      'verify_metric': _str(g['verify_metric']),
      'verify_comparator': _str(g['verify_comparator']),
      'verify_threshold': (g['verify_threshold'] as num?)?.toDouble(),
      'verify_unit': _str(g['verify_unit']),
      'verify_effective_from': _str(g['verify_effective_from']),
      'verify_conditions': _str(g['verify_conditions']),
      // Opaque JSON string, validated in the client (decodeHabitTarget) exactly
      // like verify_conditions — a target from a newer client round-trips rather
      // than being dropped here.
      'target': _str(g['target']),
      // The target's forward-only anchor (v11), a date string — validated and
      // round-tripped exactly like verify_effective_from.
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

  // Goal progress (quantitative-habit daily numbers). A malformed row is DROPPED
  // but NOT surfaced as a user-facing "skipped" count — progress is a sub-detail
  // of a habit-day, not a top-level entity the summary reports on; the verdict in
  // goal_logs is what the user sees. Requires a positive amount (a 0/negative or
  // missing amount is not a meaningful progress record).
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
    // is nulled (⇒ the goal reads as an ordinary boolean one) rather than
    // dropping the whole goal — the same forgiving posture the client's
    // evaluateMacroGoalProgress takes. linked_goal_id is passed through as a
    // string here; its referential validity (does the habit exist?) is enforced
    // at merge time against knownGoalIds, since the FK would otherwise abort.
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
  }, skipped);
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
  final progress = _asList(canonical[kProgressKey]);
  final macros = _asList(canonical[kMacrosKey]);
  final moods = _asList(canonical[kMoodsKey]);

  if (replaceExisting) {
    await txn.delete('goal_logs');
    await txn.delete('goal_progress');
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
      final rid = await txn.insert('macro_goal_categories', {
        'id': importedId,
        'user_id': owner,
        'name': cat['name'],
        'color': cat['color'],
        'created_at': cat['created_at'] ?? now,
        'updated_at': cat['updated_at'] ?? now,
        'archived_at': cat['archived_at'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (rid != 0) {
        catRemap[importedId] = importedId;
        validCatIds.add(importedId);
        // Record it so a later same-name imported category dedups onto it.
        catByName[name.toLowerCase()] = {
          'id': importedId,
          'name': cat['name'],
          'archived_at': cat['archived_at'],
        };
        stats.categories.added++;
      } else {
        // Insert was ignored — a same-name row exists that wasn't in the
        // preloaded set. Remap onto it so referencing macro goals never dangle.
        final row = await txn.query('macro_goal_categories',
            columns: ['id'],
            where: 'user_id = ? AND name = ?',
            whereArgs: [owner, cat['name']],
            limit: 1);
        if (row.isNotEmpty) {
          final fid = row.first['id'] as String;
          catRemap[importedId] = fid;
          validCatIds.add(fid);
        }
        stats.categories.unchanged++;
      }
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
      // Only register the goal as "known" and count it if the row actually
      // landed (rid == 0 means INSERT OR IGNORE dropped it). This keeps a
      // non-inserted goal out of knownGoalIds so its logs are correctly
      // orphan-skipped instead of FK-aborting the whole transaction.
      final rid = await txn.insert(
          'goals',
          _goalRow(g, id, owner, (g['created_at'] as String?) ?? now, now),
          conflictAlgorithm: ConflictAlgorithm.ignore);
      if (rid != 0) {
        knownGoalIds.add(id);
        stats.habits.added++;
      }
    } else if (incomingWins(
        incoming: g['updated_at'] as String?,
        existing: existing['updated_at'] as String?)) {
      final n = await txn.update(
          'goals',
          _goalRow(g, id, owner, existing['created_at'] as String? ?? now, now),
          where: 'id = ?',
          whereArgs: [id]);
      if (n > 0) {
        stats.habits.updated++;
      } else {
        stats.habits.unchanged++;
      }
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
    // Null a linked_goal_id whose habit is absent (would dangle the FK). The FK
    // is ON DELETE SET NULL, so a live-but-later-deleted habit already un-links
    // itself; this handles the import-time case where the habit was never here.
    final rawLinked = g['linked_goal_id'] as String?;
    final linkedGoalId =
        (rawLinked != null && knownGoalIds.contains(rawLinked)) ? rawLinked : null;
    final existing = existingMacros[id];
    if (existing == null) {
      final rid = await txn.insert(
          'long_term_goals',
          _macroRow(g, id, owner, categoryId, linkedGoalId,
              (g['created_at'] as String?) ?? now, now),
          conflictAlgorithm: ConflictAlgorithm.ignore);
      if (rid != 0) {
        stats.macroGoals.added++;
      }
    } else if (incomingWins(
        incoming: g['updated_at'] as String?,
        existing: existing['updated_at'] as String?)) {
      final n = await txn.update(
          'long_term_goals',
          _macroRow(g, id, owner, categoryId, linkedGoalId,
              existing['created_at'] as String? ?? now, now),
          where: 'id = ?',
          whereArgs: [id]);
      if (n > 0) {
        stats.macroGoals.updated++;
      } else {
        stats.macroGoals.unchanged++;
      }
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
      final rid = await txn.insert('goal_logs', {
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
      if (rid != 0) {
        affectedGoals.add(goalId);
        stats.logs.added++;
      }
    } else if (incomingWins(
        incoming: l['updated_at'] as String?,
        existing: existing['updated_at'] as String?)) {
      final n = await txn.update('goal_logs', {
        'status': l['status'],
        'value': l['value'],
        'updated_at': l['updated_at'] ?? now,
      }, where: 'id = ?', whereArgs: [existing['id']]);
      if (n > 0) {
        affectedGoals.add(goalId);
        stats.logs.updated++;
      } else {
        stats.logs.unchanged++;
      }
    } else {
      stats.logs.unchanged++;
    }
  }

  // ── Goal progress: identity by (goal_id, date), LWW — the same shape as goal
  // logs. Orphan rows (no matching goal) are skipped for the FK. Folded into the
  // habits flow with no separate stats counter (progress is a sub-detail, not a
  // reported entity); the streak recompute above is unaffected — progress never
  // feeds a streak. ──
  final existingProgress = replaceExisting
      ? const <String, Map<String, Object?>>{}
      : {
          for (final r in await txn.query('goal_progress',
              columns: ['id', 'goal_id', 'date', 'updated_at'],
              where: 'user_id = ?',
              whereArgs: [owner]))
            '${r['goal_id']}|${r['date']}': r,
        };

  for (final p in progress) {
    final goalId = p['goal_id'] as String?;
    final date = p['date'] as String?;
    if (goalId == null || date == null || !knownGoalIds.contains(goalId)) {
      continue;
    }
    final key = '$goalId|$date';
    final existing = existingProgress[key];
    if (existing == null) {
      // Deterministic id (goalId:date), matching the write path, so a re-import
      // can't mint a rival row for the same habit-day.
      await txn.insert('goal_progress', {
        'id': '$goalId:$date',
        'user_id': owner,
        'goal_id': goalId,
        'date': date,
        'amount': p['amount'],
        'source': p['source'] ?? 'manual',
        'created_at': p['created_at'] ?? now,
        'updated_at': p['updated_at'] ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else if (incomingWins(
        incoming: p['updated_at'] as String?,
        existing: existing['updated_at'] as String?)) {
      await txn.update('goal_progress', {
        'amount': p['amount'],
        'source': p['source'] ?? 'manual',
        'updated_at': p['updated_at'] ?? now,
      }, where: 'id = ?', whereArgs: [existing['id']]);
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
      final rid = await txn.insert('daily_moods', {
        'id': (m['id'] as String?) ?? newId(),
        'user_id': owner,
        'date': date,
        'mood_score': m['mood_score'],
        'energy_score': m['energy_score'],
        'created_at': m['created_at'] ?? now,
        'updated_at': m['updated_at'] ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (rid != 0) {
        stats.moods.added++;
      }
    } else if (incomingWins(
        incoming: m['updated_at'] as String?,
        existing: existing['updated_at'] as String?)) {
      final n = await txn.update('daily_moods', {
        'mood_score': m['mood_score'],
        'energy_score': m['energy_score'],
        'updated_at': m['updated_at'] ?? now,
      }, where: 'id = ?', whereArgs: [existing['id']]);
      if (n > 0) {
        stats.moods.updated++;
      } else {
        stats.moods.unchanged++;
      }
    } else {
      stats.moods.unchanged++;
    }
  }

  // ── Recompute streaks over the merged history for every touched goal. ──
  await recomputeStreaks(txn, affectedGoals);

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
    // createdAt is decided by the caller (file's value on insert, existing row's
    // on an LWW update) so a winning update never rewrites the local created_at.
    'created_at': createdAt,
    'updated_at': g['updated_at'] ?? updatedAt,
    'reminder_time': g['reminder_time'],
    'verify_provider': g['verify_provider'],
    'verify_metric': g['verify_metric'],
    'verify_comparator': g['verify_comparator'],
    'verify_threshold': g['verify_threshold'],
    'verify_unit': g['verify_unit'],
    'verify_effective_from': g['verify_effective_from'],
    'verify_conditions': g['verify_conditions'],
    // Quantitative target (v9): round-tripped so a backup→restore doesn't
    // silently turn a targeted habit back into a plain checkbox.
    'target': g['target'],
    // The target's forward-only anchor (v11), mirroring verify_effective_from.
    'target_effective_from': g['target_effective_from'],
  };
}

Map<String, Object?> _macroRow(
  Map<String, dynamic> g,
  String id,
  String owner,
  String? categoryId,
  String? linkedGoalId,
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
    'created_at': createdAt,
    'updated_at': g['updated_at'] ?? updatedAt,
    // Cumulative numeric macro goals (v10). [linkedGoalId] is the caller's
    // FK-validated value (null when the referenced habit is neither in the
    // backup nor already present) — writing a dangling ref would abort the
    // insert under the ON-DELETE-SET-NULL foreign key.
    'target_amount': g['target_amount'],
    'target_unit': g['target_unit'],
    'progress_amount': g['progress_amount'],
    'linked_goal_id': linkedGoalId,
  };
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Recomputes the signed `streak` for every log of each goal in [goalIds] from
/// the full persisted history, and writes back only the rows whose streak
/// actually changed (minimizing sync churn).
///
/// Returns the number of rows it corrected, so a caller can report how much
/// damage there was — the one-time repair in
/// [PrivateLocalDatabase.repairAllStreaks] needs that, and an import can log it.
///
/// PUBLIC because it is the single implementation of "what should this row's
/// streak be": the import path and the repair path must never disagree, and a
/// second copy is exactly how they would.
/// [stampUpdatedAt], when given, is written to `updated_at` on every row this
/// corrects. That is REQUIRED for a repair and deliberately omitted for the
/// import.
///
/// The AFTER UPDATE sync trigger stamps `sync_state` from the ROW's own
/// `updated_at`, not from now (private_db_schema.dart), so a row corrected
/// without a new stamp goes dirty carrying its ORIGINAL timestamp. It is pushed
/// with that stamp, and every peer applies on strict greater-than
/// (`if (rec.updatedAtMs <= localMs) return skipped`, sync_engine.dart) — an
/// equal timestamp loses. The corrected value would reach the zone and be
/// discarded by every other device, leaving a multi-device user permanently
/// half-repaired. `sync_local_store.dart` states the same rule: an unbumped row
/// loses LWW on the other devices and never propagates.
///
/// The import path passes null because it is already inside an LWW merge that
/// manages its own timestamps.
Future<int> recomputeStreaks(
  Transaction txn,
  Set<String> goalIds, {
  String? stampUpdatedAt,
}) async {
  var corrected = 0;
  for (final goalId in goalIds) {
    final goalRows = await txn.query('goals',
        columns: ['start_date', 'frequency_days'],
        where: 'id = ?',
        whereArgs: [goalId],
        limit: 1);
    if (goalRows.isEmpty) continue;
    final startDate =
        DateTime.tryParse(goalRows.first['start_date'] as String? ?? '') ??
            DateTime(2000);
    // The private DB stores frequency_days as a JSON string ("[1,3,5]"); decode
    // it so a recomputed streak skips off-days like the live one.
    final rawFreq = goalRows.first['frequency_days'];
    final frequencyDays = _frequencyDays(
      rawFreq is String ? jsonDecode(rawFreq) : rawFreq,
    );

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
          habitId: goalId,
          date: d,
          logs: map,
          startDate: startDate,
          frequencyDays: frequencyDays);
      final old = (r['streak'] as num?)?.toInt() ?? 0;
      if (newStreak != old) {
        await txn.update(
            'goal_logs',
            {
              'streak': newStreak,
              'updated_at': ?stampUpdatedAt,
            },
            where: 'id = ?',
            whereArgs: [id]);
        corrected++;
      }
    }
  }
  return corrected;
}

// ─────────────────────────────────────────────────────────────────────────────
// Cloud-mode plan (Supabase)
// ─────────────────────────────────────────────────────────────────────────────

/// A fully-computed cloud import: the exact rows to write and delete, decided
/// from the fetched existing state — with NO network calls. `BackupImportService`
/// builds this BEFORE it deletes anything (so a bad plan can never wipe data),
/// then executes it. Being pure, it is unit-testable without Supabase.
class CloudImportPlan {
  /// New category rows to insert. NOTE: deliberately carry no `updated_at` —
  /// the cloud `macro_goal_categories` table has no such column.
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> macros;
  final List<Map<String, dynamic>> logs;
  final List<Map<String, dynamic>> progress;
  final List<Map<String, dynamic>> moods;

  /// Existing categories to fill an `archived_at` on (id -> archived_at). Applied
  /// as a bare `archived_at` update — again, never touching `updated_at`.
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

/// Computes a [CloudImportPlan] from canonical data + the fetched existing state.
/// Mirrors [applyPrivateImportMerge]'s identity + last-write-wins semantics.
/// Pass empty existing-state collections for replace mode (everything is added).
CloudImportPlan planCloudImport({
  required String userId,
  required Map<String, dynamic> canonical,
  required bool replaceExisting,
  required String now,
  required List<Map<String, dynamic>> existingCategories, // id,name,archived_at
  required Map<String, String?> existingGoals, // id -> updated_at
  required Map<String, String?> existingMacros, // id -> updated_at
  required Map<String, Map<String, dynamic>> existingLogs, // gid|date -> {id,updated_at}
  required Map<String, Map<String, dynamic>> existingMoods, // date -> {id,updated_at}
  Map<String, Map<String, dynamic>> existingProgress = const {}, // gid|date -> {id,updated_at}
  required String Function() newId,
}) {
  final stats = ImportMergeStats(replaced: replaceExisting);

  final categories = _asList(canonical[kCategoriesKey]);
  final goals = _asList(canonical[kGoalsKey]);
  final logs = _asList(canonical[kLogsKey]);
  final macros = _asList(canonical[kMacrosKey]);
  final moods = _asList(canonical[kMoodsKey]);

  // ── Categories ──
  final catById = {for (final c in existingCategories) c['id'] as String: c};
  final catByName = {
    for (final c in existingCategories)
      (c['name'] as String).trim().toLowerCase(): c,
  };
  final catRemap = <String, String>{};
  final validCatIds = <String>{
    for (final c in existingCategories) c['id'] as String,
  };
  final catsToWrite = <Map<String, dynamic>>[];
  final catArchiveFills = <({String id, String archivedAt})>[];

  for (final cat in categories) {
    final importedId = (cat['id'] as String?) ?? newId();
    final name = (cat['name'] as String? ?? '').trim();
    final match = catById[importedId] ?? catByName[name.toLowerCase()];
    if (match != null) {
      final finalId = match['id'] as String;
      catRemap[importedId] = finalId;
      validCatIds.add(finalId);
      final importedArchived = cat['archived_at'] as String?;
      if (match['archived_at'] == null && importedArchived != null) {
        catArchiveFills.add((id: finalId, archivedAt: importedArchived));
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
  final knownGoalIds = <String>{...existingGoals.keys};
  final goalsToWrite = <Map<String, dynamic>>[];
  for (final g in goals) {
    final id = (g['id'] as String?) ?? newId();
    final has = existingGoals.containsKey(id);
    if (has &&
        !incomingWins(
            incoming: g['updated_at'] as String?,
            existing: existingGoals[id])) {
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
      // Carry the verification rule into the cloud upsert — otherwise a
      // cloud-mode (account) import silently strips auto-verification from every
      // habit. Mirrors the private merge (_goalRow), the live writer
      // (Goal.toJson), and the desktop cloud plan.
      'verify_provider': g['verify_provider'],
      'verify_metric': g['verify_metric'],
      'verify_comparator': g['verify_comparator'],
      'verify_threshold': g['verify_threshold'],
      'verify_unit': g['verify_unit'],
      'verify_effective_from': g['verify_effective_from'],
      'verify_conditions': g['verify_conditions'],
      // Quantitative target (v9) — without it a cloud import strips a habit's
      // target, reverting it to a checkbox. Mirrors the private merge.
      'target': g['target'],
      // The target's forward-only anchor (v11), mirroring verify_effective_from.
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
        : (catRemap[importedCatId] ?? importedCatId);
    final categoryId =
        (remapped != null && validCatIds.contains(remapped)) ? remapped : null;
    final rawLinked = g['linked_goal_id'] as String?;
    final linkedGoalId =
        (rawLinked != null && knownGoalIds.contains(rawLinked)) ? rawLinked : null;
    final has = existingMacros.containsKey(id);
    if (has &&
        !incomingWins(
            incoming: g['updated_at'] as String?,
            existing: existingMacros[id])) {
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
      // Cumulative numeric macro goals (v10). linked_goal_id FK-validated against
      // knownGoalIds so a cloud upsert can't dangle it.
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

  // ── Goal progress: natural key (goal_id, date); deterministic id, so the same
  // habit-day converges. Folded in with no stats counter (a sub-detail, not a
  // reported entity). Orphans skipped for the FK; intra-file dups dropped. ──
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
    if (!seenProgressKeys.add(key)) continue; // intra-file dup
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

  return CloudImportPlan(
    categories: catsToWrite,
    goals: goalsToWrite,
    macros: macrosToWrite,
    logs: logsToWrite,
    progress: progressToWrite,
    moods: moodsToWrite,
    categoryArchiveFills: catArchiveFills,
    affectedGoals: affectedGoals,
    stats: stats,
  );
}
