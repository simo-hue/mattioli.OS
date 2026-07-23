// D10 forward-only rule-edit freezing: the save-layer stamp
// (`stampVerificationEffectiveFrom`) and the JSON round-trip of the new
// `verify_effective_from` column. The reconcile freeze itself is covered by
// verification_wiring_test.dart (effectiveFrom = max(startDate, anchor)).
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/models/goal.dart';

void main() {
  final steps = VerificationCatalog.steps.ruleWith(10000);
  final stepsHigher = VerificationCatalog.steps.ruleWith(12000);
  final sleep = VerificationCatalog.sleepHours.ruleWith(8);
  final today = DateTime(2026, 7, 23, 14, 30); // deliberately not midnight

  Goal goal({
    VerificationRule? rule,
    DateTime? verifyEffectiveFrom,
    String title = 'Move',
  }) =>
      Goal(
        id: 'g1',
        title: title,
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2026, 1, 1),
        verificationRule: rule,
        verifyEffectiveFrom: verifyEffectiveFrom,
      );

  group('stampVerificationEffectiveFrom', () {
    test('a brand-new rule takes effect today (date-only)', () {
      final out = stampVerificationEffectiveFrom(
        goal(rule: steps),
        previous: null,
        today: today,
      );
      expect(out.verifyEffectiveFrom, DateTime(2026, 7, 23));
    });

    test('a manual habit gets no anchor', () {
      final out = stampVerificationEffectiveFrom(
        goal(rule: null, verifyEffectiveFrom: DateTime(2026, 5, 1)),
        previous: null,
        today: today,
      );
      expect(out.verifyEffectiveFrom, isNull);
    });

    test('an unchanged rule preserves the previous anchor (not today)', () {
      final previous = goal(rule: steps, verifyEffectiveFrom: DateTime(2026, 3, 1));
      // A title edit — same rule content.
      final out = stampVerificationEffectiveFrom(
        goal(rule: steps, title: 'Move more'),
        previous: previous,
        today: today,
      );
      expect(out.verifyEffectiveFrom, DateTime(2026, 3, 1));
    });

    test('an unchanged rule with a null prior anchor stays null — a non-rule '
        'edit must not retroactively freeze a pre-D10 habit', () {
      final previous = goal(rule: steps, verifyEffectiveFrom: null);
      final out = stampVerificationEffectiveFrom(
        goal(rule: steps, title: 'renamed'),
        previous: previous,
        today: today,
      );
      expect(out.verifyEffectiveFrom, isNull);
    });

    test('a changed threshold re-stamps to today', () {
      final previous = goal(rule: steps, verifyEffectiveFrom: DateTime(2026, 3, 1));
      final out = stampVerificationEffectiveFrom(
        goal(rule: stepsHigher),
        previous: previous,
        today: today,
      );
      expect(out.verifyEffectiveFrom, DateTime(2026, 7, 23));
    });

    test('a changed metric re-stamps to today', () {
      final previous = goal(rule: steps, verifyEffectiveFrom: DateTime(2026, 3, 1));
      final out = stampVerificationEffectiveFrom(
        goal(rule: sleep),
        previous: previous,
        today: today,
      );
      expect(out.verifyEffectiveFrom, DateTime(2026, 7, 23));
    });

    test('adding a rule to a previously-manual habit stamps today', () {
      final previous = goal(rule: null);
      final out = stampVerificationEffectiveFrom(
        goal(rule: steps),
        previous: previous,
        today: today,
      );
      expect(out.verifyEffectiveFrom, DateTime(2026, 7, 23));
    });

    test('clearing a rule drops the anchor', () {
      final previous = goal(rule: steps, verifyEffectiveFrom: DateTime(2026, 3, 1));
      final out = stampVerificationEffectiveFrom(
        goal(rule: null),
        previous: previous,
        today: today,
      );
      expect(out.verifyEffectiveFrom, isNull);
    });
  });

  group('JSON round-trip', () {
    test('a verified goal carries verify_effective_from date-only', () {
      final json = goal(rule: steps, verifyEffectiveFrom: DateTime(2026, 6, 15))
          .toJson();
      expect(json['verify_effective_from'], '2026-06-15');
      final back = Goal.fromJson({...json, 'id': 'g1'});
      expect(back.verifyEffectiveFrom, DateTime(2026, 6, 15));
    });

    test('a manual habit omits the column', () {
      final json = goal(rule: null, verifyEffectiveFrom: DateTime(2026, 6, 15))
          .toJson();
      expect(json.containsKey('verify_effective_from'), isFalse);
    });

    test('a verified goal with no anchor omits the column', () {
      final json = goal(rule: steps, verifyEffectiveFrom: null).toJson();
      expect(json.containsKey('verify_effective_from'), isFalse);
    });
  });
}
