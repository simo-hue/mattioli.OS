import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'target_axes.dart';

/// The envelope version persisted inside the JSON, so the shape can evolve
/// without another column. Mirrors `kVerifyConditionsVersion`.
const int kHabitTargetVersion = 1;

/// A quantitative goal attached to a habit: *how much*, *of what*, *over which
/// window*, *in which direction*, *filled by whom*.
///
/// Null on a [HabitTarget]-less habit — which is every habit that exists today
/// — so the absence of one is exactly the current boolean check-in behaviour.
///
/// Persisted as ONE nullable JSON column (`goals.target`) rather than a spread
/// of typed columns. That follows the `verify_conditions` precedent for the same
/// reason it was chosen there: a target is a small closed object that is always
/// read and written whole, and a JSON envelope lets a future axis ship without a
/// migration on two backends plus a CHECK constraint.
///
/// It deliberately does NOT reuse the `verify_*` columns. Two independent facts
/// make that impossible rather than merely unwise: `verificationColumnsFor`
/// NULLs all five flat columns for a habit with no conditions (i.e. every manual
/// habit) and again for a compound one, and both private write paths spread that
/// result unconditionally on every save; and `Goal.toJson` gates the whole
/// verification spread on `verificationRule != null`, so a manual habit's target
/// would never reach Supabase at all. A target and a verification rule are
/// orthogonal, and "auto-verified AND separately counted" stays expressible.
@immutable
class HabitTarget {
  /// Who supplies the progress number.
  final TargetFillSource fillSource;

  /// Whether the target is a floor (`atLeast`) or a ceiling (`atMost`).
  final TargetDirection direction;

  /// The window progress accumulates over before resetting.
  final TargetPeriod period;

  /// How a period's entries combine into the compared number.
  final TargetAggregation aggregation;

  /// The number to reach (or stay under), in [unit].
  final double amount;

  final TargetUnit unit;

  /// The default increment for one tap of the stepper (or one timer session's
  /// rounding granularity). "4 sets of 20" is `amount: 80, step: 20`, which is
  /// what makes the ring fill in four taps instead of eighty.
  final double step;

  /// How the user enters progress.
  final TargetInput input;

  /// The [TargetPreset.id] this target was created from, or null for one
  /// restored from a blob whose preset this build does not know. Presentational
  /// and diagnostic only — every axis needed to evaluate the target is stored
  /// explicitly above, so an unknown preset never changes behaviour.
  final String? presetId;

  /// Keys present in the stored blob that this build does not understand,
  /// preserved verbatim so they survive a round-trip through an older client.
  ///
  /// Without this, the sequence "iPhone on a newer build sets a field → Mac on
  /// an older build edits the habit's title → the field is gone" silently
  /// destroys data the newer build depends on. The engine syncs whole rows, so
  /// that sequence is ordinary, not exotic.
  final Map<String, Object?> extra;

  const HabitTarget({
    required this.fillSource,
    required this.direction,
    required this.period,
    required this.aggregation,
    required this.amount,
    required this.unit,
    required this.step,
    required this.input,
    this.presetId,
    this.extra = const {},
  });

  /// Whether progress comes from a sensor rather than the user.
  bool get isMeasured => fillSource.isMeasured;

  /// Whether the UI may offer a stepper / timer for this target.
  ///
  /// False for every measured target: offering a `+1` on a HealthKit step count
  /// would invite the user to write a number the next reconcile pass silently
  /// overwrites with the sensor's. [input] is therefore meaningless — not
  /// merely unused — whenever this is false.
  bool get isUserEnterable => !isMeasured;

  /// Whether this is a "stay under" target — the polarity that inverts what an
  /// empty day means.
  bool get isLimit => direction == TargetDirection.atMost;

  HabitTarget copyWith({
    TargetFillSource? fillSource,
    TargetDirection? direction,
    TargetPeriod? period,
    TargetAggregation? aggregation,
    double? amount,
    TargetUnit? unit,
    double? step,
    TargetInput? input,
    String? presetId,
    bool clearPresetId = false,
    Map<String, Object?>? extra,
  }) =>
      HabitTarget(
        fillSource: fillSource ?? this.fillSource,
        direction: direction ?? this.direction,
        period: period ?? this.period,
        aggregation: aggregation ?? this.aggregation,
        amount: amount ?? this.amount,
        unit: unit ?? this.unit,
        step: step ?? this.step,
        input: input ?? this.input,
        presetId: clearPresetId ? null : (presetId ?? this.presetId),
        extra: extra ?? this.extra,
      );

  /// The persisted map. Unknown keys are re-emitted FIRST so a known key can
  /// never be shadowed by a stale one of the same name.
  Map<String, Object?> toWire() => {
        ...extra,
        'v': kHabitTargetVersion,
        'src': fillSource.wireName,
        'dir': direction.wireName,
        'per': period.wireName,
        'agg': aggregation.wireName,
        'amount': amount,
        'unit': unit.wireName,
        'step': step,
        'input': input.wireName,
        if (presetId != null) 'preset': presetId,
      };

  /// The JSON string stored in `goals.target`.
  String encode() => jsonEncode(toWire());

