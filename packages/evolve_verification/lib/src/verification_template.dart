import 'package:flutter/foundation.dart';

import 'verification_provider.dart';
import 'verification_rule.dart';

/// A curated, pre-wired kind of verifiable habit (D5).
///
/// Templates — not a freeform builder — are the only way to create a rule, so
/// every rule is provably implementable by a native query/monitor and no
/// nonsensical combination (`≤ steps`, `≥ screen time`) can exist. The user
/// only picks the [key]'s template and a threshold number; everything else
/// (provider, comparator, unit, aggregation, native identifier) is fixed here.
@immutable
class VerificationTemplate {
  /// Stable identifier persisted in `goals.verify_metric`. NEVER rename.
  final String key;
  final VerificationProvider provider;

  /// Display grouping for the creation UI (presentational only — not persisted).
  final VerificationCategory category;

  final VerificationComparator comparator;
  final VerificationUnit unit;
  final VerificationAggregation aggregation;

  final double defaultThreshold;
  final double minThreshold;
  final double maxThreshold;

  /// Stepper increment for the threshold picker UI.
  final double step;

  /// Whether the metric effectively requires an Apple Watch to produce data —
  /// drives the soft "needs a Watch to auto-verify" warning at creation (D5/D9).
  final bool requiresWatch;

  /// The Apple sample identifier the native HealthKit bridge queries
  /// (e.g. `stepCount`, `appleExerciseTime`, `sleepAnalysis`). Null for Screen
  /// Time, which is driven by a DeviceActivity monitor rather than a query.
  final String? healthKitTypeIdentifier;

  const VerificationTemplate({
    required this.key,
    required this.provider,
    required this.category,
    required this.comparator,
    required this.unit,
    required this.aggregation,
    required this.defaultThreshold,
    required this.minThreshold,
    required this.maxThreshold,
    required this.step,
    this.requiresWatch = false,
    this.healthKitTypeIdentifier,
  });

  bool get isHealthKit => provider == VerificationProvider.healthKit;
  bool get isScreenTime => provider == VerificationProvider.screenTime;

  /// Clamps [threshold] into `[minThreshold, maxThreshold]`.
  double clampThreshold(double threshold) =>
      threshold.clamp(minThreshold, maxThreshold);

  /// Builds a concrete [VerificationRule] from this template and a user
  /// threshold (clamped to the template's bounds).
  VerificationRule ruleWith(double threshold) => VerificationRule(
        provider: provider,
        metricKey: key,
        comparator: comparator,
        threshold: clampThreshold(threshold),
        unit: unit,
      );
}

/// The v1 template catalog (D5): eight HealthKit "reach a target" habits
/// covering all three Activity rings plus sleep/mindful/distance/workout, and
/// two Screen Time "stay under a limit" habits — total device usage (Mode B)
/// and combined usage of picked apps/categories (Mode A). Compound rules are
/// deliberately excluded from v1.
abstract final class VerificationCatalog {
  // ---- HealthKit (atLeast) --------------------------------------------------

  static const steps = VerificationTemplate(
    key: 'steps',
    provider: VerificationProvider.healthKit,
    category: VerificationCategory.activity,
    comparator: VerificationComparator.atLeast,
    unit: VerificationUnit.count,
    aggregation: VerificationAggregation.sum,
    defaultThreshold: 10000,
    minThreshold: 1,
    maxThreshold: 1000000,
    step: 100,
    healthKitTypeIdentifier: 'stepCount',
  );

  static const exerciseMinutes = VerificationTemplate(
    key: 'exercise_minutes',
    provider: VerificationProvider.healthKit,
    category: VerificationCategory.activity,
    comparator: VerificationComparator.atLeast,
    unit: VerificationUnit.minutes,
    aggregation: VerificationAggregation.sum,
    defaultThreshold: 30,
    minThreshold: 1,
    maxThreshold: 1440,
    step: 5,
    healthKitTypeIdentifier: 'appleExerciseTime',
  );

  static const activeEnergy = VerificationTemplate(
    key: 'active_energy',
    provider: VerificationProvider.healthKit,
    category: VerificationCategory.activity,
    comparator: VerificationComparator.atLeast,
    unit: VerificationUnit.kilocalories,
    aggregation: VerificationAggregation.sum,
    defaultThreshold: 500,
    minThreshold: 1,
    maxThreshold: 10000,
    step: 50,
    healthKitTypeIdentifier: 'activeEnergyBurned',
  );

