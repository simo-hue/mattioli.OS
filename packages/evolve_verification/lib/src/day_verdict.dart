import 'package:flutter/foundation.dart';

/// The resolved (or not-yet-resolved) state of one goal-day (D4).
enum VerificationOutcome {
  /// Not yet resolvable: the day is still in progress, or we're awaiting a
  /// Screen Time signal. No `goal_logs` row is written.
  pending,

  /// Verified success → written to `goal_logs` as `'done'`.
  pass,

  /// Verified failure → written to `goal_logs` as `'missed'`.
  fail,

  /// The day ended without a definitive signal (permission off, no data, the
  /// extension never fired). No `goal_logs` row; recorded in the local
  /// bookkeeping table and surfaced as a "did you keep it?" nudge.
  couldNotVerify;
}

/// The outcome of evaluating a single goal-day, plus the measured number when
/// one exists.
@immutable
class DayVerdict {
  final VerificationOutcome outcome;

  /// The measured quantity (e.g. 12043 steps) for HealthKit verdicts →
  /// persisted to `goal_logs.value`. Always null for Screen Time (the raw
  /// number is not obtainable) and for pending/couldn't-verify days.
  final double? measuredValue;

  const DayVerdict(this.outcome, {this.measuredValue});

  const DayVerdict.pending([double? value])
      : this(VerificationOutcome.pending, measuredValue: value);
  const DayVerdict.pass([double? value])
      : this(VerificationOutcome.pass, measuredValue: value);
  const DayVerdict.fail([double? value])
      : this(VerificationOutcome.fail, measuredValue: value);
  const DayVerdict.couldNotVerify() : this(VerificationOutcome.couldNotVerify);

  bool get isTerminal =>
      outcome == VerificationOutcome.pass || outcome == VerificationOutcome.fail;

  @override
  bool operator ==(Object other) =>
      other is DayVerdict &&
      other.outcome == outcome &&
      other.measuredValue == measuredValue;

  @override
  int get hashCode => Object.hash(outcome, measuredValue);

  @override
  String toString() => 'DayVerdict(${outcome.name}, value: $measuredValue)';
}
