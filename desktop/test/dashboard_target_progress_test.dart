// Desktop counterpart of the mobile habit_progress_notifier_test: the
// DashboardController.setHabitProgressForDay path — it stores the day's number
// AND derives the verdict (goal_logs) through TargetVerdict.logStatus, keeping
// the progress map and the verdict map in step. Runs over a recording fake
// repository, so no Supabase / private DB is touched.

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  }) async {
    progressCalls.add({
      'habitId': habitId,
      'amount': amount,
      'derivedStatus': derivedStatus,
      'streak': streak,
    });
  }
}

void main() {
  final count = TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);
  final limit = TargetPresetCatalog.limitCountDaily.targetWith(amount: 1);
  final now = DateTime(2026, 7, 24);
  const pastDay = '2026-07-10';

  (ProviderContainer, _RecordingRepository) build(DashboardHabit habit) {
    final repo = _RecordingRepository(_snapshotWith(habit));
    final container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
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

    test('does not invent misses for an untouched count habit', () async {
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

      await controller.reconcileManualTargets(now: now);
      final afterFirst = repo.progressCalls.length;
      await controller.reconcileManualTargets(now: now);

      expect(repo.progressCalls.length, afterFirst);
    });
  });
}
