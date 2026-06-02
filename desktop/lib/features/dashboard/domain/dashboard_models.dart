import 'package:flutter/material.dart';

enum HabitState { pending, completed }

enum GoalState { active, completed, failed }

enum GoalType { lifetime, annual, quarterly, monthly, weekly }

enum CalendarViewMode { month, week, year, life }

class DashboardHabit {
  const DashboardHabit({
    required this.id,
    required this.title,
    required this.category,
    required this.color,
    required this.streak,
    required this.weeklyProgress,
    required this.state,
    this.description,
    this.icon,
    this.frequencyDays,
    this.startDate,
    this.endDate,
    this.displayOrder,
    this.reminderTime,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String category;
  final Color color;
  final int streak;
  final List<bool> weeklyProgress;
  final HabitState state;
  final String? description;
  final String? icon;
  final List<int>? frequencyDays;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? displayOrder;
  final String? reminderTime;
  final bool isActive;

  bool isActiveOn(DateTime date) {
    final viewingDate = DateTime(date.year, date.month, date.day);
    final start = startDate == null
        ? null
        : DateTime(startDate!.year, startDate!.month, startDate!.day);
    final end = endDate == null
        ? null
        : DateTime(endDate!.year, endDate!.month, endDate!.day);
    return isActive &&
        (start == null || !start.isAfter(viewingDate)) &&
        (end == null || !end.isBefore(viewingDate));
  }

  DashboardHabit copyWith({
    String? id,
    String? title,
    String? category,
    Color? color,
    int? streak,
    List<bool>? weeklyProgress,
    HabitState? state,
    String? reminderTime,
    bool clearReminder = false,
    bool? isActive,
    String? description,
    String? icon,
    List<int>? frequencyDays,
    DateTime? startDate,
    DateTime? endDate,
    int? displayOrder,
  }) {
    return DashboardHabit(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      color: color ?? this.color,
      streak: streak ?? this.streak,
      weeklyProgress: weeklyProgress ?? this.weeklyProgress,
      state: state ?? this.state,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      frequencyDays: frequencyDays ?? this.frequencyDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      displayOrder: displayOrder ?? this.displayOrder,
      reminderTime: clearReminder ? null : (reminderTime ?? this.reminderTime),
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toRemoteJson() => {
    if (id.isNotEmpty) 'id': id,
    'title': title,
    'description': category,
    if (icon != null) 'icon': icon,
    'color': dashboardColorToHex(color),
    if (frequencyDays != null) 'frequency_days': frequencyDays,
    'start_date': (startDate ?? DateTime.now()).toIso8601String(),
    if (endDate != null) 'end_date': endDate!.toIso8601String(),
    if (displayOrder != null) 'display_order': displayOrder,
    if (reminderTime != null) 'reminder_time': reminderTime,
  };

  factory DashboardHabit.fromRemoteJson(
    Map<String, dynamic> json, {
    required List<bool> weeklyProgress,
    required HabitState state,
    required int streak,
  }) {
    return DashboardHabit(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['description'] as String? ?? 'Generale',
      color: dashboardColorFromHex(json['color'] as String?),
      streak: streak,
      weeklyProgress: weeklyProgress,
      state: state,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      frequencyDays: (json['frequency_days'] as List<dynamic>?)
          ?.map((day) => day as int)
          .toList(),
      startDate: DateTime.tryParse(json['start_date'] as String? ?? ''),
      endDate: DateTime.tryParse(json['end_date'] as String? ?? ''),
      displayOrder: json['display_order'] as int?,
      reminderTime: json['reminder_time'] as String?,
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
    this.type = GoalType.annual,
    this.year,
    this.quarter,
    this.month,
    this.weekNumber,
    this.categoryId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final Color color;
  final double progress;
  final String dueLabel;
  final GoalState state;
  final GoalType type;
  final int? year;
  final int? quarter;
  final int? month;
  final int? weekNumber;
  final String? categoryId;
  final DateTime? createdAt;

  DashboardGoal copyWith({
    String? id,
    String? title,
    String? category,
    Color? color,
    double? progress,
    String? dueLabel,
    GoalState? state,
    GoalType? type,
    int? year,
    int? quarter,
    int? month,
    int? weekNumber,
    bool clearCategory = false,
    bool clearCategoryId = false,
    String? categoryId,
    DateTime? createdAt,
  }) {
    return DashboardGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      category: clearCategory ? '' : (category ?? this.category),
      color: color ?? this.color,
      progress: progress ?? this.progress,
      dueLabel: dueLabel ?? this.dueLabel,
      state: state ?? this.state,
      type: type ?? this.type,
      year: year ?? this.year,
      quarter: quarter ?? this.quarter,
      month: month ?? this.month,
      weekNumber: weekNumber ?? this.weekNumber,
      categoryId: clearCategory || clearCategoryId
          ? null
          : (categoryId ?? this.categoryId),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toRemoteJson() => {
    if (id.isNotEmpty) 'id': id,
    'title': title,
    'status': state.name,
    'type': type.name,
    'year': year,
    'quarter': quarter,
    'month': month,
    'week_number': weekNumber,
    'category_key': category,
    'category_id': categoryId,
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
  };

  factory DashboardGoal.fromRemoteJson(Map<String, dynamic> json) {
    final state = GoalState.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => GoalState.active,
    );
    final type = GoalType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => GoalType.lifetime,
    );
    return DashboardGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category_key'] as String? ?? '',
      color: dashboardGoalColor(json['category_key'] as String?),
      progress: state == GoalState.completed ? 1 : 0,
      dueLabel: dashboardGoalDueLabel(
        type: type,
        year: json['year'] as int?,
        quarter: json['quarter'] as int?,
        month: json['month'] as int?,
        weekNumber: json['week_number'] as int?,
      ),
      state: state,
      type: type,
      year: json['year'] as int?,
      quarter: json['quarter'] as int?,
      month: json['month'] as int?,
      weekNumber: json['week_number'] as int?,
      categoryId: json['category_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
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

  Map<String, dynamic> toJson() => {'mood': mood, 'energy': energy};

  factory DailyCheckIn.fromJson(Map<String, dynamic> json) {
    return DailyCheckIn(
      mood: json['mood'] as int?,
      energy: json['energy'] as int?,
    );
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.habits,
    required this.goals,
    required this.trend,
    required this.checkIn,
    this.habitLogs = const {},
    this.moods = const {},
    this.isRefreshing = false,
    this.errorMessage,
  });

  final List<DashboardHabit> habits;
  final List<DashboardGoal> goals;
  final List<TrendPoint> trend;
  final DailyCheckIn checkIn;
  final Map<String, Map<String, String>> habitLogs;
  final Map<String, DailyCheckIn> moods;
  final bool isRefreshing;
  final String? errorMessage;

  List<DashboardHabit> get todayHabits => habitsFor(DateTime.now());

  int get completedHabits =>
      todayHabits.where((habit) => habit.state == HabitState.completed).length;

  int get totalHabits => todayHabits.length;

  double get completionRate =>
      totalHabits == 0 ? 0 : completedHabits / totalHabits;

  double get currentWeekCompletionRate => _weekCompletionRate(DateTime.now());

  double get previousWeekCompletionRate =>
      _weekCompletionRate(DateTime.now().subtract(const Duration(days: 7)));

  double get weeklyMomentum =>
      currentWeekCompletionRate - previousWeekCompletionRate;

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

  String? habitStatusFor(String habitId, DateTime date) =>
      habitLogs[dashboardDateKey(date)]?[habitId];

  double completionFor(DateTime date) {
    final activeHabits = habitsFor(date);
    if (activeHabits.isEmpty) return 0;
    final done = activeHabits.where((habit) {
      final status = habitStatusFor(habit.id, date);
      if (status != null) return status == 'done';
      return _isDashboardCurrentWeek(date) &&
          habit.weeklyProgress[date.weekday - 1];
    }).length;
    return done / activeHabits.length;
  }

  List<DashboardHabit> habitsFor(DateTime date) =>
      habits.where((habit) => habit.isActiveOn(date)).toList();

  double _weekCompletionRate(DateTime anchor) {
    final monday = DateTime(
      anchor.year,
      anchor.month,
      anchor.day,
    ).subtract(Duration(days: anchor.weekday - 1));
    var done = 0;
    var total = 0;
    for (var day = 0; day < 7; day++) {
      final date = monday.add(Duration(days: day));
      final activeHabits = habitsFor(date);
      total += activeHabits.length;
      done += activeHabits.where((habit) {
        return habitStatusFor(habit.id, date) == 'done';
      }).length;
    }
    return total == 0 ? 0 : done / total;
  }

  DashboardSnapshot copyWith({
    List<DashboardHabit>? habits,
    List<DashboardGoal>? goals,
    List<TrendPoint>? trend,
    DailyCheckIn? checkIn,
    Map<String, Map<String, String>>? habitLogs,
    Map<String, DailyCheckIn>? moods,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardSnapshot(
      habits: habits ?? this.habits,
      goals: goals ?? this.goals,
      trend: trend ?? this.trend,
      checkIn: checkIn ?? this.checkIn,
      habitLogs: habitLogs ?? this.habitLogs,
      moods: moods ?? this.moods,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  static const empty = DashboardSnapshot(
    habits: [],
    goals: [],
    trend: [],
    checkIn: DailyCheckIn(),
  );
}

String dashboardDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

bool _isDashboardCurrentWeek(DateTime date) {
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

String dashboardColorToHex(Color color) {
  final rgb = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
  return '#${rgb.toUpperCase()}';
}

Color dashboardColorFromHex(String? hex) {
  try {
    return Color(int.parse((hex ?? '').replaceFirst('#', 'ff'), radix: 16));
  } catch (_) {
    return const Color(0xFF3B82F6);
  }
}

Color dashboardGoalColor(String? category) => switch (category) {
  'lavoro' => const Color(0xFF3B82F6),
  'salute' => const Color(0xFF10B981),
  'finanza' => const Color(0xFFF59E0B),
  'relazioni' => const Color(0xFFEC4899),
  'formazione' => const Color(0xFF7C3AED),
  'hobby' => const Color(0xFF06B6D4),
  'spirituale' => const Color(0xFFF97316),
  'altro' => const Color(0xFF6B7280),
  _ => const Color(0xFF3B82F6),
};

String dashboardGoalDueLabel({
  required GoalType type,
  int? year,
  int? quarter,
  int? month,
  int? weekNumber,
}) {
  return switch (type) {
    GoalType.lifetime => 'Obiettivo di vita',
    GoalType.annual => year?.toString() ?? 'Obiettivo annuale',
    GoalType.quarterly =>
      quarter == null ? 'Trimestre' : 'Q$quarter ${year ?? ''}',
    GoalType.monthly => month == null ? 'Mese' : '$month/${year ?? ''}',
    GoalType.weekly =>
      weekNumber == null
          ? 'Settimana'
          : 'Settimana $weekNumber, ${month ?? ''}/${year ?? ''}',
  };
}

extension GoalStateLabel on GoalState {
  String get label => switch (this) {
    GoalState.active => 'In corso',
    GoalState.completed => 'Completato',
    GoalState.failed => 'Non completato',
  };
}

extension GoalTypeLabel on GoalType {
  String get label => switch (this) {
    GoalType.lifetime => 'Vita',
    GoalType.annual => 'Annuale',
    GoalType.quarterly => 'Trimestrale',
    GoalType.monthly => 'Mensile',
    GoalType.weekly => 'Settimanale',
  };
}

extension CalendarViewModeLabel on CalendarViewMode {
  String get label => switch (this) {
    CalendarViewMode.month => 'Mese',
    CalendarViewMode.week => 'Settimana',
    CalendarViewMode.year => 'Anno',
    CalendarViewMode.life => 'Vita',
  };
}
