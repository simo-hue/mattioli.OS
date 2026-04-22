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
  final int? weekNumber; // 1-5 (logical week of month)
  final String? categoryKey; // e.g. 'red', 'blue', 'lavoro', etc.
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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// A goal category with a display label and color
class GoalCategory {
  final String key;
  final String label;
  final Color color;

  const GoalCategory({
    required this.key,
    required this.label,
    required this.color,
  });
}

/// Default categories (mock — same semantics as web app)
const List<GoalCategory> kDefaultCategories = [
  GoalCategory(key: 'lavoro', label: 'Lavoro', color: Color(0xFF3B82F6)),
  GoalCategory(key: 'salute', label: 'Salute', color: Color(0xFF10B981)),
  GoalCategory(key: 'finanza', label: 'Finanza', color: Color(0xFFF59E0B)),
  GoalCategory(key: 'relazioni', label: 'Relazioni', color: Color(0xFFEC4899)),
  GoalCategory(key: 'formazione', label: 'Formazione', color: Color(0xFF7C3AED)),
  GoalCategory(key: 'hobby', label: 'Hobby', color: Color(0xFF06B6D4)),
  GoalCategory(key: 'spirituale', label: 'Spirituale', color: Color(0xFFF97316)),
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
