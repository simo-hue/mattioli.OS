import 'target_axes.dart';
import 'target_preset.dart';

/// Something wrong (or merely odd) about an amount/step combination the user
/// typed into the habit creation UI.
///
/// The UI owns the wording — this package must not import i18n — so each case
/// carries only the numbers a message needs. Blocking cases are the ones where
/// the habit would not FUNCTION; everything else is legal and merely likely to
/// surprise, so it warns and lets the user proceed.
enum TargetIssueKind {
  /// The amount is outside the preset's supported range. Blocking: the value
  /// cannot be stored honestly.
  amountOutOfRange,

  /// A zero, negative, or empty step. Blocking: the `+` button would be inert,
  /// which is not a habit the user can log.
  stepNotPositive,

  /// One tap would overshoot the whole goal (step > amount). Legal — someone
  /// may want a single-tap day — but usually a typo.
  ///
  /// Note step EQUAL to the amount is fine and never reported: "at most 1
  /// coffee, step 1" is exactly right.
  stepExceedsAmount,

  /// The amount is not a whole number of steps, so no sequence of taps lands on
  /// it exactly. Goal 80 with step 30 reaches 60 then 90 — never 80.
  amountNotDivisibleByStep,

  /// Completing one day would take an impractical number of taps. Only reported
  /// for `atLeast` targets: for a limit ("at most 1440 minutes") you are not
  /// tapping your way to the cap, so the count is meaningless there.
  tooManyTaps,
}

extension TargetIssueKindX on TargetIssueKind {
  /// Whether this must be fixed before the habit can be saved.
  bool get isBlocking =>
      this == TargetIssueKind.amountOutOfRange ||
      this == TargetIssueKind.stepNotPositive;
}

/// One issue, with the numbers its message needs.
class TargetIssue {
  const TargetIssue(this.kind, {this.lowerBound, this.upperBound, this.taps});

  final TargetIssueKind kind;

  /// For [TargetIssueKind.amountOutOfRange]: the preset's limits.
  /// For [TargetIssueKind.amountNotDivisibleByStep]: the two reachable amounts
  /// either side of the requested one, so the UI can say "nearest are 60 and 90"
  /// instead of merely reporting a problem.
  final double? lowerBound;
  final double? upperBound;

  /// For [TargetIssueKind.tooManyTaps]: how many taps a full day would need.
  final int? taps;

  bool get isBlocking => kind.isBlocking;

  @override
  String toString() =>
      'TargetIssue(${kind.name}, lower: $lowerBound, upper: $upperBound, taps: $taps)';
}

/// Above this many taps to complete one day, [TargetIssueKind.tooManyTaps] is
/// reported. 80 push-ups in sets of 20 is 4 taps; 100 in steps of 1 is 100.
///
/// A judgement call, deliberately generous: the point is to catch "you will tap
/// this a hundred times a day", not to police anyone's preference.
const int kMaxReasonableTaps = 25;

/// Doubles compare with a tolerance because amounts can be fractional (the
/// coffee limit's minimum is 0.5), and 80 % 0.1 is not exactly 0 in binary
/// floating point.
const double _epsilon = 1e-9;

/// Validates a typed amount/step pair against its preset.
///
/// Returns every issue found, blocking ones first. An empty list means the
/// combination is sound. Pure and UI-free so both apps score it identically —
/// the two clients disagreeing about what is valid is exactly the drift this
/// package exists to prevent.
List<TargetIssue> validateHabitTarget({
  required TargetPreset preset,
  required double? amount,
  required double? step,
}) {
  final issues = <TargetIssue>[];

  // A null amount means the field is empty/unparseable. Treat it as out of
  // range rather than inventing a value.
  if (amount == null ||
      amount < preset.minAmount - _epsilon ||
      amount > preset.maxAmount + _epsilon) {
    issues.add(TargetIssue(
      TargetIssueKind.amountOutOfRange,
      lowerBound: preset.minAmount,
      upperBound: preset.maxAmount,
    ));
  }

  if (step == null || step <= _epsilon) {
    issues.add(const TargetIssue(TargetIssueKind.stepNotPositive));
  }

  // The remaining checks are relationships, so they need both numbers to be
  // present and individually sane. Reporting "80 is not divisible by 0" on top
  // of "the step cannot be 0" would be noise.
  if (issues.isNotEmpty || amount == null || step == null) return issues;

  if (step > amount + _epsilon) {
    issues.add(const TargetIssue(TargetIssueKind.stepExceedsAmount));
  } else {
    final taps = amount / step;
    final whole = taps.roundToDouble();
    if ((taps - whole).abs() > 1e-6) {
      // Report the reachable amounts either side, so the message can be
      // actionable rather than merely correct.
      final below = (taps.floorToDouble()) * step;
      final above = (taps.ceilToDouble()) * step;
      issues.add(TargetIssue(
        TargetIssueKind.amountNotDivisibleByStep,
        lowerBound: below > 0 ? below : null,
        upperBound: above,
      ));
    }

    // Only meaningful when you are tapping TOWARDS something.
    if (preset.direction == TargetDirection.atLeast &&
        taps > kMaxReasonableTaps) {
      issues.add(TargetIssue(
        TargetIssueKind.tooManyTaps,
        taps: taps.ceil(),
      ));
    }
  }

  return issues;
}
