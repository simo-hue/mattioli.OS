import 'package:flutter/material.dart';

enum GoalType { lifetime, annual, quarterly, monthly, weekly }

enum GoalStatus { active, completed, failed }

/// Mirrors the web app's `LongTermGoal` interface
class MacroGoal {
  final String id;
  final String title;
  final GoalStatus status;
  final GoalType type;
  final int? year;
  final int? quarter; // 1-4
  final int? month; // 1-12
  final int? weekNumber; // 1-6 (logical week of month)
  final String? categoryKey; // e.g. 'red', 'blue', 'lavoro', etc.
  final String? categoryId; // UUID for custom categories
  final DateTime createdAt;

  // ── Cumulative numeric macro goals (private schema v10) ──
  /// The optional numeric target ("500 km", "24 books"). Null ⇒ an ordinary
  /// boolean macro goal (active/completed/failed, no numbers) — every macro
  /// goal that existed before this feature.
  final double? targetAmount;

  /// The unit [targetAmount] is expressed in, stored as a `TargetUnit` wire name
  /// (count/minutes/hours/kilocalories/kilometers). Kept as a raw string, not a
  /// typed enum, so a unit added by a newer client round-trips through this build
  /// verbatim rather than being dropped — the same forward-compat posture as the
  /// habit `target` blob.
  final String? targetUnit;

  /// The STORED progress value for a MANUAL-entry numeric goal (no
  /// [linkedGoalId]). When a habit is linked, progress is DERIVED from that
  /// habit and this field is ignored for display — but it is also the snapshot
  /// slot the delete/unlink path writes the derived total into, so an unlinked
  /// goal keeps the value it had reached.
  final double? progressAmount;

  /// The habit (goals.id) whose daily `goal_progress` feeds this macro goal.
  /// Null ⇒ a manual-entry numeric goal (progress read from [progressAmount]).
  final String? linkedGoalId;

  const MacroGoal({
    required this.id,
    required this.title,
    required this.status,
    required this.type,
    this.year,
    this.quarter,
    this.month,
    this.weekNumber,
    this.categoryKey,
    this.categoryId,
    required this.createdAt,
    this.targetAmount,
    this.targetUnit,
    this.progressAmount,
    this.linkedGoalId,
  });

  /// Whether this macro goal carries a numeric target (vs a plain boolean one).
  bool get hasNumericTarget => targetAmount != null;

  /// Whether progress is DERIVED from a linked habit (vs STORED manually).
  bool get isLinked => linkedGoalId != null;

  MacroGoal copyWith({
    String? id,
    String? title,
    GoalStatus? status,
    GoalType? type,
    int? year,
    int? quarter,
    int? month,
    int? weekNumber,
    String? categoryKey,
    String? categoryId,
    bool clearCategory = false,
    DateTime? createdAt,
    double? targetAmount,
    String? targetUnit,
    double? progressAmount,
    String? linkedGoalId,
    // Reverts to an ordinary boolean goal: nulls the target, unit, stored
    // progress AND the link in one operation.
    bool clearTarget = false,
    // Breaks the habit link without touching the target — pass a snapshot via
    // [progressAmount] so the derived value survives as a manual one.
    bool clearLink = false,
  }) {
    return MacroGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      type: type ?? this.type,
      year: year ?? this.year,
      quarter: quarter ?? this.quarter,
      month: month ?? this.month,
      weekNumber: weekNumber ?? this.weekNumber,
      categoryKey: clearCategory ? null : (categoryKey ?? this.categoryKey),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
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

  factory MacroGoal.fromJson(Map<String, dynamic> json) {
    return MacroGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      status: GoalStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GoalStatus.active,
      ),
      type: GoalType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GoalType.lifetime,
      ),
      year: json['year'] as int?,
      quarter: json['quarter'] as int?,
      month: json['month'] as int?,
      weekNumber: json['week_number'] as int?,
      categoryKey: json['category_key'] as String?,
      categoryId: json['category_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      targetAmount: (json['target_amount'] as num?)?.toDouble(),
      targetUnit: json['target_unit'] as String?,
      progressAmount: (json['progress_amount'] as num?)?.toDouble(),
      linkedGoalId: json['linked_goal_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      'status': status.name,
      'type': type.name,
      'year': year,
      'quarter': quarter,
      'month': month,
      'week_number': weekNumber,
      'category_key': categoryKey,
      'category_id': categoryId,
      'created_at': createdAt.toIso8601String(),
      // The numeric-target columns are emitted ONLY when set, exactly like the
      // habit `target` column. This keeps a plain boolean macro goal's payload
      // free of them so a cloud insert keeps working on a project whose Supabase
      // `long_term_goals` predates the 20260724 target migration — the feature
      // ships dark, so only boolean goals exist until that migration lands.
      if (targetAmount != null) 'target_amount': targetAmount,
      if (targetUnit != null) 'target_unit': targetUnit,
      if (progressAmount != null) 'progress_amount': progressAmount,
      if (linkedGoalId != null) 'linked_goal_id': linkedGoalId,
    };
  }
}

/// A goal category with a display label and color
class GoalCategory {
  final String key;
  final String label;
  final Color color;
  final DateTime? archivedAt;

  const GoalCategory({
    required this.key,
    required this.label,
    required this.color,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  factory GoalCategory.fromJson(Map<String, dynamic> json) {
    // Categories are read back through an eager `rows.map(...).toList()`, so a
    // single unparseable value would throw for the WHOLE list and empty every
    // picker. Mirrors the guarded parse in `Goal.fromJson`.
    Color parseColor(String hexString) {
      try {
        return Color(int.parse(hexString.replaceAll('#', '0xFF')));
      } catch (_) {
        return const Color(0xFF6B7280);
      }
    }

    final colorStr = json['color'] as String? ?? '#6B7280';
    final archivedAtStr = json['archived_at'] as String?;
    return GoalCategory(
      key: json['id'] as String,
      label: json['name'] as String,
      color: parseColor(colorStr),
      archivedAt: archivedAtStr == null ? null : DateTime.tryParse(archivedAtStr),
    );
  }
}

/// Default categories (mock — same semantics as web app)
const List<GoalCategory> kDefaultCategories = [
  GoalCategory(key: 'lavoro', label: 'Lavoro', color: Color(0xFF3B82F6)),
  GoalCategory(key: 'salute', label: 'Salute', color: Color(0xFF10B981)),
  GoalCategory(key: 'finanza', label: 'Finanza', color: Color(0xFFF59E0B)),
  GoalCategory(key: 'relazioni', label: 'Relazioni', color: Color(0xFFEC4899)),
  GoalCategory(
    key: 'formazione',
    label: 'Formazione',
    color: Color(0xFF7C3AED),
  ),
  GoalCategory(key: 'hobby', label: 'Hobby', color: Color(0xFF06B6D4)),
  GoalCategory(
    key: 'spirituale',
    label: 'Spirituale',
    color: Color(0xFFF97316),
  ),
  GoalCategory(key: 'altro', label: 'Altro', color: Color(0xFF6B7280)),
];

Color? categoryColor(String? key) {
  if (key == null) return null;
  try {
    return kDefaultCategories.firstWhere((c) => c.key == key).color;
  } catch (_) {
    return null;
  }
}

String? categoryLabel(String? key) {
  if (key == null) return null;
  try {
    return kDefaultCategories.firstWhere((c) => c.key == key).label;
  } catch (_) {
    return key;
  }
}
