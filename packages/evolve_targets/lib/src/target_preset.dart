import 'package:flutter/foundation.dart';

import 'habit_target.dart';
import 'target_axes.dart';

/// A curated, pre-wired kind of quantitative habit.
///
/// Presets — not a freeform axis builder — are the only way the creation UI
/// makes a target, exactly as [VerificationTemplate] is the only way it makes a
/// rule. The user picks a preset and a number; every axis is fixed here. That
/// keeps the four-axis model from ever reaching the user as a matrix, and makes
/// nonsensical combinations (`atMost` counted `count` over a `month` entered by
/// `timer`) unconstructible rather than merely discouraged.
///
/// Adding a habit kind later — "4 gym sessions per week", "≤3 beers per week",
/// "500 km per year" — is ONE entry in [TargetPresetCatalog.all] plus its
/// translation keys. No migration, no model change, no new code path: that is
/// the whole point of storing the axes rather than a kind enum.
@immutable
class TargetPreset {
  /// Stable identifier persisted in the target blob's `preset` key. NEVER
  /// rename: an old row carrying a renamed id would lose its preset binding
  /// (harmlessly — every axis is stored explicitly — but the edit UI would no
  /// longer recognise its own creation).
  final String id;

  /// The i18n key the apps resolve for this preset's title. Kept as a key, not
  /// a string: this package has no localisation and must not acquire one.
  final String labelKey;

  /// The i18n key for the one-line explanation shown under the title.
  final String descriptionKey;

  final TargetDirection direction;
  final TargetPeriod period;
  final TargetAggregation aggregation;
  final TargetUnit unit;
  final TargetInput input;

  final double defaultAmount;
  final double minAmount;
  final double maxAmount;

  /// The default per-tap increment. User-editable in the creation UI for
  /// stepper presets — "80 push-ups in sets of 20" is the entire reason this
  /// axis is exposed at all.
  final double defaultStep;

  /// Whether the creation UI offers the step as an editable field. False where
  /// a step is an implementation detail (a timer measures real elapsed time).
  final bool stepIsEditable;

  const TargetPreset({
    required this.id,
    required this.labelKey,
    required this.descriptionKey,
    required this.direction,
    required this.period,
    required this.aggregation,
    required this.unit,
    required this.input,
    required this.defaultAmount,
    required this.minAmount,
    required this.maxAmount,
    required this.defaultStep,
    this.stepIsEditable = true,
  });

  /// Clamps [amount] into `[minAmount, maxAmount]`.
  double clampAmount(double amount) => amount.clamp(minAmount, maxAmount);

  /// Builds a concrete manual [HabitTarget] from this preset.
  ///
  /// [step] is clamped to `(0, amount]`: a zero or negative step would make the
  /// stepper inert, and a step larger than the target would overshoot the whole
  /// goal in one tap.
  HabitTarget targetWith({double? amount, double? step}) {
    final a = clampAmount(amount ?? defaultAmount);
    final rawStep = step ?? defaultStep;
    final s = rawStep <= 0 ? defaultStep : (rawStep > a ? a : rawStep);
    return HabitTarget(
      fillSource: TargetFillSource.manual,
      direction: direction,
      period: period,
      aggregation: aggregation,
      amount: a,
      unit: unit,
      step: s,
      input: input,
      presetId: id,
    );
  }

  /// Whether [target] was (or could have been) produced by this preset —
  /// every axis matches, ignoring the amount, the step and the recorded id.
  /// Used by the edit UI to re-select the right preset for a target whose
  /// `preset` key is missing or belongs to a build that renamed it.
  bool matches(HabitTarget target) =>
      target.fillSource == TargetFillSource.manual &&
      target.direction == direction &&
      target.period == period &&
      target.aggregation == aggregation &&
      target.unit == unit &&
      target.input == input;
}

/// The v1 preset catalog: four manual, per-day kinds.
///
/// Two "reach it" and two "stay under it", each in a counted and a timed
/// flavour. Weekly quotas are deliberately absent — not because the model
/// cannot express them ([TargetPeriod.week] round-trips today) but because
/// nothing in the streak engine or the analytics layer buckets by week yet, and
/// a preset the stats cannot score would be a lie.
abstract final class TargetPresetCatalog {
  /// "Do it N times a day" — push-ups, glasses of water, pages.
  static const countDaily = TargetPreset(
    id: 'count_daily',
    labelKey: 'targets.presets.countDaily.label',
    descriptionKey: 'targets.presets.countDaily.description',
    direction: TargetDirection.atLeast,
    period: TargetPeriod.day,
    aggregation: TargetAggregation.sum,
    unit: TargetUnit.count,
    input: TargetInput.stepper,
    defaultAmount: 10,
    minAmount: 1,
    maxAmount: 100000,
    defaultStep: 1,
  );

  /// "Spend N minutes a day" — reading, practising, deep work.
  static const durationDaily = TargetPreset(
    id: 'duration_daily',
    labelKey: 'targets.presets.durationDaily.label',
    descriptionKey: 'targets.presets.durationDaily.description',
    direction: TargetDirection.atLeast,
    period: TargetPeriod.day,
    aggregation: TargetAggregation.sum,
    unit: TargetUnit.minutes,
    input: TargetInput.timer,
    defaultAmount: 20,
    minAmount: 1,
    maxAmount: 1440,
    defaultStep: 5,
  );

  /// "Stay under N a day" — coffees, cigarettes, snacks.
  static const limitCountDaily = TargetPreset(
    id: 'limit_count_daily',
    labelKey: 'targets.presets.limitCountDaily.label',
    descriptionKey: 'targets.presets.limitCountDaily.description',
    direction: TargetDirection.atMost,
    period: TargetPeriod.day,
    aggregation: TargetAggregation.sum,
    unit: TargetUnit.count,
    input: TargetInput.stepper,
    defaultAmount: 1,
    minAmount: 0.5,
    maxAmount: 10000,
    defaultStep: 1,
  );

  /// "Stay under N minutes a day" — the manual counterpart of the Screen Time
  /// rule, for the things iOS cannot measure (television, gaming on a console).
  static const limitDurationDaily = TargetPreset(
    id: 'limit_duration_daily',
    labelKey: 'targets.presets.limitDurationDaily.label',
    descriptionKey: 'targets.presets.limitDurationDaily.description',
    direction: TargetDirection.atMost,
    period: TargetPeriod.day,
    aggregation: TargetAggregation.sum,
    unit: TargetUnit.minutes,
    input: TargetInput.stepper,
    defaultAmount: 30,
    minAmount: 1,
    maxAmount: 1440,
    defaultStep: 5,
  );

  /// All presets, in creation-UI display order.
  static const List<TargetPreset> all = [
    countDaily,
    durationDaily,
    limitCountDaily,
    limitDurationDaily,
  ];

  /// Looks up a preset by its stable [TargetPreset.id], or null if unknown
  /// (e.g. one introduced by a newer client).
  static TargetPreset? byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The preset that produced [target] — by recorded id first, then by axis
  /// match, so a target whose `preset` key is absent still lands on the right
  /// row in the edit UI.
  static TargetPreset? forTarget(HabitTarget target) {
    final byRecordedId = byId(target.presetId);
    if (byRecordedId != null) return byRecordedId;
    for (final p in all) {
      if (p.matches(target)) return p;
    }
    return null;
  }
}
