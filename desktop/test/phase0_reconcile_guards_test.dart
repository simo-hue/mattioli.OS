// Phase 0 regression guards for the desktop dashboard controller.
//
// Three confirmed findings, all in the manual-target/toggle area, all of which
// silently corrupted or destroyed user data with the targets flag ON:
//   #1 a FAILED goal_progress read looked identical to "no progress", so the
//      sweep resolved recorded breaches to 'done' and applied amount 0 — which
//      DELETES the server row;
//   #2 the sweep wrote backfilled days into the CURRENT week's 7-slot grid,
//      marking days that have not happened yet as done;
//   #3 toggleHabitForDay had neither the verification guard nor the target
//      guard its two sibling writers carry, so macOS check-ins were reverted.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/clock.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingRepository extends DashboardRepository {
  _RecordingRepository(this._snapshot);
  DashboardSnapshot _snapshot;

  final List<Map<String, Object?>> progressCalls = [];
  final List<Map<String, Object?>> statusCalls = [];

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<void> save(DashboardSnapshot snapshot) async => _snapshot = snapshot;

  @override
  Future<void> setHabitProgress({
    required String habitId,
    required DateTime date,
    required double amount,
    required String? derivedStatus,
    required int streak,
    bool verdictOnly = false,
  }) async {
    progressCalls.add({
      'habitId': habitId,
      'date': dashboardDateKey(date),
      'amount': amount,
      'derivedStatus': derivedStatus,
    });
  }

  @override
  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) async {
    final next = switch (currentStatus) {
      null => 'done',
      'done' => 'missed',
      _ => null,
    };
    statusCalls.add({
      'habitId': habitId,
      'date': dashboardDateKey(date),
      'status': next,
    });
    return next;
  }
}

