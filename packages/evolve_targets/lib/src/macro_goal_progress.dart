import 'package:flutter/foundation.dart';

import 'target_axes.dart';

/// A cumulative macro goal's progress toward its numeric target, computed once
/// so every surface (the ring, the "320 / 500 km" label, the completed check)
/// reads the same numbers.
///
/// A macro goal is a "reach it" (`atLeast`) target by construction — "run 500
/// km this year", "read 24 books". There is deliberately no `atMost` polarity
/// here (a limit is a habit concept, not a macro-goal one), so [isComplete] is
/// simply "reached the amount" and the ring never inverts its meaning the way a
/// [HabitTarget] limit ring does.
@immutable
class MacroGoalProgress {
  /// The effective progress value — the linked habit's summed contribution when
  /// the goal is fed by a habit, else the stored manual value. Already resolved
  /// by [evaluateMacroGoalProgress]; never negative.
  final double amount;

  /// The number to reach.
  final double target;

  /// The unit both [amount] and [target] are expressed in, carried through for
  /// the label ("320 / 500 km"). Purely presentational — the arithmetic here is
  /// unit-agnostic. Null when the goal stored no unit.
  final TargetUnit? unit;

  /// Progress as a share of the target, clamped to `0..1` — what the bar fills
  /// to. Zero when the target is non-positive (a guard; a real target is always
  /// positive).
  final double fraction;

  /// The same ratio unclamped, so "140 % of target" can be shown as an
  /// overachievement rather than flattened to 100 %.
  final double rawFraction;

  /// Whether the goal has reached (or passed) its target.
  final bool isComplete;

  const MacroGoalProgress({
    required this.amount,
    required this.target,
    required this.unit,
    required this.fraction,
    required this.rawFraction,
    required this.isComplete,
  });

  @override
  bool operator ==(Object other) =>
      other is MacroGoalProgress &&
      other.amount == amount &&
      other.target == target &&
      other.unit == unit &&
      other.fraction == fraction &&
      other.rawFraction == rawFraction &&
      other.isComplete == isComplete;

  @override
  int get hashCode =>
      Object.hash(amount, target, unit, fraction, rawFraction, isComplete);

  @override
  String toString() => 'MacroGoalProgress($amount/$target '
      '${unit?.wireName ?? ''}, ${(fraction * 100).round()}%)';
}

/// The effective progress amount for a macro goal — DERIVED from the linked
/// habit when [isLinked], else the STORED manual value.
///
/// This is the one place the "linked ⇒ sum the habit, unlinked ⇒ read the
/// stored number" rule lives, so a display path and a snapshot-on-unlink path
/// cannot disagree about which source wins. Both inputs default to zero when
/// absent: a linked goal with no logged progress reads as 0, and a manual goal
/// that was never advanced reads as 0. Never negative — a stray negative stored
/// value (corruption / a hand-built row) floors at 0.
///
/// [linkedSum] is the sum of the linked habit's `goal_progress.amount` over the
/// macro goal's period; computing it is a database query, so it is passed in
/// rather than computed here (this stays pure and unit-testable).
double resolveMacroProgressAmount({
  required bool isLinked,
  double? storedAmount,
  double? linkedSum,
}) {
  final raw = isLinked ? (linkedSum ?? 0) : (storedAmount ?? 0);
  return raw < 0 ? 0 : raw;
}

/// Evaluates a macro goal's [targetAmount] against its progress, resolving the
/// source ([isLinked] picks [linkedSum] over [storedAmount]) and computing the
/// completion fraction in one step.
///
/// Returns null when [targetAmount] is null or non-positive — i.e. an ordinary
/// boolean macro goal, or a corrupt/hand-built one with no meaningful target.
/// Callers treat a null result as "no numeric target, render the plain boolean
/// goal", exactly as a null [targetAmount] means today.
MacroGoalProgress? evaluateMacroGoalProgress({
  required double? targetAmount,
  TargetUnit? unit,
  required bool isLinked,
  double? storedAmount,
  double? linkedSum,
}) {
  if (targetAmount == null || !targetAmount.isFinite || targetAmount <= 0) {
    return null;
  }
  final amount = resolveMacroProgressAmount(
    isLinked: isLinked,
    storedAmount: storedAmount,
    linkedSum: linkedSum,
  );
  final raw = amount / targetAmount;
  final fraction = raw.clamp(0.0, 1.0).toDouble();
  return MacroGoalProgress(
    amount: amount,
    target: targetAmount,
    unit: unit,
    fraction: fraction,
    rawFraction: raw,
    isComplete: amount >= targetAmount,
  );
}
