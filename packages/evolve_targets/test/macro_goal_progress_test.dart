import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveMacroProgressAmount', () {
    test('linked ⇒ uses the summed linked-habit progress, not the stored value',
        () {
      expect(
        resolveMacroProgressAmount(
            isLinked: true, storedAmount: 999, linkedSum: 320),
        320,
      );
    });

    test('unlinked ⇒ uses the stored value, not any stray linked sum', () {
      expect(
        resolveMacroProgressAmount(
            isLinked: false, storedAmount: 12, linkedSum: 999),
        12,
      );
    });

    test('a linked goal with no logged progress reads as 0', () {
      expect(
        resolveMacroProgressAmount(isLinked: true, linkedSum: null),
        0,
      );
    });

    test('a manual goal never advanced reads as 0', () {
      expect(
        resolveMacroProgressAmount(isLinked: false, storedAmount: null),
        0,
      );
    });

    test('a negative stored value floors at 0', () {
      expect(
        resolveMacroProgressAmount(isLinked: false, storedAmount: -5),
        0,
      );
    });
  });

  group('evaluateMacroGoalProgress', () {
    test('null target ⇒ null (an ordinary boolean macro goal)', () {
      expect(
        evaluateMacroGoalProgress(targetAmount: null, isLinked: false),
        isNull,
      );
    });

    test('non-positive target ⇒ null (corrupt / hand-built)', () {
      expect(
        evaluateMacroGoalProgress(targetAmount: 0, isLinked: false),
        isNull,
      );
      expect(
        evaluateMacroGoalProgress(targetAmount: -10, isLinked: false),
        isNull,
      );
    });

    test('derived progress: sums the linked habit toward the target', () {
      final p = evaluateMacroGoalProgress(
        targetAmount: 500,
        unit: TargetUnit.kilometers,
        isLinked: true,
        linkedSum: 320,
        storedAmount: 0, // ignored while linked
      )!;
      expect(p.amount, 320);
      expect(p.target, 500);
      expect(p.unit, TargetUnit.kilometers);
      expect(p.fraction, closeTo(0.64, 1e-9));
      expect(p.rawFraction, closeTo(0.64, 1e-9));
      expect(p.isComplete, isFalse);
    });

    test('stored progress: a manual goal reads its own value', () {
      final p = evaluateMacroGoalProgress(
        targetAmount: 24,
        unit: TargetUnit.count,
        isLinked: false,
        storedAmount: 6,
        linkedSum: 99, // ignored while unlinked
      )!;
      expect(p.amount, 6);
      expect(p.fraction, closeTo(0.25, 1e-9));
      expect(p.isComplete, isFalse);
    });

    test('reaching the target marks it complete and fills the bar', () {
      final p = evaluateMacroGoalProgress(
        targetAmount: 500,
        isLinked: true,
        linkedSum: 500,
      )!;
      expect(p.isComplete, isTrue);
      expect(p.fraction, 1.0);
      expect(p.rawFraction, 1.0);
    });

    test('overachievement clamps the bar but keeps the raw ratio', () {
      final p = evaluateMacroGoalProgress(
        targetAmount: 500,
        isLinked: true,
        linkedSum: 700,
      )!;
      expect(p.isComplete, isTrue);
      expect(p.fraction, 1.0); // clamped for the bar
      expect(p.rawFraction, closeTo(1.4, 1e-9)); // 140% preserved
    });

    test('a linked goal with no progress is 0% but a valid (not null) result',
        () {
      final p = evaluateMacroGoalProgress(
        targetAmount: 500,
        isLinked: true,
        linkedSum: null,
      )!;
      expect(p.amount, 0);
      expect(p.fraction, 0);
      expect(p.isComplete, isFalse);
    });
  });
}
