// Compound verifiable habits at the Goal model layer: the verify_conditions
// JSON round-trip (with the flat verify_* columns nulled) and the D10 re-stamp
// detecting condition/operator edits.
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/models/goal.dart';

void main() {
  final steps = VerificationCatalog.steps.ruleWith(10000);
  final exercise = VerificationCatalog.exerciseMinutes.ruleWith(30);
  final energy = VerificationCatalog.activeEnergy.ruleWith(500);

  Goal goal({
    VerificationRule? rule,
    List<VerificationRule>? additional,
    VerificationJoin? join,
    DateTime? anchor,
  }) =>
      Goal(
        id: 'g1',
        title: 'Move',
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2026, 1, 1),
        verificationRule: rule,
        additionalConditions: additional,
        verificationJoin: join,
        verifyEffectiveFrom: anchor,
      );

  group('serialization (Q4 flat-vs-JSON)', () {
    test('a compound goal writes verify_conditions and NULLS the flat columns', () {
      final json = goal(
        rule: steps,
        additional: [exercise],
        join: VerificationJoin.and,
        anchor: DateTime(2026, 6, 1),
      ).toJson();

      expect(json['verify_conditions'], isNotNull);
      // Flat columns are emitted-but-null so a pre-compound client reads manual.
      expect(json.containsKey('verify_provider'), isTrue);
      expect(json['verify_provider'], isNull);
      expect(json['verify_metric'], isNull);
      final decoded = decodeVerifyConditions(json['verify_conditions'])!;
      expect(decoded.op, VerificationJoin.and);
      expect(decoded.conditions, [steps, exercise]);
      expect(json['verify_effective_from'], '2026-06-01');
    });

    test('compound round-trips through fromJson', () {
      final json = goal(
        rule: steps,
        additional: [exercise, energy],
        join: VerificationJoin.or,
      ).toJson();
      final back = Goal.fromJson({...json, 'id': 'g1'});

      expect(back.isCompoundVerified, isTrue);
      expect(back.verificationRule, steps);
      expect(back.additionalConditions, [exercise, energy]);
      expect(back.verificationJoin, VerificationJoin.or);
      expect(back.verificationConditions, [steps, exercise, energy]);
    });

    test('a single rule still uses the flat columns, verify_conditions null', () {
      final json = goal(rule: steps).toJson();
      expect(json['verify_metric'], 'steps');
      expect(json['verify_conditions'], isNull);
      final back = Goal.fromJson({...json, 'id': 'g1'});
      expect(back.verificationRule, steps);
      expect(back.isCompoundVerified, isFalse);
      expect(back.additionalConditions, isNull);
      expect(back.verificationJoin, isNull);
    });

    test('a manual habit omits every verification column', () {
      final json = goal().toJson();
      expect(json.containsKey('verify_conditions'), isFalse);
      expect(json.containsKey('verify_provider'), isFalse);
    });
  });

  group('D10 re-stamp covers the whole condition set + operator', () {
    final today = DateTime(2026, 7, 23, 9);

    test('flipping the operator counts as an edit → re-stamp today', () {
      final prev = goal(
          rule: steps,
          additional: [exercise],
          join: VerificationJoin.or,
          anchor: DateTime(2026, 3, 1));
      final next =
          goal(rule: steps, additional: [exercise], join: VerificationJoin.and);
      final out =
          stampVerificationEffectiveFrom(next, previous: prev, today: today);
      expect(out.verifyEffectiveFrom, DateTime(2026, 7, 23));
    });

    test('adding a condition counts as an edit → re-stamp today', () {
      final prev = goal(
          rule: steps,
          additional: [exercise],
          join: VerificationJoin.or,
          anchor: DateTime(2026, 3, 1));
      final next = goal(
          rule: steps, additional: [exercise, energy], join: VerificationJoin.or);
      final out =
          stampVerificationEffectiveFrom(next, previous: prev, today: today);
      expect(out.verifyEffectiveFrom, DateTime(2026, 7, 23));
    });

    test('an unchanged compound preserves the prior anchor', () {
      final prev = goal(
          rule: steps,
          additional: [exercise],
          join: VerificationJoin.and,
          anchor: DateTime(2026, 3, 1));
      // Same conditions + operator, e.g. a title edit elsewhere.
      final next =
          goal(rule: steps, additional: [exercise], join: VerificationJoin.and);
      final out =
          stampVerificationEffectiveFrom(next, previous: prev, today: today);
      expect(out.verifyEffectiveFrom, DateTime(2026, 3, 1));
    });

    test('single → compound (adding a 2nd condition) re-stamps', () {
      final prev = goal(rule: steps, anchor: DateTime(2026, 3, 1));
      final next =
          goal(rule: steps, additional: [exercise], join: VerificationJoin.or);
      final out =
          stampVerificationEffectiveFrom(next, previous: prev, today: today);
      expect(out.verifyEffectiveFrom, DateTime(2026, 7, 23));
    });
  });
}
