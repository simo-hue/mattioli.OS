/// Which Apple data source verifies a goal.
///
/// The [wireName]s are the exact strings persisted in the `goals.verify_provider`
/// column across both backends (Supabase + SQLCipher), so they must stay stable.
enum VerificationProvider {
  healthKit,
  screenTime;

  String get wireName => switch (this) {
        VerificationProvider.healthKit => 'healthkit',
        VerificationProvider.screenTime => 'screentime',
      };

  static VerificationProvider? fromWire(String? value) => switch (value) {
        'healthkit' => VerificationProvider.healthKit,
        'screentime' => VerificationProvider.screenTime,
        _ => null,
      };
}

/// Direction of the threshold comparison.
///
/// [atLeast] models HealthKit "reach a target" goals (≥ N steps); [atMost]
/// models Screen Time "stay under a limit" goals (≤ N minutes).
enum VerificationComparator {
  atLeast,
  atMost;

  String get wireName => switch (this) {
        VerificationComparator.atLeast => 'gte',
        VerificationComparator.atMost => 'lte',
      };

  static VerificationComparator? fromWire(String? value) => switch (value) {
        'gte' => VerificationComparator.atLeast,
        'lte' => VerificationComparator.atMost,
        _ => null,
      };
}

/// How the native bridge aggregates a HealthKit metric's samples over a day.
enum VerificationAggregation {
  /// Sum of sample quantities (steps, energy, minutes, distance).
  sum,

  /// Count of qualifying samples (stand hours, workouts).
  count;

  String get wireName => name;

  static VerificationAggregation fromWire(String? value) =>
      VerificationAggregation.values
          .firstWhere((a) => a.name == value, orElse: () => VerificationAggregation.sum);
}

/// A display grouping for verification templates in the creation UI. Purely
/// presentational (never persisted), so values may be reordered or renamed
/// freely. Declaration order is the section display order.
enum VerificationCategory {
  activity,
  mindfulness,
  sleep,
  screenTime,
}

/// How the conditions of a compound verifiable habit combine (post-v1 feature).
///
/// [or] = pass if *any* condition is met (inclusive disjunction — "10k steps OR
/// 30 min exercise"); [and] = pass only if *all* are met (conjunction). A
/// single-condition habit has no meaningful operator; [or] is the harmless
/// default. The [wireName]s are persisted inside the `goals.verify_conditions`
/// JSON, so they must stay stable.
enum VerificationJoin {
  or,
  and;

  String get wireName => switch (this) {
        VerificationJoin.or => 'or',
        VerificationJoin.and => 'and',
      };

  static VerificationJoin? fromWire(String? value) => switch (value) {
        'or' => VerificationJoin.or,
        'and' => VerificationJoin.and,
        _ => null,
      };
}

/// Physical unit of a metric, used for threshold formatting + display. Distance
/// is stored canonically in kilometers; the UI may localise to miles.
enum VerificationUnit {
  count,
  minutes,
  hours,
  kilocalories,
  kilometers;

  String get wireName => name;

  static VerificationUnit? fromWire(String? value) {
    for (final u in VerificationUnit.values) {
      if (u.name == value) return u;
    }
    return null;
  }
}
