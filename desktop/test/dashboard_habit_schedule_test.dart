import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DashboardHabit habit({List<int>? frequencyDays, DateTime? end}) =>
      DashboardHabit(
        id: 'h1',
        title: 'Gym',
        color: const Color(0xFF3B82F6),
        streak: 0,
        weeklyProgress: const [false, false, false, false, false, false, false],
        state: HabitState.pending,
        startDate: DateTime(2026, 1, 5), // a Monday
        endDate: end,
        frequencyDays: frequencyDays,
      );

  group('DashboardHabit.isScheduledOn', () {
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

    test('empty frequencyDays behaves like every-day', () {
      final h = habit(frequencyDays: const []);
      expect(h.isScheduledOn(DateTime(2026, 1, 6)), isTrue); // Tue
    });

    test('a scheduled weekday after endDate is hidden', () {
      final h = habit(frequencyDays: [1, 3, 5], end: DateTime(2026, 1, 7));
      expect(h.isScheduledOn(DateTime(2026, 1, 7)), isTrue); // Wed, on end date
      expect(h.isScheduledOn(DateTime(2026, 1, 9)), isFalse); // Fri, after end
    });
  });
}
