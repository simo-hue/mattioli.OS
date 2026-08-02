import 'package:flutter/foundation.dart';

import 'habit_target.dart';
import 'target_axes.dart';
import 'target_verdict.dart';

/// How many past days a manual-target sweep looks back.
///
/// Larger than the verification reconcile's 7-day window because a limit habit's
/// quiet days are *genuine successes* that must be materialised into `goal_logs`
/// (a day with no consumption stayed under the cap), and a user may go a while
/// without opening the app. Bounding the window bounds the effect in BOTH
/// directions: the "opened the app after weeks away and got a free streak" for
/// limit habits, and — since auto-fail — the mirror image for count habits,
/// where the same absence returns as a wall of red. Days older than this stay
/// unmaterialised rather than retroactively filled either way. Tunable in one
/// place.
const int kManualTargetBackfillDays = 45;

/// One habit-day the sweep wants (re)applied so its verdict matches its stored
/// progress. Carries the day's progress [amount] (0 when there is no row) so the
/// caller can drive its normal `setProgress` path, which re-derives and persists
/// the verdict.
///
/// That is the path for every change EXCEPT a [verdictOnly] one, which has no
/// number to write and must not pretend otherwise. The two are still one writer
/// of `goal_logs` — the verdict-only path simply skips the `goal_progress` leg —
/// so there is no second progress→status mapping to keep in step, which is the
/// property that mattered.
@immutable
class TargetReconcileChange {
  final String goalId;
  final String dateKey;

  /// The progress to (re)apply for the day — `progressFor(dateKey) ?? 0`. For a
  /// quiet limit day this is 0, which the caller's setProgress resolves to a
  /// `done` verdict once the day is closed.
  ///
  /// Meaningless when [verdictOnly] is set: there was no row, so there is no
  /// number, and the 0 is a placeholder the caller must ignore rather than
  /// write. The constructor asserts the two agree.
  final double amount;

  /// True when this change was derived from a day with NO stored progress row —
  /// an untouched `atLeast` day at or after the auto-fail anchor.
  ///
  /// The caller MUST apply such a change by writing the VERDICT alone, never
  /// through its `setProgress` path. There is no number to store (that is the
  /// whole point: the user entered nothing), and `setProgress(0)` *deletes* the
  /// day's `goal_progress` row — so if the progress map were ever stale or
  /// mid-load, absence would be misread and a real count would be destroyed and
  /// its deletion tombstoned to sync. Writing only the verdict makes that class
  /// of loss structurally impossible: the worst case is a wrong status, which
  /// the next sweep re-derives from the surviving number.
  final bool verdictOnly;

  const TargetReconcileChange({
    required this.goalId,
    required this.dateKey,
    required this.amount,
    this.verdictOnly = false,
  }) : assert(!verdictOnly || amount == 0,
            'a verdict-only change has no stored number — a non-zero amount '
            'means it was built from a day that HAS one, and routing that '
            'through the verdict-only path would silently drop it');

  @override
  bool operator ==(Object other) =>
      other is TargetReconcileChange &&
      other.goalId == goalId &&
      other.dateKey == dateKey &&
      other.amount == amount &&
      other.verdictOnly == verdictOnly;

  @override
  int get hashCode => Object.hash(goalId, dateKey, amount, verdictOnly);

  @override
  String toString() =>
      'TargetReconcileChange($goalId, $dateKey, $amount'
      '${verdictOnly ? ', verdictOnly' : ''})';
}

