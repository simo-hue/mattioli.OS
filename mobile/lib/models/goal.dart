import 'package:flutter/material.dart';

class Goal {
  final String id;
  final String title;
  final String? description;
  final String? icon;
  final Color color;
  final List<int>? frequencyDays;
  final DateTime startDate;
  final DateTime? endDate;
  final int? displayOrder;

  const Goal({
    required this.id,
    required this.title,
    this.description,
    this.icon,
    required this.color,
    this.frequencyDays,
    required this.startDate,
    this.endDate,
    this.displayOrder,
  });

  /// Checks if the habit should be visible on a specific date.
  bool isActiveOn(DateTime date) {
    // Normalize both to date-only at midnight local time for comparison
    final viewingDate = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    
    if (start.isAfter(viewingDate)) return false;
    
    if (endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (end.isBefore(viewingDate)) return false;
    }
    
    return true;
  }

  Goal copyWith({
    String? id,
    String? title,
    String? description,
    bool clearDescription = false,
    String? icon,
    bool clearIcon = false,
    Color? color,
    List<int>? frequencyDays,
    bool clearFrequency = false,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    int? displayOrder,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      icon: clearIcon ? null : (icon ?? this.icon),
      color: color ?? this.color,
      frequencyDays: clearFrequency ? null : (frequencyDays ?? this.frequencyDays),
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    Color parseColor(String hexString) {
      try {
        return Color(int.parse(hexString.replaceFirst('#', 'ff'), radix: 16));
      } catch (_) {
        return const Color(0xFF3B82F6);
      }
    }

    return Goal(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      color: parseColor(json['color'] as String),
      frequencyDays: (json['frequency_days'] as List<dynamic>?)?.map((e) => e as int).toList(),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      displayOrder: json['display_order'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    String toHex(Color c) => '#${c.value.toRadixString(16).substring(2, 8).toUpperCase()}';

    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      if (description != null) 'description': description,
      if (icon != null) 'icon': icon,
      'color': toHex(color),
      if (frequencyDays != null) 'frequency_days': frequencyDays,
      'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
      if (displayOrder != null) 'display_order': displayOrder,
    };
  }
}
