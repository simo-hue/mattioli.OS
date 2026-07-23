import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/verification_wiring.dart';
import 'package:mattioli_os/models/goal.dart';

void main() {
  Goal goal(
    String id, {
    VerificationRule? rule,
    List<int>? frequencyDays,
    DateTime? startDate,
    DateTime? verifyEffectiveFrom,
  }) =>
      Goal(
        id: id,
        title: id,
        color: const Color(0xFF3B82F6),
        startDate: startDate ?? DateTime(2026, 1, 1),
        frequencyDays: frequencyDays,
        verificationRule: rule,
        verifyEffectiveFrom: verifyEffectiveFrom,
      );

  final steps = VerificationCatalog.steps.ruleWith(10000);
  final screen = VerificationCatalog.screenTimeTotal.ruleWith(120);

  group('verifiableGoalsFrom', () {
    test('keeps only verified goals honoring the per-provider flags', () {
      final goals = [
        goal('manual'), // no rule → excluded
        goal('steps', rule: steps, frequencyDays: [1, 2, 3]),
        goal('screen', rule: screen),
      ];
      final all = verifiableGoalsFrom(goals,
          healthKitEnabled: true,
          screenTimeAppsEnabled: true,
          screenTimeTotalEnabled: true);
      expect(all.map((g) => g.goalId), ['steps', 'screen']);

      final hkOnly = verifiableGoalsFrom(goals,
          healthKitEnabled: true,
          screenTimeAppsEnabled: false,
          screenTimeTotalEnabled: false);
      expect(hkOnly.map((g) => g.goalId), ['steps']);

      final stOnly = verifiableGoalsFrom(goals,
          healthKitEnabled: false,
          screenTimeAppsEnabled: true,
          screenTimeTotalEnabled: true);
      expect(stOnly.map((g) => g.goalId), ['screen']);

      final none = verifiableGoalsFrom(goals,
          healthKitEnabled: false,
          screenTimeAppsEnabled: false,
          screenTimeTotalEnabled: false);
      expect(none, isEmpty);
    });

    test('maps rule, effectiveFrom=startDate, and frequency→weekdays', () {
      final v = verifiableGoalsFrom(
        [goal('steps', rule: steps, frequencyDays: [1, 3, 5], startDate: DateTime(2026, 6, 1))],
        healthKitEnabled: true,
        screenTimeAppsEnabled: true,
        screenTimeTotalEnabled: true,
      ).single;
      expect(v.rule, steps);
      expect(v.effectiveFrom, DateTime(2026, 6, 1));
      expect(v.activeWeekdays, {1, 3, 5});
    });

    group('effectiveFrom honors the D10 verifyEffectiveFrom anchor', () {
      VerifiableGoal only(Goal g) => verifiableGoalsFrom(
            [g],
            healthKitEnabled: true,
            screenTimeAppsEnabled: true,
            screenTimeTotalEnabled: true,
          ).single;

      test('anchor after startDate wins → freezes days before the edit', () {
        final v = only(goal('steps',
            rule: steps,
            startDate: DateTime(2026, 1, 1),
            verifyEffectiveFrom: DateTime(2026, 6, 15)));
        expect(v.effectiveFrom, DateTime(2026, 6, 15));
      });

      test('null anchor falls back to startDate (pre-D10 behavior)', () {
        final v = only(goal('steps',
            rule: steps, startDate: DateTime(2026, 6, 1)));
        expect(v.effectiveFrom, DateTime(2026, 6, 1));
      });

      test('anchor before startDate is clamped up to startDate', () {
        final v = only(goal('steps',
            rule: steps,
            startDate: DateTime(2026, 6, 1),
            verifyEffectiveFrom: DateTime(2026, 1, 1)));
        expect(v.effectiveFrom, DateTime(2026, 6, 1));
      });
    });

    group('compound habits (Q1–Q5)', () {
      final stepsRule = VerificationCatalog.steps.ruleWith(10000);
      final exRule = VerificationCatalog.exerciseMinutes.ruleWith(30);
      Goal compoundGoal(VerificationJoin op) => Goal(
            id: 'gc',
            title: 'gc',
            color: const Color(0xFF3B82F6),
            startDate: DateTime(2026, 1, 1),
            verificationRule: stepsRule,
            additionalConditions: [exRule],
            verificationJoin: op,
          );

      List<VerifiableGoal> build(Goal g, {required bool compound, bool hk = true}) =>
          verifiableGoalsFrom([g],
              healthKitEnabled: hk,
              screenTimeAppsEnabled: true,
              screenTimeTotalEnabled: true,
              compoundEnabled: compound);

      test('builds a compound VerifiableGoal (conditions + operator) when on', () {
        final v = build(compoundGoal(VerificationJoin.and), compound: true).single;
        expect(v.isCompound, isTrue);
        expect(v.conditions, [stepsRule, exRule]);
        expect(v.join, VerificationJoin.and);
      });

      test('skips a compound goal when the compound flag is off', () {
        expect(build(compoundGoal(VerificationJoin.or), compound: false), isEmpty);
      });

      test('skips a compound goal when HealthKit is off', () {
        expect(
            build(compoundGoal(VerificationJoin.or), compound: true, hk: false),
            isEmpty);
      });
    });

    test('null frequency_days → every day (empty weekday set)', () {
      final v = verifiableGoalsFrom(
        [goal('steps', rule: steps)],
        healthKitEnabled: true,
        screenTimeAppsEnabled: true,
        screenTimeTotalEnabled: true,
      ).single;
      expect(v.activeWeekdays, isEmpty);
    });

    test('Mode A and Mode B gate independently', () {
      final apps = VerificationCatalog.screenTimeApps.ruleWith(60);
      final total = VerificationCatalog.screenTimeTotal.ruleWith(120);
      final goals = [goal('apps', rule: apps), goal('total', rule: total)];
      // Mode A live, Mode B dark → only the apps goal survives.
      expect(
        verifiableGoalsFrom(goals,
                healthKitEnabled: false,
                screenTimeAppsEnabled: true,
                screenTimeTotalEnabled: false)
            .map((g) => g.goalId),
        ['apps'],
      );
      // The reverse.
      expect(
        verifiableGoalsFrom(goals,
                healthKitEnabled: false,
                screenTimeAppsEnabled: false,
                screenTimeTotalEnabled: true)
            .map((g) => g.goalId),
        ['total'],
      );
    });

    test('a Mode-A goal with no resolvable selection is flagged missing', () {
      final apps = VerificationCatalog.screenTimeApps.ruleWith(60);
      VerifiableGoal build(String? Function(String)? resolver) =>
          verifiableGoalsFrom(
            [goal('a', rule: apps)],
            healthKitEnabled: false,
            screenTimeAppsEnabled: true,
            screenTimeTotalEnabled: false,
            screenTimeSelectionFor: resolver,
          ).single;

      expect(build((_) => 'BLOB').screenTimeSelectionMissing, isFalse);
      expect(build((_) => null).screenTimeSelectionMissing, isTrue);

      // Mode B is never "selection missing".
      final total = verifiableGoalsFrom(
        [goal('t', rule: VerificationCatalog.screenTimeTotal.ruleWith(120))],
        healthKitEnabled: false,
        screenTimeAppsEnabled: false,
        screenTimeTotalEnabled: true,
      ).single;
      expect(total.screenTimeSelectionMissing, isFalse);
    });
  });

  group('loggedOutcomesFrom', () {
    test('maps done→pass, missed→fail; drops skipped, unknown, unlisted, bad dates',
        () {
      final logs = {
        '2026-07-13': {'g': 'done', 'h': 'missed', 'x': 'done'},
        '2026-07-12': {'g': 'skipped', 'h': 'weird'},
        'not-a-date': {'g': 'done'},
      };
      final out = loggedOutcomesFrom(logs, {'g', 'h'});
      expect(out['g'], {DateTime(2026, 7, 13): VerificationOutcome.pass});
      expect(out['h'], {DateTime(2026, 7, 13): VerificationOutcome.fail});
      expect(out.containsKey('x'), isFalse); // not in the id set
    });
  });

  group('screenTimeSpecsFrom', () {
    test('emits specs only for screen-time goals, threshold rounded', () {
      final goals = verifiableGoalsFrom(
        [
          goal('steps', rule: steps),
          goal('screen', rule: VerificationCatalog.screenTimeTotal.ruleWith(90), frequencyDays: [6, 7]),
        ],
        healthKitEnabled: true,
        screenTimeAppsEnabled: true,
        screenTimeTotalEnabled: true,
      );
      final specs = screenTimeSpecsFrom(goals);
      expect(specs, hasLength(1));
      expect(specs.single.goalId, 'screen');
      expect(specs.single.thresholdMinutes, 90);
      expect(specs.single.activeWeekdays, {6, 7});
    });
  });

  test('dateKeyOf zero-pads to yyyy-MM-dd', () {
    expect(dateKeyOf(DateTime(2026, 7, 5)), '2026-07-05');
    expect(dateKeyOf(DateTime(2026, 12, 31)), '2026-12-31');
  });

  group('couldNotVerifyNudges', () {
    test('collapses to one nudge per goal (latest day), drops untitled', () {
      final report = ReconcileReport(couldNotVerify: 4, nudges: [
        CouldNotVerifyEntry(
            goalId: 'g', day: DateTime(2026, 7, 11), shouldNudge: true),
        CouldNotVerifyEntry(
            goalId: 'g', day: DateTime(2026, 7, 13), shouldNudge: true),
        CouldNotVerifyEntry(
            goalId: 'h', day: DateTime(2026, 7, 12), shouldNudge: true),
        CouldNotVerifyEntry(
            goalId: 'x', day: DateTime(2026, 7, 12), shouldNudge: true),
      ]);
      final nudges = couldNotVerifyNudges(report, {'g': 'Steps', 'h': 'Sleep'});
      expect(nudges.map((n) => n.goalId).toSet(), {'g', 'h'}); // 'x' untitled
      final g = nudges.firstWhere((n) => n.goalId == 'g');
      expect(g.day, DateTime(2026, 7, 13)); // latest of g's two days
      expect(g.title, 'Steps');
    });

    test('empty report yields no nudges', () {
      expect(couldNotVerifyNudges(const ReconcileReport(), {'g': 'Steps'}),
          isEmpty);
    });
  });

  group('unnudgedNudges', () {
    VerificationNudge nudge(String g, DateTime d) =>
        VerificationNudge(goalId: g, title: g, day: d);

    test('drops candidates whose goal+day was already nudged', () {
      final candidates = [
        nudge('g', DateTime(2026, 7, 13)),
        nudge('h', DateTime(2026, 7, 13)),
      ];
      final already = {
        'g': {DateTime(2026, 7, 13)},
      };
      expect(unnudgedNudges(candidates, already).map((n) => n.goalId), ['h']);
    });

    test('a later day for the same goal still nudges', () {
      final candidates = [nudge('g', DateTime(2026, 7, 14))];
      final already = {
        'g': {DateTime(2026, 7, 13)},
      };
      expect(unnudgedNudges(candidates, already), hasLength(1));
    });

    test('empty already-nudged keeps everything', () {
      expect(
        unnudgedNudges([nudge('g', DateTime(2026, 7, 13))], const {}),
        hasLength(1),
      );
    });
  });

  group('celebrationNotices', () {
    LogWrite write(String g, DateTime d, VerificationOutcome o) =>
        LogWrite(goalId: g, day: d, outcome: o);

    test('celebrates only today passes with a known title', () {
      final writes = [
        write('g', DateTime(2026, 7, 13), VerificationOutcome.pass), // today
        write('past', DateTime(2026, 7, 11), VerificationOutcome.pass), // old
        write('fail', DateTime(2026, 7, 13), VerificationOutcome.fail), // fail
        write('x', DateTime(2026, 7, 13), VerificationOutcome.pass), // untitled
      ];
      final notices = celebrationNotices(
        writes,
        {'g': 'Steps', 'past': 'Sleep', 'fail': 'Screen'},
        '2026-07-13',
      );
      expect(notices.map((n) => n.goalId), ['g']);
      expect(notices.single.title, 'Steps');
      expect(notices.single.dateKey, '2026-07-13');
    });

    test('no passes today yields nothing', () {
      final writes = [
        write('g', DateTime(2026, 7, 11), VerificationOutcome.pass),
      ];
      expect(celebrationNotices(writes, {'g': 'Steps'}, '2026-07-13'), isEmpty);
    });
  });
}
