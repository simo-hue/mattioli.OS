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
