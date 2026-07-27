// v11 forward-only target-edit freezing: the save-layer stamp
// (`stampTargetEffectiveFrom`) and the JSON round-trip of the new
// `target_effective_from` column. The reconcile freeze itself is covered by
// packages/evolve_targets target_reconcile_test.dart (effectiveFrom clamps the
// sweep window). Mirrors verify_effective_from_stamp_test.dart.
import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/models/goal.dart';

void main() {
  HabitTarget pushups(double amount) =>
      TargetPresetCatalog.countDaily.targetWith(amount: amount, step: 20);
  final t80 = pushups(80);
  final t200 = pushups(200);
  final today = DateTime(2026, 7, 23, 14, 30); // deliberately not midnight

  Goal goal({
    HabitTarget? target,
    DateTime? targetEffectiveFrom,
    String title = 'Push-ups',
  }) =>
      Goal(
        id: 'g1',
        title: title,
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2026, 1, 1),
        target: target,
        targetEffectiveFrom: targetEffectiveFrom,
      );

  group('stampTargetEffectiveFrom', () {
    test('a brand-new target takes effect today (date-only)', () {
      final out = stampTargetEffectiveFrom(
        goal(target: t80),
        previous: null,
        today: today,
      );
      expect(out.targetEffectiveFrom, DateTime(2026, 7, 23));
    });

    test('a checkbox habit (no target) gets no anchor', () {
      final out = stampTargetEffectiveFrom(
        goal(target: null, targetEffectiveFrom: DateTime(2026, 5, 1)),
        previous: null,
        today: today,
      );
      expect(out.targetEffectiveFrom, isNull);
    });

    test('an unchanged target preserves the previous anchor (not today)', () {
      final previous = goal(target: t80, targetEffectiveFrom: DateTime(2026, 3, 1));
      // A title edit — same target content.
      final out = stampTargetEffectiveFrom(
        goal(target: t80, title: 'Push-ups (AM)'),
        previous: previous,
        today: today,
      );
      expect(out.targetEffectiveFrom, DateTime(2026, 3, 1));
    });

    test('an unchanged target with a null prior anchor stays null — a non-target '
        'edit must not retroactively freeze a pre-v11 habit', () {
      final previous = goal(target: t80, targetEffectiveFrom: null);
      final out = stampTargetEffectiveFrom(
        goal(target: t80, title: 'renamed'),
        previous: previous,
        today: today,
      );
      expect(out.targetEffectiveFrom, isNull);
    });

    test('a changed amount re-stamps to today', () {
      final previous = goal(target: t80, targetEffectiveFrom: DateTime(2026, 3, 1));
      final out = stampTargetEffectiveFrom(
        goal(target: t200),
        previous: previous,
        today: today,
      );
      expect(out.targetEffectiveFrom, DateTime(2026, 7, 23));
    });

    test('adding a target to a previously-checkbox habit stamps today', () {
      final previous = goal(target: null);
      final out = stampTargetEffectiveFrom(
        goal(target: t80),
        previous: previous,
        today: today,
      );
      expect(out.targetEffectiveFrom, DateTime(2026, 7, 23));
    });

    test('clearing a target drops the anchor', () {
      final previous = goal(target: t80, targetEffectiveFrom: DateTime(2026, 3, 1));
      final out = stampTargetEffectiveFrom(
        goal(target: null),
        previous: previous,
        today: today,
      );
      expect(out.targetEffectiveFrom, isNull);
    });
  });

  group('JSON round-trip', () {
    test('a targeted goal carries target_effective_from date-only', () {
      final json = goal(target: t80, targetEffectiveFrom: DateTime(2026, 6, 15))
          .toJson();
      expect(json['target_effective_from'], '2026-06-15');
      final back = Goal.fromJson({...json, 'id': 'g1'});
      expect(back.targetEffectiveFrom, DateTime(2026, 6, 15));
    });

    test('a checkbox habit omits the column', () {
      final json = goal(target: null, targetEffectiveFrom: DateTime(2026, 6, 15))
          .toJson();
      expect(json.containsKey('target_effective_from'), isFalse);
    });

    test('a targeted goal with no anchor omits the column', () {
      final json = goal(target: t80, targetEffectiveFrom: null).toJson();
      expect(json.containsKey('target_effective_from'), isFalse);
    });
  });

  test('a STEP-only edit preserves the anchor — it changes no verdict', () {
    // step is how many taps reach the amount, not what the amount is. 80 is
    // still 80 whether you got there in 4 taps of 20 or 80 taps of 1, so no past
    // day can change verdict and history must not be re-anchored. Before this,
    // `previous.target == updated.target` was false for a step edit and the
    // sweep silently stopped revisiting earlier days.
    final anchored =
        goal(target: t80, targetEffectiveFrom: DateTime(2026, 7, 1));
    final restepped = goal(
      target: TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 10),
      targetEffectiveFrom: DateTime(2026, 7, 1),
    );

    final stamped = stampTargetEffectiveFrom(
      restepped,
      previous: anchored,
      today: today,
    );

    expect(stamped.targetEffectiveFrom, DateTime(2026, 7, 1),
        reason: 'the original anchor must survive a step-only edit');
  });

  test('an AMOUNT edit still re-anchors, so the freeze keeps working', () {
    // The guard above must not disable the feature it sits next to.
    final anchored =
        goal(target: t80, targetEffectiveFrom: DateTime(2026, 7, 1));
    final raised =
        goal(target: t200, targetEffectiveFrom: DateTime(2026, 7, 1));

    final stamped = stampTargetEffectiveFrom(
      raised,
      previous: anchored,
      today: today,
    );

    expect(stamped.targetEffectiveFrom, DateTime(2026, 7, 23));
  });
}
