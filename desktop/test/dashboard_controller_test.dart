import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';

void main() {
  // These tests assert on the Italian UI copy, so pin the slang locale to
  // Italian (base locale is English). `setLocale` is async — slang lazy-loads
  // the deferred locale library.
  setUp(() => LocaleSettings.setLocale(AppLocale.it));
  test('toggling a habit updates the desktop dashboard snapshot', () async {
    final container = _testContainer(snapshot: _singleHabitSnapshot());
    addTearDown(container.dispose);

    final initial = container.read(dashboardControllerProvider);
    final habit = initial.habits.first;

    await container
        .read(dashboardControllerProvider.notifier)
        .toggleHabit(habit.id);

    final updated = container.read(dashboardControllerProvider);
    final updatedHabit = updated.habits.firstWhere(
      (item) => item.id == habit.id,
    );
    final expected = habit.state == HabitState.completed
        ? HabitState.pending
        : HabitState.completed;

    expect(updatedHabit.state, expected);
  });

  test('daily check-in persists mood and energy in state', () async {
    final container = _testContainer();
    addTearDown(container.dispose);

    await container
        .read(dashboardControllerProvider.notifier)
        .updateCheckIn(mood: 72, energy: 64);

    final checkIn = container.read(dashboardControllerProvider).checkIn;
    expect(checkIn.mood, 72);
    expect(checkIn.energy, 64);
    expect(checkIn.isComplete, isTrue);
  });

  test('habit management supports create update and delete', () async {
    final container = _testContainer();
    addTearDown(container.dispose);
    final controller = container.read(dashboardControllerProvider.notifier);

    await controller.addHabit(
      title: 'Passeggiata serale',
      category: 'Salute',
      color: EvolveColors.cyan,
      reminderTime: '19:00',
    );

    var habit = container
        .read(dashboardControllerProvider)
        .habits
        .lastWhere((item) => item.title == 'Passeggiata serale');
    expect(habit.reminderTime, '19:00');

    await controller.updateHabit(
      id: habit.id,
      title: 'Passeggiata',
      category: 'Benessere',
      color: EvolveColors.primaryStrong,
    );

    habit = container
        .read(dashboardControllerProvider)
        .habits
        .firstWhere((item) => item.id == habit.id);
    expect(habit.title, 'Passeggiata');
    expect(habit.category, 'Benessere');
    expect(habit.reminderTime, isNull);

    await controller.deleteHabit(habit.id);
    expect(
      container
          .read(dashboardControllerProvider)
          .habits
          .where((item) => item.id == habit.id),
      isEmpty,
    );
  });

  test(
    'goal lifecycle supports create fail reschedule complete and delete',
    () async {
      final container = _testContainer();
      addTearDown(container.dispose);
      final controller = container.read(dashboardControllerProvider.notifier);

      await controller.addGoal(
        title: 'Preparare la demo',
        category: 'Lavoro',
        color: EvolveColors.violet,
        type: GoalType.weekly,
        dueLabel: 'Settimana corrente',
      );

      var goal = container
          .read(dashboardControllerProvider)
          .goals
          .lastWhere((item) => item.title == 'Preparare la demo');
      expect(goal.type, GoalType.weekly);

      await controller.updateGoalState(goal.id, GoalState.failed);
      goal = container
          .read(dashboardControllerProvider)
          .goals
          .firstWhere((item) => item.id == goal.id);
      expect(goal.state, GoalState.failed);

      await controller.rescheduleGoal(goal.id);
      final failedGoal = container
          .read(dashboardControllerProvider)
          .goals
          .firstWhere((item) => item.id == goal.id);
      expect(failedGoal.state, GoalState.failed);
      goal = container
          .read(dashboardControllerProvider)
          .goals
          .lastWhere((item) => item.title == 'Preparare la demo');
      expect(goal.state, GoalState.active);
      expect(goal.id, isNot(failedGoal.id));

      await controller.completeGoal(goal.id);
      goal = container
          .read(dashboardControllerProvider)
          .goals
          .firstWhere((item) => item.id == goal.id);
      expect(goal.state, GoalState.completed);
      expect(goal.progress, 1);

      await controller.deleteGoal(goal.id);
      expect(
        container
            .read(dashboardControllerProvider)
            .goals
            .where((item) => item.id == goal.id),
        isEmpty,
      );
    },
  );

  test('habit day state cycles through done missed and empty', () async {
    final snapshot = DashboardSnapshot(
      habits: [
        DashboardHabit(
          id: 'walk',
          title: 'Passeggiata',
          category: 'Salute',
          color: EvolveColors.primaryStrong,
          streak: 0,
          weeklyProgress: const [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
          ],
          state: HabitState.pending,
        ),
      ],
      goals: const [],
      trend: const [],
      checkIn: const DailyCheckIn(),
    );
    final repository = _TestDashboardRepository(snapshot);
    final container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(dashboardControllerProvider.notifier);
    final today = DateTime.now();

    await controller.toggleHabitForDay('walk', today);
    expect(
      container.read(dashboardControllerProvider).habitStatusFor('walk', today),
      'done',
    );
    await controller.toggleHabitForDay('walk', today);
    expect(
      container.read(dashboardControllerProvider).habitStatusFor('walk', today),
      'missed',
    );
    await controller.toggleHabitForDay('walk', today);
    expect(
      container.read(dashboardControllerProvider).habitStatusFor('walk', today),
      isNull,
    );
  });

  test('reorderHabits moves a habit and reassigns display order', () async {
    DashboardHabit habit(String id, int order) => DashboardHabit(
      id: id,
      title: id,
      category: 'Cat',
      color: EvolveColors.primaryStrong,
      streak: 0,
      weeklyProgress: const [false, false, false, false, false, false, false],
      state: HabitState.pending,
      displayOrder: order,
    );
    final snapshot = DashboardSnapshot(
      habits: [habit('a', 0), habit('b', 1), habit('c', 2)],
      goals: const [],
      trend: const [],
      checkIn: const DailyCheckIn(),
    );
    final repository = _TestDashboardRepository(snapshot);
    final container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(dashboardControllerProvider.notifier);

    // Move 'a' (index 0) to the end (onReorderItem target index 2).
    await controller.reorderHabits(0, 2);

    final habits = container.read(dashboardControllerProvider).habits;
    expect(habits.map((h) => h.id).toList(), ['b', 'c', 'a']);
    // display_order reassigned to the new positions.
    expect(habits.map((h) => h.displayOrder).toList(), [0, 1, 2]);
    // Persisted to the repository in the new order.
    expect(repository.lastReorder?.map((h) => h.id).toList(), ['b', 'c', 'a']);
  });

  test('historical completion uses stored logs without synthetic fallback', () {
    final loggedDate = DateTime(2025, 1, 10);
    final missingDate = DateTime(2025, 1, 11);
    final snapshot = DashboardSnapshot(
      habits: [
        DashboardHabit(
          id: 'read',
          title: 'Leggere',
          category: 'Formazione',
          color: EvolveColors.violet,
          streak: 1,
          weeklyProgress: const [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
          ],
          state: HabitState.pending,
        ),
      ],
      goals: const [],
      trend: const [],
      checkIn: const DailyCheckIn(),
      habitLogs: {
        '2025-01-10': {'read': 'done'},
      },
    );

    expect(snapshot.completionFor(loggedDate), 1);
    expect(snapshot.completionFor(missingDate), 0);
  });

  test('historical completion ignores habits outside their active range', () {
    final beforeStart = DateTime(2025, 1, 9);
    final firstActiveDay = DateTime(2025, 1, 10);
    final snapshot = DashboardSnapshot(
      habits: [
        DashboardHabit(
          id: 'read',
          title: 'Leggere',
          category: 'Formazione',
          color: EvolveColors.violet,
          streak: 1,
          weeklyProgress: const [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
          ],
          state: HabitState.pending,
          startDate: firstActiveDay,
        ),
      ],
      goals: const [],
      trend: const [],
      checkIn: const DailyCheckIn(),
      habitLogs: {
        '2025-01-09': {'read': 'done'},
        '2025-01-10': {'read': 'done'},
      },
    );

    expect(snapshot.habitsFor(beforeStart), isEmpty);
    expect(snapshot.completionFor(beforeStart), 0);
    expect(snapshot.completionFor(firstActiveDay), 1);
  });

  test('today summary ignores habits outside their active range', () {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final snapshot = DashboardSnapshot(
      habits: [
        const DashboardHabit(
          id: 'active',
          title: 'Attiva',
          category: 'Salute',
          color: EvolveColors.cyan,
          streak: 1,
          weeklyProgress: [true, true, true, true, true, true, true],
          state: HabitState.completed,
        ),
        DashboardHabit(
          id: 'future',
          title: 'Futura',
          category: 'Salute',
          color: EvolveColors.cyan,
          streak: 0,
          weeklyProgress: const [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
          ],
          state: HabitState.pending,
          startDate: tomorrow,
        ),
      ],
      goals: const [],
      trend: const [],
      checkIn: const DailyCheckIn(),
    );

    expect(snapshot.todayHabits.map((habit) => habit.id), ['active']);
    expect(snapshot.completedHabits, 1);
    expect(snapshot.totalHabits, 1);
    expect(snapshot.completionRate, 1);
  });

  test(
    'goal creation and updates retain selected period and custom category',
    () async {
      final repository = _TestDashboardRepository(DashboardSnapshot.empty);
      final container = ProviderContainer(
        overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(dashboardControllerProvider.notifier);

      await controller.addGoal(
        title: 'Preparare la retrospettiva',
        category: 'lavoro',
        color: EvolveColors.cyan,
        type: GoalType.weekly,
        dueLabel: 'Settimana 5, Maggio 2026',
        year: 2026,
        month: 5,
        weekNumber: 5,
      );
      var goal = container.read(dashboardControllerProvider).goals.single;
      expect(goal.year, 2026);
      expect(goal.month, 5);
      expect(goal.weekNumber, 5);

      await controller.updateGoal(
        id: goal.id,
        title: goal.title,
        category: '',
        categoryId: 'custom-category',
        color: EvolveColors.rose,
      );
      goal = container.read(dashboardControllerProvider).goals.single;
      expect(goal.category, isEmpty);
      expect(goal.categoryId, 'custom-category');

      await controller.rescheduleGoal(goal.id);
      final rescheduled = container
          .read(dashboardControllerProvider)
          .goals
          .lastWhere((item) => item.id != goal.id);
      expect(rescheduled.month, 6);
      expect(rescheduled.weekNumber, 1);
      expect(rescheduled.categoryId, 'custom-category');
    },
  );

  test('offline habit creation keeps a syncable optimistic draft', () async {
    final repository = _OfflineDashboardRepository();
    final container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container
        .read(dashboardControllerProvider.notifier)
        .addHabit(
          title: 'Lettura serale',
          category: 'Formazione',
          color: EvolveColors.violet,
        );

    final snapshot = container.read(dashboardControllerProvider);
    final habit = snapshot.habits.single;
    expect(habit.title, 'Lettura serale');
    expect(
      habit.id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(snapshot.errorMessage, contains('Sincronizzazione da riprovare'));
    expect(repository.load().habits.single.id, habit.id);
  });

  test('reset data clears the dashboard repository and controller', () async {
    final repository = _TestDashboardRepository(DashboardSnapshot.empty);
    final container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(dashboardControllerProvider.notifier).resetData();

    expect(container.read(dashboardControllerProvider).habits, isEmpty);
    expect(container.read(dashboardControllerProvider).goals, isEmpty);
    expect(repository.load().habits, isEmpty);
  });

  test(
    'offline refresh exposes cached data and keeps the sync warning',
    () async {
      final repository = _CachedOfflineDashboardRepository();
      final container = ProviderContainer(
        overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container.read(dashboardControllerProvider.notifier).refresh();

      final snapshot = container.read(dashboardControllerProvider);
      expect(snapshot.habits.single.title, 'Cache cifrata');
      expect(snapshot.errorMessage, contains('Dati locali mantenuti'));
      expect(snapshot.isRefreshing, isFalse);
    },
  );

  test('weekly momentum is derived from synchronized habit logs', () {
    final now = DateTime.now();
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final previousMonday = thisMonday.subtract(const Duration(days: 7));
    final snapshot = DashboardSnapshot(
      habits: [
        DashboardHabit(
          id: 'walk',
          title: 'Passeggiata',
          category: 'Salute',
          color: EvolveColors.primaryStrong,
          streak: 0,
          weeklyProgress: const [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
          ],
          state: HabitState.pending,
          startDate: previousMonday,
        ),
      ],
      goals: const [],
      trend: const [],
      checkIn: const DailyCheckIn(),
      habitLogs: {
        dashboardDateKey(previousMonday): {'walk': 'done'},
        dashboardDateKey(thisMonday): {'walk': 'done'},
        dashboardDateKey(thisMonday.add(const Duration(days: 1))): {
          'walk': 'done',
        },
      },
    );

    expect(snapshot.currentWeekCompletionRate, closeTo(2 / 7, 0.0001));
    expect(snapshot.previousWeekCompletionRate, closeTo(1 / 7, 0.0001));
    expect(snapshot.weeklyMomentum, closeTo(1 / 7, 0.0001));
  });
}

ProviderContainer _testContainer({DashboardSnapshot? snapshot}) {
  return ProviderContainer(
    overrides: [
      dashboardRepositoryProvider.overrideWithValue(
        _TestDashboardRepository(snapshot ?? DashboardSnapshot.empty),
      ),
    ],
  );
}

DashboardSnapshot _singleHabitSnapshot() {
  return DashboardSnapshot(
    habits: const [
      DashboardHabit(
        id: 'walk',
        title: 'Passeggiata',
        category: 'Salute',
        color: EvolveColors.primaryStrong,
        streak: 0,
        weeklyProgress: [false, false, false, false, false, false, false],
        state: HabitState.pending,
      ),
    ],
    goals: const [],
    trend: const [],
    checkIn: const DailyCheckIn(),
  );
}

class _TestDashboardRepository extends DashboardRepository {
  _TestDashboardRepository(this._snapshot);

  DashboardSnapshot _snapshot;

  /// Records the last order persisted via [reorderHabits].
  List<DashboardHabit>? lastReorder;

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<void> reorderHabits(List<DashboardHabit> habits) async {
    lastReorder = habits;
  }

  @override
  Future<void> resetData() async {
    _snapshot = DashboardSnapshot.empty;
  }
}

class _OfflineDashboardRepository extends DashboardRepository {
  DashboardSnapshot _snapshot = DashboardSnapshot.empty;

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<DashboardHabit> createHabit(DashboardHabit habit) {
    throw const SocketException('Network is unreachable');
  }
}

class _CachedOfflineDashboardRepository extends DashboardRepository {
  final DashboardSnapshot _cached = DashboardSnapshot(
    habits: const [
      DashboardHabit(
        id: 'cached',
        title: 'Cache cifrata',
        category: 'Sistema',
        color: EvolveColors.primaryStrong,
        streak: 0,
        weeklyProgress: [false, false, false, false, false, false, false],
        state: HabitState.pending,
      ),
    ],
    goals: const [],
    trend: const [],
    checkIn: const DailyCheckIn(),
  );

  @override
  DashboardSnapshot load() => DashboardSnapshot.empty;

  @override
  Future<DashboardSnapshot> refresh() {
    throw DashboardRefreshException(
      cachedSnapshot: _cached,
      cause: const SocketException('Network is unreachable'),
    );
  }

  @override
  Future<void> save(DashboardSnapshot snapshot) async {}
}
