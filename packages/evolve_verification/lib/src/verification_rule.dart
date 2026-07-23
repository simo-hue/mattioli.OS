import 'package:flutter/foundation.dart';

import 'verification_provider.dart';
import 'verification_template.dart';

/// The persisted verification condition attached to a goal (D4/D8).
///
/// Stored as five nullable columns on `goals` (all null ⇒ an ordinary manual
/// habit). This is deliberately flat — one goal has at most one rule; compound
/// (multi-metric) goals are a post-v1 feature.
@immutable
class VerificationRule {
  final VerificationProvider provider;

  /// The [VerificationTemplate.key] this rule was built from.
  final String metricKey;
  final VerificationComparator comparator;
  final double threshold;
  final VerificationUnit unit;

  const VerificationRule({
    required this.provider,
    required this.metricKey,
    required this.comparator,
    required this.threshold,
    required this.unit,
  });

  /// The originating template, or null if the key is unknown to this client.
  VerificationTemplate? get template => VerificationCatalog.byKey(metricKey);

  bool get isHealthKit => provider == VerificationProvider.healthKit;
  bool get isScreenTime => provider == VerificationProvider.screenTime;

  /// The five `goals` columns this rule maps to. The caller merges these into
  /// the goal row (and writes all-null when a goal has no rule).
  Map<String, Object?> toColumns() => {
        'verify_provider': provider.wireName,
        'verify_metric': metricKey,
        'verify_comparator': comparator.wireName,
        'verify_threshold': threshold,
        'verify_unit': unit.wireName,
      };

  /// All-null column map for a manual (non-verifiable) goal — use when clearing
  /// a rule so a stale rule can't linger in the row.
  static Map<String, Object?> get nullColumns => const {
        'verify_provider': null,
        'verify_metric': null,
        'verify_comparator': null,
        'verify_threshold': null,
        'verify_unit': null,
      };

  /// Reconstructs a rule from a `goals` row, or null when the row describes a
  /// manual habit or is missing any required verification field (treated as
  /// "not verifiable" rather than throwing — a partial rule must never
  /// half-activate verification).
  static VerificationRule? fromColumns(Map<String, Object?> row) {
    final provider = VerificationProvider.fromWire(row['verify_provider'] as String?);
    final metricKey = row['verify_metric'] as String?;
    final comparator = VerificationComparator.fromWire(row['verify_comparator'] as String?);
    final threshold = (row['verify_threshold'] as num?)?.toDouble();
    final unit = VerificationUnit.fromWire(row['verify_unit'] as String?);

    if (provider == null ||
        metricKey == null ||
        metricKey.isEmpty ||
        comparator == null ||
        threshold == null ||
        unit == null) {
      return null;
    }
    return VerificationRule(
      provider: provider,
      metricKey: metricKey,
      comparator: comparator,
      threshold: threshold,
      unit: unit,
    );
  }

  /// Compact wire form for one condition inside the `goals.verify_conditions`
  /// JSON (compound habits). Short keys, distinct from [toColumns]' column
  /// names, so the two representations can't be confused.
  Map<String, Object?> toWire() => {
        'provider': provider.wireName,
        'metric': metricKey,
        'comparator': comparator.wireName,
        'threshold': threshold,
        'unit': unit.wireName,
      };

  /// Parses a [toWire] map back into a rule, or null if any field is missing or
  /// invalid — a malformed condition must never half-activate verification.
  static VerificationRule? fromWire(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.cast<String, Object?>();
    // Type-safe reads: a corrupted / foreign / newer-client blob may carry a
    // wrong-typed field. A bad condition must degrade to null (the caller then
    // rejects the whole set) — it must NEVER throw out of the decode path, which
    // runs inside an eager goal-row map that a throw would take down entirely.
    final providerRaw = m['provider'];
    final metricRaw = m['metric'];
    final comparatorRaw = m['comparator'];
    final thresholdRaw = m['threshold'];
    final unitRaw = m['unit'];
    final provider = VerificationProvider.fromWire(
        providerRaw is String ? providerRaw : null);
    final metricKey = metricRaw is String ? metricRaw : null;
    final comparator = VerificationComparator.fromWire(
        comparatorRaw is String ? comparatorRaw : null);
    final threshold = thresholdRaw is num ? thresholdRaw.toDouble() : null;
    final unit =
        VerificationUnit.fromWire(unitRaw is String ? unitRaw : null);
    if (provider == null ||
        metricKey == null ||
        metricKey.isEmpty ||
        comparator == null ||
        threshold == null ||
        unit == null) {
      return null;
    }
    return VerificationRule(
      provider: provider,
      metricKey: metricKey,
      comparator: comparator,
      threshold: threshold,
      unit: unit,
    );
  }

  VerificationRule copyWith({
    VerificationComparator? comparator,
    double? threshold,
  }) => VerificationRule(
        provider: provider,
        metricKey: metricKey,
        comparator: comparator ?? this.comparator,
        threshold: threshold ?? this.threshold,
        unit: unit,
      );

  @override
  bool operator ==(Object other) =>
      other is VerificationRule &&
      other.provider == provider &&
      other.metricKey == metricKey &&
      other.comparator == comparator &&
      other.threshold == threshold &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(provider, metricKey, comparator, threshold, unit);

  @override
  String toString() =>
      'VerificationRule($metricKey ${comparator.wireName} $threshold ${unit.wireName})';
}
