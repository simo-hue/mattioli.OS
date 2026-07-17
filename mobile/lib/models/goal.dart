import 'package:evolve_verification/evolve_verification.dart';
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
  final String? reminderTime; // "HH:mm" or null

  /// Auto-verification rule (null ⇒ ordinary manual habit). Round-tripped
  /// through the `verify_*` columns; verification itself runs only on iOS.
  final VerificationRule? verificationRule;

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
    this.reminderTime,
    this.verificationRule,
  });

  bool get isVerified => verificationRule != null;

  /// Whether the habit's active *range* covers [date] (start ≤ date ≤ end),
  /// ignoring the weekly schedule. Use [isScheduledOn] for day-view display —
  /// this predicate is only the lifetime bound.
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

  /// Whether the habit should actually appear on [date]: inside its active
  /// range AND scheduled for that weekday. `frequencyDays == null` (or empty)
  /// means "every day", matching the shared `frequency_days` convention. This
  /// is the predicate every day-scoped list (today, calendars, day popup) uses
  /// so an off-day habit is hidden rather than shown-and-uncompletable.
  bool isScheduledOn(DateTime date) {
    if (!isActiveOn(date)) return false;
    final freq = frequencyDays;
    if (freq == null || freq.isEmpty) return true;
    return freq.contains(date.weekday);
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
    String? reminderTime,
    bool clearReminderTime = false,
    VerificationRule? verificationRule,
    bool clearVerificationRule = false,
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
      reminderTime: clearReminderTime ? null : (reminderTime ?? this.reminderTime),
      verificationRule: clearVerificationRule
          ? null
          : (verificationRule ?? this.verificationRule),
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

    // Goals are read back through an eager `rows.map(...).toList()`, so throwing
    // on one bad date would hide EVERY goal rather than just this one. A row
    // predating the import validator's date check falls back to a start that
    // keeps the habit visible and editable, so the user can repair it.
    DateTime? parseDate(dynamic value) =>
        value is String ? DateTime.tryParse(value) : null;

    return Goal(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      color: parseColor(json['color'] as String),
      frequencyDays: (json['frequency_days'] as List<dynamic>?)?.map((e) => e as int).toList(),
      startDate: parseDate(json['start_date']) ?? DateTime(2000),
      endDate: parseDate(json['end_date']),
      displayOrder: json['display_order'] as int?,
      reminderTime: json['reminder_time'] as String?,
      verificationRule: VerificationRule.fromColumns(json),
    );
  }

  /// Canonical `goals.frequency_days` shape shared with desktop
  /// (`dashboard_controller._canonicalFrequencyDays`): sorted, de-duplicated ISO
  /// weekdays, with an all-7 selection collapsed to `null` (the every-day
  /// encoding both platforms already read). Keeps a "select every day" from
  /// writing `[1..7]`, which means the same thing but churns sync. An empty or
  /// null input returns `null`; the picker enforces ≥1 day, so this is defensive.
  static List<int>? canonicalFrequencyDays(List<int>? days) {
    if (days == null || days.isEmpty) return null;
    final unique = days.toSet();
    if (unique.containsAll(const {1, 2, 3, 4, 5, 6, 7})) return null;
    return unique.toList()..sort();
  }

  Map<String, dynamic> toJson() {
    String toHex(Color c) => '#${c.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';

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
      if (reminderTime != null) 'reminder_time': reminderTime,
      // Only emitted for verified goals: keeps manual-habit writes free of the
      // verify_* columns, so they don't depend on the Supabase migration having
      // been applied yet. The private (SQLite) path always writes them.
      if (verificationRule != null) ...verificationRule!.toColumns(),
    };
  }
}
