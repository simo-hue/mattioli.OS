class MacroGoalDateRange {
  const MacroGoalDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

int logicalWeekOfMonth(DateTime date) {
  return ((date.day - 1) ~/ 7) + 1;
}

int logicalWeeksInMonth(int year, int month) {
  final daysInMonth = DateTime.utc(year, month + 1, 0).day;
  return ((daysInMonth - 1) ~/ 7) + 1;
}

MacroGoalDateRange logicalWeekRange(int year, int month, int week) {
  final maxWeek = logicalWeeksInMonth(year, month);
  final selectedWeek = week.clamp(1, maxWeek);
  final monthStart = DateTime.utc(year, month, 1);
  final start = monthStart.add(Duration(days: (selectedWeek - 1) * 7));

  return MacroGoalDateRange(
    start: start,
    end: start.add(const Duration(days: 6)),
  );
}

/// The `[start, end]` calendar range (inclusive, UTC, day-granular) a cumulative
/// macro goal of [type] covers, from its period fields — the window a linked
/// habit's daily progress is summed over. Returns **null** for a lifetime goal
/// (all history, no bound) and for any period missing the fields it needs (a
/// safe "sum everything" fallback rather than a throw).
///
/// [type] is a `GoalType`/`long_term_goal_type` wire name
/// (lifetime/annual/quarterly/monthly/weekly). Weekly reuses [logicalWeekRange]
/// so the boundary matches the app's week-of-month calendar exactly.
MacroGoalDateRange? macroGoalPeriodRange({
  required String type,
  int? year,
  int? quarter,
  int? month,
  int? week,
}) {
  switch (type) {
    case 'annual':
      if (year == null) return null;
      return MacroGoalDateRange(
        start: DateTime.utc(year, 1, 1),
        end: DateTime.utc(year, 12, 31),
      );
    case 'quarterly':
      if (year == null || quarter == null) return null;
      final startMonth = (quarter - 1) * 3 + 1;
      return MacroGoalDateRange(
        start: DateTime.utc(year, startMonth, 1),
        // Day 0 of the month after the quarter's last month = that last day.
        end: DateTime.utc(year, startMonth + 3, 0),
      );
    case 'monthly':
      if (year == null || month == null) return null;
      return MacroGoalDateRange(
        start: DateTime.utc(year, month, 1),
        end: DateTime.utc(year, month + 1, 0),
      );
    case 'weekly':
      if (year == null || month == null || week == null) return null;
      return logicalWeekRange(year, month, week);
    case 'lifetime':
    default:
      return null;
  }
}
