// Forward-compat preservation of an undecodable newer-client compound blob on
// DashboardHabit (the verify-side twin of rawTargetBlob). A compound with more
// than kMaxVerificationConditions conditions decodes to null (reads as manual)
// and must survive a desktop edit / write instead of being stripped.
import 'dart:convert';

import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final steps = VerificationCatalog.steps.ruleWith(10000);
  final exercise = VerificationCatalog.exerciseMinutes.ruleWith(30);
  final energy = VerificationCatalog.activeEnergy.ruleWith(500);
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

  const week = [false, false, false, false, false, false, false];

  DashboardHabit manualWithBlob() => DashboardHabit(
        id: 'g1',
        title: 'Move',
        color: const Color(0xFF3B82F6),
        streak: 0,
        weeklyProgress: week,
        state: HabitState.pending,
        rawVerifyConditionsBlob: fourCond,
      );

  test('an undecodable compound reads as manual but carries the blob', () {
    final h = manualWithBlob();
    expect(h.verificationRule, isNull);
    expect(h.rawVerifyConditionsBlob, fourCond);
  });

  test('a title edit preserves the blob and writes it back verbatim', () {
    final edited = manualWithBlob().copyWith(title: 'Renamed');
    expect(edited.rawVerifyConditionsBlob, fourCond);
    expect(edited.verifyColumnValues['verify_conditions'], fourCond);
    expect(edited.verifyColumnValues['verify_provider'], isNull);
  });

  test('toRemoteJson round-trips the undecodable compound verbatim', () {
    final json = manualWithBlob().toRemoteJson();
    expect(json['verify_conditions'], fourCond);
    final back = DashboardHabit.fromRemoteJson(
      Map<String, dynamic>.from(json),
      weeklyProgress: week,
      state: HabitState.pending,
      streak: 0,
    );
    expect(back.rawVerifyConditionsBlob, fourCond);
    expect(back.verificationRule, isNull);
  });

  test('a target supersedes the preserved compound (mutual exclusion)', () {
    final edited = manualWithBlob().copyWith(
      target: TargetPresetCatalog.countDaily.targetWith(amount: 80),
    );
    expect(edited.verifyColumnValues['verify_conditions'], isNull);
  });

  test('a plain manual habit omits verify_conditions from toRemoteJson', () {
    final json = DashboardHabit(
      id: 'g2',
      title: 'Plain',
      color: const Color(0xFF3B82F6),
      streak: 0,
      weeklyProgress: week,
      state: HabitState.pending,
    ).toRemoteJson();
    expect(json.containsKey('verify_conditions'), isFalse);
  });
}
