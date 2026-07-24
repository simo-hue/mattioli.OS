// The Goal model's quantitative-target plumbing: fromJson/toJson round-trip, the
// forward-compatible preservation of a target a newer client wrote, and the
// copyWith clear/replace semantics the save layer depends on.
import 'dart:convert';

import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/models/goal.dart';

void main() {
  Goal baseGoal({HabitTarget? target, String? rawTargetBlob}) => Goal(
        id: 'g1',
        title: 'Push-ups',
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2026, 7, 1),
        target: target,
        rawTargetBlob: rawTargetBlob,
      );

  final pushUps =
      TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);

  group('round-trip', () {
    test('a target survives fromJson(toJson(...))', () {
      final json = baseGoal(target: pushUps).toJson();
      final restored = Goal.fromJson({...json, 'id': 'g1'});
      expect(restored.target, pushUps);
      expect(restored.hasTarget, isTrue);
    });

    test('a plain habit emits no target column', () {
      expect(baseGoal().toJson().containsKey('target'), isFalse);
      expect(baseGoal().targetColumnValue, isNull);
    });

    test('a habit with a target round-trips through the private-row shape', () {
      // Simulates _goalFromRow / _goalToRow: the DB stores the encoded string.
      final column = baseGoal(target: pushUps).targetColumnValue;
      final restored = Goal.fromJson({
        'id': 'g1',
        'title': 'Push-ups',
        'color': '#3B82F6',
        'start_date': '2026-07-01',
        'target': column,
      });
      expect(restored.target, pushUps);
    });
  });

  group('forward compatibility (the reason rawTargetBlob exists)', () {
    // A target written by a newer client: valid JSON, an axis value this build
    // cannot decode. decodeHabitTarget returns null, so `target` is null — but
    // the blob must survive an unrelated edit here rather than being nulled.
    final futureBlob = jsonEncode({
      'v': 1,
      'src': 'manual',
      'dir': 'gte',
      'per': 'quarter', // unknown period → undecodable on this build
      'agg': 'sum',
      'amount': 4,
      'unit': 'count',
      'step': 1,
      'input': 'stepper',
    });

    test('an undecodable target reads as a plain habit but is preserved', () {
      final goal = Goal.fromJson({
        'id': 'g1',
        'title': 'Gym',
        'color': '#3B82F6',
        'start_date': '2026-07-01',
        'target': futureBlob,
      });
      expect(goal.target, isNull, reason: 'this build cannot decode it');
      expect(goal.hasTarget, isFalse, reason: 'so it renders as a plain habit');
      expect(goal.rawTargetBlob, futureBlob);
    });

    test('a title edit writes the undecodable blob back verbatim', () {
      final goal = Goal.fromJson({
        'id': 'g1',
        'title': 'Gym',
        'color': '#3B82F6',
        'start_date': '2026-07-01',
        'target': futureBlob,
      });
      final edited = goal.copyWith(title: 'Gym session');
      expect(edited.targetColumnValue, futureBlob,
          reason: 'the newer-client target must not be stripped by an '
              'unrelated edit on this build');
      expect(edited.toJson()['target'], futureBlob);
    });

    test('setting a real target supersedes a preserved blob', () {
      final goal = baseGoal(rawTargetBlob: futureBlob);
      final edited = goal.copyWith(target: pushUps);
      expect(edited.target, pushUps);
      expect(edited.targetColumnValue, pushUps.encode());
      expect(edited.rawTargetBlob, isNull);
    });

    test('clearing wipes both the target and any preserved blob', () {
      final goal = baseGoal(rawTargetBlob: futureBlob);
      final cleared = goal.copyWith(clearTarget: true);
      expect(cleared.target, isNull);
      expect(cleared.rawTargetBlob, isNull);
      expect(cleared.targetColumnValue, isNull,
          reason: 'an explicit clear must not let the old blob resurrect');
    });
  });

  group('displayTarget projection', () {
    test('a manual target is shown directly', () {
      expect(baseGoal(target: pushUps).displayTarget, pushUps);
    });

    test('a plain habit shows nothing', () {
      expect(baseGoal().displayTarget, isNull);
    });
  });

  test('a garbage target column degrades to a plain habit, never throws', () {
    final goal = Goal.fromJson({
      'id': 'g1',
      'title': 'Push-ups',
      'color': '#3B82F6',
      'start_date': '2026-07-01',
      'target': 'not json at all',
    });
    expect(goal.target, isNull);
    // Garbage that is not a non-empty object is not "an unreadable target", so
    // it is dropped on the next save rather than round-tripped.
    expect(goal.targetColumnValue, isNull);
  });
}
