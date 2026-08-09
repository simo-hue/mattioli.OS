// The trigger policy for the two end-of-day passes (verification reconcile +
// manual-target sweep).
//
// These exist because both passes shipped with `AppLifecycleState.resumed` as
// their ONLY trigger, and iOS does not deliver that on a cold start. A
// force-quit → launch loop therefore never scored a habit-day: a verified habit
// never became done/missed, and a count habit's closed day kept no verdict.
// `main.dart` now also triggers on the goal list's scoring content and on the
// calendar day rolling over; this pins the two pure predicates behind that.

import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/reconcile_triggers.dart';
import 'package:mattioli_os/models/goal.dart';

void main() {
  Goal goal(
    String id, {
    String title = 'habit',
    VerificationRule? rule,
    List<VerificationRule>? additionalConditions,
    VerificationJoin? join,
    HabitTarget? target,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? frequencyDays,
    DateTime? verifyEffectiveFrom,
    DateTime? targetEffectiveFrom,
    Color color = const Color(0xFF3B82F6),
  }) => Goal(
    id: id,
    title: title,
    color: color,
    startDate: startDate ?? DateTime(2026, 1, 1),
    endDate: endDate,
    frequencyDays: frequencyDays,
    verificationRule: rule,
    additionalConditions: additionalConditions,
    verificationJoin: join,
    verifyEffectiveFrom: verifyEffectiveFrom,
    target: target,
    targetEffectiveFrom: targetEffectiveFrom,
  );

  final steps = VerificationCatalog.steps.ruleWith(10000);
  final exercise = VerificationCatalog.exerciseMinutes.ruleWith(30);
  HabitTarget pushups(double amount) =>
      TargetPresetCatalog.countDaily.targetWith(amount: amount, step: 20);
  final count80 = pushups(80);

  group('shouldReconcileForDayChange', () {
    test('a null last-run day is not a rollover — the goal trigger owns the '
        'first pass, and firing here too would race it every launch', () {
      expect(
        shouldReconcileForDayChange(
          lastReconciledDay: null,
          now: DateTime(2026, 8, 4, 9),
        ),
        isFalse,
      );
    });

    test('the same calendar day is not a rollover, at any hour', () {
      expect(
        shouldReconcileForDayChange(
          lastReconciledDay: DateTime(2026, 8, 4, 0, 0, 1),
          now: DateTime(2026, 8, 4, 23, 59, 59),
        ),
        isFalse,
      );
    });

    test(
      'crossing midnight IS a rollover — this is the app-left-open case that '
      'no lifecycle event covers',
      () {
        expect(
          shouldReconcileForDayChange(
            lastReconciledDay: DateTime(2026, 8, 4, 23, 59),
            now: DateTime(2026, 8, 5, 0, 0, 30),
          ),
          isTrue,
        );
      },
    );

    test(
      'a clock that moves BACKWARDS also re-runs: both passes are idempotent, '
      'so a redundant pass is cheap and a missed one is unresolvable',
      () {
        expect(
          shouldReconcileForDayChange(
            lastReconciledDay: DateTime(2026, 8, 5),
            now: DateTime(2026, 8, 4, 12),
          ),
          isTrue,
        );
      },
    );
  });

  group('goalReconcileSignature', () {
    test('is stable across rebuilds of the same content — the goal list is '
        'rebuilt on every applied iCloud sync, which the 60s poll can reach '
        'once a minute', () {
      final a = [goal('1', rule: steps), goal('2', target: count80)];
      final b = [goal('1', rule: steps), goal('2', target: count80)];
      expect(goalReconcileSignature(a), goalReconcileSignature(b));
    });

    test('ignores a reorder — display_order means nothing to either pass and '
        'must not cost a round of Health queries', () {
      final ordered = [goal('1', rule: steps), goal('2', rule: exercise)];
      expect(
        goalReconcileSignature(ordered),
        goalReconcileSignature(ordered.reversed.toList()),
      );
    });

    test('ignores a rename and a recolour', () {
      expect(
        goalReconcileSignature([goal('1', title: 'Walk', rule: steps)]),
        goalReconcileSignature([
          goal(
            '1',
            title: 'Walk more',
            rule: steps,
            color: const Color(0xFFEF4444),
          ),
        ]),
      );
    });

    test('changes when a habit is ADDED — this is the create trigger', () {
      expect(
        goalReconcileSignature([goal('1', rule: steps)]),
        isNot(
          goalReconcileSignature([
            goal('1', rule: steps),
            goal('2', target: count80),
          ]),
        ),
      );
    });

    test('changes when a second condition is added — the compound edit that '
        'used to wait for a background round trip to be scored', () {
      expect(
        goalReconcileSignature([goal('1', rule: steps)]),
        isNot(
          goalReconcileSignature([
            goal(
              '1',
              rule: steps,
              additionalConditions: [exercise],
              join: VerificationJoin.and,
            ),
          ]),
        ),
      );
    });

    test('changes when the compound OPERATOR flips, which changes every '
        "day's verdict without touching a threshold", () {
      Goal compound(VerificationJoin join) =>
          goal('1', rule: steps, additionalConditions: [exercise], join: join);
      expect(
        goalReconcileSignature([compound(VerificationJoin.or)]),
        isNot(goalReconcileSignature([compound(VerificationJoin.and)])),
      );
    });

    test('changes when a threshold changes', () {
      expect(
        goalReconcileSignature([goal('1', rule: steps)]),
        isNot(
          goalReconcileSignature([
            goal('1', rule: VerificationCatalog.steps.ruleWith(12000)),
          ]),
        ),
      );
    });

    test('changes when a target amount changes', () {
      final raised = pushups(100);
      expect(
        goalReconcileSignature([goal('1', target: count80)]),
        isNot(goalReconcileSignature([goal('1', target: raised)])),
      );
    });

    test('changes when either forward-only anchor moves — both decide which '
        'days are in the pass\'s reach', () {
      expect(
        goalReconcileSignature([
          goal('1', rule: steps, verifyEffectiveFrom: DateTime(2026, 7, 1)),
        ]),
        isNot(
          goalReconcileSignature([
            goal('1', rule: steps, verifyEffectiveFrom: DateTime(2026, 8, 1)),
          ]),
        ),
      );
      expect(
        goalReconcileSignature([
          goal('1', target: count80, targetEffectiveFrom: DateTime(2026, 7, 1)),
        ]),
        isNot(
          goalReconcileSignature([
            goal(
              '1',
              target: count80,
              targetEffectiveFrom: DateTime(2026, 8, 1),
            ),
          ]),
        ),
      );
    });

    test('changes when the schedule changes — an off-day is never scored, so '
        'the set of days in scope moved', () {
      expect(
        goalReconcileSignature([goal('1', rule: steps)]),
        isNot(
          goalReconcileSignature([
            goal('1', rule: steps, frequencyDays: [1, 3, 5]),
          ]),
        ),
      );
    });

    test('ignores the ORDER of frequency_days, and does not mutate the '
        "goal's own list while sorting it", () {
      final days = [5, 1, 3];
      final g = goal('1', rule: steps, frequencyDays: days);
      final sig = goalReconcileSignature([g]);
      expect(days, [
        5,
        1,
        3,
      ], reason: 'the model list must not be sorted in place');
      expect(
        sig,
        goalReconcileSignature([
          goal('1', rule: steps, frequencyDays: [1, 3, 5]),
        ]),
      );
    });

    test('changes when the active range changes — an end date takes days out '
        'of scope', () {
      expect(
        goalReconcileSignature([goal('1', target: count80)]),
        isNot(
          goalReconcileSignature([
            goal('1', target: count80, endDate: DateTime(2026, 8, 31)),
          ]),
        ),
      );
    });


  });
}
