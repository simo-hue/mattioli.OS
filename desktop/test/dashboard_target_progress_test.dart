// Desktop counterpart of the mobile habit_progress_notifier_test: the
// DashboardController.setHabitProgressForDay path — it stores the day's number
// AND derives the verdict (goal_logs) through TargetVerdict.logStatus, keeping
// the progress map and the verdict map in step. Runs over a recording fake
// repository, so no Supabase / private DB is touched.

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/clock.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DashboardHabit _habit({required HabitTarget target}) => DashboardHabit(
      id: 'h1',
      title: 'Push-ups',
      color: EvolveColors.primaryStrong,
      streak: 0,
      weeklyProgress: const [false, false, false, false, false, false, false],
      state: HabitState.pending,
      startDate: DateTime(2026, 7, 1),
      target: target,
    );

/// Waits out the unawaited `reconcileManualTargets()` tail that `refresh()`
/// fires when the controller is first read. Long enough to cover the async
/// preference read the auto-fail anchor now performs.
Future<void> _drainBackgroundSweep() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

DashboardSnapshot _snapshotWith(DashboardHabit habit) => DashboardSnapshot(
      habits: [habit],
      goals: const [],
      trend: const [],
      checkIn: const DailyCheckIn(),
    );

class _RecordingRepository extends DashboardRepository {
  _RecordingRepository(this._snapshot);
  DashboardSnapshot _snapshot;
  final List<Map<String, Object?>> progressCalls = [];

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _snapshot = snapshot;
  }

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
      'streak': streak,
      'verdictOnly': verdictOnly,
    });
  }
}

