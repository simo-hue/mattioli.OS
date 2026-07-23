// The Q5 compound truth table: VerificationService.combineVerdicts folds N
// per-condition HealthKit verdicts into one day verdict. OR and AND are duals:
//   OR  (pass if ANY met):  pass > pending > couldNotVerify > fail
//   AND (pass if ALL met):  fail > couldNotVerify > pending > pass
// In practice a day's conditions are all "today" (∈ pass/pending) or all "past"
// (∈ pass/fail/couldNotVerify), so the two groups below mirror reality.
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pass = DayVerdict.pass();
  const fail = DayVerdict.fail();
  const pending = DayVerdict.pending();
  const cnv = DayVerdict.couldNotVerify();

  VerificationOutcome or(List<DayVerdict> v) =>
      VerificationService.combineVerdicts(v, VerificationJoin.or).outcome;
  VerificationOutcome and(List<DayVerdict> v) =>
      VerificationService.combineVerdicts(v, VerificationJoin.and).outcome;

  group('OR — pass if any condition is met', () {
    test('today conditions (pass/pending)', () {
      expect(or([pass, pending]), VerificationOutcome.pass);
      expect(or([pending, pending]), VerificationOutcome.pending);
      expect(or([pass, pass]), VerificationOutcome.pass);
    });

    test('past conditions (pass/fail/couldNotVerify)', () {
      expect(or([pass, fail]), VerificationOutcome.pass);
      expect(or([fail, fail]), VerificationOutcome.fail);
      // The key judgment call: an unread condition might have been met, so a
      // definite fail alongside a couldNotVerify is NOT a failure.
      expect(or([fail, cnv]), VerificationOutcome.couldNotVerify);
      expect(or([pass, cnv]), VerificationOutcome.pass);
      expect(or([cnv, cnv]), VerificationOutcome.couldNotVerify);
    });
  });

  group('AND — pass only if all conditions are met', () {
    test('today conditions (pass/pending)', () {
      expect(and([pass, pass]), VerificationOutcome.pass);
      expect(and([pass, pending]), VerificationOutcome.pending);
      expect(and([pending, pending]), VerificationOutcome.pending);
    });

    test('past conditions (pass/fail/couldNotVerify)', () {
      expect(and([pass, pass]), VerificationOutcome.pass);
      expect(and([pass, fail]), VerificationOutcome.fail);
      // A hard fail short-circuits past an unknown: one definitely-missed
      // required condition dooms the conjunction.
      expect(and([fail, cnv]), VerificationOutcome.fail);
      expect(and([pass, cnv]), VerificationOutcome.couldNotVerify);
      expect(and([cnv, cnv]), VerificationOutcome.couldNotVerify);
    });

    test('three conditions', () {
      expect(and([pass, pass, pass]), VerificationOutcome.pass);
      expect(and([pass, pass, fail]), VerificationOutcome.fail);
      expect(and([pass, pass, cnv]), VerificationOutcome.couldNotVerify);
      expect(or([fail, fail, pass]), VerificationOutcome.pass);
    });
  });

  group('degenerate + value handling', () {
    test('a single verdict is returned verbatim, value preserved', () {
      const single = DayVerdict.pass(12043);
      expect(VerificationService.combineVerdicts([single], VerificationJoin.or),
          single);
      expect(VerificationService.combineVerdicts([single], VerificationJoin.and),
          single);
    });

    test('a compound verdict drops the measured value (Q6)', () {
      final v = VerificationService.combineVerdicts(
        const [DayVerdict.pass(100), DayVerdict.pass(200)],
        VerificationJoin.or,
      );
      expect(v.outcome, VerificationOutcome.pass);
      expect(v.measuredValue, isNull);
    });
  });
}
