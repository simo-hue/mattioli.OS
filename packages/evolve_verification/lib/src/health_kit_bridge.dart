import 'verification_provider.dart';

/// Authorization state we can *observe* for HealthKit.
///
/// NOTE: for **read** access Apple deliberately never reports `denied` — a
/// denied type is indistinguishable from one that simply has no data. So this
/// enum is only meaningfully populated for share/write flows; the reconcile
/// engine infers read-denial from a run of couldn't-verify days instead (D9).
enum HealthAuthorizationStatus { notDetermined, authorized, denied }

/// Thin, query-based contract over native HealthKit (D7).
///
/// The real implementation is a MethodChannel to Swift living in `mobile/`;
/// tests use an in-memory fake. All reconcile/verdict logic lives above this in
/// [VerificationService], so it is unit-testable without a device.
abstract interface class HealthKitBridge {
  /// Whether HealthKit exists on this device at all (false on iPad/macOS).
  Future<bool> isHealthDataAvailable();

  /// Requests read authorization for the given Apple sample identifiers
  /// (incremental — call again for new types as goals are added, per D9).
  Future<void> requestAuthorization(Set<String> typeIdentifiers);

  /// The aggregated quantity for [typeIdentifier] over the local calendar day
  /// [day], or **null** when there is no data / it cannot be determined.
  ///
  /// Null routes the day to [VerificationOutcome.couldNotVerify] (for a past
  /// day) or [VerificationOutcome.pending] (for today) — never to a false
  /// `missed` — because null and "read denied" are indistinguishable.
  Future<double?> dailyQuantity({
    required String typeIdentifier,
    required VerificationAggregation aggregation,
    required DateTime day,
  });

  /// Whether any sample of [typeIdentifier] exists within the last [withinDays]
  /// days. Powers the creation-time "needs an Apple Watch to auto-verify" probe
  /// for Watch-dependent templates (D5/D9).
  Future<bool> hasRecentData({
    required String typeIdentifier,
    required int withinDays,
  });
}
