import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter_test/flutter_test.dart';

HabitTarget _atLeast({
  double amount = 80,
  TargetFillSource fillSource = TargetFillSource.manual,
}) =>
    HabitTarget(
      fillSource: fillSource,
      direction: TargetDirection.atLeast,
      period: TargetPeriod.day,
      aggregation: TargetAggregation.sum,
      amount: amount,
      unit: TargetUnit.count,
      step: 20,
      input: TargetInput.stepper,
    );

HabitTarget _atMost({
  double amount = 1,
  TargetFillSource fillSource = TargetFillSource.manual,
}) =>
    HabitTarget(
      fillSource: fillSource,
      direction: TargetDirection.atMost,
      period: TargetPeriod.day,
      aggregation: TargetAggregation.sum,
      amount: amount,
      unit: TargetUnit.count,
      step: 1,
      input: TargetInput.stepper,
    );

TargetVerdict _eval(HabitTarget t, double? progress, {required bool over}) =>
    evaluateTarget(target: t, progress: progress, periodIsOver: over);

void main() {
  group('atLeast (reach it)', () {
    test('is pending part-way through an open day', () {
      final v = _eval(_atLeast(), 40, over: false);
      expect(v.outcome, TargetOutcome.pending);
      expect(v.fraction, 0.5);
      expect(v.logStatus, isNull, reason: 'a half-done day writes no log row');
    });

    test('is met the instant the target is reached, without waiting for the day to end', () {
      final v = _eval(_atLeast(), 80, over: false);
      expect(v.outcome, TargetOutcome.met);
      expect(v.logStatus, 'done');
    });

    test('is unmet once the day closes short', () {
      final v = _eval(_atLeast(), 60, over: true);
      expect(v.outcome, TargetOutcome.unmet);
      expect(v.logStatus, 'missed');
    });

    test('an untouched manual day is zero, not unknown', () {
      expect(_eval(_atLeast(), null, over: false).outcome, TargetOutcome.pending);
      expect(_eval(_atLeast(), null, over: true).outcome, TargetOutcome.unmet);
    });

    test('overshoot is reported raw but the ring stays full', () {
      final v = _eval(_atLeast(), 120, over: true);
      expect(v.outcome, TargetOutcome.met);
      expect(v.fraction, 1.0);
      expect(v.rawFraction, 1.5);
    });
  });

  group('atMost (stay under it)', () {
    test('is pending while the day is open, even at zero', () {
      // The correction that matters: a limit habit is NOT green from breakfast.
      // Staying under a ceiling is only knowable once the day is over, which is
      // exactly how the shipped auto-verified atMost path already behaves.
      final v = _eval(_atMost(), 0, over: false);
      expect(v.outcome, TargetOutcome.pending);
      expect(v.logStatus, isNull);
    });

    test('resolves to met once the day closes under the limit', () {
      final v = _eval(_atMost(), 1, over: true);
      expect(v.outcome, TargetOutcome.met);
      expect(v.logStatus, 'done');
    });

    test('an untouched manual day means nothing consumed, so it succeeds', () {
      final v = _eval(_atMost(), null, over: true);
      expect(v.outcome, TargetOutcome.met);
      expect(v.effectiveProgress, 0);
      expect(v.logStatus, 'done');
    });

    test('breaches immediately and stickily when the ceiling is crossed', () {
      final open = _eval(_atMost(), 2, over: false);
      expect(open.outcome, TargetOutcome.breached);
      expect(open.logStatus, 'missed');
      // Still breached at day end — the rest of the day cannot redeem it.
      expect(_eval(_atMost(), 2, over: true).outcome, TargetOutcome.breached);
    });

    test('exactly at the limit is not a breach', () {
      expect(_eval(_atMost(amount: 1), 1, over: false).outcome,
          TargetOutcome.pending);
      expect(_eval(_atMost(amount: 1), 1.000001, over: false).outcome,
          TargetOutcome.breached);
    });

    test('fraction is the share of the allowance consumed', () {
      expect(_eval(_atMost(amount: 4), 3, over: false).fraction, 0.75);
    });
  });

  group('measured sources treat silence as silence', () {
    test('no measurement on an open day is pending, not zero', () {
      final v = _eval(_atLeast(fillSource: TargetFillSource.healthKit), null,
          over: false);
      expect(v.outcome, TargetOutcome.pending);
    });

    test('no measurement on a closed day is unknown, never a success', () {
      // The asymmetry with the manual case is the whole feature: a manual limit
      // with no entries means "I consumed nothing"; a Screen Time limit with no
      // samples means the sensor said nothing, which is not evidence of success.
      final measured = _eval(
          _atMost(fillSource: TargetFillSource.screenTime), null,
          over: true);
      expect(measured.outcome, TargetOutcome.unknown);
      expect(measured.logStatus, isNull);

      final manual = _eval(_atMost(), null, over: true);
      expect(manual.outcome, TargetOutcome.met);
    });

    test('an explicit zero measurement IS evidence and resolves normally', () {
      final v = _eval(_atMost(fillSource: TargetFillSource.screenTime), 0,
          over: true);
      expect(v.outcome, TargetOutcome.met);
    });
  });

  group('outcome helpers', () {
    test('only pending is non-terminal', () {
      expect(TargetOutcome.pending.isTerminal, isFalse);
      for (final o in TargetOutcome.values.where((o) => o != TargetOutcome.pending)) {
        expect(o.isTerminal, isTrue);
      }
    });

    test('only met is a success', () {
      expect(TargetOutcome.met.isSuccess, isTrue);
      for (final o in TargetOutcome.values.where((o) => o != TargetOutcome.met)) {
        expect(o.isSuccess, isFalse);
      }
    });

    test('every outcome maps to a log status or explicitly to no row', () {
      // Exhaustive so a future outcome cannot be added without deciding what it
      // writes — the mapping is the contract both apps depend on.
      const expected = {
        TargetOutcome.met: 'done',
        TargetOutcome.unmet: 'missed',
        TargetOutcome.breached: 'missed',
        TargetOutcome.pending: null,
        TargetOutcome.unknown: null,
      };
      expect(expected.keys.toSet(), TargetOutcome.values.toSet());
      for (final entry in expected.entries) {
        final verdict = TargetVerdict(
          outcome: entry.key,
          fraction: 0,
          rawFraction: 0,
          effectiveProgress: 0,
        );
        expect(verdict.logStatus, entry.value);
      }
    });
  });

  group('increment / decrement', () {
    test('adds and subtracts one step', () {
      final t = _atLeast();
      expect(progressAfterIncrement(t, null), 20);
      expect(progressAfterIncrement(t, 20), 40);
      expect(progressAfterDecrement(t, 40), 20);
    });

    test('never goes negative', () {
      final t = _atLeast();
      expect(progressAfterDecrement(t, null), 0);
      expect(progressAfterDecrement(t, 10), 0);
    });

    test('fractional steps do not accumulate floating-point dust', () {
      final t = HabitTarget(
        fillSource: TargetFillSource.manual,
        direction: TargetDirection.atLeast,
        period: TargetPeriod.day,
        aggregation: TargetAggregation.sum,
        amount: 5,
        unit: TargetUnit.kilometers,
        step: 0.1,
        input: TargetInput.stepper,
      );
      var progress = 0.0;
      for (var i = 0; i < 50; i++) {
        progress = progressAfterIncrement(t, progress);
      }
      expect(progress, 5.0);
      expect(_eval(t, progress, over: false).outcome, TargetOutcome.met);
    });
  });
}
