// Compound verifiable habits at the Goal model layer: the verify_conditions
// JSON round-trip (with the flat verify_* columns nulled) and the D10 re-stamp
// detecting condition/operator edits.
import 'dart:convert';

import 'package:evolve_targets/evolve_targets.dart';
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

  group('rawVerifyConditionsBlob (forward-compat preservation)', () {
    // A newer client's 4-condition compound — over this build's cap of 3, so it
    // decodes to null (reads as manual) but must survive an unrelated edit.
    final fourCond = jsonEncode({
      'v': 1,
      'op': 'and',
      'conditions': [
        steps.toWire(),
        exercise.toWire(),
        energy.toWire(),
        VerificationCatalog.sleepHours.ruleWith(8).toWire(),
      ],
    });

    Goal manualWithBlob() => Goal(
          id: 'g1',
          title: 'Move',
          color: const Color(0xFF3B82F6),
          startDate: DateTime(2026, 1, 1),
          rawVerifyConditionsBlob: fourCond,
        );

    test('an undecodable compound reads as manual but carries the blob', () {
      final g = manualWithBlob();
      expect(g.verificationRule, isNull);
      expect(g.rawVerifyConditionsBlob, fourCond);
    });

    test('a title edit preserves the blob and writes it back verbatim', () {
      final edited = manualWithBlob().copyWith(title: 'Renamed');
      expect(edited.rawVerifyConditionsBlob, fourCond);
      expect(edited.verifyColumnValues['verify_conditions'], fourCond);
      expect(edited.verifyColumnValues['verify_provider'], isNull);
    });

    test('toJson round-trips the undecodable compound verbatim', () {
      final json = manualWithBlob().toJson();
      expect(json['verify_conditions'], fourCond);
      final back = Goal.fromJson({...json, 'id': 'g1'});
      expect(back.rawVerifyConditionsBlob, fourCond);
      expect(back.verificationRule, isNull);
    });

    test('setting a real rule supersedes the preserved blob', () {
      final edited = manualWithBlob().copyWith(verificationRule: steps);
      expect(edited.rawVerifyConditionsBlob, isNull);
      expect(edited.verifyColumnValues['verify_conditions'], isNull);
      expect(edited.verifyColumnValues['verify_provider'], isNotNull);
    });

    test('a target supersedes the preserved compound (mutual exclusion)', () {
      final edited = manualWithBlob().copyWith(
        target: TargetPresetCatalog.countDaily.targetWith(amount: 80),
      );
      expect(edited.verifyColumnValues['verify_conditions'], isNull);
    });

    test('a plain manual habit omits verify_conditions from toJson', () {
      final json = Goal(
        id: 'g1',
        title: 'Plain',
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2026, 1, 1),
      ).toJson();
      expect(json.containsKey('verify_conditions'), isFalse);
    });

    test('the D10 anchor rides with the preserved compound (private write)', () {
      final g = manualWithBlob().copyWith(
        verifyEffectiveFrom: DateTime(2026, 6, 15),
      );
      // The private REPLACE write keeps the anchor next to the blob it belongs to
      // instead of stripping it (the bug the final check caught).
      expect(g.verifyEffectiveFromColumnValue, '2026-06-15');
    });

    test('a plain manual habit writes a null anchor', () {
      final g = Goal(
        id: 'g1',
        title: 'Plain',
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2026, 1, 1),
        verifyEffectiveFrom: DateTime(2026, 6, 15),
      );
      expect(g.verifyEffectiveFromColumnValue, isNull);
    });
  });
}
