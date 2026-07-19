import 'package:flutter/foundation.dart';

import 'day_verdict.dart';
import 'health_kit_bridge.dart';
import 'screen_time_bridge.dart';
import 'verification_provider.dart';
import 'verification_rule.dart';

/// A verifiable goal as the reconcile engine sees it (D4/D6/D9/D10).
@immutable
class VerifiableGoal {
  final String goalId;
  final VerificationRule rule;

  /// Earliest day verification applies: `max(goal.startDate, the day the rule
  /// was enabled/last edited)`. Rule edits are forward-only (D10), so moving
  /// this is how a threshold change takes effect without rewriting history.
  final DateTime effectiveFrom;

  /// ISO weekdays (1 = Mon … 7 = Sun) the goal is scheduled; empty = every day
  /// (D6). Off-days are never evaluated, nudged, or written.
  final Set<int> activeWeekdays;

  /// True for a Mode-A Screen Time goal (`screen_time_apps`) whose device-local
  /// `FamilyActivitySelection` can't be resolved — e.g. the goal was synced to a
  /// new device (the blob never syncs), a reinstall dropped it, or the picker
  /// was cancelled. Such a goal is *not* being monitored, so it must never emit
  /// a `pass`; reconcile treats it as "no signal" so it records couldn't-verify.
  final bool screenTimeSelectionMissing;

  const VerifiableGoal({
    required this.goalId,
    required this.rule,
    required this.effectiveFrom,
    this.activeWeekdays = const {},
    this.screenTimeSelectionMissing = false,
  });
}

/// What the caller already has persisted for a goal-day, so reconcile stays
/// idempotent (skip re-writing an unchanged verdict) and never overwrites a
/// frozen manual entry (D9).
@immutable
class ExistingDay {
  /// The terminal outcome already in `goal_logs` (done→pass, missed→fail), or
  /// null if there is no terminal row yet.
  final VerificationOutcome? loggedOutcome;

  /// Whether that row's provenance is manual. Manual entries win and freeze the
  /// day against all future auto-writes (D9).
  final bool manual;

  const ExistingDay({this.loggedOutcome, this.manual = false});
}

/// One idempotent write the caller should apply to `goal_logs` (pass→'done',
/// fail→'missed'), carrying the measured [value] for `goal_logs.value`.
@immutable
class LogWrite {
  final String goalId;
  final DateTime day;
  final VerificationOutcome outcome; // always pass or fail
  final double? value;

  const LogWrite({
    required this.goalId,
    required this.day,
    required this.outcome,
    this.value,
  });

  @override
  bool operator ==(Object other) =>
      other is LogWrite &&
      other.goalId == goalId &&
      other.day == day &&
      other.outcome == outcome &&
      other.value == value;

  @override
  int get hashCode => Object.hash(goalId, day, outcome, value);

  @override
  String toString() => 'LogWrite($goalId, $day, ${outcome.name}, value: $value)';
}

/// A couldn't-verify day for the local bookkeeping table, plus whether it's
/// still within the nag window and should prompt a manual-resolution nudge (D6).
@immutable
class CouldNotVerifyEntry {
  final String goalId;
  final DateTime day;
  final bool shouldNudge;

  const CouldNotVerifyEntry({
    required this.goalId,
    required this.day,
    required this.shouldNudge,
  });

  @override
  bool operator ==(Object other) =>
      other is CouldNotVerifyEntry &&
      other.goalId == goalId &&
      other.day == day &&
      other.shouldNudge == shouldNudge;

  @override
  int get hashCode => Object.hash(goalId, day, shouldNudge);

  @override
  String toString() =>
      'CouldNotVerifyEntry($goalId, $day, nudge: $shouldNudge)';
}

/// The applyable result of a reconcile pass. Pure data — the caller persists
/// [writes] to `goal_logs` (recomputing streak tails), records [couldNotVerify]
/// in the local table, and fires nudges. Keeping it declarative is what makes
/// the engine unit-testable without a database (D3/D7).
@immutable
class ReconcilePlan {
  final List<LogWrite> writes;
  final List<CouldNotVerifyEntry> couldNotVerify;

  const ReconcilePlan({
    this.writes = const [],
    this.couldNotVerify = const [],
  });

  bool get isEmpty => writes.isEmpty && couldNotVerify.isEmpty;
}