void main() {
  final count = TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);
  final limit = TargetPresetCatalog.limitCountDaily.targetWith(amount: 1);
  final now = DateTime(2026, 7, 24);

  // Preferences are readable in every test here, so no test's result depends on
  // the anchor read happening to FAIL — the auto-fail group below re-seeds a
  // backdated anchor, and everything else runs as a fresh install (anchor
  // stamped at `now`, nothing earlier in reach).
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const {});
  });

  (ProviderContainer, _RecordingRepository) build(DashboardHabit habit) {
    final repo = _RecordingRepository(_snapshotWith(habit));
    final container = ProviderContainer(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(repo),
        // Pin the clock. Without this the suite is a time bomb: building the
        // controller fires an unawaited refresh(), whose tail fires an
        // unawaited reconcileManualTargets() that this test never calls and so
        // cannot pass `now:` to. That sweep read the real wall clock, agreed
        // with [now] only on 2026-07-24, and from 2026-07-25 resolved 07-24 as
        // a CLOSED day — overwriting the verdicts asserted below.
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return (container, repo);
  }

  test('a partial count on an OPEN day stores the number, no verdict', () async {
    final (container, repo) = build(_habit(target: count));
    final controller = container.read(dashboardControllerProvider.notifier);

    await controller.setHabitProgressForDay(
        'h1', DateTime(2026, 7, 24), 40, now: now);

    final state = container.read(dashboardControllerProvider);
    expect(state.habitProgressFor('h1', DateTime(2026, 7, 24)), 40);
    expect(state.habitStatusFor('h1', DateTime(2026, 7, 24)), isNull);
    expect(repo.progressCalls.single['derivedStatus'], isNull);
  });

  test('reaching a count target derives a done verdict', () async {
    final (container, repo) = build(_habit(target: count));
    final controller = container.read(dashboardControllerProvider.notifier);

    await controller.setHabitProgressForDay(
        'h1', DateTime(2026, 7, 24), 80, now: now);

    final state = container.read(dashboardControllerProvider);
    expect(state.habitProgressFor('h1', DateTime(2026, 7, 24)), 80);
    expect(state.habitStatusFor('h1', DateTime(2026, 7, 24)), 'done');
    expect(state.habits.first.state, HabitState.completed);
    expect(repo.progressCalls.single['derivedStatus'], 'done');
  });

  test('a partial count on a CLOSED day is an honest miss', () async {
    final (container, repo) = build(_habit(target: count));
    final controller = container.read(dashboardControllerProvider.notifier);

    await controller.setHabitProgressForDay(
        'h1', DateTime(2026, 7, 10), 40, now: now);

    final state = container.read(dashboardControllerProvider);
    expect(state.habitStatusFor('h1', DateTime(2026, 7, 10)), 'missed');
    expect(repo.progressCalls.single['derivedStatus'], 'missed');
  });

  test('a closed limit day under the cap resolves to done', () async {
    final (container, _) = build(_habit(target: limit));
    final controller = container.read(dashboardControllerProvider.notifier);

    await controller.setHabitProgressForDay(
        'h1', DateTime(2026, 7, 10), 1, now: now);

    expect(
      container
          .read(dashboardControllerProvider)
          .habitStatusFor('h1', DateTime(2026, 7, 10)),
      'done',
    );
  });

  test('exceeding a limit derives a missed verdict', () async {
    final (container, _) = build(_habit(target: limit));
    final controller = container.read(dashboardControllerProvider.notifier);

    await controller.setHabitProgressForDay(
        'h1', DateTime(2026, 7, 10), 2, now: now);

    expect(
      container
          .read(dashboardControllerProvider)
          .habitStatusFor('h1', DateTime(2026, 7, 10)),
      'missed',
    );
  });

  test('a limit day today stays pending (not green from breakfast)', () async {
    final (container, _) = build(_habit(target: limit));
    final controller = container.read(dashboardControllerProvider.notifier);

    await controller.setHabitProgressForDay(
        'h1', DateTime(2026, 7, 24), 0, now: now);

    expect(
      container
          .read(dashboardControllerProvider)
          .habitStatusFor('h1', DateTime(2026, 7, 24)),
      isNull,
    );
  });

  test('returning to zero clears the number and re-derives the verdict', () async {
    final (container, repo) = build(_habit(target: count));
    final controller = container.read(dashboardControllerProvider.notifier);

    await controller.setHabitProgressForDay('h1', DateTime(2026, 7, 10), 80,
        now: now);
    expect(
      container
          .read(dashboardControllerProvider)
          .habitStatusFor('h1', DateTime(2026, 7, 10)),
      'done',
    );

    await controller.setHabitProgressForDay('h1', DateTime(2026, 7, 10), 0,
        now: now);
    final state = container.read(dashboardControllerProvider);
    expect(state.habitProgressFor('h1', DateTime(2026, 7, 10)), isNull);
    // 0 on a closed atLeast day is unmet → 'missed', not cleared.
    expect(state.habitStatusFor('h1', DateTime(2026, 7, 10)), 'missed');
    expect(repo.progressCalls.last['amount'], 0.0);
  });

  test('a measured (non-enterable) target is a no-op here', () async {
    final measured = count.copyWith(fillSource: TargetFillSource.healthKit);
    final (container, repo) = build(_habit(target: measured));
    final controller = container.read(dashboardControllerProvider.notifier);

    await controller.setHabitProgressForDay(
        'h1', DateTime(2026, 7, 24), 40, now: now);

    // Nothing entered — a HealthKit ring is filled by the verification pipeline,
    // never by this path.
    expect(repo.progressCalls, isEmpty);
    expect(
      container
          .read(dashboardControllerProvider)
          .habitProgressFor('h1', DateTime(2026, 7, 24)),
      isNull,
    );
  });

  group('reconcileManualTargets (end-of-day sweep)', () {
    test('materialises a limit habit\'s quiet closed days on macOS', () async {
      final habit = _habit(target: limit).copyWith(startDate: DateTime(2026, 7, 21));
      final (container, _) = build(habit);
      final controller = container.read(dashboardControllerProvider.notifier);

      await controller.reconcileManualTargets(now: now);

      final state = container.read(dashboardControllerProvider);
      expect(state.habitStatusFor('h1', DateTime(2026, 7, 21)), 'done');
      expect(state.habitStatusFor('h1', DateTime(2026, 7, 22)), 'done');
      expect(state.habitStatusFor('h1', DateTime(2026, 7, 23)), 'done');
      // today stays pending
      expect(state.habitStatusFor('h1', DateTime(2026, 7, 24)), isNull);
    });

    test('does not invent misses for days that closed BEFORE the anchor',
        () async {
      // Fresh install: the sweep stamps the anchor at today, so every day that
      // closed before the rule existed is out of reach.
      final habit = _habit(target: count).copyWith(startDate: DateTime(2026, 7, 20));
      final (container, repo) = build(habit);
      final controller = container.read(dashboardControllerProvider.notifier);

      await controller.reconcileManualTargets(now: now);

      expect(repo.progressCalls, isEmpty);
    });

    test('is idempotent — a second pass writes nothing new', () async {
      final habit = _habit(target: limit).copyWith(startDate: DateTime(2026, 7, 22));
      final (container, repo) = build(habit);
      final controller = container.read(dashboardControllerProvider.notifier);
      // Reading the notifier fires refresh(), whose unawaited tail runs its own
      // sweep. Let it finish before counting: otherwise it lands between the two
      // passes below and reads as a non-idempotent write that never happened.
      await _drainBackgroundSweep();
      repo.progressCalls.clear();

      await controller.reconcileManualTargets(now: now);
      final afterFirst = repo.progressCalls.length;
      await controller.reconcileManualTargets(now: now);

      expect(repo.progressCalls.length, afterFirst);
    });
  });

  group('auto-fail for untouched count days (macOS)', () {
    // Preferences are real here — the anchor is what decides how far the rule
    // reaches, so it has to be readable for any of this to mean anything.
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(
          {kAutoFailAnchorPrefKey: '2026-07-01'});
    });

    test('an untouched count day at/after the anchor resolves to missed',
        () async {
      final habit =
          _habit(target: count).copyWith(startDate: DateTime(2026, 7, 21));
      final (container, _) = build(habit);
      final controller = container.read(dashboardControllerProvider.notifier);

      await controller.reconcileManualTargets(now: now);

      final state = container.read(dashboardControllerProvider);
      expect(state.habitStatusFor('h1', DateTime(2026, 7, 21)), 'missed');
      expect(state.habitStatusFor('h1', DateTime(2026, 7, 22)), 'missed');
      expect(state.habitStatusFor('h1', DateTime(2026, 7, 23)), 'missed');
      // Today is still open.
      expect(state.habitStatusFor('h1', DateTime(2026, 7, 24)), isNull);
    });

    test('auto-fail writes the verdict ONLY — goal_progress is never touched',
        () async {
      final habit =
          _habit(target: count).copyWith(startDate: DateTime(2026, 7, 23));
      final (container, repo) = build(habit);
      // Reading the notifier fires refresh(), whose unawaited tail runs the
      // sweep — the production path. Let it complete and assert on what it did,
      // rather than racing it with an explicit second call.
      container.read(dashboardControllerProvider.notifier);
      await _drainBackgroundSweep();

      final call = repo.progressCalls
          .singleWhere((c) => c['date'] == '2026-07-23');
      expect(call['verdictOnly'], isTrue,
          reason: 'a day with no number must not be written through the '
              'progress path, where amount 0 means DELETE');
      expect(call['derivedStatus'], 'missed');
      expect(container.read(dashboardControllerProvider)
              .habitProgressFor('h1', DateTime(2026, 7, 23)),
          isNull);
    });

    test('a verdict-only write leaves a REAL number in the map alone', () async {
      // The assertion above cannot fail: the day never had a number, so the
      // delete path and the verdict-only path are indistinguishable on it. The
      // guard exists for the case where the map is NOT empty — drive it
      // directly, because that is the only way to see the branch do work.
      final habit =
          _habit(target: count).copyWith(startDate: DateTime(2026, 7, 1));
      final (container, repo) = build(habit);
      final controller = container.read(dashboardControllerProvider.notifier);
      final day = DateTime(2026, 7, 10);
      await controller.setHabitProgressForDay('h1', day, 40, now: now);
      expect(container.read(dashboardControllerProvider)
              .habitProgressFor('h1', day), 40);

      await controller.setHabitProgressForDay('h1', day, 0,
          now: now, verdictOnly: true);

      expect(container.read(dashboardControllerProvider)
              .habitProgressFor('h1', day), 40,
          reason: 'a verdict-only write must never remove a stored count — '
              'that is the entire reason the flag exists');
      expect(repo.progressCalls.last['verdictOnly'], isTrue);
    });

    test('a verified habit is never auto-failed (one owner per habit-day)',
        () async {
      // Parity with mobile: "couldn't verify" is not "you failed", and the
      // verification pipeline owns this habit's goal_logs.
      // Driven EXPLICITLY, with a positive control first. Asserting "no writes"
      // after a timed drain also passes when the sweep never ran at all — and
      // this one additionally passed on the strength of a second, independent
      // guard inside setHabitProgressForDay, so it proved neither the guard it
      // names nor that anything happened.
      final plain =
          _habit(target: count).copyWith(startDate: DateTime(2026, 7, 21));
      final (control, controlRepo) = build(plain);
      await control
          .read(dashboardControllerProvider.notifier)
          .reconcileManualTargets(now: now);
      expect(controlRepo.progressCalls, isNotEmpty,
          reason: 'the control must auto-fail, or the assertion below is '
              'satisfied by a sweep that simply did nothing');

      final habit = _habit(target: count).copyWith(
        startDate: DateTime(2026, 7, 21),
        verificationRule: VerificationCatalog.steps.ruleWith(10000),
      );
      final (container, repo) = build(habit);
      await container
          .read(dashboardControllerProvider.notifier)
          .reconcileManualTargets(now: now);

      expect(repo.progressCalls, isEmpty);
      expect(
        container
            .read(dashboardControllerProvider)
            .habitStatusFor('h1', DateTime(2026, 7, 22)),
        isNull,
      );
    });

    test('the tile shows TODAY\'s streak, not the last swept day\'s', () async {
      // Auto-fail Mon–Thu, complete today: the card must not read 💔4 for a
      // habit finished an hour ago. The row keeps the swept day's streak; the
      // tile is always today's.
      final habit =
          _habit(target: count).copyWith(startDate: DateTime(2026, 7, 20));
      final (container, _) = build(habit);
      final controller = container.read(dashboardControllerProvider.notifier);
      await controller.setHabitProgressForDay(
          'h1', DateTime(2026, 7, 24), 80, now: now); // today, done
      await controller.reconcileManualTargets(now: now);

      final tile = container.read(dashboardControllerProvider).habits.first;
      expect(tile.streak, greaterThan(0),
          reason: 'a habit completed today must not show a negative streak '
              'because the sweep last touched an older, failed day');
    });

    test('a habit removed mid-sweep does not abandon the remaining changes',
        () async {
      // The applier resolves each change against live state; a pull that drops a
      // habit between computing and applying used to throw StateError out of
      // firstWhere and skip every change after it.
      final habit =
          _habit(target: count).copyWith(startDate: DateTime(2026, 7, 21));
      final (container, _) = build(habit);
      final controller = container.read(dashboardControllerProvider.notifier);

      await expectLater(
        controller.setHabitProgressForDay(
            'does-not-exist', DateTime(2026, 7, 22), 0, now: now),
        completes,
      );
    });

    test('logging the number afterwards reverses an auto-failed day', () async {
      // Parity with mobile: auto-fail is never a trap. The verdict-only write
      // must leave the progress map in a state a later real edit builds on.
      final habit =
          _habit(target: count).copyWith(startDate: DateTime(2026, 7, 23));
      final (container, _) = build(habit);
      final controller = container.read(dashboardControllerProvider.notifier);
      await _drainBackgroundSweep();
      expect(
        container
            .read(dashboardControllerProvider)
            .habitStatusFor('h1', DateTime(2026, 7, 23)),
        'missed',
      );

      await controller.setHabitProgressForDay(
          'h1', DateTime(2026, 7, 23), 80, now: now);

      final state = container.read(dashboardControllerProvider);
      expect(state.habitStatusFor('h1', DateTime(2026, 7, 23)), 'done');
      expect(state.habitProgressFor('h1', DateTime(2026, 7, 23)), 80);
    });

    test('is idempotent — a second auto-fail pass writes nothing new', () async {
      final habit =
          _habit(target: count).copyWith(startDate: DateTime(2026, 7, 22));
      final (container, repo) = build(habit);
      final controller = container.read(dashboardControllerProvider.notifier);
      // The refresh() tail's sweep IS the first pass; let it land, then run a
      // second one explicitly and check nothing further is written.
      await _drainBackgroundSweep();
      final afterFirst = repo.progressCalls.length;
      expect(afterFirst, greaterThan(0),
          reason: 'the first sweep must actually auto-fail something, or this '
              'test proves nothing');

      await controller.reconcileManualTargets(now: now);

      expect(repo.progressCalls.length, afterFirst);
    });

    test('a fresh install stamps the anchor and spares earlier history',
        () async {
      SharedPreferences.setMockInitialValues(const {}); // undo this group's seed
      final habit =
          _habit(target: count).copyWith(startDate: DateTime(2026, 7, 20));
      final (container, repo) = build(habit);
      final controller = container.read(dashboardControllerProvider.notifier);

      await controller.reconcileManualTargets(now: now);

      expect(repo.progressCalls, isEmpty,
          reason: 'days that closed before the rule existed must render '
              'exactly as the user last saw them');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kAutoFailAnchorPrefKey), '2026-07-24');
    });
  });
}
