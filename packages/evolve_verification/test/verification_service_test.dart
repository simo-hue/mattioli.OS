import 'package:evolve_verification/evolve_verification.dart';
import 'package:evolve_verification/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A fixed "today" keeps the day arithmetic deterministic.
  final today = DateTime(2026, 7, 13);
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  late FakeHealthKitBridge health;
  late FakeScreenTimeBridge screen;

  setUp(() {
    health = FakeHealthKitBridge();
    screen = FakeScreenTimeBridge();
  });

  VerificationService service({int backfill = 3, int nag = 2}) =>
      VerificationService(
        health: health,
        screenTime: screen,
        backfillDays: backfill,
        nagWindowDays: nag,
      );

  VerifiableGoal steps({DateTime? from, Set<int> weekdays = const {}}) =>
      VerifiableGoal(
        goalId: 'g_steps',
        rule: VerificationCatalog.steps.ruleWith(10000),
        effectiveFrom: from ?? daysAgo(30),
        activeWeekdays: weekdays,
      );

  group('reconcile — HealthKit', () {
    test('writes verified passes/fails and records couldn\'t-verify', () async {
      const id = 'stepCount';
      health.setQuantity(id, daysAgo(1), 12000); // pass
      health.setQuantity(id, daysAgo(2), 5000); // fail (past, below target)
      health.setQuantity(id, today, 3000); // pending (still today)
      // daysAgo(2) is the window edge with backfill=3 (window = today..today-2).

      final plan = await service().reconcile(goals: [steps()], today: today);

      expect(
        plan.writes,
        containsAll([
          LogWrite(
              goalId: 'g_steps',
              day: daysAgo(1),
              outcome: VerificationOutcome.pass,
              value: 12000),
          LogWrite(
              goalId: 'g_steps',
              day: daysAgo(2),
              outcome: VerificationOutcome.fail,
              value: 5000),
        ]),
      );
      // Today is pending → no write for it.
      expect(plan.writes.any((w) => w.day == today), isFalse);
    });

    test('today never fails an atLeast goal, only passes or stays pending',
        () async {
      health.setQuantity('stepCount', today, 12000);
      final plan = await service().reconcile(goals: [steps()], today: today);
      expect(
        plan.writes,
        contains(LogWrite(
            goalId: 'g_steps',
            day: today,
            outcome: VerificationOutcome.pass,
            value: 12000)),
      );
    });

    test('missing past data becomes couldn\'t-verify with a nag window',
        () async {
      // No data programmed at all → every past day is couldn't-verify.
      final plan = await service(backfill: 5, nag: 2)
          .reconcile(goals: [steps()], today: today);

      final byDay = {for (final e in plan.couldNotVerify) e.day: e};
      expect(byDay[daysAgo(1)]!.shouldNudge, isTrue); // age 1 ≤ 2
      expect(byDay[daysAgo(2)]!.shouldNudge, isTrue); // age 2 ≤ 2
      expect(byDay[daysAgo(3)]!.shouldNudge, isFalse); // age 3 > 2 → quiet
      expect(byDay[daysAgo(4)]!.shouldNudge, isFalse);
      expect(plan.writes, isEmpty);
    });
  });

  group('reconcile — freezing and idempotency', () {
    test('a manual entry freezes the day against auto-writes (D9)', () async {
      health.setQuantity('stepCount', daysAgo(1), 5000); // would be a fail
      final existing = {
        'g_steps': {
          daysAgo(1): const ExistingDay(
              loggedOutcome: VerificationOutcome.pass, manual: true),
        },
      };
      final plan = await service()
          .reconcile(goals: [steps()], today: today, existing: existing);
      expect(plan.writes.any((w) => w.day == daysAgo(1)), isFalse);
    });

    test('an unchanged auto verdict is not rewritten (idempotent)', () async {
      health.setQuantity('stepCount', daysAgo(1), 12000); // pass
      final existing = {
        'g_steps': {
          daysAgo(1):
              const ExistingDay(loggedOutcome: VerificationOutcome.pass),
        },
      };
      final plan = await service()
          .reconcile(goals: [steps()], today: today, existing: existing);
      expect(plan.writes.any((w) => w.day == daysAgo(1)), isFalse);
    });

    test('a changed verdict IS rewritten (late data flips fail→pass)', () async {
      health.setQuantity('stepCount', daysAgo(1), 12000); // now a pass
      final existing = {
        'g_steps': {
          daysAgo(1):
              const ExistingDay(loggedOutcome: VerificationOutcome.fail),
        },
      };
      final plan = await service()
          .reconcile(goals: [steps()], today: today, existing: existing);
      expect(
        plan.writes,
        contains(LogWrite(
            goalId: 'g_steps',
            day: daysAgo(1),
            outcome: VerificationOutcome.pass,
            value: 12000)),
      );
    });
  });

  group('reconcile — scheduling and effective date', () {
    test('off-days are skipped entirely — no verdict, no nudge (D6)', () async {
      // Schedule only today's weekday; program today as pending.
      health.setQuantity('stepCount', today, 3000);
      final plan = await service(backfill: 5).reconcile(
        goals: [steps(weekdays: {today.weekday})],
        today: today,
      );
      // Only today is evaluated (pending) and every other day is skipped, so
      // the plan is completely empty — off-days do not spam couldn't-verify.
      expect(plan.isEmpty, isTrue);
    });

    test('days before effectiveFrom are not evaluated (forward-only, D10)',
        () async {
      health.setQuantity('stepCount', daysAgo(1), 5000); // pre-effective fail
      health.setQuantity('stepCount', today, 12000); // pass
      final plan = await service(backfill: 7).reconcile(
        goals: [steps(from: today)],
        today: today,
      );
      expect(plan.writes.any((w) => w.day == daysAgo(1)), isFalse);
      expect(plan.couldNotVerify.any((e) => e.day == daysAgo(1)), isFalse);
      expect(
        plan.writes,
        contains(LogWrite(
            goalId: 'g_steps',
            day: today,
            outcome: VerificationOutcome.pass,
            value: 12000)),
      );
    });
  });

  group('reconcile — Screen Time', () {
    VerifiableGoal screenGoal() => VerifiableGoal(
          goalId: 'g_screen',
          rule: VerificationCatalog.screenTimeTotal.ruleWith(120),
          effectiveFrom: daysAgo(30),
        );

    test('reached-threshold → missed, stayed-under → done, buffer clears',
        () async {
      screen.addSignal(ScreenTimeSignal(
          goalId: 'g_screen',
          day: daysAgo(1),
          kind: ScreenTimeSignalKind.reachedThreshold));
      screen.addSignal(ScreenTimeSignal(
          goalId: 'g_screen',
          day: daysAgo(2),
          kind: ScreenTimeSignalKind.stayedUnder));

      final first =
          await service().reconcile(goals: [screenGoal()], today: today);
      expect(
        first.writes,
        containsAll([
          LogWrite(
              goalId: 'g_screen',
              day: daysAgo(1),
              outcome: VerificationOutcome.fail),
          LogWrite(
              goalId: 'g_screen',
              day: daysAgo(2),
              outcome: VerificationOutcome.pass),
        ]),
      );

      // Buffer was drained: a second pass has no signals, so past days with no
      // signal fall to couldn't-verify instead of re-writing.
      final second =
          await service().reconcile(goals: [screenGoal()], today: today);
      expect(second.writes, isEmpty);
      expect(second.couldNotVerify, isNotEmpty);
    });

    test('a reached-threshold signal wins over a duplicate stayed-under',
        () async {
      // Out-of-order / duplicated signals for the same day (finding #4).
      screen.addSignal(ScreenTimeSignal(
          goalId: 'g_screen',
          day: daysAgo(1),
          kind: ScreenTimeSignalKind.reachedThreshold));
      screen.addSignal(ScreenTimeSignal(
          goalId: 'g_screen',
          day: daysAgo(1),
          kind: ScreenTimeSignalKind.stayedUnder));

      final plan =
          await service().reconcile(goals: [screenGoal()], today: today);
      expect(
        plan.writes,
        contains(LogWrite(
            goalId: 'g_screen',
            day: daysAgo(1),
            outcome: VerificationOutcome.fail)),
      );
      expect(
        plan.writes.any((w) =>
            w.day == daysAgo(1) && w.outcome == VerificationOutcome.pass),
        isFalse,
      );
    });

    test('does not drain when there is no screen-time goal', () async {
      screen.addSignal(ScreenTimeSignal(
          goalId: 'g_screen',
          day: daysAgo(1),
          kind: ScreenTimeSignalKind.reachedThreshold));
      await service().reconcile(goals: [steps()], today: today);
      // Signal is still buffered because drain was skipped.
      final drained = await screen.drainSignals();
      expect(drained, hasLength(1));
    });

    test('a selection-missing Mode-A goal never passes off a stale signal',
        () async {
      // A Mode-A goal whose device-local selection is unresolvable isn't being
      // monitored; a stale monitor's stayed-under must be ignored so a past day
      // records couldn't-verify, never a silent pass.
      screen.addSignal(ScreenTimeSignal(
          goalId: 'g_apps',
          day: daysAgo(1),
          kind: ScreenTimeSignalKind.stayedUnder));
      final missing = VerifiableGoal(
        goalId: 'g_apps',
        rule: VerificationCatalog.screenTimeApps.ruleWith(60),
        effectiveFrom: daysAgo(30),
        screenTimeSelectionMissing: true,
      );
      final plan = await service().reconcile(goals: [missing], today: today);
      expect(
        plan.writes.any((w) => w.outcome == VerificationOutcome.pass),
        isFalse,
        reason: 'a selection-missing goal must never pass',
      );
      expect(plan.couldNotVerify.any((e) => e.goalId == 'g_apps'), isTrue);
    });
  });

  // Regressions for defects caught by the adversarial review of the engine.
  group('reconcile — regressions', () {
    VerifiableGoal screenGoal() => VerifiableGoal(
          goalId: 'g_screen',
          rule: VerificationCatalog.screenTimeTotal.ruleWith(120),
          effectiveFrom: daysAgo(30),
        );

    test('a day with a terminal logged outcome is never re-nudged as '
        'couldn\'t-verify (finding 1)', () async {
      // Screen Time signals are ephemeral: after the pass that logged `missed`,
      // later reconciles see no signal for the day and must NOT re-record it.
      final existing = {
        'g_screen': {
          daysAgo(1):
              const ExistingDay(loggedOutcome: VerificationOutcome.fail),
        },
      };
      final plan = await service().reconcile(
        goals: [screenGoal()],
        today: today,
        existing: existing,
      );
      expect(plan.couldNotVerify.any((e) => e.day == daysAgo(1)), isFalse);
      expect(plan.writes.any((w) => w.day == daysAgo(1)), isFalse);
    });

    test('every emitted day is pinned to local midnight across a DST window '
        '(finding 2)', () async {
      // Oct 2026 contains the EU DST fall-back; iterate a window over it and
      // assert no day drifted off midnight (which would miss midnight-keyed
      // lookups for manual-freeze/idempotency/signals).
      final dstToday = DateTime(2026, 10, 27);
      final id = 'stepCount';
      for (var i = 0; i < 5; i++) {
        health.setQuantity(
            id, dstToday.subtract(Duration(days: i)), 12000.0 - i);
      }
      final plan = await VerificationService(
        health: health,
        screenTime: screen,
        backfillDays: 5,
      ).reconcile(
        goals: [
          VerifiableGoal(
            goalId: 'g_steps',
            rule: VerificationCatalog.steps.ruleWith(10000),
            effectiveFrom: DateTime(2026, 1, 1),
          )
        ],
        today: dstToday,
      );
      for (final w in plan.writes) {
        expect(w.day.hour, 0, reason: '$w not at midnight');
        expect(w.day, DateTime(w.day.year, w.day.month, w.day.day));
      }
      for (final e in plan.couldNotVerify) {
        expect(e.day.hour, 0, reason: '$e not at midnight');
      }
      // The window covers exactly the five calendar days Oct 23–27, and every
      // one passes (all ≥ 10000 steps, today included).
      expect(plan.writes.map((w) => w.day).toSet(), {
        DateTime(2026, 10, 23),
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 26),
        DateTime(2026, 10, 27),
      });
    });

    test('a logged screen-time fail is permanent against a late stayed-under '
        '(finding 3)', () async {
      screen.addSignal(ScreenTimeSignal(
          goalId: 'g_screen',
          day: daysAgo(1),
          kind: ScreenTimeSignalKind.stayedUnder));
      final existing = {
        'g_screen': {
          daysAgo(1):
              const ExistingDay(loggedOutcome: VerificationOutcome.fail),
        },
      };
      final plan = await service().reconcile(
        goals: [screenGoal()],
        today: today,
        existing: existing,
      );
      // The fail must not be flipped back to a pass.
      expect(plan.writes.any((w) => w.day == daysAgo(1)), isFalse);
    });
  });
}