void main() {
  // Thu 2026-07-23. Its week (Mon-start) is 07-20 .. 07-26.
  final now = DateTime(2026, 7, 23);
  final limit = TargetPresetCatalog.limitCountDaily.targetWith(amount: 1);
  final count = TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);

  // Preferences must be readable, with the auto-fail anchor backdated, or every
  // count-habit test below would silently run with auto-fail OFF (the anchor
  // read fails without a binding) and prove nothing about the guard it names.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(
        {kAutoFailAnchorPrefKey: '2026-07-01'});
  });

  DashboardHabit habitWith({
    HabitTarget? target,
    VerificationRule? rule,
    DateTime? startDate,
  }) =>
      DashboardHabit(
        id: 'h1',
        title: 'Coffee',
        color: EvolveColors.primaryStrong,
        streak: 0,
        weeklyProgress: const [false, false, false, false, false, false, false],
        state: HabitState.pending,
        startDate: startDate ?? DateTime(2026, 7, 1),
        target: target,
        verificationRule: rule,
      );

  (ProviderContainer, _RecordingRepository) build(
    DashboardSnapshot snapshot,
  ) {
    final repo = _RecordingRepository(snapshot);
    final c = ProviderContainer(overrides: [
      dashboardRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    return (c, repo);
  }

  DashboardSnapshot snap(
    DashboardHabit habit, {
    Map<String, Map<String, String>> logs = const {},
    Map<String, Map<String, double>> progress = const {},
    bool progressStale = false,
  }) =>
      DashboardSnapshot(
        habits: [habit],
        goals: const [],
        trend: const [],
        checkIn: const DailyCheckIn(),
        habitLogs: logs,
        habitProgress: progress,
        progressStale: progressStale,
      );

  group('#1 a degraded goal_progress read must not drive the sweep', () {
    test('a stale snapshot skips the sweep entirely', () async {
      // The exact production shape: goals + logs loaded fine, the goal_progress
      // request failed, so habitProgress is EMPTY but not because the user has
      // no progress. 07-21 is a recorded breach.
      final (c, repo) = build(snap(
        habitWith(target: limit, startDate: DateTime(2026, 7, 20)),
        logs: const {
          '2026-07-21': {'h1': 'missed'},
        },
        progress: const {},
        progressStale: true,
      ));

      await c
          .read(dashboardControllerProvider.notifier)
          .reconcileManualTargets(now: now);

      expect(repo.progressCalls, isEmpty,
          reason: 'the sweep ran against a failed fetch and would have '
              'deleted the real server rows');
      expect(c.read(dashboardControllerProvider).habitLogs['2026-07-21']?['h1'],
          'missed',
          reason: 'a recorded breach must not be flipped to done');
    });

    test('a healthy snapshot still sweeps', () async {
      // The guard must not disable the feature: same data, progressStale false.
      final (c, repo) = build(snap(
        habitWith(target: limit, startDate: DateTime(2026, 7, 21)),
      ));

      await c
          .read(dashboardControllerProvider.notifier)
          .reconcileManualTargets(now: now);

      expect(repo.progressCalls, isNotEmpty,
          reason: 'quiet closed limit days must still resolve to done');
    });

    test('a stale snapshot must not let AUTO-FAIL read absence as zero',
        () async {
      // The same finding, now with the opposite sign. A failed goal_progress
      // fetch leaves every count day looking untouched, and auto-fail's whole
      // premise is that an untouched day means the user did zero. It does not
      // mean that when the number simply never arrived — the 07-21 day below
      // was a completed 80, and the day already carries the 'done' it earned.
      final (c, repo) = build(snap(
        habitWith(target: count, startDate: DateTime(2026, 7, 20)),
        logs: const {
          '2026-07-21': {'h1': 'done'},
        },
        progress: const {},
        progressStale: true,
      ));

      await c
          .read(dashboardControllerProvider.notifier)
          .reconcileManualTargets(now: now);

      expect(repo.progressCalls, isEmpty);
      expect(c.read(dashboardControllerProvider).habitLogs['2026-07-21']?['h1'],
          'done',
          reason: 'an earned day must not be auto-failed because the progress '
              'read failed');
    });
  });

  group('#2 the sweep must not write outside the current week', () {
    test('backfilled days from a previous week leave weeklyProgress alone',
        () async {
      // Habit started 07-13 (previous week). The sweep backfills 07-13..07-22.
      // 07-18 is a Saturday in the PREVIOUS week; index 5 of the current week's
      // grid is Saturday 07-25, which has not happened yet.
      final (c, _) = build(snap(
        habitWith(target: limit, startDate: DateTime(2026, 7, 13)),
      ));

      await c
          .read(dashboardControllerProvider.notifier)
          .reconcileManualTargets(now: now);

      final grid = c.read(dashboardControllerProvider).habits.first.weeklyProgress;
      // Only days inside 07-20..07-26 that were actually swept may be true:
      // Mon 07-20, Tue 07-21, Wed 07-22. Thu(today) onward must stay false.
      expect(grid[3], isFalse, reason: 'Thursday is today and unswept');
      expect(grid[4], isFalse, reason: 'Friday 07-24 has not happened');
      expect(grid[5], isFalse, reason: 'Saturday 07-25 has not happened');
      expect(grid[6], isFalse, reason: 'Sunday 07-26 has not happened');
    });
  });

  group('#3 toggleHabitForDay owns neither verified nor quantitative days', () {
    test('a verified habit is not toggled', () async {
      final (c, repo) = build(snap(
        habitWith(
          rule: const VerificationRule(
            provider: VerificationProvider.healthKit,
            metricKey: 'steps',
            comparator: VerificationComparator.atLeast,
            threshold: 10000,
            unit: VerificationUnit.count,
          ),
        ),
      ));

      await c
          .read(dashboardControllerProvider.notifier)
          .toggleHabitForDay('h1', DateTime(2026, 7, 22));

      expect(repo.statusCalls, isEmpty,
          reason: 'a Mac cannot record the manual-provenance freeze that would '
              'protect this write, so the iPhone reconcile would revert it');
      expect(c.read(dashboardControllerProvider).habitLogs, isEmpty);
    });

    test('a quantitative habit is not toggled', () async {
      final (c, repo) = build(snap(habitWith(target: limit)));

      await c
          .read(dashboardControllerProvider.notifier)
          .toggleHabitForDay('h1', DateTime(2026, 7, 22));

      expect(repo.statusCalls, isEmpty,
          reason: 'the manual-target sweep owns this verdict and would rewrite '
              'it on the next refresh, so the toggle only appears to work');
    });

    test('a plain checkbox habit still toggles', () async {
      final (c, repo) = build(snap(habitWith()));

      await c
          .read(dashboardControllerProvider.notifier)
          .toggleHabitForDay('h1', DateTime(2026, 7, 22));

      expect(repo.statusCalls, isNotEmpty,
          reason: 'the guard must not break ordinary habits');
      expect(c.read(dashboardControllerProvider).habitLogs['2026-07-22']?['h1'],
          'done');
    });
  });
}
