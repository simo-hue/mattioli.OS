import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('axis aliases share one wire vocabulary with verification', () {
    // These identities are the whole reason the aliases exist: a rule and a
    // target must never disagree about what 'lte' or 'minutes' means.
    test('direction is the verification comparator', () {
      expect(TargetDirection.atMost, VerificationComparator.atMost);
      expect(TargetDirection.atLeast.wireName, 'gte');
      expect(TargetDirection.atMost.wireName, 'lte');
    });

    test('unit and aggregation are the verification ones', () {
      expect(TargetUnit.minutes, VerificationUnit.minutes);
      expect(TargetAggregation.count, VerificationAggregation.count);
    });

    test('measured fill sources use the provider wire names verbatim', () {
      for (final p in VerificationProvider.values) {
        expect(targetFillSourceForProvider(p).wireName, p.wireName);
      }
    });
  });

  group('period wire names', () {
    test('round-trip and reject the unknown', () {
      for (final p in TargetPeriod.values) {
        expect(TargetPeriod.fromWire(p.wireName), p);
      }
      expect(TargetPeriod.fromWire('quarter'), isNull);
      expect(TargetPeriod.fromWire(null), isNull);
      for (final i in TargetInput.values) {
        expect(TargetInput.fromWire(i.wireName), i);
      }
      expect(TargetInput.fromWire('telepathy'), isNull);
    });
  });

  group('daysInPeriod', () {
    test('a day period is just that day, normalised to midnight', () {
      final days = daysInPeriod(TargetPeriod.day, DateTime(2026, 7, 23, 14, 32));
      expect(days, [DateTime(2026, 7, 23)]);
    });

    test('a week starts on Monday by default', () {
      // 2026-07-23 is a Thursday.
      final days = daysInPeriod(TargetPeriod.week, DateTime(2026, 7, 23));
      expect(days.first, DateTime(2026, 7, 20)); // Monday
      expect(days.last, DateTime(2026, 7, 26)); // Sunday
      expect(days.length, 7);
    });

    test('a week can start on Sunday when the user prefers it', () {
      final days = daysInPeriod(TargetPeriod.week, DateTime(2026, 7, 23),
          weekStartsOnMonday: false);
      expect(days.first, DateTime(2026, 7, 19)); // Sunday
      expect(days.last, DateTime(2026, 7, 25));
    });

    test('a Sunday is the END of a Monday week, not the start', () {
      final days = daysInPeriod(TargetPeriod.week, DateTime(2026, 7, 26));
      expect(days.first, DateTime(2026, 7, 20));
      expect(days.last, DateTime(2026, 7, 26));
    });

    test('a Sunday is the START of a Sunday week', () {
      final days = daysInPeriod(TargetPeriod.week, DateTime(2026, 7, 26),
          weekStartsOnMonday: false);
      expect(days.first, DateTime(2026, 7, 26));
    });

    test('a month spans exactly its own days, leap years included', () {
      expect(daysInPeriod(TargetPeriod.month, DateTime(2026, 7, 15)).length, 31);
      expect(daysInPeriod(TargetPeriod.month, DateTime(2026, 2, 15)).length, 28);
      expect(daysInPeriod(TargetPeriod.month, DateTime(2028, 2, 15)).length, 29);
      final feb = daysInPeriod(TargetPeriod.month, DateTime(2028, 2, 15));
      expect(feb.first, DateTime(2028, 2, 1));
      expect(feb.last, DateTime(2028, 2, 29));
    });

    test('a week may straddle a month or year boundary', () {
      final days = daysInPeriod(TargetPeriod.week, DateTime(2026, 12, 31));
      expect(days.first, DateTime(2026, 12, 28));
      expect(days.last, DateTime(2027, 1, 3));
    });

    test('every day of a year lands in a week that starts on the right day',
        () {
      // The DST guard, written as an invariant rather than a fixed date so it
      // needs no timezone harness: whatever zone the process runs in, a week
      // must be seven consecutive dates, must begin on the configured first
      // day, and must CONTAIN its own anchor.
      //
      // Walking back with `subtract(Duration(days: n))` breaks all three at
      // once, because a `Duration` is a fixed 24 hours and a calendar day is
      // not. Under `TZ=Europe/Rome` with Sunday-start weeks, 2026-03-29 is 23
      // hours long, so stepping back from Saturday 2026-04-04 00:00 by 6×24h
      // undershoots to `03-28 23:00` — a SATURDAY — and the week returned is
      // 03-28…04-03, which does not contain 04-04 at all. In a zone without
      // DST (CI runs UTC) every anchor below already passed, so this is a
      // regression guard, not a probe.
      for (final mondayStart in [true, false]) {
        var anchor = DateTime(2026);
        while (anchor.year == 2026) {
          final days = daysInPeriod(TargetPeriod.week, anchor,
              weekStartsOnMonday: mondayStart);
          final where = 'anchor $anchor, mondayStart=$mondayStart';
          expect(days.length, DateTime.daysPerWeek, reason: where);
          expect(days.first.weekday,
              mondayStart ? DateTime.monday : DateTime.sunday,
              reason: where);
          expect(days, contains(anchor), reason: where);
          for (var i = 1; i < days.length; i++) {
            final prev = days[i - 1];
            expect(days[i], DateTime(prev.year, prev.month, prev.day + 1),
                reason: where);
          }
          anchor = DateTime(anchor.year, anchor.month, anchor.day + 1);
        }
      }
    });
  });

  group('periodIsOver', () {
    test('a day is over only once the calendar has moved on', () {
      final day = DateTime(2026, 7, 23);
      expect(periodIsOver(TargetPeriod.day, day, DateTime(2026, 7, 23, 23, 59)),
          isFalse);
      expect(periodIsOver(TargetPeriod.day, day, DateTime(2026, 7, 24)), isTrue);
    });

    test('a past day stays over', () {
      expect(
          periodIsOver(
              TargetPeriod.day, DateTime(2026, 1, 1), DateTime(2026, 7, 23)),
          isTrue);
    });

    test('a future day is not over', () {
      expect(
          periodIsOver(
              TargetPeriod.day, DateTime(2026, 8, 1), DateTime(2026, 7, 23)),
          isFalse);
    });

    test('a week is over only after its last day', () {
      final thursday = DateTime(2026, 7, 23);
      expect(periodIsOver(TargetPeriod.week, thursday, DateTime(2026, 7, 26)),
          isFalse, reason: 'Sunday is still inside the week');
      expect(periodIsOver(TargetPeriod.week, thursday, DateTime(2026, 7, 27)),
          isTrue);
    });

    test('a month is over only after its last day', () {
      final mid = DateTime(2026, 7, 15);
      expect(periodIsOver(TargetPeriod.month, mid, DateTime(2026, 7, 31)),
          isFalse);
      expect(
          periodIsOver(TargetPeriod.month, mid, DateTime(2026, 8, 1)), isTrue);
    });
  });
}
