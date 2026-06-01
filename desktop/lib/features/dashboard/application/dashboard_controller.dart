import 'dart:async';
import 'dart:math';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardSnapshot>(
      DashboardController.new,
    );

class DashboardController extends Notifier<DashboardSnapshot> {
  DashboardRepository get _repository => ref.read(dashboardRepositoryProvider);

  @override
  DashboardSnapshot build() {
    final repository = ref.watch(dashboardRepositoryProvider);
    final snapshot = repository.load();
    if (repository.isCloudBacked) {
      unawaited(Future<void>.microtask(refresh));
    }
    return snapshot;
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final snapshot = await _repository.refresh();
      state = snapshot.copyWith(isRefreshing: false, clearError: true);
    } catch (error, stack) {
      AppLogger.error('Unable to refresh dashboard state', error, stack);
      final cachedSnapshot = error is DashboardRefreshException
          ? error.cachedSnapshot
          : null;
      state = (cachedSnapshot ?? state).copyWith(
        isRefreshing: false,
        errorMessage: 'Sincronizzazione non riuscita. Dati locali mantenuti.',
      );
    }
  }

  Future<void> toggleHabit(String id) async {
    await toggleHabitForDay(id, DateTime.now());
  }

  Future<void> toggleHabitForDay(String id, DateTime date) async {
    final dateKey = dashboardDateKey(date);
    final weekdayIndex = date.weekday - 1;
    final currentStatus =
        state.habitStatusFor(id, date) ??
        ((_isToday(date)
                ? state.habits.firstWhere((habit) => habit.id == id).state ==
                      HabitState.completed
                : _isCurrentWeek(date) &&
                      state.habits
                          .firstWhere((habit) => habit.id == id)
                          .weeklyProgress[weekdayIndex])
            ? 'done'
            : null);
    final nextStatus = _nextHabitStatus(currentStatus);
    final logs = {
      for (final entry in state.habitLogs.entries)
        entry.key: Map<String, String>.from(entry.value),
    };
    final dayLogs = logs.putIfAbsent(dateKey, () => {});
    if (nextStatus == null) {
      dayLogs.remove(id);
    } else {
      dayLogs[id] = nextStatus;
    }
    final habits = [
      for (final habit in state.habits)
        if (habit.id == id)
          _setHabitForWeekday(
            habit,
            weekdayIndex,
            _isToday(date),
            nextStatus == 'done',
          )
        else
          habit,
    ];
    state = state.copyWith(habits: habits, habitLogs: logs);
    await _saveLocal();
    await _syncRemote(
      () => _repository.setHabitStatus(
        habitId: id,
        date: date,
        currentStatus: currentStatus,
      ),
    );
  }

  Future<void> addHabit({
    required String title,
    required String category,
    required Color color,
    String? reminderTime,
  }) async {
    final draft = DashboardHabit(
      id: _newLocalId(),
      title: title,
      category: category,
      color: color,
      streak: 0,
      weeklyProgress: const [false, false, false, false, false, false, false],
      state: HabitState.pending,
      reminderTime: reminderTime,
      startDate: DateTime.now(),
    );
    state = state.copyWith(habits: [...state.habits, draft]);
    await _saveLocal();
    try {
      final habit = await _repository.createHabit(draft);
      state = state.copyWith(
        habits: [
          for (final item in state.habits)
            if (item.id == draft.id) habit else item,
        ],
      );
      await _saveLocal();
    } catch (error, stack) {
      _recordSyncError('Unable to sync the new habit', error, stack);
    }
  }

  Future<void> updateHabit({
    required String id,
    required String title,
    required String category,
    required Color color,
    String? reminderTime,
  }) async {
    final habits = [
      for (final habit in state.habits)
        if (habit.id == id)
          habit.copyWith(
            title: title,
            category: category,
            color: color,
            reminderTime: reminderTime,
            clearReminder: reminderTime == null,
          )
        else
          habit,
    ];
    state = state.copyWith(habits: habits);
    await _saveLocal();
    await _syncRemote(
      () =>
          _repository.updateHabit(habits.firstWhere((habit) => habit.id == id)),
    );
  }

  Future<void> deleteHabit(String id) async {
    state = state.copyWith(
      habits: state.habits.where((habit) => habit.id != id).toList(),
    );
    await _saveLocal();
    await _syncRemote(() => _repository.deleteHabit(id));
  }

  Future<void> updateCheckIn({required int mood, required int energy}) async {
    final checkIn = DailyCheckIn(mood: mood, energy: energy);
    final moods = Map<String, DailyCheckIn>.from(state.moods)
      ..[dashboardDateKey(DateTime.now())] = checkIn;
    state = state.copyWith(checkIn: checkIn, moods: moods);
    await _saveLocal();
    await _syncRemote(() => _repository.saveCheckIn(DateTime.now(), checkIn));
  }

  Future<void> completeGoal(String id) async {
    await updateGoalState(id, GoalState.completed);
  }

  Future<void> addGoal({
    required String title,
    required String category,
    required Color color,
    required GoalType type,
    required String dueLabel,
    String? categoryId,
  }) async {
    final now = DateTime.now();
    final draft = DashboardGoal(
      id: _newLocalId(),
      title: title,
      category: category,
      color: color,
      progress: 0,
      dueLabel: dueLabel,
      type: type,
      categoryId: categoryId,
      year: type == GoalType.lifetime ? null : now.year,
      quarter: type == GoalType.quarterly ? ((now.month - 1) ~/ 3) + 1 : null,
      month: type == GoalType.monthly || type == GoalType.weekly
          ? now.month
          : null,
      weekNumber: type == GoalType.weekly ? ((now.day - 1) ~/ 7) + 1 : null,
      createdAt: now,
    );
    await _createGoalOptimistically(draft);
  }

  Future<void> updateGoalState(String id, GoalState goalState) async {
    final goals = [
      for (final goal in state.goals)
        if (goal.id == id)
          goal.copyWith(
            state: goalState,
            progress: goalState == GoalState.completed ? 1 : goal.progress,
          )
        else
          goal,
    ];
    state = state.copyWith(goals: goals);
    await _saveLocal();
    await _syncRemote(
      () => _repository.updateGoal(goals.firstWhere((goal) => goal.id == id)),
    );
  }

  Future<void> rescheduleGoal(String id) async {
    final goal = state.goals.firstWhere((goal) => goal.id == id);
    if (goal.type == GoalType.lifetime) return;

    await updateGoalState(id, GoalState.failed);
    final next = _nextGoalPeriod(goal);
    final draft = goal.copyWith(
      id: _newLocalId(),
      state: GoalState.active,
      progress: 0,
      dueLabel: dashboardGoalDueLabel(
        type: goal.type,
        year: next.year,
        quarter: next.quarter,
        month: next.month,
        weekNumber: next.weekNumber,
      ),
      year: next.year,
      quarter: next.quarter,
      month: next.month,
      weekNumber: next.weekNumber,
      createdAt: DateTime.now(),
    );
    await _createGoalOptimistically(draft);
  }

  Future<void> deleteGoal(String id) async {
    state = state.copyWith(
      goals: state.goals.where((goal) => goal.id != id).toList(),
    );
    await _saveLocal();
    await _syncRemote(() => _repository.deleteGoal(id));
  }

  Future<void> _createGoalOptimistically(DashboardGoal draft) async {
    state = state.copyWith(goals: [...state.goals, draft]);
    await _saveLocal();
    try {
      final goal = await _repository.createGoal(draft);
      state = state.copyWith(
        goals: [
          for (final item in state.goals)
            if (item.id == draft.id) goal else item,
        ],
      );
      await _saveLocal();
    } catch (error, stack) {
      _recordSyncError('Unable to sync the new macro goal', error, stack);
    }
  }

  Future<void> _saveLocal() async {
    try {
      await _repository.save(state);
    } catch (error, stack) {
      AppLogger.error('Unable to save the local dashboard cache', error, stack);
    }
  }

  Future<void> _syncRemote(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      _recordSyncError('Unable to sync dashboard mutation', error, stack);
    }
  }

  void _recordSyncError(String message, Object error, StackTrace stack) {
    AppLogger.error(message, error, stack);
    state = state.copyWith(
      errorMessage:
          'Modifica salvata localmente. Sincronizzazione da riprovare.',
    );
  }

  String? _nextHabitStatus(String? currentStatus) {
    return switch (currentStatus) {
      null => 'done',
      'done' => 'missed',
      _ => null,
    };
  }

  String _newLocalId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  DashboardHabit _setHabitForWeekday(
    DashboardHabit habit,
    int weekdayIndex,
    bool updateToday,
    bool completed,
  ) {
    final progress = [...habit.weeklyProgress];
    progress[weekdayIndex] = completed;

    return habit.copyWith(
      weeklyProgress: progress,
      state: updateToday
          ? (completed ? HabitState.completed : HabitState.pending)
          : habit.state,
      streak: completed
          ? habit.streak + 1
          : (habit.streak > 0 ? habit.streak - 1 : 0),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isCurrentWeek(DateTime date) {
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(monday) && !normalized.isAfter(sunday);
  }

  _GoalPeriod _nextGoalPeriod(DashboardGoal goal) {
    var year = goal.year ?? DateTime.now().year;
    var month = goal.month ?? DateTime.now().month;
    var quarter = goal.quarter ?? ((month - 1) ~/ 3) + 1;
    var weekNumber = goal.weekNumber ?? ((DateTime.now().day - 1) ~/ 7) + 1;

    switch (goal.type) {
      case GoalType.lifetime:
        break;
      case GoalType.annual:
        year++;
      case GoalType.quarterly:
        if (quarter < 4) {
          quarter++;
        } else {
          year++;
          quarter = 1;
        }
        month = (quarter - 1) * 3 + 1;
      case GoalType.monthly:
        if (month < 12) {
          month++;
        } else {
          year++;
          month = 1;
        }
        quarter = ((month - 1) ~/ 3) + 1;
      case GoalType.weekly:
        final maximumWeek = (DateUtils.getDaysInMonth(year, month) / 7).ceil();
        if (weekNumber < maximumWeek) {
          weekNumber++;
        } else if (month < 12) {
          month++;
          weekNumber = 1;
        } else {
          year++;
          month = 1;
          weekNumber = 1;
        }
        quarter = ((month - 1) ~/ 3) + 1;
    }

    return _GoalPeriod(
      year: year,
      quarter: quarter,
      month: month,
      weekNumber: weekNumber,
    );
  }
}

class _GoalPeriod {
  const _GoalPeriod({
    required this.year,
    required this.quarter,
    required this.month,
    required this.weekNumber,
  });

  final int year;
  final int quarter;
  final int month;
  final int weekNumber;
}
