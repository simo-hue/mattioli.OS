import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardSnapshot>(
      DashboardController.new,
    );

class DashboardController extends Notifier<DashboardSnapshot> {
  DashboardRepository get _repository => ref.read(dashboardRepositoryProvider);

  @override
  DashboardSnapshot build() => ref.watch(dashboardRepositoryProvider).load();

  Future<void> toggleHabit(String id) async {
    final habits = [
      for (final habit in state.habits)
        if (habit.id == id)
          habit.copyWith(
            state: habit.state == HabitState.completed
                ? HabitState.pending
                : HabitState.completed,
          )
        else
          habit,
    ];
    state = state.copyWith(habits: habits);
    await _repository.save(state);
  }

  Future<void> updateCheckIn({required int mood, required int energy}) async {
    state = state.copyWith(
      checkIn: DailyCheckIn(mood: mood, energy: energy),
    );
    await _repository.save(state);
  }

  Future<void> completeGoal(String id) async {
    final goals = [
      for (final goal in state.goals)
        if (goal.id == id)
          goal.copyWith(state: GoalState.completed, progress: 1)
        else
          goal,
    ];
    state = state.copyWith(goals: goals);
    await _repository.save(state);
  }
}
