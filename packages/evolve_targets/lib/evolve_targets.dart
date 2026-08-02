/// Pure-Dart core for quantitative habit targets on the Evolve apps.
///
/// A habit today is a checkbox: done, missed, or nothing. A *target* gives it a
/// number — 80 push-ups, 20 minutes, at most one coffee — and this package owns
/// what that number means everywhere it is read.
///
/// Four axes, not four habit types: [TargetDirection] (reach it / stay under
/// it), [TargetPeriod] (day / week / month), [TargetAggregation] (sum / count)
/// and [TargetFillSource] (typed by the user / measured by HealthKit / measured
/// by Screen Time). Every kind the app offers is a point in that space, chosen
/// through a curated [TargetPreset] so the matrix never reaches the user. A new
/// kind is a new preset, not a new code path.
///
/// The direction/unit/aggregation enums are ALIASES of `evolve_verification`'s,
/// so a manually-counted target and an auto-verified threshold share one wire
/// vocabulary and one verdict table — and [targetFromVerificationRule] projects
/// the latter into the former, which is what lets both render as the same ring.
library;

export 'src/auto_fail_anchor.dart';
export 'src/habit_target.dart';
export 'src/macro_goal_progress.dart';
export 'src/target_axes.dart';
export 'src/target_preset.dart';
export 'src/target_projection.dart';
export 'src/target_validation.dart';
export 'src/target_reconcile.dart';
export 'src/target_verdict.dart';
