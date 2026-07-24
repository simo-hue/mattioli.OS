import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/macro_goal_calendar.dart';
import 'package:mattioli_os/core/macro_goal_progress_resolver.dart';
import 'package:mattioli_os/core/supabase_macro_goal_progress.dart';

void main() {
  group('resolveMacroGoalProgress', () {
    test('manual goal reads the stored amount without querying', () async {
      var called = false;
      final amount = await resolveMacroGoalProgress(
        typeWireName: 'annual',
        year: 2026,
        linkedGoalId: null,
        storedAmount: 320,
        fetchLinkedSum: (_, _) async {
          called = true;
          return 999;
        },
      );
      expect(amount, 320);
      expect(called, isFalse, reason: 'a manual goal must not hit the DB');
    });

    test('manual goal with no stored progress reads as 0', () async {
      final amount = await resolveMacroGoalProgress(
        typeWireName: 'lifetime',
        linkedGoalId: null,
        storedAmount: null,
        fetchLinkedSum: (_, _) async => 999,
      );
      expect(amount, 0);
    });

    test('manual goal floors a corrupt negative stored value at 0', () async {
      final amount = await resolveMacroGoalProgress(
        typeWireName: 'lifetime',
        linkedGoalId: null,
        storedAmount: -50,
        fetchLinkedSum: (_, _) async => 0,
      );
      expect(amount, 0);
    });

    test('linked goal sums the habit over its period range', () async {
      MacroGoalDateRange? seenRange;
      String? seenHabit;
      final amount = await resolveMacroGoalProgress(
        typeWireName: 'annual',
        year: 2026,
        linkedGoalId: 'habit-1',
        storedAmount: 111, // ignored while linked
        fetchLinkedSum: (habitId, range) async {
          seenHabit = habitId;
          seenRange = range;
          return 42.5;
        },
      );
      expect(amount, 42.5);
      expect(seenHabit, 'habit-1');
      // An annual 2026 goal maps to the whole calendar year.
      expect(seenRange, isNotNull);
      expect(seenRange!.start, DateTime.utc(2026, 1, 1));
      expect(seenRange!.end, DateTime.utc(2026, 12, 31));
    });

    test('linked lifetime goal passes a null range (all history)', () async {
      MacroGoalDateRange? seenRange;
      var sawFetch = false;
      await resolveMacroGoalProgress(
        typeWireName: 'lifetime',
        linkedGoalId: 'habit-2',
        fetchLinkedSum: (habitId, range) async {
          sawFetch = true;
          seenRange = range;
          return 7;
        },
      );
      expect(sawFetch, isTrue);
      expect(seenRange, isNull);
    });

    test('linked goal with no logged progress resolves to 0', () async {
      final amount = await resolveMacroGoalProgress(
        typeWireName: 'monthly',
        year: 2026,
        month: 7,
        linkedGoalId: 'habit-3',
        fetchLinkedSum: (_, _) async => 0,
      );
      expect(amount, 0);
    });
  });

  group('evaluateMacroGoalProgress wiring (fraction for the bar)', () {
    test('resolved amount + target yields the clamped fraction + label',
        () async {
      final amount = await resolveMacroGoalProgress(
        typeWireName: 'annual',
        year: 2026,
        linkedGoalId: 'habit-1',
        fetchLinkedSum: (_, _) async => 320,
      );
      final progress = evaluateMacroGoalProgress(
        targetAmount: 500,
        unit: TargetUnit.kilometers,
        isLinked: true,
        linkedSum: amount,
      );
      expect(progress, isNotNull);
      expect(progress!.amount, 320);
      expect(progress.target, 500);
      expect(progress.fraction, closeTo(0.64, 1e-9));
      expect(progress.isComplete, isFalse);
    });

    test('overachievement clamps the bar but keeps rawFraction', () async {
      final amount = await resolveMacroGoalProgress(
        typeWireName: 'annual',
        year: 2026,
        linkedGoalId: 'habit-1',
        fetchLinkedSum: (_, _) async => 700,
      );
      final progress = evaluateMacroGoalProgress(
        targetAmount: 500,
        isLinked: true,
        linkedSum: amount,
      )!;
      expect(progress.fraction, 1.0);
      expect(progress.rawFraction, closeTo(1.4, 1e-9));
      expect(progress.isComplete, isTrue);
    });
  });

  group('sumProgressRows', () {
    test('sums the amount column and treats missing/null as 0', () {
      final total = sumProgressRows([
        {'amount': 10},
        {'amount': 5.5},
        {'amount': null},
        <String, dynamic>{},
      ]);
      expect(total, 15.5);
    });

    test('empty rows sum to 0', () {
      expect(sumProgressRows(const []), 0);
    });
  });

  group('macroGoalProgressDateKey', () {
    test('formats as zero-padded yyyy-MM-dd', () {
      expect(macroGoalProgressDateKey(DateTime.utc(2026, 1, 3)), '2026-01-03');
      expect(macroGoalProgressDateKey(DateTime.utc(2026, 12, 31)), '2026-12-31');
    });
  });
}
