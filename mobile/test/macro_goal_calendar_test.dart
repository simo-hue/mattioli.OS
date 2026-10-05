import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/macro_goal_calendar.dart';

void main() {
  test('weekly ranges are Monday–Sunday, including a fifth owned week', () {
    final january = weekBucketRange(2026, 1, 5);
    expect(january.start, DateTime.utc(2026, 1, 26));
    expect(january.end, DateTime.utc(2026, 2, 1));
    expect(
      nextWeekBucket(const WeekBucket(year: 2026, month: 1, week: 5)),
      const WeekBucket(year: 2026, month: 2, week: 1),
    );
    expect(macroGoalWeeksInMonth(2026, 1), 5);
    expect(macroGoalWeeksInMonth(2026, 2), 4);
  });

  test('week ownership remains constant across its month/year boundary', () {
    for (var offset = 0; offset < 7; offset++) {
      expect(
        weekBucketOf(DateTime(2025, 12, 29 + offset, 23, 30)),
        const WeekBucket(year: 2026, month: 1, week: 1),
      );
    }
  });

  test('legacy periods map to their greatest-overlap week', () {
    expect(
      legacyWeekBucket(2026, 8, 5),
      const WeekBucket(year: 2026, month: 9, week: 1),
    );
    expect(
      legacyWeekBucket(2026, 5, 1),
      const WeekBucket(year: 2026, month: 4, week: 5),
    );
  });

  test('plan reanchoring works at both ends of a month', () {
    for (final now in [DateTime(2026, 8, 31), DateTime(2027, 1, 1)]) {
      final b = weekBucketOf(now);
      final weekly = reanchorPeriod(
        now: now,
        toWeekly: true,
        year: now.year,
        month: now.month,
      );
      expect(weekly, (year: b.year, month: b.month));
      expect(
        reanchorPeriod(
          now: now,
          toWeekly: false,
          year: weekly.year,
          month: weekly.month,
        ),
        (year: now.year, month: now.month),
      );
      expect(reanchorPeriod(now: now, toWeekly: true, year: 2020, month: 6), (
        year: 2020,
        month: 6,
      ));
    }
  });
}
