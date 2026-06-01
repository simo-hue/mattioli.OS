import 'package:flutter/material.dart';

enum HabitState { pending, completed }

enum GoalState { active, completed }

class DashboardHabit {
  const DashboardHabit({
    required this.id,
    required this.title,
    required this.category,
    required this.color,
    required this.streak,
    required this.weeklyProgress,
    required this.state,
  });

  final String id;
  final String title;
  final String category;
  final Color color;
  final int streak;
  final List<bool> weeklyProgress;
  final HabitState state;

  DashboardHabit copyWith({HabitState? state}) {
    return DashboardHabit(
      id: id,
      title: title,
      category: category,
      color: color,
      streak: streak,
      weeklyProgress: weeklyProgress,
      state: state ?? this.state,
    );
  }
}

class DashboardGoal {
  const DashboardGoal({
    required this.id,
    required this.title,
    required this.category,
    required this.color,
    required this.progress,
    required this.dueLabel,
    this.state = GoalState.active,
  });

  final String id;
  final String title;
  final String category;
  final Color color;
  final double progress;
  final String dueLabel;
  final GoalState state;

  DashboardGoal copyWith({GoalState? state, double? progress}) {
    return DashboardGoal(
      id: id,
      title: title,
      category: category,
      color: color,
      progress: progress ?? this.progress,
      dueLabel: dueLabel,
      state: state ?? this.state,
    );
  }
}

class TrendPoint {
  const TrendPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class DailyCheckIn {
  const DailyCheckIn({this.mood, this.energy});

  final int? mood;
  final int? energy;

  bool get isComplete => mood != null && energy != null;

  DailyCheckIn copyWith({int? mood, int? energy}) {
    return DailyCheckIn(mood: mood ?? this.mood, energy: energy ?? this.energy);
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.habits,
    required this.goals,
    required this.trend,
    required this.checkIn,
  });

  final List<DashboardHabit> habits;
  final List<DashboardGoal> goals;
  final List<TrendPoint> trend;
  final DailyCheckIn checkIn;

  int get completedHabits =>
      habits.where((habit) => habit.state == HabitState.completed).length;

  int get totalHabits => habits.length;

  double get completionRate =>
      totalHabits == 0 ? 0 : completedHabits / totalHabits;

  int get activeGoals =>
      goals.where((goal) => goal.state == GoalState.active).length;

  int get bestStreak {
    if (habits.isEmpty) return 0;
    return habits.map((habit) => habit.streak).reduce((a, b) => a > b ? a : b);
  }

  double get averageGoalProgress {
    if (goals.isEmpty) return 0;
    final total = goals.fold<double>(0, (sum, goal) => sum + goal.progress);
    return total / goals.length;
  }

  DashboardSnapshot copyWith({
    List<DashboardHabit>? habits,
    List<DashboardGoal>? goals,
    DailyCheckIn? checkIn,
  }) {
    return DashboardSnapshot(
      habits: habits ?? this.habits,
      goals: goals ?? this.goals,
      trend: trend,
      checkIn: checkIn ?? this.checkIn,
    );
  }
}
