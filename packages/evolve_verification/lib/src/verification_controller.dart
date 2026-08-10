import 'package:flutter/foundation.dart';

import 'day_verdict.dart';
import 'screen_time_bridge.dart';
import 'verification_log_writer.dart';
import 'verification_service.dart';
import 'verification_state_store.dart';

/// Summary of one reconcile pass, for the caller (UI refresh + notifications).
@immutable
class ReconcileReport {
  /// The verdicts written to `goal_logs` this pass. Because [VerificationService]
  /// only emits a write when the verdict actually changed, this list is
  /// naturally de-duplicated across foregrounds — the notification layer can
  /// turn each one into a one-shot celebration/failure alert (D11) without its
  /// own bookkeeping.
  final List<LogWrite> writes;

  /// Days recorded as couldn't-verify this pass.
  final int couldNotVerify;

  /// The couldn't-verify days still inside the nag window — the notification
  /// layer turns these into "did you keep it?" nudges (D6/D11).
  final List<CouldNotVerifyEntry> nudges;


  const ReconcileReport({
    this.writes = const [],
    this.couldNotVerify = 0,
    this.nudges = const [],
  });

  /// Count of verdicts written to `goal_logs` this pass.
  int get written => writes.length;

  bool get changedAnything => writes.isNotEmpty || couldNotVerify > 0;
}

/// Orchestrates one lazy-on-foreground reconcile (D3): it assembles the
/// `existing` state the pure [VerificationService] needs (merging the app's
/// logged outcomes with the local manual-freeze bookkeeping), runs the engine,
/// then applies the resulting plan — writing verdicts through the
/// [VerificationLogWriter] and updating the [VerificationStateStore].
///
/// All side effects go through injected abstractions, so this is unit-testable
/// with fakes and carries no Flutter/storage/data-mode knowledge.
class VerificationController {
  final VerificationService service;
  final VerificationStateStore store;
  final VerificationLogWriter logWriter;

  VerificationController({
    required this.service,
    required this.store,
    required this.logWriter,
  });

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Reconciles [goals] as of [today]. [loggedOutcomes] is the app's current
  /// terminal state per goal-day (done→pass, missed→fail), typically derived
  /// from the in-memory habit-logs map.
  Future<ReconcileReport> reconcile({
    required List<VerifiableGoal> goals,
    required Map<String, Map<DateTime, VerificationOutcome>> loggedOutcomes,
    required DateTime today,
  }) async {
    if (goals.isEmpty) return const ReconcileReport();

    final todayDate = _dateOnly(today);
    final windowStart = DateTime(todayDate.year, todayDate.month,
        todayDate.day - (service.backfillDays - 1));

    // Manual freezes (D9) come from the local store; terminal outcomes come from
    // the app's logs. Merge them into the shape reconcile() consumes.
    final manual = await store.manualDays(
      goalIds: goals.map((g) => g.goalId),
      from: windowStart,
      to: todayDate,
    );

    final existing = <String, Map<DateTime, ExistingDay>>{};
    for (final goal in goals) {
      // Normalize logged keys to local-midnight up front so the merge below is
      // keyed consistently with the (already date-only) manual set — the
      // loggedOutcome can never be dropped, even for a day that is also manual.
      final rawLogged = loggedOutcomes[goal.goalId] ?? const {};
      final logged = <DateTime, VerificationOutcome>{
        for (final e in rawLogged.entries) _dateOnly(e.key): e.value,
      };
      final manualDays = manual[goal.goalId] ?? const <DateTime, String?>{};
      if (logged.isEmpty && manualDays.isEmpty) continue;

      final byDay = <DateTime, ExistingDay>{};
      for (final day in {...logged.keys, ...manualDays.keys}) {
        byDay[day] = ExistingDay(
          loggedOutcome: logged[day],
          manual: manualDays.containsKey(day),
          // The verdict the user chose, so a freeze whose row is not visible can
          // be restored rather than judged. An unrecognised status decodes to
          // null and the freeze is simply left alone — the same conservative
          // outcome as a pre-status freeze.
          manualOutcome: switch (manualDays[day]) {
            'done' => VerificationOutcome.pass,
            'missed' => VerificationOutcome.fail,
            _ => null,
          },
        );
      }
      existing[goal.goalId] = byDay;
    }

    final plan = await service.reconcile(
      goals: goals,
      today: today,
      existing: existing,
      signals: await _screenTimeSignals(goals, windowStart, todayDate),
    );

    // Only the writes that actually LANDED. A write that failed has changed
    // nothing, so it must not clear the day's "?" affordance and must not reach
    // the notification layer as a celebration — and the buffered signal behind
    // it stays put, so the next pass can derive the day again.
    final applied = <LogWrite>[];
    for (final w in plan.writes) {
      final ok = await logWriter.writeVerdict(
        goalId: w.goalId,
        day: w.day,
        outcome: w.outcome,
        value: w.value,
      );
      if (!ok) continue;
      applied.add(w);
      // A day that used to be couldn't-verify has now resolved.
      await store.resolveCouldNotVerify(w.goalId, w.day);
    }


    for (final c in plan.couldNotVerify) {
      await store.recordCouldNotVerify(c.goalId, c.day);
    }

    // Drop couldn't-verify markers that have aged out of the backfill window —
    // reconcile will never revisit them, so they'd otherwise linger forever.
    for (final goal in goals) {
      await store.pruneCouldNotVerifyBefore(goal.goalId, windowStart);
    }
    // Same for the buffered signals, and for the same reason. Global rather than
    // per-goal: a signal whose goal has since been deleted is never named by any
    // later pass, so a per-goal prune would leave it behind forever.
    await store.pruneScreenTimeSignalsBefore(windowStart);

    return ReconcileReport(
      writes: applied,
      couldNotVerify: plan.couldNotVerify.length,
      nudges: plan.couldNotVerify.where((c) => c.shouldNudge).toList(),
    );
  }

