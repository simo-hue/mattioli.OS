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
  });

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
    final colorStr = json['color'] as String? ?? '#6B7280';
    final archivedAtStr = json['archived_at'] as String?;
    return GoalCategory(
      key: json['id'] as String,
      label: json['name'] as String,
      color: Color(int.parse(colorStr.replaceAll('#', '0xFF'))),
      archivedAt: archivedAtStr == null ? null : DateTime.parse(archivedAtStr),
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
