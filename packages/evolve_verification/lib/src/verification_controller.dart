import 'package:flutter/foundation.dart';

import 'day_verdict.dart';
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
      final manualSet = manual[goal.goalId] ?? const <DateTime>{};
      if (logged.isEmpty && manualSet.isEmpty) continue;

      final byDay = <DateTime, ExistingDay>{};
      for (final day in {...logged.keys, ...manualSet}) {
        byDay[day] = ExistingDay(
          loggedOutcome: logged[day],
          manual: manualSet.contains(day),
        );
      }
      existing[goal.goalId] = byDay;
    }

    final plan = await service.reconcile(
      goals: goals,
      today: today,
      existing: existing,
    );

    for (final w in plan.writes) {
      await logWriter.writeVerdict(
        goalId: w.goalId,
        day: w.day,
        outcome: w.outcome,
        value: w.value,
      );
      // A day that used to be couldn't-verify has now resolved.
      await store.resolveCouldNotVerify(w.goalId, w.day);
    }

    for (final c in plan.couldNotVerify) {
      await store.recordCouldNotVerify(c.goalId, c.day);
    }

    return ReconcileReport(
      writes: plan.writes,
      couldNotVerify: plan.couldNotVerify.length,
      nudges: plan.couldNotVerify.where((c) => c.shouldNudge).toList(),
    );
  }
}
