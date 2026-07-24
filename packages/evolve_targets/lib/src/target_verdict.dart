import 'package:flutter/foundation.dart';

import 'habit_target.dart';
import 'target_axes.dart';

/// What a period's accumulated progress means for a target.
///
/// Mirrors `DayVerdict`'s vocabulary on purpose: a target and an auto-verified
/// rule must reach the same conclusion from the same numbers, or a habit that is
/// both counted and measured would contradict itself.
enum TargetOutcome {
  /// The period is still open and the target is not yet decided.
  pending,

  /// The target was reached (`atLeast`) or survived (`atMost`).
  met,

  /// The period closed short of an `atLeast` target.
  unmet,

  /// An `atMost` target was exceeded. Sticky: exceeding a ceiling cannot be
  /// undone by the rest of the period.
  breached,

  /// A measured target whose source produced no number for a closed period —
  /// the equivalent of "couldn't verify". Never applies to a manual target,
  /// where the absence of an entry is itself the number (zero).
  unknown;

  /// Whether the period is decided.
  bool get isTerminal => this != TargetOutcome.pending;

  /// Whether the user succeeded.
  bool get isSuccess => this == TargetOutcome.met;
}

/// A target evaluated against one period's accumulated progress.
@immutable
class TargetVerdict {
  final TargetOutcome outcome;

  /// Progress as a share of the target, clamped to `0..1` — what a ring fills
  /// to. For an `atMost` target this is the share of the allowance CONSUMED, so
  /// a full ring means trouble rather than triumph; the UI colours it by
  /// [TargetVerdict.outcome], never by fullness alone.
  final double fraction;

  /// The same ratio unclamped, so "160 % of target" can be shown as an
  /// overachievement (or an overrun) rather than silently flattened to 100 %.
  final double rawFraction;

  /// The number actually used for the comparison — [effectiveProgress] is the
  /// caller's raw progress with a manual absence resolved to zero.
  final double effectiveProgress;

  const TargetVerdict({
    required this.outcome,
    required this.fraction,
    required this.rawFraction,
    required this.effectiveProgress,
  });

  /// The `goal_logs.status` this verdict materialises as, or **null** when no
  /// log row should exist yet.
  ///
  /// This is the ONLY place the progress→status mapping lives. Both apps route
  /// through it, because the recon found the status transition independently
  /// re-implemented in six places (controller prediction, repository base,
  /// Supabase override, private override, and both notification writers) — a
  /// value-dependent verdict that landed in five of the six would be a silent,
  /// per-surface disagreement about whether a day is done.
  ///
  /// `pending`/`unknown` map to null — *no row* — which is what keeps a
  /// half-finished day out of every rate denominator. The day's number still
  /// exists and still renders: it lives in `goal_progress`, not `goal_logs`.
  String? get logStatus => switch (outcome) {
        TargetOutcome.met => 'done',
        TargetOutcome.unmet || TargetOutcome.breached => 'missed',
        TargetOutcome.pending || TargetOutcome.unknown => null,
      };

  @override
  bool operator ==(Object other) =>
      other is TargetVerdict &&
      other.outcome == outcome &&
      other.fraction == fraction &&
      other.rawFraction == rawFraction &&
      other.effectiveProgress == effectiveProgress;

  @override
  int get hashCode =>
      Object.hash(outcome, fraction, rawFraction, effectiveProgress);

  @override
  String toString() =>
      'TargetVerdict(${outcome.name}, $effectiveProgress, ${(fraction * 100).round()}%)';
}

/// Evaluates [target] against the [progress] accumulated so far in a period
/// that is [periodIsOver] or not.
///
/// The decision table is deliberately identical to the shipped auto-verified one
/// (`VerificationService`), with exactly one source-dependent difference — the
/// meaning of "no data":
///
/// | progress | manual | measured |
/// |---|---|---|
/// | absent, period open | treated as 0 | `pending` |
/// | absent, period closed | treated as 0 | `unknown` |
///
/// That difference is the whole feature. A manual limit habit with no entries
/// means "I consumed nothing", so a closed day resolves to `met` — the user
/// succeeds by doing nothing, which is the point of a limit. A *measured* limit
/// habit with no samples means the sensor said nothing, which is not evidence of
/// success and must not be scored as one.
///
/// `atLeast` resolves to `met` the instant the target is reached; `atMost`
/// cannot resolve to `met` before the period closes, because staying under a
/// ceiling is only knowable at the end. Both match the shipped behaviour.
TargetVerdict evaluateTarget({
  required HabitTarget target,
  required double? progress,
  required bool periodIsOver,
}) {
  // No number at all from a sensor is not zero — it is silence.
  if (progress == null && target.isMeasured) {
    return TargetVerdict(
      outcome: periodIsOver ? TargetOutcome.unknown : TargetOutcome.pending,
      fraction: 0,
      rawFraction: 0,
      effectiveProgress: 0,
    );
  }

  final effective = progress ?? 0;
  // `amount` is guaranteed positive by the decoder and by TargetPreset, so this
  // division is safe; the guard is belt-and-braces for a hand-built target.
  final raw = target.amount > 0 ? effective / target.amount : 0.0;
  final fraction = raw.clamp(0.0, 1.0).toDouble();

  final TargetOutcome outcome;
  switch (target.direction) {
    case TargetDirection.atLeast:
      if (effective >= target.amount) {
        outcome = TargetOutcome.met;
      } else {
        outcome = periodIsOver ? TargetOutcome.unmet : TargetOutcome.pending;
      }
    case TargetDirection.atMost:
      if (effective > target.amount) {
        // Sticky, and decided immediately: once the ceiling is crossed the rest
        // of the period cannot redeem it.
        outcome = TargetOutcome.breached;
      } else {
        outcome = periodIsOver ? TargetOutcome.met : TargetOutcome.pending;
      }
  }

  return TargetVerdict(
    outcome: outcome,
    fraction: fraction,
    rawFraction: raw,
    effectiveProgress: effective,
  );
}

/// Progress after one tap of the stepper (or one `+` press).
///
/// Rounded to a sane number of decimals so repeated fractional steps (0.1 km)
/// cannot accumulate binary floating-point dust into "4.999999999 km" on a ring
/// the user expects to read 5.
double progressAfterIncrement(HabitTarget target, double? current) =>
    _round(( current ?? 0) + target.step);

/// Progress after one undo of the stepper, floored at zero — a counter can
/// never go negative, and an over-decrement is a slip of the thumb, not an
/// instruction to invent negative push-ups.
double progressAfterDecrement(HabitTarget target, double? current) {
  final next = (current ?? 0) - target.step;
  return next <= 0 ? 0 : _round(next);
}

/// Rounds to 3 decimals — finer than any unit in [TargetUnit] displays, coarse
/// enough to erase accumulated floating-point error.
double _round(double v) => (v * 1000).roundToDouble() / 1000;
