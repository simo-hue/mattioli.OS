// DeviceActivity monitoring reconcile — the two bugs found by the 2026-07-17
// Screen Time survey, and the guard that fixes them.
//
// Mode A is LIVE (`VerificationConfig.screenTimeAppsEnabled == true`, so
// `screenTimeEnabled` is true) — this is shipped code, not dark code. It is the
// part of the Screen Time surface that CAN be verified on this machine: there is
// no iOS SDK here, and FamilyControls does not run in the Simulator at all.
//
// Note what is deliberately NOT asserted. `ScreenTimeBridge.syncMonitoredGoals`
// now DIFFS its registrations natively — it stops only what is no longer wanted
// and leaves an unchanged, still-live goal running with its accrued usage — but
// that behaviour lives in Swift and cannot be tested from here (no iOS SDK, and
// FamilyControls does not run in the Simulator). What is testable, and tested, is
// the Dart half: which specs are derived, and that the channel is not dialled
// when nothing the app knows about has changed.
import 'package:evolve_verification/evolve_verification.dart';
// Test doubles are exported separately so they never ship in app code.
import 'package:evolve_verification/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/verification_wiring.dart';
import 'package:mattioli_os/models/goal.dart';

void main() {
  final screenRule = VerificationCatalog.screenTimeTotal.ruleWith(120);

  Goal goal(String id, {double threshold = 120}) => Goal(
        id: id,
        title: id,
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2026, 1, 1),
        verificationRule:
            VerificationCatalog.screenTimeTotal.ruleWith(threshold),
      );

  Goal appsGoal(String id, {double threshold = 60}) => Goal(
        id: id,
        title: id,
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2026, 1, 1),
        verificationRule:
            VerificationCatalog.screenTimeApps.ruleWith(threshold),
      );

  List<VerifiableGoal> verifiable(List<Goal> goals) => verifiableGoalsFrom(
        goals,
        healthKitEnabled: false,
        screenTimeAppsEnabled: true,
        screenTimeTotalEnabled: true,
      );

  group('screenTimeSpecsChanged', () {
    const a = ScreenTimeGoalSpec(goalId: 'a', thresholdMinutes: 30);
    const b = ScreenTimeGoalSpec(goalId: 'b', thresholdMinutes: 60);

    test('A NULL CACHE ALWAYS RE-SYNCS — this is the load-bearing case', () {
      // The cache is per-process on purpose. iOS may have dropped the monitoring
      // while the app was not running (reboot, force-quit, an OS purge) and
      // nothing tells us. So the first reconcile of every launch must
      // re-register unconditionally; a persisted cache would let a stale entry
      // convince us monitoring was live when it was not.
      expect(screenTimeSpecsChanged(null, const []), isTrue);
      expect(screenTimeSpecsChanged(null, const [a]), isTrue);
    });

    test('an unchanged set is not re-synced', () {
      expect(screenTimeSpecsChanged(const [a, b], const [a, b]), isFalse);
    });

    test('order does not count as a change', () {
      // Spec order comes from goal order, which changes when a user reorders
      // their habits and means nothing at all to DeviceActivity. Treating that
      // as a change would stop and re-register every activity for a drag.
      expect(screenTimeSpecsChanged(const [a, b], const [b, a]), isFalse);
    });

    test('a changed threshold, an added goal and a removed goal all count', () {
      expect(
        screenTimeSpecsChanged(
          const [a],
          const [ScreenTimeGoalSpec(goalId: 'a', thresholdMinutes: 45)],
        ),
        isTrue,
        reason: 'threshold edit must reach DeviceActivity',
      );
      expect(screenTimeSpecsChanged(const [a], const [a, b]), isTrue);
      expect(screenTimeSpecsChanged(const [a, b], const [a]), isTrue);
      expect(screenTimeSpecsChanged(const [a], const []), isTrue);
    });

    test('a changed weekday set counts', () {
      expect(
        screenTimeSpecsChanged(
          const [ScreenTimeGoalSpec(goalId: 'a', thresholdMinutes: 30)],
          const [
            ScreenTimeGoalSpec(
              goalId: 'a',
              thresholdMinutes: 30,
              activeWeekdays: {1, 2},
            ),
          ],
        ),
        isTrue,
      );
    });
  });

  group('syncScreenTimeMonitoring', () {
    test('DELETING THE LAST GOAL STILL TELLS DEVICEACTIVITY TO STOP', () async {
      // The bug. `runVerificationReconcile` used to `return` on an empty goal
      // list BEFORE the sync, so `syncMonitoredGoals([])` was never called — and
      // the native side only stops monitoring when it is called. DeviceActivity
      // went on watching for a habit the user had deleted, for the life of the
      // install, with no UI anywhere admitting it.
      final bridge = FakeScreenTimeBridge();
      final cache = ScreenTimeSyncCache();

      await syncScreenTimeMonitoring(
        bridge: bridge,
        cache: cache,
        goals: const [],
      );

      expect(bridge.syncCallCount, 1, reason: 'the empty sync must happen');
      expect(bridge.lastSyncedSpecs, isEmpty);
    });

    test('an unchanged set is synced once, not on every foreground', () async {
      final bridge = FakeScreenTimeBridge();
      final cache = ScreenTimeSyncCache();
      final goals = verifiable([goal('a')]);

      await syncScreenTimeMonitoring(bridge: bridge, cache: cache, goals: goals);
      await syncScreenTimeMonitoring(bridge: bridge, cache: cache, goals: goals);
      await syncScreenTimeMonitoring(bridge: bridge, cache: cache, goals: goals);

      expect(
        bridge.syncCallCount,
        1,
        reason: 'reconcile runs on EVERY foreground; only the first should sync',
      );
    });

    test('a real change still gets through', () async {
      final bridge = FakeScreenTimeBridge();
      final cache = ScreenTimeSyncCache();

      await syncScreenTimeMonitoring(
        bridge: bridge,
        cache: cache,
        goals: verifiable([goal('a')]),
      );
      await syncScreenTimeMonitoring(
        bridge: bridge,
        cache: cache,
        goals: verifiable([goal('a', threshold: 45)]),
      );

      expect(bridge.syncCallCount, 2);
      expect(bridge.lastSyncedSpecs.single.thresholdMinutes, 45);
    });

    test('A FAILED SYNC IS NOT CACHED — it retries next foreground', () async {
      // Caching a failure would strand monitoring in whatever state the failure
      // left it, permanently, and the next reconcile would cheerfully skip.
      final bridge = FakeScreenTimeBridge(monitorLimit: 0); // every sync throws
      final cache = ScreenTimeSyncCache();
      final goals = verifiable([goal('a')]);

      await syncScreenTimeMonitoring(bridge: bridge, cache: cache, goals: goals);
      expect(cache.last, isNull, reason: 'a throw must not be recorded as done');

      // And it must be retried rather than skipped.
      bridge.monitorLimit = 20;
      await syncScreenTimeMonitoring(bridge: bridge, cache: cache, goals: goals);
      expect(bridge.syncCallCount, 1);
      expect(cache.last, isNotNull);
    });

    test('the monitor-limit throw does not escape the reconcile', () async {
      // It is surfaced as a typed exception by the bridge, but the reconcile
      // runs from a lifecycle hook — an escape would take the foreground pass
      // down with it.
      final bridge = FakeScreenTimeBridge(monitorLimit: 0);
      await expectLater(
        syncScreenTimeMonitoring(
          bridge: bridge,
          cache: ScreenTimeSyncCache(),
          goals: verifiable([goal('a')]),
        ),
        completes,
      );
    });

    group('authorization', () {
      test('UNAUTHORIZED DOES NOT DIAL startMonitoring', () async {
        // The native handler calls `center.startMonitoring` with no
        // authorization check of its own (`ScreenTimeBridge.syncMonitoredGoals`), and
        // DeviceActivity throws when unauthorized — on every foreground.
        for (final status in [
          ScreenTimeAuthorizationStatus.notDetermined,
          ScreenTimeAuthorizationStatus.denied,
        ]) {
          final bridge = FakeScreenTimeBridge(status: status);
          await syncScreenTimeMonitoring(
            bridge: bridge,
            cache: ScreenTimeSyncCache(),
            goals: verifiable([goal('a')]),
          );
          expect(bridge.syncCallCount, 0, reason: 'must not sync when $status');
        }
      });

      test('the reconcile never REQUESTS authorization', () async {
        // A system permission prompt fired from a background foreground-hook
        // arrives out of nowhere. The request belongs at the Screen Time opt-in,
        // which does not exist yet because the feature is dark. Until it does,
        // this stays a check.
        final bridge = FakeScreenTimeBridge(
          status: ScreenTimeAuthorizationStatus.notDetermined,
        );
        await syncScreenTimeMonitoring(
          bridge: bridge,
          cache: ScreenTimeSyncCache(),
          goals: verifiable([goal('a')]),
        );
        expect(bridge.requestAuthorizationCount, 0);
      });

      test('STOPPING needs no authorization', () async {
        // Otherwise a user who revoked Family Controls could never have
        // monitoring torn down — the authorization gate would skip the very
        // empty sync that stops it.
        final bridge = FakeScreenTimeBridge(
          status: ScreenTimeAuthorizationStatus.denied,
        );
        await syncScreenTimeMonitoring(
          bridge: bridge,
          cache: ScreenTimeSyncCache(),
          goals: const [],
        );
        expect(bridge.syncCallCount, 1);
        expect(bridge.lastSyncedSpecs, isEmpty);
      });

      test('approved syncs normally', () async {
        final bridge = FakeScreenTimeBridge(
          status: ScreenTimeAuthorizationStatus.approved,
        );
        await syncScreenTimeMonitoring(
          bridge: bridge,
          cache: ScreenTimeSyncCache(),
          goals: verifiable([goal('a')]),
        );
        expect(bridge.syncCallCount, 1);
        expect(bridge.lastSyncedSpecs.single.goalId, 'a');
      });
    });

    test('non-Screen-Time goals produce no specs', () {
      // A HealthKit-only user must never reach DeviceActivity.
      expect(screenTimeSpecsFrom(const [], today: DateTime.now()), isEmpty);
      expect(screenRule.isScreenTime, isTrue);
    });

    test('monitor-limit is surfaced via onMonitorLimit and does not escape',
        () async {
      // The cap throw is caught, reported to the UI hook, and NOT cached — the
      // sync must retry once the user removes a habit.
      final bridge = FakeScreenTimeBridge(monitorLimit: 0); // every sync throws
      final cache = ScreenTimeSyncCache();
      ScreenTimeMonitorLimitException? captured;
      await expectLater(
        syncScreenTimeMonitoring(
          bridge: bridge,
          cache: cache,
          goals: verifiable([goal('a')]),
          onMonitorLimit: (e) => captured = e,
        ),
        completes,
      );
      expect(captured, isNotNull);
      expect(cache.last, isNull, reason: 'a cap throw must not be cached');
    });

    test('a generic sync failure is swallowed and onMonitorLimit is NOT called',
        () async {
      var limitCalled = false;
      await expectLater(
        syncScreenTimeMonitoring(
          bridge: _ThrowingBridge(),
          cache: ScreenTimeSyncCache(),
          goals: verifiable([goal('a')]),
          onMonitorLimit: (_) => limitCalled = true,
        ),
        completes,
      );
      expect(limitCalled, isFalse);
    });
  });

  group('screenTimeSpecsFrom — modes & selection', () {
    test('Mode B (total) goal → one spec, mode=total, null blob', () {
      final specs = screenTimeSpecsFrom(verifiable([goal('a')]), today: DateTime.now());
      expect(specs.single.mode, ScreenTimeMode.totalUsage);
      expect(specs.single.selectionBlob, isNull);
    });

    test('Mode A goal WITH a resolved selection → spec carries mode=apps + blob',
        () {
      final specs = screenTimeSpecsFrom(
        verifiable([appsGoal('a')]),
        today: DateTime.now(),
        selectionFor: (id) => id == 'a' ? 'BLOB' : null,
      );
      expect(specs.single.mode, ScreenTimeMode.appsAndCategories);
      expect(specs.single.selectionBlob, 'BLOB');
    });

    test('Mode A goal with NO resolvable selection → NO spec', () {
      // Never registered ⇒ stays couldn't-verify, never a silent pass.
      final specs = screenTimeSpecsFrom(
        verifiable([appsGoal('a')]),
        today: DateTime.now(),
        selectionFor: (_) => null,
      );
      expect(specs, isEmpty);
    });

    test('a changed selection blob counts as a re-sync', () {
      const before = ScreenTimeGoalSpec(
        goalId: 'a',
        thresholdMinutes: 60,
        mode: ScreenTimeMode.appsAndCategories,
        selectionBlob: 'X',
      );
      const after = ScreenTimeGoalSpec(
        goalId: 'a',
        thresholdMinutes: 60,
        mode: ScreenTimeMode.appsAndCategories,
        selectionBlob: 'Y',
      );
      expect(screenTimeSpecsChanged(const [before], const [after]), isTrue);
    });
  });

  // ── syncScreenTimeMonitoringFor — the goal-list-driven entry point ─────────
  //
  // Registration used to be reachable ONLY from the `AppLifecycleState.resumed`
  // hook in main.dart, so a habit created, edited or deleted in an ordinary
  // session never reached DeviceActivity, and a cold-launched session that never
  // backgrounded registered nothing at all. This entry point is what the goal
  // list now drives.
  group('syncScreenTimeMonitoringFor', () {
    test('derives specs from a raw goal list and registers them', () async {
      final bridge = FakeScreenTimeBridge();
      final cache = ScreenTimeSyncCache();

      await syncScreenTimeMonitoringFor(
        goals: [appsGoal('a', threshold: 45)],
        bridge: bridge,
        cache: cache,
        selectionFor: (_) => 'BLOB',
      );

      expect(bridge.syncCallCount, 1);
      expect(bridge.lastSyncedSpecs.single.goalId, 'a');
      expect(bridge.lastSyncedSpecs.single.thresholdMinutes, 45);
      expect(bridge.lastSyncedSpecs.single.selectionBlob, 'BLOB');
    });

    test(
        'a Mode-A goal with no selection yet registers NOTHING — the blob is '
        'written after the goal, so the goal-change fire must not half-register',
        () async {
      final bridge = FakeScreenTimeBridge();
      final cache = ScreenTimeSyncCache();

      await syncScreenTimeMonitoringFor(
        goals: [appsGoal('a')],
        bridge: bridge,
        cache: cache,
        selectionFor: (_) => null,
      );

      expect(bridge.lastSyncedSpecs, isEmpty);
    });

    test(
        'REFRESHES THE EXTENSION NOTIFICATION COPY — this path can make a habit '
        'monitored, and the extension falls back to English without it',
        () async {
      final bridge = FakeScreenTimeBridge();

      await syncScreenTimeMonitoringFor(
        goals: [appsGoal('a')],
        bridge: bridge,
        cache: ScreenTimeSyncCache(),
        selectionFor: (_) => 'BLOB',
      );

      expect(bridge.lastNotificationCopy, isNotNull);
      expect(bridge.lastNotificationCopy!.title, isNotEmpty);
      expect(bridge.lastNotificationCopy!.body, isNotEmpty);
    });

    test('the spec diff still suppresses an unchanged re-sync', () async {
      final bridge = FakeScreenTimeBridge();
      final cache = ScreenTimeSyncCache();
      final goals = [appsGoal('a')];

      await syncScreenTimeMonitoringFor(
        goals: goals,
        bridge: bridge,
        cache: cache,
        selectionFor: (_) => 'BLOB',
      );
      await syncScreenTimeMonitoringFor(
        goals: goals,
        bridge: bridge,
        cache: cache,
        selectionFor: (_) => 'BLOB',
      );

      expect(bridge.syncCallCount, 1);
    });

    test('a deleted goal is removed from the registered set', () async {
      final bridge = FakeScreenTimeBridge();
      final cache = ScreenTimeSyncCache();

      await syncScreenTimeMonitoringFor(
        goals: [appsGoal('a'), appsGoal('b')],
        bridge: bridge,
        cache: cache,
        selectionFor: (_) => 'BLOB',
      );
      await syncScreenTimeMonitoringFor(
        goals: [appsGoal('a')],
        bridge: bridge,
        cache: cache,
        selectionFor: (_) => 'BLOB',
      );

      expect(bridge.syncCallCount, 2);
      expect(bridge.lastSyncedSpecs.map((s) => s.goalId), ['a']);
    });

    test('DELETING THE LAST GOAL still tells DeviceActivity to stop', () async {
      final bridge = FakeScreenTimeBridge();
      final cache = ScreenTimeSyncCache();

      await syncScreenTimeMonitoringFor(
        goals: [appsGoal('a')],
        bridge: bridge,
        cache: cache,
        selectionFor: (_) => 'BLOB',
      );
      await syncScreenTimeMonitoringFor(
        goals: const [],
        bridge: bridge,
        cache: cache,
        selectionFor: (_) => null,
      );

      expect(bridge.syncCallCount, 2);
      expect(bridge.lastSyncedSpecs, isEmpty);
    });

    test('a FAILING notification-copy write must not stop the registration',
        () async {
      // The copy is cosmetic — the extension falls back to English — while the
      // registration is the feature. The reconcile entry point used to await an
      // unprotected copy write of its own, so a channel error there took the
      // whole pass down with it, HealthKit verdicts included.
      final bridge = _CopyThrowingBridge();

      await syncScreenTimeMonitoringFor(
        goals: [appsGoal('a')],
        bridge: bridge,
        cache: ScreenTimeSyncCache(),
        selectionFor: (_) => 'BLOB',
      );

      expect(bridge.syncCallCount, 1);
      expect(bridge.lastSyncedSpecs.single.goalId, 'a');
    });
  });

  // ── Lifetime bound: an ARCHIVED habit must stop being monitored ────────────
  //
  // The pipeline was `endDate`-blind: it carried `frequencyDays` into the
  // verifiable goal but never the habit's own end, so an archived Screen Time
  // habit stayed registered with DeviceActivity — still counting, still able to
  // raise a real "limit reached" banner — while every day-scoped surface in the
  // app had hidden it.
  group('endDate', () {
    Goal endedGoal(String id, DateTime? endDate) => Goal(
          id: id,
          title: id,
          color: const Color(0xFF3B82F6),
          startDate: DateTime(2026, 1, 1),
          endDate: endDate,
          verificationRule: VerificationCatalog.screenTimeTotal.ruleWith(120),
        );

    final today = DateTime(2026, 7, 13);

    test('verifiableGoalsFrom carries endDate through as effectiveTo', () {
      final goals = verifiable([endedGoal('a', DateTime(2026, 7, 1))]);
      expect(goals.single.effectiveTo, DateTime(2026, 7, 1));
    });

    test('a habit that ended yesterday produces NO spec', () {
      final specs = screenTimeSpecsFrom(
        verifiable([endedGoal('a', DateTime(2026, 7, 12))]),
        today: today,
      );
      expect(specs, isEmpty);
    });

    test('a habit ending TODAY is still monitored — the bound is inclusive',
        () {
      final specs = screenTimeSpecsFrom(
        verifiable([endedGoal('a', today)]),
        today: today,
      );
      expect(specs.single.goalId, 'a');
    });

    test('a habit with no endDate is unaffected', () {
      final specs = screenTimeSpecsFrom(
        verifiable([endedGoal('a', null)]),
        today: today,
      );
      expect(specs.single.goalId, 'a');
    });

    test('archiving the last habit tells DeviceActivity to stop', () async {
      final bridge = FakeScreenTimeBridge();
      final cache = ScreenTimeSyncCache();

      await syncScreenTimeMonitoring(
        bridge: bridge,
        cache: cache,
        goals: verifiable([endedGoal('a', null)]),
        today: today,
      );
      expect(bridge.lastSyncedSpecs, hasLength(1));

      await syncScreenTimeMonitoring(
        bridge: bridge,
        cache: cache,
        goals: verifiable([endedGoal('a', DateTime(2026, 7, 12))]),
        today: today,
      );

      expect(bridge.syncCallCount, 2,
          reason: 'the deregistration has to reach native — it is the only '
              'thing that can stop the monitor');
      expect(bridge.lastSyncedSpecs, isEmpty);
    });
  });
}

/// A bridge whose notification-copy write throws, to prove the cosmetic call
/// cannot cost the registration.
class _CopyThrowingBridge extends FakeScreenTimeBridge {
  @override
  Future<void> setLocalizedNotificationCopy({
    required String title,
    required String body,
  }) async =>
      throw StateError('channel unavailable');
}

/// A bridge whose sync throws a NON-limit error, to prove the generic failure
/// path is swallowed without being mistaken for the cap.
class _ThrowingBridge extends FakeScreenTimeBridge {
  @override
  Future<void> syncMonitoredGoals(List<ScreenTimeGoalSpec> specs) async =>
      throw StateError('boom');
}
