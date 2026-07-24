import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';

enum HabitState { pending, completed }

enum GoalState { active, completed, failed }

enum GoalType { lifetime, annual, quarterly, monthly, weekly }

enum CalendarViewMode { month, week, year, life }

class DashboardHabit {
  const DashboardHabit({
    required this.id,
    required this.title,
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
    this.verificationRule,
    this.verifyEffectiveFrom,
    this.additionalConditions,
    this.verificationJoin,
    this.target,
    this.rawTargetBlob,
    this.isActive = true,
  });

  final String id;
  final String title;
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

  /// Auto-verification rule (null ⇒ manual habit). macOS never verifies — this
  /// is carried through reads/writes so a desktop edit can't wipe a rule set on
  /// iOS, and so the UI can show a read-only "auto-verified" badge.
  final VerificationRule? verificationRule;

  /// The day the current [verificationRule] took effect (D10). Carried through
  /// reads/writes for the same reason as [verificationRule] — a desktop edit
  /// must not drop it — even though macOS never runs reconcile itself.
  final DateTime? verifyEffectiveFrom;

  /// Extra conditions (2nd, 3rd) of a compound verifiable habit, joined by
  /// [verificationJoin] (Q1–Q5). Null/empty ⇒ an ordinary single-rule habit
  /// ([verificationRule] is the whole rule). When set, [verificationRule] is the
  /// first condition. Persisted via the `verify_conditions` JSON column; the flat
  /// `verify_*` columns are then null. macOS never verifies — carried through so
  /// a desktop edit can't wipe a compound rule set on iOS.
  final List<VerificationRule>? additionalConditions;

  /// How a compound habit's conditions combine (Q1). Null for a single-rule or
  /// manual habit.
  final VerificationJoin? verificationJoin;

  /// The quantitative daily target (count / duration / limit), or null for an
  /// ordinary boolean habit or a target this build cannot decode (see
  /// [rawTargetBlob]). Persisted via the `goals.target` JSON column.
  final HabitTarget? target;

  /// The raw `goals.target` value exactly as stored, kept so a target written by
  /// a NEWER client (one whose axis values this build can't decode, so [target]
  /// is null) is written back verbatim on an unrelated edit instead of being
  /// nulled. Same forward-compat guard as mobile's `Goal.rawTargetBlob`.
  final String? rawTargetBlob;

  final bool isActive;

  /// Whether this habit carries a target this build can read.
  bool get hasTarget => target != null;

  /// The target to DISPLAY: an explicit manual [target] wins, else a single
  /// verification rule projects into one (so a verified threshold and a manual
  /// count render as the same ring). Null for a plain or compound-verified habit.
  HabitTarget? get displayTarget =>
      displayTargetFor(ownTarget: target, conditions: verificationConditions);

  /// The value to write to the `goals.target` column: the live target encoded,
  /// else a preserved unreadable blob verbatim, else null. Shared by every write
  /// path so they cannot disagree about what an undecodable target round-trips to.
  String? get targetColumnValue {
    if (target != null) return target!.encode();
    if (hasUnreadableTarget(rawTargetBlob)) return rawTargetBlob;
    return null;
  }

  /// All verification conditions in order — [verificationRule] (if any) followed
  /// by [additionalConditions]. Empty for a manual habit, length 1 for a single
  /// rule, 2..3 for a compound habit.
  List<VerificationRule> get verificationConditions => [
    ?verificationRule,
    ...?additionalConditions,
  ];

  /// Whether this habit combines more than one verification condition (Q4/Q5).
  bool get isCompoundVerified =>
      additionalConditions != null && additionalConditions!.isNotEmpty;

  /// Whether the habit's active *range* covers [date] (start ≤ date ≤ end),
  /// ignoring the weekly schedule. Use [isScheduledOn] for day-view display.
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

  /// Whether the habit should actually appear on [date]: inside its active
  /// range AND scheduled for that weekday. `frequencyDays == null`/empty means
  /// "every day", matching the shared `frequency_days` convention. Every
  /// day-scoped list ([DashboardSnapshot.habitsFor]) uses this so an off-day
  /// habit is hidden rather than shown-and-uncompletable.
  bool isScheduledOn(DateTime date) {
    if (!isActiveOn(date)) return false;
    final freq = frequencyDays;
    if (freq == null || freq.isEmpty) return true;
    return freq.contains(date.weekday);
  }

