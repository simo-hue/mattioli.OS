class MacroGoalDateRange {
  final DateTime start;
  final DateTime end;

  const MacroGoalDateRange({required this.start, required this.end});
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
  final selectedWeek = week < 1 ? 1 : (week > maxWeek ? maxWeek : week);
  final monthStart = DateTime.utc(year, month, 1);
  final start = monthStart.add(Duration(days: (selectedWeek - 1) * 7));

  return MacroGoalDateRange(
    start: start,
    end: start.add(const Duration(days: 6)),
  );
}
