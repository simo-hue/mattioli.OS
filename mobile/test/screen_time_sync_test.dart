// DeviceActivity monitoring reconcile — the two bugs found by the 2026-07-17
// Screen Time survey, and the guard that fixes them.
//
// The feature is dark (`VerificationConfig.screenTimeEnabled == false`), so none
// of this runs in the shipped app yet. It is fixed now because these are the
// defects that would have been enabled along with it, and because they are the
// part of the Screen Time surface that CAN be verified on this machine: there is
// no iOS SDK here, and FamilyControls does not run in the Simulator at all.
//
// Note what is deliberately NOT asserted. The native handler answers a sync with
// a bare `center.stopMonitoring()` (every activity, unconditionally) and then
// re-registers the set (AppDelegate.swift:621-660). Whether that resets
// DeviceActivity's accumulated usage counters is a claim about Apple's framework
// that cannot be tested from here, so no test here pretends to. What is testable
// — and tested — is that the churn does not happen when nothing changed.
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

  List<VerifiableGoal> verifiable(List<Goal> goals) => verifiableGoalsFrom(
        goals,
        healthKitEnabled: false,
        screenTimeEnabled: true,
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
        // authorization check of its own (AppDelegate.swift:644), and
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
      expect(screenTimeSpecsFrom(const []), isEmpty);
      expect(screenRule.isScreenTime, isTrue);
    });
  });
}