  DashboardHabit copyWith({
    String? id,
    String? title,
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
    bool clearFrequencyDays = false,
    DateTime? startDate,
    DateTime? endDate,
    int? displayOrder,
    VerificationRule? verificationRule,
    bool clearVerificationRule = false,
    DateTime? verifyEffectiveFrom,
    bool clearVerifyEffectiveFrom = false,
    List<VerificationRule>? additionalConditions,
    bool clearAdditionalConditions = false,
    VerificationJoin? verificationJoin,
    bool clearVerificationJoin = false,
    HabitTarget? target,
    bool clearTarget = false,
  }) {
    return DashboardHabit(
      id: id ?? this.id,
      title: title ?? this.title,
      color: color ?? this.color,
      streak: streak ?? this.streak,
      weeklyProgress: weeklyProgress ?? this.weeklyProgress,
      state: state ?? this.state,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      frequencyDays: clearFrequencyDays
          ? null
          : (frequencyDays ?? this.frequencyDays),
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      displayOrder: displayOrder ?? this.displayOrder,
      reminderTime: clearReminder ? null : (reminderTime ?? this.reminderTime),
      verificationRule: clearVerificationRule
          ? null
          : (verificationRule ?? this.verificationRule),
      verifyEffectiveFrom: clearVerifyEffectiveFrom
          ? null
          : (verifyEffectiveFrom ?? this.verifyEffectiveFrom),
      additionalConditions: clearAdditionalConditions
          ? null
          : (additionalConditions ?? this.additionalConditions),
      verificationJoin: clearVerificationJoin
          ? null
          : (verificationJoin ?? this.verificationJoin),
      // A new target supersedes any preserved raw blob; clearing wipes both; a
      // copy touching neither preserves an unreadable newer-client target.
      target: clearTarget ? null : (target ?? this.target),
      rawTargetBlob:
          clearTarget ? null : (target != null ? null : rawTargetBlob),
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toRemoteJson() => {
    if (id.isNotEmpty) 'id': id,
    'title': title,
    'description': description,
    if (icon != null) 'icon': icon,
    'color': dashboardColorToHex(color),
    if (frequencyDays != null) 'frequency_days': frequencyDays,
    'start_date': (startDate ?? DateTime.now()).toIso8601String(),
    if (endDate != null) 'end_date': endDate!.toIso8601String(),
    if (displayOrder != null) 'display_order': displayOrder,
    if (reminderTime != null) 'reminder_time': reminderTime,
    // Only for verified goals — keeps manual-habit writes independent of whether
    // the Supabase verify_* migration has been applied yet. Single rule → flat
    // verify_* columns; compound → verify_conditions JSON with the flat columns
    // nulled (Q4).
    if (verificationRule != null)
      ...verificationColumnsFor(
        verificationConditions,
        verificationJoin ?? VerificationJoin.or,
      ),
    // The rule's effective-from day (D10), date-only to match the Supabase
    // `date` column. Carried even though macOS never reconciles.
    if (verificationRule != null && verifyEffectiveFrom != null)
      'verify_effective_from':
          verifyEffectiveFrom!.toIso8601String().substring(0, 10),
    // The quantitative target. Emitted only when there is something to write, so
    // a plain habit's payload stays free of the column (independent of the v9
    // migration). NOTE: an UPDATE leaves omitted columns untouched, so a write
    // path that must be able to CLEAR a target force-writes `targetColumnValue`
    // explicitly rather than relying on this (see SupabaseDashboardRepository).
    if (targetColumnValue != null) 'target': targetColumnValue,
  };

  factory DashboardHabit.fromRemoteJson(
    Map<String, dynamic> json, {
    required List<bool> weeklyProgress,
    required HabitState state,
    required int streak,
  }) {
    // Read precedence (Q4): a compound habit's `verify_conditions` JSON wins;
    // otherwise the flat `verify_*` columns describe a single rule (or a manual
    // habit when both are absent).
    final verification = readVerificationColumns(json);
    final conditions = verification?.conditions ?? const <VerificationRule>[];
    return DashboardHabit(
      id: json['id'] as String,
      title: json['title'] as String,
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
      verificationRule: conditions.isEmpty ? null : conditions.first,
      additionalConditions:
          conditions.length > 1 ? conditions.sublist(1) : null,
      verificationJoin: conditions.length > 1 ? verification!.op : null,
      verifyEffectiveFrom:
          DateTime.tryParse(json['verify_effective_from'] as String? ?? ''),
      target: decodeHabitTarget(json['target']),
      rawTargetBlob: json['target'] as String?,
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
    this.targetAmount,
    this.targetUnit,
    this.progressAmount,
    this.linkedGoalId,
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

  // ── Cumulative numeric macro goals (private schema v10) ──
  /// The optional numeric target ("500 km", "24 books"). Null ⇒ an ordinary
  /// boolean macro goal (the only kind that existed before this feature). This
  /// is distinct from [progress], which stays the derived 0-or-1 completion the
  /// dashboard already averages; the numeric fraction is computed on demand from
  /// these fields via `package:evolve_targets`.
  final double? targetAmount;

  /// [targetAmount]'s unit as a `TargetUnit` wire name, kept as a raw string so
  /// a unit from a newer client round-trips verbatim (forward-compat, like the
  /// habit `target` blob).
  final String? targetUnit;

  /// STORED progress for a manual-entry numeric goal; ignored for display while
  /// [linkedGoalId] is set (progress is then derived from the linked habit), but
  /// it is the snapshot slot written on unlink/delete.
  final double? progressAmount;

  /// The habit (goals.id) whose daily `goal_progress` feeds this macro goal.
  /// Null ⇒ a manual-entry numeric goal.
  final String? linkedGoalId;

  /// Whether this macro goal carries a numeric target (vs a plain boolean one).
  bool get hasNumericTarget => targetAmount != null;

  /// Whether progress is DERIVED from a linked habit (vs STORED manually).
  bool get isLinked => linkedGoalId != null;

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
    double? targetAmount,
    String? targetUnit,
    double? progressAmount,
    String? linkedGoalId,
    // Reverts to an ordinary boolean goal (nulls target, unit, progress, link).
    bool clearTarget = false,
    // Breaks the habit link only — pass a snapshot via [progressAmount].
    bool clearLink = false,
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
      targetAmount: clearTarget ? null : (targetAmount ?? this.targetAmount),
      targetUnit: clearTarget ? null : (targetUnit ?? this.targetUnit),
      progressAmount:
          clearTarget ? null : (progressAmount ?? this.progressAmount),
      linkedGoalId: clearTarget || clearLink
          ? null
          : (linkedGoalId ?? this.linkedGoalId),
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
    // Numeric-target columns emitted ONLY when set — like the habit `target`
    // column — so a plain boolean macro goal's payload stays free of them and a
    // cloud insert keeps working before the 20260724 macro-target migration
    // lands. The feature ships dark, so only boolean goals exist until then.
    if (targetAmount != null) 'target_amount': targetAmount,
    if (targetUnit != null) 'target_unit': targetUnit,
    if (progressAmount != null) 'progress_amount': progressAmount,
    if (linkedGoalId != null) 'linked_goal_id': linkedGoalId,
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
      targetAmount: (json['target_amount'] as num?)?.toDouble(),
      targetUnit: json['target_unit'] as String?,
      progressAmount: (json['progress_amount'] as num?)?.toDouble(),
      linkedGoalId: json['linked_goal_id'] as String?,
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
    this.habitProgress = const {},
    this.moods = const {},
    this.isRefreshing = false,
    this.errorMessage,
  });

  final List<DashboardHabit> habits;
  final List<DashboardGoal> goals;
  final List<TrendPoint> trend;
  final DailyCheckIn checkIn;
  final Map<String, Map<String, String>> habitLogs;

  /// `dateKey -> habitId -> accumulated amount` for quantitative habits — the
  /// parallel of [habitLogs] for the `goal_progress` table. Kept SEPARATE (a
  /// partial day has a number but no verdict) so the many `== 'done'` readers of
  /// [habitLogs] never had to change.
  final Map<String, Map<String, double>> habitProgress;

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

  /// The accumulated progress number for a habit-day, or null if none recorded.
  double? habitProgressFor(String habitId, DateTime date) =>
      habitProgress[dashboardDateKey(date)]?[habitId];

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
      habits.where((habit) => habit.isScheduledOn(date)).toList();

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
    Map<String, Map<String, double>>? habitProgress,
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
      habitProgress: habitProgress ?? this.habitProgress,
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
    GoalType.lifetime => t.dueLabel.lifetime,
    GoalType.annual => year?.toString() ?? t.dueLabel.annual,
    GoalType.quarterly =>
      quarter == null ? t.dueLabel.quarter : 'Q$quarter ${year ?? ''}',
    GoalType.monthly =>
      month == null ? t.common.calendarView.month : '$month/${year ?? ''}',
    GoalType.weekly =>
      weekNumber == null
          ? t.common.calendarView.week
          : '${t.common.calendarView.week} $weekNumber, ${month ?? ''}/${year ?? ''}',
  };
}

extension GoalStateLabel on GoalState {
  String get label => switch (this) {
    GoalState.active => t.goalState.active,
    GoalState.completed => t.statistics.completed2,
    GoalState.failed => t.statistics.notCompleted,
  };
}

extension GoalTypeLabel on GoalType {
  String get label => switch (this) {
    GoalType.lifetime => t.common.calendarView.life,
    GoalType.annual => t.macroGoals.types.annual,
    GoalType.quarterly => t.macroGoals.types.quarterly,
    GoalType.monthly => t.macroGoals.types.monthly,
    GoalType.weekly => t.macroGoals.types.weekly,
  };
}

extension CalendarViewModeLabel on CalendarViewMode {
  String get label => switch (this) {
    CalendarViewMode.month => t.common.calendarView.month,
    CalendarViewMode.week => t.common.calendarView.week,
    CalendarViewMode.year => t.common.calendarView.year,
    CalendarViewMode.life => t.common.calendarView.life,
  };
}
