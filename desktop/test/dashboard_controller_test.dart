import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toggling a habit updates the desktop dashboard snapshot', () async {
    final container = ProviderContainer();
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
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(dashboardControllerProvider.notifier)
        .updateCheckIn(mood: 72, energy: 64);

    final checkIn = container.read(dashboardControllerProvider).checkIn;
    expect(checkIn.mood, 72);
    expect(checkIn.energy, 64);
    expect(checkIn.isComplete, isTrue);
  });
}