  @override
  bool operator ==(Object other) =>
      other is HabitTarget &&
      other.fillSource == fillSource &&
      other.direction == direction &&
      other.period == period &&
      other.aggregation == aggregation &&
      other.amount == amount &&
      other.unit == unit &&
      other.step == step &&
      other.input == input &&
      other.presetId == presetId &&
      // Deep, not `mapEquals`: `extra` holds arbitrary JSON, so a nested value
      // ({'rampUp': {'weekly': 5}}) is a fresh instance after every decode and
      // a shallow compare would report two identical targets as different —
      // which would make the save path think an untouched habit had changed.
      _jsonDeepEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(fillSource, direction, period, aggregation,
      amount, unit, step, input, presetId);

  @override
  String toString() => 'HabitTarget(${direction.wireName} $amount '
      '${unit.wireName}/${period.wireName} via ${fillSource.wireName})';
}

/// Structural equality over decoded-JSON values (maps, lists, scalars).
///
/// Hand-rolled rather than pulling in `package:collection` for one function:
/// this package's dependency list is deliberately just `flutter` +
/// `evolve_verification`, and the shape here is closed — whatever `jsonDecode`
/// can produce, nothing more.
bool _jsonDeepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_jsonDeepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_jsonDeepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// The reserved keys [HabitTarget.toWire] owns. Anything else in a stored blob
/// is a newer client's field and is preserved in [HabitTarget.extra].
const Set<String> _knownTargetKeys = {
  'v',
  'src',
  'dir',
  'per',
  'agg',
  'amount',
  'unit',
  'step',
  'input',
  'preset',
};

/// Decodes a `goals.target` value (a JSON string, or an already-decoded Map),
/// or **null** when it is absent, blank, malformed, or describes a target this
/// build cannot faithfully evaluate.
///
/// Degrading to null means the habit reads as an ordinary boolean one — the
/// same safety posture as `decodeVerifyConditions`, and for the same reason: a
/// half-understood target is worse than no target, because it would silently
/// mark days done or missed against a rule the user never set. Strictness is
/// therefore total — an unrecognised axis value rejects the whole blob rather
/// than falling back to a default. (Note this is deliberately stricter than
/// `VerificationAggregation.fromWire`, which defaults unknown input to `sum`;
/// that default is safe for a catalog-constrained rule and is not safe here.)
///
/// Never throws: this runs inside the eager `rows.map(...)` that builds the goal
/// list, where one exception would hide EVERY habit rather than one.
HabitTarget? decodeHabitTarget(Object? raw) {
  if (raw == null) return null;
  try {
    Map<String, Object?> map;
    if (raw is String) {
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      map = decoded.cast<String, Object?>();
    } else if (raw is Map) {
      map = raw.cast<String, Object?>();
    } else {
      return null;
    }

    // Type-safe reads throughout: a corrupted, foreign or newer-client blob may
    // carry a wrong-typed field, and that must degrade to null, never throw.
    final srcRaw = map['src'];
    final dirRaw = map['dir'];
    final perRaw = map['per'];
    final aggRaw = map['agg'];
    final unitRaw = map['unit'];
    final inputRaw = map['input'];
    final amountRaw = map['amount'];
    final stepRaw = map['step'];
    final presetRaw = map['preset'];

    final fillSource =
        TargetFillSource.fromWire(srcRaw is String ? srcRaw : null);
    final direction =
        TargetDirection.fromWire(dirRaw is String ? dirRaw : null);
    final period = TargetPeriod.fromWire(perRaw is String ? perRaw : null);
    final unit = TargetUnit.fromWire(unitRaw is String ? unitRaw : null);
    final input = TargetInput.fromWire(inputRaw is String ? inputRaw : null);
    final amount = amountRaw is num ? amountRaw.toDouble() : null;
    final step = stepRaw is num ? stepRaw.toDouble() : null;

    // Strict aggregation parse — see the doc comment above.
    TargetAggregation? aggregation;
    if (aggRaw is String) {
      for (final a in TargetAggregation.values) {
        if (a.name == aggRaw) aggregation = a;
      }
    }

    if (fillSource == null ||
        direction == null ||
        period == null ||
        aggregation == null ||
        unit == null ||
        input == null ||
        amount == null ||
        step == null) {
      return null;
    }
    // A non-positive target is not a target: it would make every day
    // instantly complete (atLeast) or instantly breached (atMost). Reject
    // rather than clamp, so a corrupt blob cannot quietly rewrite history.
    if (!amount.isFinite || amount <= 0) return null;
    if (!step.isFinite || step <= 0) return null;

    return HabitTarget(
      fillSource: fillSource,
      direction: direction,
      period: period,
      aggregation: aggregation,
      amount: amount,
      unit: unit,
      step: step,
      input: input,
      presetId: presetRaw is String && presetRaw.isNotEmpty ? presetRaw : null,
      extra: {
        for (final e in map.entries)
          if (!_knownTargetKeys.contains(e.key)) e.key: e.value,
      },
    );
  } catch (_) {
    return null;
  }
}

/// Whether [raw] holds *something* — used by the write path to tell "this habit
/// has no target" apart from "this habit has a target this build cannot read".
///
/// The distinction matters on save: a blob we could not decode must be written
/// back **verbatim**, never nulled, or an older client silently strips a target
/// the user set on a newer one. Callers keep the original string alongside the
/// decoded object for exactly this.
bool hasUnreadableTarget(Object? raw) =>
    raw != null && decodeHabitTarget(raw) == null && _isNonEmptyBlob(raw);

bool _isNonEmptyBlob(Object? raw) {
  if (raw is Map) return raw.isNotEmpty;
  if (raw is! String || raw.trim().isEmpty) return false;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map && decoded.isNotEmpty;
  } catch (_) {
    return false;
  }
}