/// The device-free reconcile/verdict engine (D3/D6). Owns *all* decision logic;
/// the bridges only supply data. Lazy-on-foreground reconciliation is the
/// authoritative verdict path — background execution merely lowers latency.
class VerificationService {
  final HealthKitBridge health;
  final ScreenTimeBridge screenTime;

  /// How many days back a foreground reconcile settles (D6).
  final int backfillDays;

  /// How many days a couldn't-verify day keeps nudging before it goes quiet
  /// (D6).
  ///
  /// Defaults to 1 — a nudged day is only ever `today` or `yesterday`, which is
  /// exactly the **resolvable window** the rest of the design enforces: the "?"
  /// affordance renders only on `today`/`yesterday`
  /// (`couldNotVerifyDaysProvider`) and the day-details editor rejects anything
  /// before yesterday. A wider window (e.g. 2) would let `shouldNudge` fire for
  /// an age-2 day whose nudge tap dead-ends — no "?" to tap, and the cell
  /// refuses the edit. So the nag window must never exceed that resolvable
  /// window.
  final int nagWindowDays;

  const VerificationService({
    required this.health,
    required this.screenTime,
    this.backfillDays = 7,
    this.nagWindowDays = 1,
  });

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Next local calendar day. Uses `DateTime` day-overflow rather than
  /// `Duration(days: 1)` so iteration stays pinned to local midnight across DST
  /// transitions (a `Duration` day is a fixed 24h and would drift off midnight
  /// on the 23h/25h day, breaking the midnight-keyed lookups below).
  static DateTime _nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

  /// Pure decision table for one HealthKit day (D4/D6). Exposed static so it can
  /// be exhaustively unit-tested in isolation.
  ///
  /// - null value → pending (today) / couldn't-verify (past): a missing read is
  ///   never a false failure, since read-denial looks identical to zero.
  /// - atLeast: meeting the target passes immediately; below-target only fails
  ///   once the day is over (today it's still pending — you could get there).
  /// - atMost: exceeding fails immediately and permanently; staying under is
  ///   only final at day end (today it's pending — you could still exceed).
  @visibleForTesting
  static DayVerdict evaluateHealthDay({
    required VerificationRule rule,
    required double? measuredValue,
    required bool isToday,
  }) {
    if (measuredValue == null) {
      return isToday
          ? const DayVerdict.pending()
          : const DayVerdict.couldNotVerify();
    }
    final meets = rule.comparator == VerificationComparator.atLeast
        ? measuredValue >= rule.threshold
        : measuredValue <= rule.threshold;

    if (rule.comparator == VerificationComparator.atLeast) {
      if (meets) return DayVerdict.pass(measuredValue);
      return isToday
          ? DayVerdict.pending(measuredValue)
          : DayVerdict.fail(measuredValue);
    } else {
      if (!meets) return DayVerdict.fail(measuredValue);
      return isToday
          ? DayVerdict.pending(measuredValue)
          : DayVerdict.pass(measuredValue);
    }
  }

  /// Pure decision table for one Screen Time day (D2/D4). Driven by the
  /// extension's signal, not a query.
  static DayVerdict evaluateScreenTimeDay({
    required VerificationRule rule,
    required ScreenTimeSignalKind? signal,
    required bool isToday,
  }) {
    if (signal == null) {
      return isToday
          ? const DayVerdict.pending()
          : const DayVerdict.couldNotVerify();
    }

    if (rule.comparator == VerificationComparator.atLeast) {
      // Goal: At least X minutes.
      switch (signal) {
        case ScreenTimeSignalKind.reachedThreshold:
          return const DayVerdict.pass();
        case ScreenTimeSignalKind.stayedUnder:
          return const DayVerdict.fail();
      }
    } else {
      // Limit: At most X minutes.
      switch (signal) {
        case ScreenTimeSignalKind.reachedThreshold:
          return const DayVerdict.fail();
        case ScreenTimeSignalKind.stayedUnder:
          return const DayVerdict.pass();
      }
    }
  }

  bool _isScheduled(VerifiableGoal goal, DateTime day) =>
      goal.activeWeekdays.isEmpty || goal.activeWeekdays.contains(day.weekday);

