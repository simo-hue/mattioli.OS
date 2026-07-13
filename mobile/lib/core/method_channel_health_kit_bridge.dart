import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/services.dart';

/// Production [HealthKitBridge] over a MethodChannel to native Swift
/// (`evolve/healthkit`). It marshals the contract only — all reconcile/verdict
/// logic stays in Dart (`VerificationService`).
///
/// Degrades **safely** when the native plugin is absent (feature flag off, or a
/// Screen-Time-only build): reads return null/false and mutations no-op, so a
/// missing plugin can never crash the app or fabricate a verdict. A null
/// [dailyQuantity] is exactly what routes a day to couldn't-verify/pending.
///
/// The day is passed as an explicit local `[startMs, endMs)` epoch-millisecond
/// window (computed with DST-safe calendar math) so the native `HKStatisticsQuery`
/// predicate is unambiguous across the channel.
class MethodChannelHealthKitBridge implements HealthKitBridge {
  static const MethodChannel channel = MethodChannel('evolve/healthkit');

  const MethodChannelHealthKitBridge();

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _dayEnd(DateTime d) => DateTime(d.year, d.month, d.day + 1);

  @override
  Future<bool> isHealthDataAvailable() async {
    try {
      final v = await channel.invokeMethod<bool>('isHealthDataAvailable');
      return v ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> requestAuthorization(Set<String> typeIdentifiers) async {
    try {
      await channel.invokeMethod<void>('requestAuthorization', {
        'types': typeIdentifiers.toList(),
      });
    } on MissingPluginException {
      // no-op: authorization simply hasn't been granted.
    }
  }

  @override
  Future<double?> dailyQuantity({
    required String typeIdentifier,
    required VerificationAggregation aggregation,
    required DateTime day,
  }) async {
    try {
      final v = await channel.invokeMethod('dailyQuantity', {
        'type': typeIdentifier,
        'aggregation': aggregation.wireName,
        'startMs': _dayStart(day).millisecondsSinceEpoch,
        'endMs': _dayEnd(day).millisecondsSinceEpoch,
      });
      // Coerce int/double NSNumber → double; null (no data / can't determine)
      // passes straight through.
      return (v as num?)?.toDouble();
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> hasRecentData({
    required String typeIdentifier,
    required int withinDays,
  }) async {
    try {
      final v = await channel.invokeMethod<bool>('hasRecentData', {
        'type': typeIdentifier,
        'withinDays': withinDays,
      });
      return v ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
