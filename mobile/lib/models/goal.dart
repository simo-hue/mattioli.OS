import 'package:evolve_targets/evolve_targets.dart';
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

  /// The raw `goals.verify_conditions` value exactly as stored, kept so a
  /// compound written by a NEWER client — one with MORE than
  /// `kMaxVerificationConditions` conditions, which this build decodes to null
  /// (so [verificationRule] is null and it reads as manual) — is written back
  /// verbatim on an unrelated edit instead of being stripped. The verify-side
  /// twin of [rawTargetBlob]. Null for a single-rule or manual habit; a readable
  /// compound re-encodes from its conditions, so this is consulted only when the
  /// blob could not be decoded. See [verifyColumnValues].
  final String? rawVerifyConditionsBlob;

  /// The quantitative daily target (count / duration / limit), or null for an
  /// ordinary boolean habit — which is every habit that predates this feature —
  /// or for a target blob this build cannot decode (see [rawTargetBlob]).
  /// Persisted via the `goals.target` JSON column (`package:evolve_targets`).
  final HabitTarget? target;

  /// The raw `goals.target` value exactly as stored, kept so a target written by
  /// a NEWER client — one whose axis values this build cannot decode, so
  /// [target] is null — is written back verbatim on an unrelated edit (title,
  /// colour, schedule) instead of being silently nulled. Sync serializes whole
  /// rows, so "newer device sets it, older device edits the title" is an
  /// ordinary sequence, not an exotic one. Null when the column is empty; the
  /// save layer prefers [target] when it is set, then a non-empty unreadable
  /// blob, then null.
  final String? rawTargetBlob;

  /// The day the current [target] took effect (v11, forward-only target edits) —
  /// the exact analogue of [verifyEffectiveFrom] for the quantitative target.
  /// Null ⇒ fall back to [startDate]. The manual-target end-of-day sweep never
  /// rewrites days before this date, so editing a target's amount (or switching
  /// a habit's tracking class) applies forward instead of retroactively
  /// re-deriving history. Owned by the save path (stamped on target
  /// create/change), never set by the creation UI.
  final DateTime? targetEffectiveFrom;

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
    this.rawVerifyConditionsBlob,
    this.target,
    this.rawTargetBlob,
    this.targetEffectiveFrom,
  });

  bool get isVerified => verificationRule != null;

  /// Whether this habit carries a quantitative target — one this build can read.
  /// A habit with only an undecodable [rawTargetBlob] reports false, so it is
  /// treated (and rendered) as an ordinary boolean habit rather than a broken
  /// one, while the blob still round-trips on save.
  bool get hasTarget => target != null;

  /// The target to DISPLAY for this habit: an explicit manual [target] wins,
  /// otherwise a single verification rule projects into one (so a verified
  /// threshold and a manual count render as the same ring). Null for a plain
  /// habit or a compound verified one. See `displayTargetFor`.
  HabitTarget? get displayTarget =>
      displayTargetFor(ownTarget: target, conditions: verificationConditions);

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
    String? rawVerifyConditionsBlob,
    HabitTarget? target,
    bool clearTarget = false,
    DateTime? targetEffectiveFrom,
    bool clearTargetEffectiveFrom = false,
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
      // Setting a NEW rule supersedes any preserved compound blob (the rule is
      // authoritative). Otherwise preserve it — DELIBERATELY NOT tied to
      // clearVerificationRule, so an unrelated edit that passes
      // clearVerificationRule (the modal does, for a habit that reads as manual)
      // can't strip a newer client's undecodable compound. The write path
      // ([verifyColumnValues]) decides whether the preserved blob is actually
      // emitted (only when still unreadable and target-free).
      rawVerifyConditionsBlob: verificationRule != null
          ? null
          : (rawVerifyConditionsBlob ?? this.rawVerifyConditionsBlob),
      // Setting a new target supersedes any preserved raw blob (a real edit is
      // authoritative); clearing wipes both, so an undecodable old blob can't
      // resurrect a target the user just removed. A copy that touches neither
      // keeps both, so a title/colour edit preserves an unreadable newer-client
      // target verbatim.
      target: clearTarget ? null : (target ?? this.target),
      rawTargetBlob:
          clearTarget ? null : (target != null ? null : rawTargetBlob),
      targetEffectiveFrom: clearTargetEffectiveFrom
          ? null
          : (targetEffectiveFrom ?? this.targetEffectiveFrom),
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

    // The target column: decode for use, and keep the raw blob so an
    // undecodable newer-client target survives an edit here (see rawTargetBlob).
    final rawTarget = json['target'] as String?;

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
      // Keep the raw compound blob so an undecodable newer-client compound
      // (which decodes to no conditions → reads as manual) survives an edit.
      rawVerifyConditionsBlob: json['verify_conditions'] as String?,
      verifyEffectiveFrom: parseDate(json['verify_effective_from']),
      target: decodeHabitTarget(rawTarget),
      rawTargetBlob: rawTarget,
      targetEffectiveFrom: parseDate(json['target_effective_from']),
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
      // Emitted for a real rule OR to preserve an undecodable newer-client
      // compound blob (target-free); a plain manual habit stays column-free so
      // its writes don't depend on the verify migrations. Single rule → flat
      // verify_* columns; compound → verify_conditions JSON with the flat columns
      // nulled (Q4); a preserved blob → that blob verbatim, flat nulled.
      if (verificationRule != null ||
          (targetColumnValue == null &&
              hasUnreadableVerifyConditions(rawVerifyConditionsBlob)))
        ...verifyColumnValues,
      // The rule's effective-from day (D10) rides alongside a live rule; a
      // manual habit has neither a rule nor an effective-from.
      if (verificationRule != null && verifyEffectiveFrom != null)
        'verify_effective_from': isoDate(verifyEffectiveFrom!),
      // The quantitative target. Emitted only when there is something to write,
      // so a plain habit's payload stays free of the column and does not depend
      // on the v9 Supabase migration having been applied yet. A readable target
      // is re-encoded (lossless — its unknown `extra` keys are preserved); an
      // unreadable newer-client blob is written back verbatim so an edit here
      // cannot strip it.
      if (targetColumnValue != null) 'target': targetColumnValue,
      // The target's effective-from day (v11) rides alongside a live target,
      // exactly like verify_effective_from rides a live rule. Gated on the
      // target being written (readable or a preserved blob) so the anchor is
      // never orphaned from — nor stranded without — its target.
      if (targetColumnValue != null && targetEffectiveFrom != null)
        'target_effective_from': isoDate(targetEffectiveFrom!),
    };
  }

  /// The value to write to the `goals.target` column: the live target encoded,
  /// else a preserved unreadable blob verbatim, else null. Shared by the cloud
  /// (`toJson`) and private (`_goalToRow`) write paths so they cannot disagree
  /// about what an undecodable target round-trips to.
  String? get targetColumnValue {
    if (target != null) return target!.encode();
    if (hasUnreadableTarget(rawTargetBlob)) return rawTargetBlob;
    return null;
  }

  /// The six `goals` verify_* columns to WRITE, preserving an undecodable
  /// newer-client compound blob (a >[kMaxVerificationConditions] set this build
  /// can't represent) when it couldn't be decoded into a rule — the verify-side
  /// twin of [targetColumnValue]. Shared by the cloud (`toJson`) and private
  /// (`_goalToRow`) write paths so they cannot disagree. See
  /// [verificationColumnValues].
  Map<String, Object?> get verifyColumnValues => verificationColumnValues(
        conditions: verificationConditions,
        op: verificationJoin ?? VerificationJoin.or,
        rawConditionsBlob: rawVerifyConditionsBlob,
        hasTarget: targetColumnValue != null,
      );

  /// The `verify_effective_from` (D10) date string to WRITE. The anchor rides
  /// with a live rule OR a preserved undecodable compound blob — so the private
  /// REPLACE write keeps it alongside the blob instead of nulling it (which
  /// would strip the freeze anchor and let a higher-cap peer re-verify recent
  /// days). Null for a plain / manual / target habit. Date-only (YYYY-MM-DD).
  String? get verifyEffectiveFromColumnValue {
    if (verifyEffectiveFrom == null) return null;
    final hasVerification = verificationRule != null ||
        (targetColumnValue == null &&
            hasUnreadableVerifyConditions(rawVerifyConditionsBlob));
    return hasVerification
        ? verifyEffectiveFrom!.toIso8601String().substring(0, 10)
        : null;
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

/// Stamps [updated]'s [Goal.targetEffectiveFrom] for a forward-only target edit
/// (v11) — the exact analogue of [stampVerificationEffectiveFrom] for the
/// quantitative target. The save layer calls this so the anchor is owned
/// centrally and never by the creation UI:
///
/// - no target at all (readable or a preserved unreadable blob) ⇒ no anchor;
/// - a target this build cannot decode (a newer-client blob) is preserved
///   verbatim on an unrelated edit and its anchor rides along UNCHANGED — this
///   build neither authored nor can evaluate it, so it must not re-stamp;
/// - readable target unchanged vs [previous] ⇒ preserve the previous anchor
///   verbatim, **including null** — a title/colour/schedule edit must never
///   retroactively freeze a habit that predates the anchor;
/// - readable target newly set, or its content changed ⇒ effective [today], so
///   the manual-target sweep won't rewrite days before the edit. Switching a
///   habit's tracking class (checkbox→number, or number→verified which
///   sets/clears the target) is exactly such a change.
///
/// "Target content" is [HabitTarget]'s value equality (amount, direction, unit,
/// period, aggregation, step, input, fillSource, presetId and the deep `extra`),
/// so changing any axis counts as an edit.
Goal stampTargetEffectiveFrom(
  Goal updated, {
  required Goal? previous,
  required DateTime today,
}) {
  // No target at all ⇒ no anchor.
  if (updated.targetColumnValue == null) {
    return updated.copyWith(clearTargetEffectiveFrom: true);
  }
  // An undecodable newer-client target: preserve its carried anchor verbatim.
  if (updated.target == null) {
    return updated;
  }
  // Same target meaning ⇒ preserve the prior anchor verbatim (incl. null): a
  // title/colour/schedule edit must never retroactively freeze history.
  if (previous != null && previous.target == updated.target) {
    final anchor = previous.targetEffectiveFrom;
    return anchor == null
        ? updated.copyWith(clearTargetEffectiveFrom: true)
        : updated.copyWith(targetEffectiveFrom: anchor);
  }
  // Newly targeted, or the target changed ⇒ effective from today.
  return updated.copyWith(
    targetEffectiveFrom: DateTime(today.year, today.month, today.day),
  );
}
