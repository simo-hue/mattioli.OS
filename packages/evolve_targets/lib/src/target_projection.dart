import 'package:evolve_verification/evolve_verification.dart';

import 'habit_target.dart';
import 'target_axes.dart';

/// Projects an auto-verification rule into the equivalent [HabitTarget].
///
/// This is the unification. "10 000 steps" and "80 push-ups" are the same shape
/// of goal — a number to reach, over a day, in a unit — differing only in who
/// supplies the number. Projecting rather than storing means:
///
///  * a verified habit gets a progress ring for free, filled by the measurement
///    the reconcile pass already reads, instead of the empty checkbox it shows
///    today;
///  * there is ONE renderer, one formatter and one verdict table for both kinds,
///    so they cannot drift apart visually or semantically;
///  * nothing is written to the database. The rule stays the single source of
///    truth in its own columns, so no migration, no double-write, and no risk of
///    a projected copy disagreeing with the rule it came from.
///
/// Returns null when the rule's metric key is unknown to this build (a template
/// added by a newer client). The rule still verifies — the *native* side owns
/// that — but this build cannot claim to know how the metric aggregates, so it
/// declines to draw a ring rather than drawing a misleading one.
HabitTarget? targetFromVerificationRule(VerificationRule rule) {
  final template = rule.template;
  if (template == null) return null;
  return HabitTarget(
    fillSource: targetFillSourceForProvider(rule.provider),
    direction: rule.comparator,
    // Verification is per-day everywhere in the stack: the reconcile pass walks
    // days, the bridges query a day's samples, and a verdict materialises as one
    // `goal_logs` row per date.
    period: TargetPeriod.day,
    aggregation: template.aggregation,
    amount: rule.threshold,
    unit: rule.unit,
    // The threshold picker's granularity, reused so a projected target formats
    // its numbers the same way the rule editor does.
    step: template.step,
    // Meaningless for a measured source — nothing is hand-entered — but the
    // model is total rather than nullable. `HabitTarget.isUserEnterable` is the
    // predicate the UI must gate entry on; it is false for every projection.
    input: TargetInput.stepper,
  );
}

/// The target to DISPLAY for a habit, given whatever it has.
///
/// Precedence is explicit and deliberate: an own manual target wins over a
/// projected rule. The two are orthogonal — a habit may be auto-verified *and*
/// carry a manual count — and when both exist the manual one is the number the
/// user chose to watch, so it is the one that gets the ring.
///
/// [conditions] is the habit's full verification condition list (empty for a
/// manual habit, one for a single rule, 2–3 for a compound one). A compound
/// habit gets NO projected target: two conditions joined by OR have no single
/// meaningful fraction, and inventing one — the max? the first? — would show a
/// number the user could not act on. Compound habits keep their existing
/// per-condition display.
HabitTarget? displayTargetFor({
  required HabitTarget? ownTarget,
  required List<VerificationRule> conditions,
}) {
  if (ownTarget != null) return ownTarget;
  if (conditions.length != 1) return null;
  return targetFromVerificationRule(conditions.first);
}
