// The amount/step contract both apps score against. It lives here precisely so
// iPhone and Mac cannot disagree about what counts as a valid habit.
import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final count = TargetPresetCatalog.countDaily; // atLeast, 1..100000, step 1
  final limit = TargetPresetCatalog.limitCountDaily; // atMost, 0.5..10000
  final minutes = TargetPresetCatalog.durationDaily; // atLeast, 1..1440

  List<TargetIssueKind> kinds(
    TargetPreset preset, {
    required double? amount,
    required double? step,
  }) =>
      validateHabitTarget(preset: preset, amount: amount, step: step)
          .map((i) => i.kind)
          .toList();

  group('a sound combination reports nothing', () {
    test('80 push-ups in sets of 20', () {
      expect(kinds(count, amount: 80, step: 20), isEmpty);
    });

    test('at most 1 coffee, step 1 — step EQUAL to the amount is correct', () {
      // The obvious limit habit. If this ever warns, the feature is crying wolf
      // on its own most common case.
      expect(kinds(limit, amount: 1, step: 1), isEmpty);
    });

    test('a fractional amount the preset explicitly allows', () {
      expect(kinds(limit, amount: 0.5, step: 0.5), isEmpty);
    });
  });

  group('blocking issues', () {
    test('an amount below the preset minimum', () {
      final issues = validateHabitTarget(preset: count, amount: 0, step: 1);
      expect(issues.single.kind, TargetIssueKind.amountOutOfRange);
      expect(issues.single.isBlocking, isTrue);
      // The message needs the bounds, not just the fact.
      expect(issues.single.lowerBound, count.minAmount);
      expect(issues.single.upperBound, count.maxAmount);
    });

    test('an amount above the preset maximum', () {
      expect(kinds(minutes, amount: 2000, step: 5),
          contains(TargetIssueKind.amountOutOfRange));
    });

    test('an empty amount is out of range, not silently zero', () {
      expect(kinds(count, amount: null, step: 1),
          contains(TargetIssueKind.amountOutOfRange));
    });

    test('a zero or empty step blocks', () {
      expect(kinds(count, amount: 80, step: 0),
          contains(TargetIssueKind.stepNotPositive));
      expect(kinds(count, amount: 80, step: null),
          contains(TargetIssueKind.stepNotPositive));
    });

    test('relationship checks stay quiet while a value is individually broken',
        () {
      // "80 is not divisible by 0" on top of "the step cannot be 0" is noise.
      expect(kinds(count, amount: 80, step: 0), [
        TargetIssueKind.stepNotPositive,
      ]);
    });
  });

  group('warnings — legal, but probably not what was meant', () {
    test('one tap overshoots the whole goal', () {
      final issues = validateHabitTarget(preset: count, amount: 80, step: 100);
      expect(issues.single.kind, TargetIssueKind.stepExceedsAmount);
      expect(issues.single.isBlocking, isFalse,
          reason: 'a single-tap day is unusual, not forbidden');
    });

    test('the goal is unreachable in whole taps, and says what IS reachable',
        () {
      // 80 with step 30: taps land on 60 and 90, never 80.
      final issues = validateHabitTarget(preset: count, amount: 80, step: 30);
      final issue =
          issues.firstWhere((i) => i.kind == TargetIssueKind.amountNotDivisibleByStep);
      expect(issue.lowerBound, 60);
      expect(issue.upperBound, 90);
      expect(issue.isBlocking, isFalse);
    });

    test('a hundred taps a day is flagged — the complaint that started this', () {
      final issues = validateHabitTarget(preset: count, amount: 100, step: 1);
      final issue =
          issues.firstWhere((i) => i.kind == TargetIssueKind.tooManyTaps);
      expect(issue.taps, 100);
    });

    test('just under the threshold stays quiet', () {
      expect(kinds(count, amount: kMaxReasonableTaps.toDouble(), step: 1),
          isEmpty);
    });

    test('tap count is NOT reported for a limit habit', () {
      // "At most 1000 coffees, step 1" is 1000 taps on paper, but nobody taps
      // their way to a ceiling — the number is meaningless there.
      expect(kinds(limit, amount: 1000, step: 1),
          isNot(contains(TargetIssueKind.tooManyTaps)));
    });
  });

  group('floating point does not invent problems', () {
    test('a fractional step that divides exactly is not flagged', () {
      // 3 / 0.5 == 6 exactly, but binary floating point makes naive % unsafe.
      expect(kinds(limit, amount: 3, step: 0.5), isEmpty);
    });

    test('an amount exactly at a bound is inside it', () {
      expect(kinds(minutes, amount: minutes.maxAmount, step: minutes.maxAmount),
          isEmpty);
      expect(kinds(limit, amount: limit.minAmount, step: limit.minAmount),
          isEmpty);
    });
  });

  group('HabitTarget.hasSameScoringMeaningAs', () {
    final base = TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);

    test('a step-only change scores identically', () {
      final restepped = base.copyWith(step: 10);
      expect(base == restepped, isFalse, reason: 'they are not equal objects');
      expect(base.hasSameScoringMeaningAs(restepped), isTrue,
          reason: 'but 80 is still 80 — no past day can change verdict');
    });

    test('an amount change does NOT score identically', () {
      expect(base.hasSameScoringMeaningAs(base.copyWith(amount: 100)), isFalse);
    });

    test('a direction change does NOT score identically', () {
      expect(
        base.hasSameScoringMeaningAs(
          base.copyWith(direction: TargetDirection.atMost),
        ),
        isFalse,
      );
    });

    test('identical targets score identically', () {
      expect(base.hasSameScoringMeaningAs(base), isTrue);
    });
  });

  group('the save gate only re-prompts on a CHANGED target', () {
    // Both apps skip the "Save anyway" confirmation when the target is
    // unchanged, so an accepted warning does not re-ask on every later rename or
    // recolour. That gate uses FULL equality, not hasSameScoringMeaningAs — and
    // this pins why: the divisibility and tap-count warnings both depend on
    // `step`, so a step-only edit genuinely CAN change which warnings apply and
    // must be re-prompted.
    final base = TargetPresetCatalog.countDaily.targetWith(amount: 100, step: 1);

    test('a step-only edit changes which warnings apply', () {
      // 100 in steps of 1 is 100 taps -> tooManyTaps.
      expect(
        kinds(TargetPresetCatalog.countDaily, amount: 100, step: 1),
        contains(TargetIssueKind.tooManyTaps),
      );
      // 100 in steps of 25 is 4 taps and divides exactly -> nothing.
      expect(kinds(TargetPresetCatalog.countDaily, amount: 100, step: 25),
          isEmpty);
    });

    test('and full equality sees that edit, while scoring-meaning does not', () {
      final restepped = base.copyWith(step: 25);
      expect(base == restepped, isFalse,
          reason: 'the save gate must re-prompt, because the warnings changed');
      expect(base.hasSameScoringMeaningAs(restepped), isTrue,
          reason: 'yet no past verdict changed, so the freeze must NOT re-anchor '
              '— the two comparisons are deliberately different tools');
    });
  });
}