  static const standHours = VerificationTemplate(
    key: 'stand_hours',
    provider: VerificationProvider.healthKit,
    category: VerificationCategory.activity,
    comparator: VerificationComparator.atLeast,
    unit: VerificationUnit.count,
    aggregation: VerificationAggregation.count,
    defaultThreshold: 12,
    minThreshold: 1,
    maxThreshold: 24,
    step: 1,
    requiresWatch: true,
    healthKitTypeIdentifier: 'appleStandHour',
  );

  static const distance = VerificationTemplate(
    key: 'distance',
    provider: VerificationProvider.healthKit,
    category: VerificationCategory.activity,
    comparator: VerificationComparator.atLeast,
    unit: VerificationUnit.kilometers,
    aggregation: VerificationAggregation.sum,
    defaultThreshold: 5,
    minThreshold: 0.1,
    maxThreshold: 500,
    step: 0.1,
    healthKitTypeIdentifier: 'distanceWalkingRunning',
  );

  static const mindfulMinutes = VerificationTemplate(
    key: 'mindful_minutes',
    provider: VerificationProvider.healthKit,
    category: VerificationCategory.mindfulness,
    comparator: VerificationComparator.atLeast,
    unit: VerificationUnit.minutes,
    aggregation: VerificationAggregation.sum,
    defaultThreshold: 10,
    minThreshold: 1,
    maxThreshold: 1440,
    step: 5,
    healthKitTypeIdentifier: 'mindfulSession',
  );

  static const sleepHours = VerificationTemplate(
    key: 'sleep_hours',
    provider: VerificationProvider.healthKit,
    category: VerificationCategory.sleep,
    comparator: VerificationComparator.atLeast,
    unit: VerificationUnit.hours,
    aggregation: VerificationAggregation.sum,
    defaultThreshold: 8,
    minThreshold: 0.5,
    maxThreshold: 24,
    step: 0.5,
    healthKitTypeIdentifier: 'sleepAnalysis',
  );

  static const workout = VerificationTemplate(
    key: 'workout',
    provider: VerificationProvider.healthKit,
    category: VerificationCategory.activity,
    comparator: VerificationComparator.atLeast,
    unit: VerificationUnit.count,
    aggregation: VerificationAggregation.count,
    defaultThreshold: 1,
    minThreshold: 1,
    maxThreshold: 100,
    step: 1,
    healthKitTypeIdentifier: 'workout',
  );

  // ---- Screen Time (atMost) -------------------------------------------------

  /// Mode B — total device usage. Its "empty selection = all activity" native
  /// semantics are unverified on-device, so it ships dark behind
  /// `screenTimeTotalEnabled`.
  static const screenTimeTotal = VerificationTemplate(
    key: 'screen_time_total',
    provider: VerificationProvider.screenTime,
    category: VerificationCategory.screenTime,
    comparator: VerificationComparator.atMost,
    unit: VerificationUnit.minutes,
    aggregation: VerificationAggregation.sum,
    defaultThreshold: 120,
    minThreshold: 1,
    maxThreshold: 1440,
    step: 5,
  );

  /// Mode A — combined usage of the apps/categories the user picks with
  /// `FamilyActivityPicker`. The picked selection is stored device-local and
  /// keyed by goalId; the threshold measures the whole set as one activity.
  static const screenTimeApps = VerificationTemplate(
    key: 'screen_time_apps',
    provider: VerificationProvider.screenTime,
    category: VerificationCategory.screenTime,
    comparator: VerificationComparator.atMost,
    unit: VerificationUnit.minutes,
    aggregation: VerificationAggregation.sum,
    defaultThreshold: 60,
    minThreshold: 1,
    maxThreshold: 1440,
    step: 5,
  );

  /// All templates, in a sensible display order.
  static const List<VerificationTemplate> all = [
    steps,
    exerciseMinutes,
    activeEnergy,
    standHours,
    distance,
    mindfulMinutes,
    sleepHours,
    workout,
    screenTimeApps,
    screenTimeTotal,
  ];

  /// Looks up a template by its stable [VerificationTemplate.key], or null if
  /// unknown (e.g. a future template synced down from a newer client).
  static VerificationTemplate? byKey(String? key) {
    for (final t in all) {
      if (t.key == key) return t;
    }
    return null;
  }
}
