import 'package:evolve_sync/macro_goal_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every civil date has one seven-day week, owned by Thursday', () {
    // Includes leap centuries, leap days, year/month edges and every weekday
    // alignment. The oracle uses the containing week's actual Thursday.
    for (var date = DateTime.utc(1999); date.year <= 2101;
        date = date.add(const Duration(days: 1))) {
      final b = weekBucketOf(date);
      final r = weekBucketRange(b.year, b.month, b.week);
      expect(r.start.weekday, DateTime.monday);
      expect(r.end.weekday, DateTime.sunday);
      expect(r.end.difference(r.start).inDays, 6);
      expect(!date.isBefore(r.start) && !date.isAfter(r.end), isTrue);
      final thursday = r.start.add(const Duration(days: 3));
      expect((b.year, b.month), (thursday.year, thursday.month));
      expect(b.week, inInclusiveRange(1, macroGoalWeeksInMonth(b.year, b.month)));
      expect(prevWeekBucket(nextWeekBucket(b)), b);
      expect(weekBucketRange(nextWeekBucket(b).year, nextWeekBucket(b).month,
          nextWeekBucket(b).week).start, r.end.add(const Duration(days: 1)));
    }
  });

  test('four/five weeks per month and ISO-style year ownership', () {
    expect(macroGoalWeeksInMonth(2026, 1), 5);
    expect(macroGoalWeeksInMonth(2026, 2), 4);
    expect(weekBucketOf(DateTime(2027, 1, 3)),
        const WeekBucket(year: 2026, month: 12, week: 5));
    expect(weekBucketOf(DateTime(2025, 12, 29)),
        const WeekBucket(year: 2026, month: 1, week: 1));
  });

  test('legacy mapping maximizes overlap, including ties and week-five aliases', () {
    for (var year = 2020; year <= 2030; year++) {
      for (var month = 1; month <= 12; month++) {
        for (var week = 1; week <= 5; week++) {
          final m = DateTime.utc(year, month + (week == 5 ? 1 : 0));
          final w = week == 5 ? 1 : week;
          final previousLast = DateTime.utc(m.year, m.month, 0);
          final start = w == 1 && previousLast.day > 28
              ? DateTime.utc(previousLast.year, previousLast.month, 29)
              : DateTime.utc(m.year, m.month, (w - 1) * 7 + 1);
          final end = DateTime.utc(m.year, m.month, w * 7);
          // Independent oracle counts the dates in each candidate week.
          final counts = <WeekBucket, int>{};
          for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
            counts.update(weekBucketOf(d), (n) => n + 1, ifAbsent: () => 1);
          }
          final greatest = counts.values.reduce((a, b) => a > b ? a : b);
          final expected = counts.entries.firstWhere((e) => e.value == greatest).key;
          expect(legacyWeekBucket(year, month, week), expected);
        }
      }
    }
    expect(legacyWeekBucket(2026, 8, 5), legacyWeekBucket(2026, 9, 1));
    // 29 Apr–7 May: 5 days in Apr 27–May 3, 4 in May 4–10.
    expect(legacyWeekBucket(2026, 5, 1),
        const WeekBucket(year: 2026, month: 4, week: 5));
  });

  test('conversion preserves fields, is idempotent and trusts the date marker', () {
    final old = <String, dynamic>{
      'id': 'goal', 'type': 'weekly', 'year': 2026, 'month': 5,
      'week_number': 1, 'status': 'completed', 'target_amount': 100,
      'progress_amount': 87, 'linked_goal_id': 'habit',
    };
    final converted = normalizeStoredMacroGoal(old);
    expect(converted['week_start_date'], '2026-04-27');
    expect((converted['year'], converted['month'], converted['week_number']),
        (2026, 4, 5));
    for (final key in ['id', 'status', 'target_amount', 'progress_amount', 'linked_goal_id']) {
      expect(converted[key], old[key]);
    }
    expect(normalizeStoredMacroGoal(converted), converted);
    expect(normalizeStoredMacroGoal({...converted, 'month': 12}), converted);
    expect(old['week_start_date'], isNull, reason: 'do not mutate a cached payload');
  });

  test('invalid markers fall back to legacy; incomplete and nonweekly rows survive', () {
    final old = <String, dynamic>{'type': 'weekly', 'year': 2026, 'month': 9, 'week_number': 1};
    for (final invalid in ['2026-02-31', 'garbage', '2026-09-01', '2026-08-31T00:00:00Z']) {
      expect(normalizeStoredMacroGoal({...old, 'week_start_date': invalid}),
          normalizeStoredMacroGoal(old));
    }
    expect(storedWeekBucket({'type': 'weekly'}), isNull);
    final monthly = {...old, 'type': 'monthly'};
    expect(normalizeStoredMacroGoal(monthly), monthly);
  });
}