/// Shifts [d] by [n] calendar days. Mirrors `_shiftDays` in both apps'
/// `streak_utils.dart`, and exists for the same reason: `add`/`subtract` take a
/// fixed 24-hour `Duration`, which is NOT a day across a DST transition.
///
/// The damage is easiest to follow by which END of the window each step touches
/// (measured under `Europe/Rome`, 2026):
///
///  * **Backward**, as `windowStart` did: 45×24h back from a local midnight in
///    summer time crosses the 23-hour day and lands an hour SHORT — at 23:00 of
///    the day before the intended one. The cursor then starts off-midnight, and
///    a 24h step from `03-28 23:00` clears the whole 23-hour day to land on
///    `03-30 00:00`. **2026-03-29 is never keyed at all** — for every one of the
///    45 days it should have been in reach. For a limit habit that means a day
///    it earned never becomes the `done` it earned: an unlogged scheduled day,
///    which breaks the streak, once a year, unrecoverably.
///  * **Forward**, as the cursor did when seeded from the habit's own start
///    date: a 24h step from `10-25 00:00` lands at `10-25 23:00`, still the SAME
///    date, so the 25-hour fall-back day is **keyed twice** and its change is
///    emitted (and applied) twice.
DateTime _shiftDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

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
///  * For an **atLeast** target a day with NO progress is skipped *unless*
///    [autoFailUnmetFrom] is set and the day is at or after it — see below.
///  * For an **atMost** (limit) target a no-progress day is a quiet SUCCESS and
///    resolves to `done` — this is the case the sweep exists for.
///  * A change is emitted only when the derived status differs from [statusFor]
///    (idempotent), so a second sweep over an already-resolved history is a
///    no-op.
///
/// [autoFailUnmetFrom] turns on **auto-fail for untouched count days**: a closed,
/// scheduled `atLeast` day the user never touched is a day they did zero of the
/// thing, so it resolves to `missed` exactly like a day they incremented and
/// then undid. Leaving it null keeps the historical behaviour (untouched days
/// stay absent, like a checkbox habit), which is what every caller that has not
/// opted in still gets.
///
/// It is an ANCHOR, not a flag, for one reason: without a cutoff, shipping the
/// rule would reach back over the whole backfill window and redden days a user
/// has already looked at and moved on from. Each app stamps it once, on the
/// first run of the build that carries this rule, so history is left exactly as
/// the user last saw it and only days that close from then on are scored.
///
/// Auto-fail applies to DAILY targets only. A weekly or monthly target's
/// individual day is not a period — scoring each one as a miss would invent six
/// failures a week for a "run 3× a week" habit. (No shipped preset builds a
/// non-daily target; the decoder accepts one, so legacy or synced data can.)
///
/// And it only ever fills an EMPTY verdict. A day whose `goal_logs` row already
/// says something, with no number behind it, was decided by a human — the habit
/// reminder's "Done" action writes precisely that shape — and auto-fail must not
/// read the missing count as a contradiction.
List<TargetReconcileChange> reconcileManualTargetDays({
  required String goalId,
  required HabitTarget target,
  required DateTime today,
  required DateTime start,
  DateTime? effectiveFrom,
  required bool Function(DateTime day) isScheduled,
  required double? Function(String dateKey) progressFor,
  required String? Function(String dateKey) statusFor,
  DateTime? autoFailUnmetFrom,
  int backfillDays = kManualTargetBackfillDays,
}) {
  if (!target.isUserEnterable) return const [];

  final todayD = DateTime(today.year, today.month, today.day);
  // The sweep never looks before the target's forward-only anchor (v11): editing
  // a target's amount, or switching a habit's tracking class, stamps
  // `effectiveFrom` = today, so already-materialised past days keep their verdict
  // instead of being re-derived against the new target. NULL ⇒ fall back to
  // `start`, so habits that predate the anchor are unaffected.
  final effStart = (effectiveFrom != null && effectiveFrom.isAfter(start))
      ? effectiveFrom
      : start;
  final startD = DateTime(effStart.year, effStart.month, effStart.day);
  final windowStart = _shiftDays(todayD, -backfillDays);
  var cursor = startD.isAfter(windowStart) ? startD : windowStart;

  final isAtLeast = target.direction == TargetDirection.atLeast;
  // Normalised to midnight so the comparison is by calendar day, and null unless
  // auto-fail genuinely applies to this target (see the doc comment: daily
  // targets only).
  final autoFailFrom =
      (autoFailUnmetFrom != null && target.period == TargetPeriod.day)
          ? DateTime(autoFailUnmetFrom.year, autoFailUnmetFrom.month,
              autoFailUnmetFrom.day)
          : null;
  final changes = <TargetReconcileChange>[];
  // Bounded by construction (window ≤ backfillDays), but guard against a
  // pathological start/today so a bad clock can't spin forever.
  var guard = 0;
  while (cursor.isBefore(todayD) && guard++ < backfillDays + 366) {
    if (isScheduled(cursor)) {
      final dateKey = targetDateKey(cursor);
      final progress = progressFor(dateKey);
      final storedStatus = statusFor(dateKey);
      // No row at all — for EITHER direction. A quiet limit day and an untouched
      // count day differ in the verdict they earn (`done` vs `missed`) but not in
      // what there is to write: nothing. Both must therefore take the
      // verdict-only path. Restricting this to `atLeast` would have left the
      // delete wide open on the limit path, which is the one with the documented
      // history of exactly this loss — see the guards in `sync_refresh.dart` and
      // the desktop `progressStale` check, both written after a sweep over an
      // unloaded map deleted real rows and tombstoned them to CloudKit.
      final noStoredNumber = progress == null;
      final untouchedCountDay = noStoredNumber && isAtLeast;
      // An untouched atLeast day stays absent before the auto-fail anchor (and
      // whenever no anchor is set) — don't invent a miss in a user's history.
      // From the anchor on it IS a miss: zero push-ups is zero push-ups whether
      // or not the user opened the sheet to say so.
      //
      // But auto-fail only ever FILLS a day that has no verdict; it never
      // overrules one. A stored status with no number behind it is a deliberate
      // human act — tapping "Done" on the reminder writes exactly that — and the
      // absence of a count is not evidence against it. (Days that DO carry a
      // number keep being re-derived below, so a stale verdict is still
      // corrected; it is only the no-number case that defers.)
      final skip = untouchedCountDay &&
          (autoFailFrom == null ||
              cursor.isBefore(autoFailFrom) ||
              storedStatus != null);
      if (!skip) {
        final verdict = evaluateTarget(
          target: target,
          progress: progress,
          periodIsOver: true,
        );
        if (verdict.logStatus != storedStatus) {
          changes.add(TargetReconcileChange(
            goalId: goalId,
            dateKey: dateKey,
            amount: progress ?? 0,
            // No row existed, so there is no number to write — verdict only.
            verdictOnly: noStoredNumber,
          ));
        }
      }
    }
    cursor = _shiftDays(cursor, 1);
  }
  return changes;
}
