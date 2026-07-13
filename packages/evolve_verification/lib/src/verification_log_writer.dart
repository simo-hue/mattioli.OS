import 'day_verdict.dart';

/// Persists a verified verdict to the streak-bearing log (the app's `goal_logs`).
///
/// The implementation maps [VerificationOutcome.pass] → `'done'` and
/// [VerificationOutcome.fail] → `'missed'`, carries [value] into
/// `goal_logs.value` (the HealthKit measured number; null for Screen Time), and
/// is responsible for recomputing the streak tail from [day] forward (D10).
/// Kept as an interface so the [VerificationController] stays free of any
/// data-mode / storage concerns and is unit-testable with a fake.
abstract interface class VerificationLogWriter {
  /// Writes (or overwrites) the verdict for ([goalId], [day]). Idempotent — the
  /// controller only calls this when the verdict actually changed, but a
  /// repeated call must be harmless.
  Future<void> writeVerdict({
    required String goalId,
    required DateTime day,
    required VerificationOutcome outcome, // pass or fail only
    double? value,
  });
}
