import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final atLeast = VerificationCatalog.steps.ruleWith(10000); // ≥ 10000
  final atMost = VerificationCatalog.screenTimeTotal.ruleWith(120); // ≤ 120

  group('evaluateHealthDay — atLeast', () {
    test('null data is pending today, couldn\'t-verify in the past', () {
      expect(
        VerificationService.evaluateHealthDay(
            rule: atLeast, measuredValue: null, isToday: true),
        const DayVerdict.pending(),
      );
      expect(
        VerificationService.evaluateHealthDay(
            rule: atLeast, measuredValue: null, isToday: false),
        const DayVerdict.couldNotVerify(),
      );
    });

    test('meeting the target passes immediately (today or past)', () {
      for (final isToday in [true, false]) {
        expect(
          VerificationService.evaluateHealthDay(
              rule: atLeast, measuredValue: 12000, isToday: isToday),
          DayVerdict.pass(12000),
        );
      }
      // Exactly on the threshold counts as a pass.
      expect(
        VerificationService.evaluateHealthDay(
            rule: atLeast, measuredValue: 10000, isToday: false),
        DayVerdict.pass(10000),
      );
    });

    test('below target is pending today but fails once the day is over', () {
      expect(
        VerificationService.evaluateHealthDay(
            rule: atLeast, measuredValue: 8000, isToday: true),
        DayVerdict.pending(8000),
      );
      expect(
        VerificationService.evaluateHealthDay(
            rule: atLeast, measuredValue: 8000, isToday: false),
        DayVerdict.fail(8000),
      );
    });
  });

  group('evaluateHealthDay — atMost', () {
    test('exceeding the limit fails immediately and permanently', () {
      for (final isToday in [true, false]) {
        expect(
          VerificationService.evaluateHealthDay(
              rule: atMost, measuredValue: 150, isToday: isToday),
          DayVerdict.fail(150),
        );
      }
    });

    test('staying under is pending today, passes once the day is over', () {
      expect(
        VerificationService.evaluateHealthDay(
            rule: atMost, measuredValue: 100, isToday: true),
        DayVerdict.pending(100),
      );
      expect(
        VerificationService.evaluateHealthDay(
            rule: atMost, measuredValue: 100, isToday: false),
        DayVerdict.pass(100),
      );
    });
  });

  group('evaluateScreenTimeDay — atMost (Limits)', () {
    test('a reached-threshold signal always fails', () {
      for (final isToday in [true, false]) {
        expect(
          VerificationService.evaluateScreenTimeDay(
              rule: atMost, signal: ScreenTimeSignalKind.reachedThreshold, isToday: isToday),
          const DayVerdict.fail(),
        );
      }
    });

    test('a stayed-under signal always passes', () {
      expect(
        VerificationService.evaluateScreenTimeDay(
            rule: atMost, signal: ScreenTimeSignalKind.stayedUnder, isToday: false),
        const DayVerdict.pass(),
      );
    });

    test('no signal is pending today, couldn\'t-verify in the past', () {
      expect(
        VerificationService.evaluateScreenTimeDay(rule: atMost, signal: null, isToday: true),
        const DayVerdict.pending(),
      );
      expect(
        VerificationService.evaluateScreenTimeDay(rule: atMost, signal: null, isToday: false),
        const DayVerdict.couldNotVerify(),
      );
    });

    test('screen time verdicts never carry a measured value', () {
      final v = VerificationService.evaluateScreenTimeDay(
          rule: atMost, signal: ScreenTimeSignalKind.reachedThreshold, isToday: false);
      expect(v.measuredValue, isNull);
    });
  });

  group('evaluateScreenTimeDay — atLeast (Goals)', () {
    test('a reached-threshold signal always passes', () {
      for (final isToday in [true, false]) {
        expect(
          VerificationService.evaluateScreenTimeDay(
              rule: atLeast, signal: ScreenTimeSignalKind.reachedThreshold, isToday: isToday),
          const DayVerdict.pass(),
        );
      }
    });

    test('a stayed-under signal always fails', () {
      expect(
        VerificationService.evaluateScreenTimeDay(
            rule: atLeast, signal: ScreenTimeSignalKind.stayedUnder, isToday: false),
        const DayVerdict.fail(),
      );
    });
  });
}
