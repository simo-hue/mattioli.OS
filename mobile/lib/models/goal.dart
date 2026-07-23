import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/foundation.dart' show listEquals;
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

  /// The day the current [verificationRule] took effect (D10, forward-only rule
  /// edits). Null ⇒ fall back to [startDate]. Reconcile never rewrites days
  /// before this date, so editing a rule doesn't silently re-derive recent
  /// history. Owned by the save path (stamped on rule create/change), never set
  /// by the creation UI.
  final DateTime? verifyEffectiveFrom;

  /// Extra conditions (2nd, 3rd) of a compound verifiable habit, joined by
  /// [verificationJoin] (Q1–Q5). Null/empty ⇒ an ordinary single-rule habit
  /// ([verificationRule] is the whole rule). When set, [verificationRule] is the
  /// first condition and every condition is HealthKit (the v1 restriction, Q2).
  /// Persisted via the `verify_conditions` JSON column; the flat `verify_*`
  /// columns are then null.
  final List<VerificationRule>? additionalConditions;

  /// How a compound habit's conditions combine (Q1). Null for a single-rule or
  /// manual habit.
  final VerificationJoin? verificationJoin;

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
    this.verifyEffectiveFrom,
    this.additionalConditions,
    this.verificationJoin,
  });

  bool get isVerified => verificationRule != null;

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

  /// Whether [other] has the same verification *meaning* — the same ordered
  /// conditions AND operator. Drives the D10 re-stamp decision so that changing
  /// any condition, adding/removing one, or flipping the operator counts as a
  /// rule edit.
  bool sameVerificationAs(Goal other) =>
      listEquals(verificationConditions, other.verificationConditions) &&
      verificationJoin == other.verificationJoin;

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
    DateTime? verifyEffectiveFrom,
    bool clearVerifyEffectiveFrom = false,
    List<VerificationRule>? additionalConditions,
    bool clearAdditionalConditions = false,
    VerificationJoin? verificationJoin,
    bool clearVerificationJoin = false,
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
      verifyEffectiveFrom: clearVerifyEffectiveFrom
          ? null
          : (verifyEffectiveFrom ?? this.verifyEffectiveFrom),
      additionalConditions: clearAdditionalConditions
          ? null
          : (additionalConditions ?? this.additionalConditions),
      verificationJoin: clearVerificationJoin
          ? null
          : (verificationJoin ?? this.verificationJoin),
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

    // Read precedence (Q4): a compound habit's `verify_conditions` JSON wins;
    // otherwise the flat `verify_*` columns describe a single rule (or a manual
    // habit when both are absent).
    final verification = readVerificationColumns(json);
    final conditions = verification?.conditions ?? const <VerificationRule>[];

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
      verificationRule: conditions.isEmpty ? null : conditions.first,
      additionalConditions:
          conditions.length > 1 ? conditions.sublist(1) : null,
      verificationJoin: conditions.length > 1 ? verification!.op : null,
      verifyEffectiveFrom: parseDate(json['verify_effective_from']),
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
    // Date-only (YYYY-MM-DD) to match the Supabase `date` column and the
    // day-keyed reconcile logic.
    String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

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
      // verification columns, so they don't depend on the Supabase migration
      // having been applied yet. Single rule → flat verify_* columns; compound →
      // verify_conditions JSON with the flat columns nulled (Q4).
      if (verificationRule != null)
        ...verificationColumnsFor(
            verificationConditions, verificationJoin ?? VerificationJoin.or),
      // The rule's effective-from day (D10) rides alongside a live rule; a
      // manual habit has neither a rule nor an effective-from.
      if (verificationRule != null && verifyEffectiveFrom != null)
        'verify_effective_from': isoDate(verifyEffectiveFrom!),
    };
  }
}

/// Stamps [updated]'s [Goal.verifyEffectiveFrom] for a forward-only rule edit
/// (D10). The save layer calls this so the anchor is owned centrally and never
/// by the creation UI:
///
/// - manual habit (no rule) ⇒ no anchor;
/// - rule content unchanged vs [previous] ⇒ preserve the previous anchor
///   verbatim, **including null** — a title/colour/schedule edit must never
///   retroactively freeze a habit that predates the anchor;
/// - rule newly set, or its content changed ⇒ the rule takes effect [today], so
///   reconcile won't rewrite days before the edit.
///
/// "Rule content" is the full verification meaning — the ordered conditions AND
/// the operator ([Goal.sameVerificationAs]) — so changing any condition's
/// threshold/metric, adding or removing a condition, or flipping OR↔AND all
/// count as an edit.
Goal stampVerificationEffectiveFrom(
  Goal updated, {
  required Goal? previous,
  required DateTime today,
}) {
  // Manual habit (no conditions) ⇒ no anchor.
  if (updated.verificationRule == null) {
    return updated.copyWith(clearVerifyEffectiveFrom: true);
  }
  // Same verification meaning ⇒ preserve the prior anchor verbatim (incl. null):
  // a title/colour/schedule edit must never retroactively freeze history.
  if (previous != null && previous.sameVerificationAs(updated)) {
    final anchor = previous.verifyEffectiveFrom;
    return anchor == null
        ? updated.copyWith(clearVerifyEffectiveFrom: true)
        : updated.copyWith(verifyEffectiveFrom: anchor);
  }
  // Newly verified, or the conditions/operator changed ⇒ effective from today.
  return updated.copyWith(
    verifyEffectiveFrom: DateTime(today.year, today.month, today.day),
  );
}
