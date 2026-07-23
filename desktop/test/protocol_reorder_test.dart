import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/habits/application/protocol_reorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A fixed "today" so the active/inactive split is deterministic.
  final now = DateTime(2026, 7, 23);

  DashboardHabit habit(
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) => DashboardHabit(
    id: id,
    title: id,
    color: EvolveColors.primaryStrong,
    streak: 0,
    weeklyProgress: const [false, false, false, false, false, false, false],
    state: HabitState.pending,
    startDate: startDate,
    endDate: endDate,
    isActive: isActive,
  );

  group('reorderActiveHabits', () {
    test('reorders active rows while pinning an inactive habit in place', () {
      final full = [
        habit('a'), // active
        habit('b', endDate: DateTime(2026, 7, 1)), // ended → inactive
        habit('c'), // active
        habit('d'), // active
      ];
      // Visible (active) subset is [a, c, d]; move 'a' (index 0) to the end.
      final result = reorderActiveHabits(
        full: full,
        on: now,
        oldIndex: 0,
        newIndex: 2,
      );
      // 'b' never leaves index 1; the active slots refill as c, d, a. A plain
      // index reorder would have produced ['b', 'c', 'd', 'a'] instead.
      expect(result.map((h) => h.id).toList(), ['c', 'b', 'd', 'a']);
      // display_order is left untouched here — the controller reassigns it.
    });

    test('treats a not-yet-started habit as inactive and pinned', () {
      final full = [
        habit('a'), // active
        habit('b'), // active
        habit('c', startDate: DateTime(2026, 8, 1)), // future → inactive
      ];
      // Visible subset [a, b]; move 'b' (index 1) to the front.
      final result = reorderActiveHabits(
        full: full,
        on: now,
        oldIndex: 1,
        newIndex: 0,
      );
      expect(result.map((h) => h.id).toList(), ['b', 'a', 'c']);
    });

    test('respects the isActive flag when splitting active from hidden', () {
      final full = [
        habit('a'),
        habit('b', isActive: false), // paused → inactive
        habit('c'),
      ];
      // Visible subset [a, c]; move 'c' (index 1) to the front.
      final result = reorderActiveHabits(
        full: full,
        on: now,
        oldIndex: 1,
        newIndex: 0,
      );
      expect(result.map((h) => h.id).toList(), ['c', 'b', 'a']);
    });

    test('behaves like a plain reorder when every habit is active', () {
      final full = [habit('a'), habit('b'), habit('c')];
      final result = reorderActiveHabits(
        full: full,
        on: now,
        oldIndex: 0,
        newIndex: 2,
      );
      expect(result.map((h) => h.id).toList(), ['b', 'c', 'a']);
    });

    test('returns the same list identity for a no-op move', () {
      final full = [habit('a'), habit('b')];
      final result = reorderActiveHabits(
        full: full,
        on: now,
        oldIndex: 0,
        newIndex: 0,
      );
      expect(identical(result, full), isTrue);
    });

    test('returns the same list identity when the index is out of range', () {
      final full = [
        habit('a'),
        habit('b', endDate: DateTime(2026, 7, 1)), // inactive
      ];
      // Only one active row (index 0); index 1 is beyond the active subset.
      final result = reorderActiveHabits(
        full: full,
        on: now,
        oldIndex: 1,
        newIndex: 0,
      );
      expect(identical(result, full), isTrue);
    });
  });
}
