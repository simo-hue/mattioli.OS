/// Calendar and wire-format contract shared by both Flutter clients.
///
/// A week is seven civil dates, Monday–Sunday. Its Thursday determines the
/// owning month/year (the month containing the majority of its days). UTC
/// here represents date-only values, not instants to convert to local time.
class MacroGoalDateRange {
  const MacroGoalDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class WeekBucket {
  const WeekBucket({
    required this.year,
    required this.month,
    required this.week,
  }) : assert(week >= 1 && week <= 5);

  final int year;
  final int month;
  final int week;

  @override
  bool operator ==(Object other) =>
      other is WeekBucket &&
      year == other.year &&
      month == other.month &&
      week == other.week;

  @override
  int get hashCode => Object.hash(year, month, week);

  @override
  String toString() => 'WeekBucket($year-$month w$week)';
}

DateTime _shift(DateTime date, int days) =>
    DateTime.utc(date.year, date.month, date.day + days);

DateTime _monday(DateTime date) => _shift(date, 1 - date.weekday);

DateTime _firstThursday(int year, int month) {
  final first = DateTime.utc(year, month);
  return _shift(first, (DateTime.thursday - first.weekday) % 7);
}

/// A month owns one week per Thursday: four or five, never a partial week.
int macroGoalWeeksInMonth(int year, int month) {
  final first = _firstThursday(year, month);
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return (lastDay - first.day) ~/ 7 + 1;
}

WeekBucket weekBucketOf(DateTime date) {
  final thursday = _shift(_monday(date), 3);
  return WeekBucket(
    year: thursday.year,
    month: thursday.month,
    week: (thursday.day - 1) ~/ 7 + 1,
  );
}

/// Normalizes a NEW calendar address. Stored pre-calendar addresses must use
/// [storedWeekBucket] instead; the two formats are distinguished by the stored
/// `week_start_date`, never by guessing from a week number or creation time.
WeekBucket canonicalWeekBucket(int year, int month, int week) => weekBucketOf(
  _shift(_firstThursday(year, month), 7 * ((week < 1 ? 1 : week) - 1)),
);

MacroGoalDateRange weekBucketRange(int year, int month, int week) {
  final start = _shift(
    _firstThursday(year, month),
    -3 + 7 * ((week < 1 ? 1 : week) - 1),
  );
  return MacroGoalDateRange(start: start, end: _shift(start, 6));
}

WeekBucket nextWeekBucket(WeekBucket bucket) => weekBucketOf(
  _shift(weekBucketRange(bucket.year, bucket.month, bucket.week).start, 7),
);

WeekBucket prevWeekBucket(WeekBucket bucket) => weekBucketOf(
  _shift(weekBucketRange(bucket.year, bucket.month, bucket.week).start, -7),
);

({int year, int month}) reanchorPeriod({
  required DateTime now,
  required bool toWeekly,
  required int year,
  required int month,
}) {
  final bucket = weekBucketOf(now);
  if (toWeekly) {
    if (year == now.year && month == now.month) {
      return (year: bucket.year, month: bucket.month);
    }
  } else if (year == bucket.year && month == bucket.month) {
    return (year: now.year, month: now.month);
  }
  return (year: year, month: month);
}

/// Converts a legacy four-period address to the real week with most overlap.
/// Legacy week >= 5 meant next month's first period, whose start could be the
/// previous month's 29th. Equal overlaps choose the earlier week, consistently
/// across devices and the SQL migration. No target/status/progress is mutated.
WeekBucket legacyWeekBucket(int year, int month, int week) {
  final owner = DateTime.utc(year, month + (week >= 5 ? 1 : 0));
  final index = week >= 5 || week < 1 ? 1 : week;
  final previousLast = DateTime.utc(owner.year, owner.month, 0);
  final start = index == 1 && previousLast.day > 28
      ? DateTime.utc(previousLast.year, previousLast.month, 29)
      : DateTime.utc(owner.year, owner.month, (index - 1) * 7 + 1);
  final end = DateTime.utc(owner.year, owner.month, index * 7);
  var bestStart = _monday(start);
  var bestOverlap = -1;
  for (
    var monday = bestStart;
    !monday.isAfter(end);
    monday = _shift(monday, 7)
  ) {
    final sunday = _shift(monday, 6);
    final from = monday.isBefore(start) ? start : monday;
    final to = sunday.isAfter(end) ? end : sunday;
    final overlap = to.difference(from).inDays + 1;
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      bestStart = monday;
    }
  }
  return weekBucketOf(bestStart);
}

String calendarDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Strict date-only parsing: a malformed marker must not turn an impossible
/// date such as February 31 into a different, seemingly valid stored week.
DateTime? _parseWeekStart(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  return parsed != null &&
          calendarDateKey(parsed) == value &&
          parsed.weekday == DateTime.monday
      ? parsed
      : null;
}

WeekBucket? storedWeekBucket(Map<String, dynamic> row) {
  if (row['type'] != 'weekly') return null;
  final start = _parseWeekStart(row['week_start_date']);
  if (start != null) return weekBucketOf(start);
  final year = (row['year'] as num?)?.toInt();
  final month = (row['month'] as num?)?.toInt();
  final week = (row['week_number'] as num?)?.toInt();
  if (year == null || month == null || week == null) return null;
  return legacyWeekBucket(year, month, week);
}

/// Idempotent on reads, imports, migrations and sync. The explicit Monday is
/// authoritative, so an already-converted goal can never be converted twice.
Map<String, dynamic> normalizeStoredMacroGoal(Map<String, dynamic> row) {
  final bucket = storedWeekBucket(row);
  if (bucket == null) return row;
  return {
    ...row,
    'year': bucket.year,
    'month': bucket.month,
    'week_number': bucket.week,
    'week_start_date': calendarDateKey(
      weekBucketRange(bucket.year, bucket.month, bucket.week).start,
    ),
  };
}

String? macroGoalWeekStartDate({
  required String type,
  int? year,
  int? month,
  int? week,
}) => type == 'weekly' && year != null && month != null && week != null
    ? calendarDateKey(weekBucketRange(year, month, week).start)
    : null;

MacroGoalDateRange? storedMacroGoalPeriodRange(Map<String, dynamic> row) {
  final normalized = normalizeStoredMacroGoal(row);
  return macroGoalPeriodRange(
    type: normalized['type'] as String? ?? 'lifetime',
    year: (normalized['year'] as num?)?.toInt(),
    quarter: (normalized['quarter'] as num?)?.toInt(),
    month: (normalized['month'] as num?)?.toInt(),
    week: (normalized['week_number'] as num?)?.toInt(),
  );
}

/// Inclusive UTC civil-date range. Incomplete/lifetime periods are unbounded.
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
        start: DateTime.utc(year),
        end: DateTime.utc(year, 12, 31),
      );
    case 'quarterly':
      if (year == null || quarter == null) return null;
      final firstMonth = (quarter - 1) * 3 + 1;
      return MacroGoalDateRange(
        start: DateTime.utc(year, firstMonth),
        end: DateTime.utc(year, firstMonth + 3, 0),
      );
    case 'monthly':
      if (year == null || month == null) return null;
      return MacroGoalDateRange(
        start: DateTime.utc(year, month),
        end: DateTime.utc(year, month + 1, 0),
      );
    case 'weekly':
      if (year == null || month == null || week == null) return null;
      return weekBucketRange(year, month, week);
    default:
      return null;
  }
}
