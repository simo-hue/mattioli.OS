import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('projection from a verification rule', () {
    test('a step goal becomes an atLeast day target filled by HealthKit', () {
      final rule = VerificationCatalog.steps.ruleWith(10000);
      final target = targetFromVerificationRule(rule)!;

      expect(target.fillSource, TargetFillSource.healthKit);
      expect(target.direction, TargetDirection.atLeast);
      expect(target.period, TargetPeriod.day);
      expect(target.aggregation, VerificationCatalog.steps.aggregation);
      expect(target.amount, 10000);
      expect(target.unit, TargetUnit.count);
      expect(target.isMeasured, isTrue);
      expect(target.isUserEnterable, isFalse,
          reason: 'offering +1 on a sensor count invites a write the next '
              'reconcile pass silently overwrites');
    });

    test('a Screen Time limit becomes an atMost target', () {
      final rule = VerificationCatalog.screenTimeApps.ruleWith(30);
      final target = targetFromVerificationRule(rule)!;

      expect(target.fillSource, TargetFillSource.screenTime);
      expect(target.direction, TargetDirection.atMost);
      expect(target.isLimit, isTrue);
      expect(target.unit, TargetUnit.minutes);
      expect(target.amount, 30);
    });

    test('every catalog template projects and keeps the rule verbatim', () {
      for (final template in VerificationCatalog.all) {
        final rule = template.ruleWith(template.defaultThreshold);
        final target = targetFromVerificationRule(rule)!;
        expect(target.amount, rule.threshold, reason: template.key);
        expect(target.unit, rule.unit, reason: template.key);
        expect(target.direction, rule.comparator, reason: template.key);
        expect(target.aggregation, template.aggregation, reason: template.key);
        expect(target.step, template.step, reason: template.key);
      }
    });

    test('a rule whose metric this build does not know projects to null', () {
      // A template added by a newer client. The rule still verifies natively;
      // this build simply declines to draw a ring it cannot label.
      const unknown = VerificationRule(
        provider: VerificationProvider.healthKit,
        metricKey: 'vo2_max_from_2027',
        comparator: VerificationComparator.atLeast,
        threshold: 42,
        unit: VerificationUnit.count,
      );
      expect(unknown.template, isNull, reason: 'precondition');
      expect(targetFromVerificationRule(unknown), isNull);
    });

    test('a projected target evaluates identically to the rule it came from', () {
      final rule = VerificationCatalog.steps.ruleWith(10000);
      final target = targetFromVerificationRule(rule)!;

      expect(
        evaluateTarget(target: target, progress: 10000, periodIsOver: false)
            .outcome,
        TargetOutcome.met,
      );
      expect(
        evaluateTarget(target: target, progress: 9999, periodIsOver: true)
            .outcome,
        TargetOutcome.unmet,
      );
      // No samples on a closed day is "couldn't verify", never a pass.
      expect(
        evaluateTarget(target: target, progress: null, periodIsOver: true)
            .outcome,
        TargetOutcome.unknown,
      );
    });
  });

  group('displayTargetFor', () {
    final manual = TargetPresetCatalog.countDaily.targetWith(amount: 80);
    final rule = VerificationCatalog.steps.ruleWith(10000);

    test('a manual target wins over a projected rule', () {
      final shown =
          displayTargetFor(ownTarget: manual, conditions: [rule]);
      expect(shown, manual);
    });

    test('a single rule projects when there is no manual target', () {
      final shown = displayTargetFor(ownTarget: null, conditions: [rule]);
      expect(shown?.fillSource, TargetFillSource.healthKit);
      expect(shown?.amount, 10000);
    });

    test('a plain habit has nothing to show', () {
      expect(displayTargetFor(ownTarget: null, conditions: const []), isNull);
    });

    test('a compound habit gets no single ring', () {
      // Two conditions joined by OR have no meaningful single fraction, and
      // inventing one (the max? the first?) would show a number the user
      // cannot act on.
      final compound = [
        rule,
        VerificationCatalog.exerciseMinutes.ruleWith(30),
      ];
      expect(displayTargetFor(ownTarget: null, conditions: compound), isNull);
    });

    test('a compound habit still shows an explicit manual target', () {
      final compound = [
        rule,
        VerificationCatalog.exerciseMinutes.ruleWith(30),
      ];
      expect(displayTargetFor(ownTarget: manual, conditions: compound), manual);
    });
  });
}
