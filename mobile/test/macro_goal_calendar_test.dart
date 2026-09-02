import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/macro_goal_calendar.dart';

void main() {
  group('macro goal calendar', () {
    test('keeps the first seven month days inside the first logical week', () {
      expect(weekBucketOf(DateTime(2026, 2, 1)).week, 1);
      expect(weekBucketOf(DateTime(2026, 2, 2)).week, 1);
      expect(weekBucketOf(DateTime(2026, 2, 7)).week, 1);
      expect(weekBucketOf(DateTime(2026, 2, 8)).week, 2);
    });

    test('every month offers the same four addressable weeks', () {
      // Whatever the month's length, its last addressable week ends on the 28th
      // — the tail belongs to the next month's week 1.
      for (final (year, month) in const [
        (2026, 2), // 28 days
        (2024, 2), // 29 days
        (2026, 4), // 30 days
        (2026, 5), // 31 days
      ]) {
        final last = weekBucketRange(year, month, macroGoalWeeksInMonth);
        expect(last.end, DateTime.utc(year, month, 28));
        expect(last.end.difference(last.start).inDays, 6);
      }
    });

    test('merges a stored week 5 forward into the next month week 1', () {
      expect(
        canonicalWeekBucket(2026, 8, 5),
        const WeekBucket(year: 2026, month: 9, week: 1),
      );
      // Across the year boundary too.
      expect(
        canonicalWeekBucket(2026, 12, 5),
        const WeekBucket(year: 2027, month: 1, week: 1),
      );
      // Weeks 1-4 are already canonical.
      expect(
        canonicalWeekBucket(2026, 8, 4),
        const WeekBucket(year: 2026, month: 8, week: 4),
      );
    });

    test('places the tail days of a month in the next month week 1', () {
      expect(
        weekBucketOf(DateTime(2026, 8, 29)),
        const WeekBucket(year: 2026, month: 9, week: 1),
      );
      expect(
        weekBucketOf(DateTime(2026, 12, 31)),
        const WeekBucket(year: 2027, month: 1, week: 1),
      );
    });

    test('weeks two to four are always exactly seven days', () {
      for (final month in [2, 5, 8, 12]) {
        for (final week in [2, 3, 4]) {
          final range = weekBucketRange(2026, month, week);
          expect(range.start.day, (week - 1) * 7 + 1);
          expect(range.end.difference(range.start).inDays, 6);
          expect(range.start.month, month);
          expect(range.end.month, month);
        }
      }
    });

    test('week 1 absorbs the previous month tail when there is one', () {
      final september = weekBucketRange(2026, 9, 1);
      expect(september.start, DateTime.utc(2026, 8, 29));
      expect(september.end, DateTime.utc(2026, 9, 7));

      // The legacy spelling of the same bucket resolves identically.
      final augustWeekFive = weekBucketRange(2026, 8, 5);
      expect(augustWeekFive.start, september.start);
      expect(augustWeekFive.end, september.end);
    });

    test('week 1 after a 28-day February is an ordinary seven days', () {
      final march = weekBucketRange(2026, 3, 1);
      expect(march.start, DateTime.utc(2026, 3, 1));
      expect(march.end, DateTime.utc(2026, 3, 7));
    });

    test('week 1 absorbs a leap February tail', () {
      final march = weekBucketRange(2024, 3, 1);
      expect(march.start, DateTime.utc(2024, 2, 29));
      expect(march.end, DateTime.utc(2024, 3, 7));
    });

    test('week 1 of January reaches back into the previous year', () {
      final january = weekBucketRange(2026, 1, 1);
      expect(january.start, DateTime.utc(2025, 12, 29));
      expect(january.end, DateTime.utc(2026, 1, 7));
    });

    test('navigation never stops on the same bucket twice', () {
      var bucket = const WeekBucket(year: 2026, month: 8, week: 3);
      final seen = <WeekBucket>{bucket};
      for (var step = 0; step < 60; step++) {
        final next = nextWeekBucket(bucket);
        expect(seen.add(next), isTrue, reason: 'revisited $next');
        expect(next.week, inInclusiveRange(1, macroGoalWeeksInMonth));
        bucket = next;
      }
    });

    test('next and previous are inverses', () {
      var bucket = const WeekBucket(year: 2025, month: 11, week: 2);
      for (var step = 0; step < 40; step++) {
        final next = nextWeekBucket(bucket);
        expect(prevWeekBucket(next), bucket);
        bucket = next;
      }
    });

    test('advancing a legacy week 5 leaves its own bucket', () {
      // The bug this model exists to prevent: a rescheduled week-5 goal used to
      // land on the next month's week 1, which IS the week it just failed in.
      final legacy = canonicalWeekBucket(2026, 8, 5);
      expect(nextWeekBucket(legacy), isNot(legacy));
      expect(
        nextWeekBucket(legacy),
        const WeekBucket(year: 2026, month: 9, week: 2),
      );
    });

    test('every day of 2024-2027 falls in exactly one bucket', () {
      // The property the whole merge exists for: no overlap (a habit day summed
      // into two weekly goals) and no gap (a day counting toward nothing).
      //
      // Checked globally rather than against the neighbouring buckets only, so
      // the assertion matches the claim: every day is covered by exactly one
      // bucket's range, and every bucket's range covers only its own days.
      final owner = <DateTime, WeekBucket>{};
      var day = DateTime.utc(2024, 1, 1);
      final last = DateTime.utc(2027, 12, 31);
      while (!day.isAfter(last)) {
        owner[day] = weekBucketOf(day);
        day = day.add(const Duration(days: 1));
      }

      // Walk every bucket the period spans and paint the days its range claims.
      final claims = <DateTime, List<WeekBucket>>{};
      var bucket = weekBucketOf(DateTime.utc(2024, 1, 1));
      final stop = weekBucketOf(DateTime.utc(2027, 12, 31));
      while (true) {
        final range = weekBucketRange(bucket.year, bucket.month, bucket.week);
        var d = range.start;
        while (!d.isAfter(range.end)) {
          (claims[d] ??= <WeekBucket>[]).add(bucket);
          d = d.add(const Duration(days: 1));
        }
        if (bucket == stop) break;
        bucket = nextWeekBucket(bucket);
      }

      for (final entry in owner.entries) {
        final claimants = claims[entry.key] ?? const <WeekBucket>[];
        expect(
          claimants,
          hasLength(1),
          reason: '\${entry.key} is claimed by \$claimants',
        );
        expect(claimants.single, entry.value);
      }
    });
  });
}