  /// Runs one foreground reconcile pass over [goals] and returns an applyable
  /// [ReconcilePlan] (D3/D6). Drains Screen Time signals once, then walks each
  /// goal's scheduled days within the backfill window, honoring manual freezes
  /// (D9), forward-only effective dates (D10) and idempotency.
  Future<ReconcilePlan> reconcile({
    required List<VerifiableGoal> goals,
    required DateTime today,
    Map<String, Map<DateTime, ExistingDay>> existing = const {},
  }) async {
    final todayDate = _dateOnly(today);
    final writes = <LogWrite>[];
    final couldNotVerify = <CouldNotVerifyEntry>[];

    // Drain the extension's buffer once, only if any goal needs it (D3).
    final signalIndex = <String, Map<DateTime, ScreenTimeSignalKind>>{};
    if (goals.any((g) => g.rule.isScreenTime)) {
      for (final s in await screenTime.drainSignals()) {
        final byDay = signalIndex[s.goalId] ??= {};
        final day = _dateOnly(s.day);
        // A reached-threshold (fail) is sticky: the extension can deliver
        // duplicated/late/out-of-order signals (finding #4), and a stray
        // stayed-under must never overturn a real over-limit signal.
        if (byDay[day] == ScreenTimeSignalKind.reachedThreshold) continue;
        byDay[day] = s.kind;
      }
    }

    final windowStart = DateTime(
        todayDate.year, todayDate.month, todayDate.day - (backfillDays - 1));

    for (final goal in goals) {
      final from = _dateOnly(goal.effectiveFrom);
      var day = windowStart.isBefore(from) ? from : windowStart;

      while (!day.isAfter(todayDate)) {
        if (!_isScheduled(goal, day)) {
          day = _nextDay(day);
          continue;
        }
        final existingDay = existing[goal.goalId]?[day];

        // Manual entries freeze the day — reconcile never touches them (D9).
        if (existingDay?.manual ?? false) {
          day = _nextDay(day);
          continue;
        }

        final isToday = day == todayDate;
        final DayVerdict verdict;
        if (goal.rule.isHealthKit) {
          final template = goal.rule.template;
          final typeIdentifier =
              template?.healthKitTypeIdentifier ?? goal.rule.metricKey;
          final aggregation =
              template?.aggregation ?? VerificationAggregation.sum;
          final value = await health.dailyQuantity(
            typeIdentifier: typeIdentifier,
            aggregation: aggregation,
            day: day,
          );
          verdict = evaluateHealthDay(
            rule: goal.rule,
            measuredValue: value,
            isToday: isToday,
          );
        } else {
          // A Mode-A goal with no resolvable selection isn't being monitored:
          // force "no signal" so a stale monitor's stayed-under can never pass
          // it off — it records couldn't-verify (past) / pending (today).
          final signal = goal.screenTimeSelectionMissing
              ? null
              : signalIndex[goal.goalId]?[day];
          verdict = evaluateScreenTimeDay(
            rule: goal.rule,
            signal: signal,
            isToday: isToday,
          );
        }

        final existingOutcome = existingDay?.loggedOutcome;
        switch (verdict.outcome) {
          case VerificationOutcome.pass:
          case VerificationOutcome.fail:
            // A Screen Time threshold event (reachedThreshold) is permanent.
            // For Limits (atMost), `fail` is permanent.
            // For Goals (atLeast), `pass` is permanent.
            // A late/duplicate `stayedUnder` must never overturn it.
            final blockedFlip = goal.rule.isScreenTime &&
                ((goal.rule.comparator == VerificationComparator.atMost &&
                    existingOutcome == VerificationOutcome.fail &&
                    verdict.outcome == VerificationOutcome.pass) ||
                 (goal.rule.comparator == VerificationComparator.atLeast &&
                    existingOutcome == VerificationOutcome.pass &&
                    verdict.outcome == VerificationOutcome.fail));
            // Idempotent: only write when the verdict actually changed.
            if (!blockedFlip && existingOutcome != verdict.outcome) {
              writes.add(LogWrite(
                goalId: goal.goalId,
                day: day,
                outcome: verdict.outcome,
                value: verdict.measuredValue,
              ));
            }
          case VerificationOutcome.couldNotVerify:
            // Never contradict a day that already has a terminal verdict: Screen
            // Time signals are ephemeral (drained), so a resolved day re-reads as
            // "no signal" on later passes — that must not re-nudge (D3/D6).
            if (existingOutcome == null) {
              final ageDays = todayDate.difference(day).inDays;
              couldNotVerify.add(CouldNotVerifyEntry(
                goalId: goal.goalId,
                day: day,
                shouldNudge: ageDays <= nagWindowDays,
              ));
            }
          case VerificationOutcome.pending:
            break;
        }

        day = _nextDay(day);
      }
    }

    return ReconcilePlan(writes: writes, couldNotVerify: couldNotVerify);
  }
}
