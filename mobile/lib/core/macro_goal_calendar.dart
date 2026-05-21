int logicalWeekOfMonth(DateTime date) {
  final normalizedDate = DateTime.utc(date.year, date.month, date.day);
  final monthStart = DateTime.utc(date.year, date.month, 1);
  final effectiveFirstMonday = _firstMondayInMonth(monthStart);

  if (normalizedDate.isBefore(effectiveFirstMonday)) {
    return 1;
  }

  final dateWeekStart = _startOfWeek(normalizedDate);
  final weeksFromFirstMonday =
      dateWeekStart.difference(effectiveFirstMonday).inDays ~/ 7;
  final daysBeforeFirstMonday = effectiveFirstMonday
      .difference(monthStart)
      .inDays;
  final baseWeek = daysBeforeFirstMonday > 1 ? 2 : 1;

  return weeksFromFirstMonday + baseWeek;
}

int logicalWeeksInMonth(int year, int month) {
  final endOfMonth = DateTime.utc(year, month + 1, 0);
  return logicalWeekOfMonth(endOfMonth);
}

DateTime _firstMondayInMonth(DateTime monthStart) {
  final daysUntilMonday = (DateTime.monday - monthStart.weekday) % 7;
  return monthStart.add(Duration(days: daysUntilMonday));
}

DateTime _startOfWeek(DateTime date) {
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}
