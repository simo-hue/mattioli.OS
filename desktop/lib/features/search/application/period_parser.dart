import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/search/application/goal_nav_target.dart';

/// Turns a free-text query into concrete "jump to this Goals period" targets for
/// the ⌘K palette. It understands the vocabulary the app's own period picker
/// uses — weeks-of-month, months, quarters, years, and "lifetime" — plus a few
/// natural phrasings:
///
///   "this week"            → current week
///   "march" / "mar"        → March of the current year (monthly)
///   "march 2026"           → March 2026 (monthly)
///   "q2" / "q2 2026"       → quarter 2 (quarterly)
///   "week 2 march"/"wk2 mar" → week 2 of March (weekly)
///   "2026"                 → the year 2026 (annual)
///   "life" / "lifetime"    → lifetime goals
///
/// Pure and locale-aware: pass [monthNames] (index 0 = January, from
/// `t.common.months`) and the current [now]. Returns most-specific-first, empty
/// when nothing period-like is recognised. `now` is injected rather than read
/// from the clock so the function stays deterministic and unit-testable.
List<GoalNavTarget> parsePeriodQuery(
  String rawQuery, {
  required DateTime now,
  required List<String> monthNames,
}) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final currentQuarter = ((now.month - 1) ~/ 3) + 1;

  // Lifetime is a plain keyword with no sub-fields.
  if (q == 'life' || q == 'lifetime' || q == 'long-term' || q == 'long term') {
    return const [GoalNavTarget(type: GoalType.lifetime)];
  }

  final year = _matchYear(q);
  final month = _matchMonth(q, monthNames);
  final quarter = _matchQuarter(q);
  final week = _matchWeek(q);

  // Bare period keywords → the current period of that granularity.
  if (month == null && quarter == null && week == null && year == null) {
    if (_hasWord(q, const ['week', 'wk'])) {
      return [
        GoalNavTarget(
          type: GoalType.weekly,
          year: now.year,
          month: now.month,
          week: ((now.day - 1) ~/ 7) + 1,
        ),
      ];
    }
    if (_hasWord(q, const ['month'])) {
      return [
        GoalNavTarget(type: GoalType.monthly, year: now.year, month: now.month),
      ];
    }
    if (_hasWord(q, const ['quarter'])) {
      return [
        GoalNavTarget(
          type: GoalType.quarterly,
          year: now.year,
          quarter: currentQuarter,
        ),
      ];
    }
    if (_hasWord(q, const ['year', 'annual'])) {
      return [GoalNavTarget(type: GoalType.annual, year: now.year)];
    }
    return const [];
  }

  final resolvedYear = year ?? now.year;

  // Most specific wins: a week reference implies a weekly target, and so on.
  if (week != null) {
    return [
      GoalNavTarget(
        type: GoalType.weekly,
        year: resolvedYear,
        month: month ?? now.month,
        week: week,
      ),
    ];
  }
  if (month != null) {
    return [
      GoalNavTarget(type: GoalType.monthly, year: resolvedYear, month: month),
    ];
  }
  if (quarter != null) {
    return [
      GoalNavTarget(
        type: GoalType.quarterly,
        year: resolvedYear,
        quarter: quarter,
      ),
    ];
  }
  // Only a year was given → the annual board.
  return [GoalNavTarget(type: GoalType.annual, year: resolvedYear)];
}

/// A human label for a period target, matching the Goals page's own phrasing.
/// Words are injected so it stays locale-correct and testable.
String describePeriod(
  GoalNavTarget target, {
  required List<String> monthNames,
  required String weekWord,
  required String lifetimeWord,
}) {
  String monthOf(int? m) =>
      (m != null && m >= 1 && m <= 12) ? monthNames[m - 1] : '';
  return switch (target.type) {
    GoalType.lifetime => lifetimeWord,
    GoalType.annual => '${target.year ?? ''}',
    GoalType.quarterly => 'Q${target.quarter ?? ''} ${target.year ?? ''}'.trim(),
    GoalType.monthly => '${monthOf(target.month)} ${target.year ?? ''}'.trim(),
    GoalType.weekly =>
      '$weekWord ${target.week ?? ''}, '
              '${monthOf(target.month)} ${target.year ?? ''}'
          .trim(),
  };
}

int? _matchYear(String q) {
  final m = RegExp(r'\b(20\d{2})\b').firstMatch(q);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

int? _matchQuarter(String q) {
  final short = RegExp(r'\bq\s*([1-4])\b').firstMatch(q);
  if (short != null) return int.tryParse(short.group(1)!);
  final long = RegExp(r'\bquarter\s*([1-4])\b').firstMatch(q);
  if (long != null) return int.tryParse(long.group(1)!);
  return null;
}

int? _matchWeek(String q) {
  final m = RegExp(r'\b(?:w|wk|week)\s*([1-6])\b').firstMatch(q);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

/// Finds a month by full name or a 3+ letter prefix of it (case-insensitive),
/// e.g. "march", "mar", "marc" → 3. Requires at least 3 letters so "m" alone
/// doesn't spuriously match.
int? _matchMonth(String q, List<String> monthNames) {
  final words = q.split(RegExp(r'[\s,./-]+')).where((w) => w.length >= 3);
  for (final word in words) {
    for (var i = 0; i < monthNames.length; i++) {
      final name = monthNames[i].toLowerCase();
      if (name == word || name.startsWith(word)) return i + 1;
    }
  }
  return null;
}

bool _hasWord(String q, List<String> words) {
  final tokens = q.split(RegExp(r'[\s,./-]+')).toSet();
  return words.any(tokens.contains);
}