  /// The Screen Time signals this pass should reason about: whatever the
  /// extension has buffered since the last drain, UNIONED with whatever earlier
  /// passes drained and stored, resolved by the sticky `reachedThreshold` rule.
  ///
  /// Returns null when no goal is a Screen Time goal, which tells
  /// [VerificationService] to skip signals entirely (and, on the legacy path,
  /// not to drain). Draining for a HealthKit-only goal list would destroy the
  /// buffer of a Screen Time habit whose feature flag is currently off.
  ///
  /// Every store call is individually guarded. Persistence is a robustness
  /// mechanism, so a store that cannot be written or read must degrade to the
  /// old one-shot behaviour — this pass still holds the freshly drained rows in
  /// memory — rather than take the whole reconcile down with it.
  Future<Map<String, Map<DateTime, ScreenTimeSignalKind>>?> _screenTimeSignals(
    List<VerifiableGoal> goals,
    DateTime windowStart,
    DateTime todayDate,
  ) async {
    if (!goals.any((g) => g.rule.isScreenTime)) return null;

    final drained = await service.screenTime.drainSignals();
    // Written BEFORE anything can throw further down, because from the moment
    // the drain returned, this process holds the only copy in existence.
    if (drained.isNotEmpty) {
      try {
        await store.recordScreenTimeSignals(drained);
      } catch (_) {
        // Degrades to the pre-durability behaviour for this pass only: the rows
        // are still in `drained` below, so nothing is lost NOW — only the
        // ability to re-derive the day later.
      }
    }

    var stored = const <ScreenTimeSignal>[];
    try {
      stored = await store.screenTimeSignals(
        // A Mode-A goal whose device-local selection cannot be resolved is NOT
        // being monitored, so nothing may pass it off — the engine forces its
        // per-day lookup to "no signal" for exactly that reason. Excluding it
        // from the read-back keeps that suppression true of the BUFFER too:
        // before signals were durable the destructive drain made it permanent
        // by accident, and a replay would have handed a limit habit a `pass`
        // for a day nothing was watching.
        //
        // The rows are deliberately still WRITTEN (see above) and merely not
        // read: an unresolvable blob is often transient — a re-pick, a restored
        // prefs file — and destroying the evidence on a flag that may be a false
        // positive is the failure this whole buffer exists to prevent. Suppress
        // the read, keep the record.
        goalIds: goals
            .where((g) => !g.screenTimeSelectionMissing)
            .map((g) => g.goalId),
        from: windowStart,
        to: todayDate,
      );
    } catch (_) {
      // Fall through with `drained` alone.
    }

    final index = <String, Map<DateTime, ScreenTimeSignalKind>>{};
    // Order-independent by construction: `reachedThreshold` wins over
    // `stayedUnder` whichever arrives first, so merging the stored rows and the
    // freshly drained ones in either order gives the same answer.
    for (final s in [...stored, ...drained]) {
      final byDay = index[s.goalId] ??= {};
      final day = _dateOnly(s.day);
      if (byDay[day] == ScreenTimeSignalKind.reachedThreshold) continue;
      byDay[day] = s.kind;
    }
    return index;
  }
}
