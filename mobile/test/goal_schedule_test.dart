import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/models/goal.dart';

void main() {
  Goal habit({List<int>? frequencyDays, DateTime? end}) => Goal(
    id: 'h1',
    title: 'Gym',
    color: const Color(0xFF3B82F6),
    startDate: DateTime(2026, 1, 5), // a Monday
    endDate: end,
    frequencyDays: frequencyDays,
  );

  group('Goal.canonicalFrequencyDays', () {
    test('all 7 days collapse to null (every-day)', () {
      expect(Goal.canonicalFrequencyDays([1, 2, 3, 4, 5, 6, 7]), isNull);
    });

    test('sorts and de-duplicates a partial selection', () {
      expect(Goal.canonicalFrequencyDays([5, 1, 3, 3]), [1, 3, 5]);
    });

    test('null and empty both return null', () {
      expect(Goal.canonicalFrequencyDays(null), isNull);
      expect(Goal.canonicalFrequencyDays([]), isNull);
    });
  });

  group('Goal.isScheduledOn', () {
    // Jan 5 2026 = Mon … Jan 9 = Fri, Jan 10 = Sat.
    test('every-day habit (null) shows on every weekday', () {
      final h = habit(frequencyDays: null);
      for (var day = 5; day <= 11; day++) {
        expect(h.isScheduledOn(DateTime(2026, 1, day)), isTrue);
      }
    });

    test('Mon/Wed/Fri habit shows only on those weekdays', () {
      final h = habit(frequencyDays: [1, 3, 5]);
      expect(h.isScheduledOn(DateTime(2026, 1, 5)), isTrue); // Mon
      expect(h.isScheduledOn(DateTime(2026, 1, 6)), isFalse); // Tue
      expect(h.isScheduledOn(DateTime(2026, 1, 7)), isTrue); // Wed
      expect(h.isScheduledOn(DateTime(2026, 1, 9)), isTrue); // Fri
      expect(h.isScheduledOn(DateTime(2026, 1, 10)), isFalse); // Sat
    });

    test('a scheduled weekday before startDate is still hidden', () {
      final h = habit(frequencyDays: [1, 3, 5]);
      // The Monday one week before start.
      expect(h.isScheduledOn(DateTime(2025, 12, 29)), isFalse);
    });

    test('a scheduled weekday after endDate is hidden', () {
      final h = habit(frequencyDays: [1, 3, 5], end: DateTime(2026, 1, 7));
      expect(h.isScheduledOn(DateTime(2026, 1, 7)), isTrue); // Wed, on end date
      expect(h.isScheduledOn(DateTime(2026, 1, 9)), isFalse); // Fri, after end
    });
  });
}
