import 'package:flutter/foundation.dart';

import 'habit_target.dart';
import 'target_axes.dart';
import 'target_verdict.dart';

/// How many past days a manual-target sweep looks back.
///
/// Larger than the verification reconcile's 7-day window because a limit habit's
/// quiet days are *genuine successes* that must be materialised into `goal_logs`
/// (a day with no consumption stayed under the cap), and a user may go a while
/// without opening the app. Bounding the window also bounds the "opened the app
/// after weeks away and got a free streak" effect — days older than this stay
/// unmaterialised rather than retroactively filled. Tunable in one place.
const int kManualTargetBackfillDays = 45;

/// One habit-day the sweep wants (re)applied so its verdict matches its stored
/// progress. Carries the day's progress [amount] (0 when there is no row) so the
/// caller can drive its normal `setProgress` path, which re-derives and persists
/// the verdict — one write path, not a second one to keep in step.
@immutable
class TargetReconcileChange {
  final String goalId;
  final String dateKey;

  /// The progress to (re)apply for the day — `progressFor(dateKey) ?? 0`. For a
  /// quiet limit day this is 0, which the caller's setProgress resolves to a
  /// `done` verdict once the day is closed.
  final double amount;

  const TargetReconcileChange({
    required this.goalId,
    required this.dateKey,
    required this.amount,
  });

  @override
  bool operator ==(Object other) =>
      other is TargetReconcileChange &&
      other.goalId == goalId &&
      other.dateKey == dateKey &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(goalId, dateKey, amount);

  @override
  String toString() =>
      'TargetReconcileChange($goalId, $dateKey, $amount)';
}

/// Canonical `YYYY-MM-DD` day key. MUST match the key both apps build for
/// `goal_logs`/`goal_progress` (`dashboardDateKey` on desktop, the inline key on
/// mobile) so [progressFor]/[statusFor] lookups resolve against the same string.
String targetDateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Computes the verdict changes so every CLOSED, scheduled day in the backfill
/// window reflects a manual target's stored progress — the end-of-day resolution
/// a live increment cannot do for a day that closed while the app was shut.
///
/// Pure: the caller supplies the schedule predicate and the per-day lookups, and
/// applies the returned changes through its own `setProgress` path (both apps
/// share this function). Returns an empty list for a measured target — a
/// HealthKit/Screen Time ring is resolved by the verification pipeline, never
/// here.
///
/// The rules, in order:
///  * Only CLOSED days (strictly before [today]); today's verdict is derived
///    live by the increment path, so re-deriving it here would fight that.
///  * The window starts at `max(start, today - backfillDays)` — never before the
///    habit's own start date.
///  * Off-schedule days are skipped: they never carry a verdict (the documented
///    hide-off-day invariant on both platforms).
///  * For an **atLeast** target a day with NO progress is skipped, so an
///    untouched day stays absent (parity with a checkbox habit) rather than
///    being sprayed with `missed`; its streak already breaks on the absent row.
///  * For an **atMost** (limit) target a no-progress day is a quiet SUCCESS and
///    resolves to `done` — this is the case the sweep exists for.
///  * A change is emitted only when the derived status differs from [statusFor]
///    (idempotent), so a second sweep over an already-resolved history is a
///    no-op.
List<TargetReconcileChange> reconcileManualTargetDays({
  required String goalId,
  required HabitTarget target,
  required DateTime today,
  required DateTime start,
  required bool Function(DateTime day) isScheduled,
  required double? Function(String dateKey) progressFor,
  required String? Function(String dateKey) statusFor,
  int backfillDays = kManualTargetBackfillDays,
}) {
  if (!target.isUserEnterable) return const [];

  final todayD = DateTime(today.year, today.month, today.day);
  final startD = DateTime(start.year, start.month, start.day);
  final windowStart = todayD.subtract(Duration(days: backfillDays));
  var cursor = startD.isAfter(windowStart) ? startD : windowStart;

  final isAtLeast = target.direction == TargetDirection.atLeast;
  final changes = <TargetReconcileChange>[];
  // Bounded by construction (window ≤ backfillDays), but guard against a
  // pathological start/today so a bad clock can't spin forever.
  var guard = 0;
  while (cursor.isBefore(todayD) && guard++ < backfillDays + 366) {
    if (isScheduled(cursor)) {
      final dateKey = targetDateKey(cursor);
      final progress = progressFor(dateKey);
      // An untouched atLeast day stays absent — don't invent a miss.
      if (!(progress == null && isAtLeast)) {
        final verdict = evaluateTarget(
          target: target,
          progress: progress,
          periodIsOver: true,
        );
        if (verdict.logStatus != statusFor(dateKey)) {
          changes.add(TargetReconcileChange(
            goalId: goalId,
            dateKey: dateKey,
            amount: progress ?? 0,
          ));
        }
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  return changes;
}
