/// Local, unsynced bookkeeping for verification (D4/D8) — the piece that lives
/// *outside* the streak-bearing `goal_logs` row.
///
/// It records only two things per goal-day, both mobile-local:
///   * **manual** — the user resolved this day by hand, so reconcile must freeze
///     it and never overwrite with an auto verdict (D9);
///   * **couldn't-verify** — the day ended with no definitive signal, driving
///     the "?" affordance and the "did you keep it?" nudge (D4/D6).
///
/// It deliberately does NOT store auto pass/fail verdicts — those already live
/// in `goal_logs` (done/missed) and would only duplicate state. The concrete
/// implementation is a small on-device database in the app; tests use a fake.
abstract interface class VerificationStateStore {
  /// The manually-resolved (frozen) days for each of [goalIds] within the
  /// inclusive range [from]..[to], each mapped to the STATUS the user chose
  /// (`done`/`missed`), or **null** for a freeze recorded before the status was
  /// stored. Keys omit goals with no manual days.
  ///
  /// The status is what makes a freeze self-describing, and that is what keeps
  /// this table incapable of losing a check-in. A freeze whose `goal_logs` row
  /// is not visible used to be indistinguishable from a write that never landed,
  /// so reconcile deleted the freeze and let the sensor score the day — over the
  /// user's own answer. It cannot tell those apart, because both look identical
  /// from here: a reminder Done that upserted STRAIGHT TO THE SERVER queues
  /// nothing, so a merely-stale in-memory map presents exactly as a failed
  /// write. Carrying the status means reconcile never has to guess: it restores
  /// what the user chose.
  Future<Map<String, Map<DateTime, String?>>> manualDays({
    required Iterable<String> goalIds,
    required DateTime from,
    required DateTime to,
  });

  /// The unresolved couldn't-verify days for [goalId] (drives the "?" UI).
  Future<Set<DateTime>> couldNotVerifyDays(String goalId);

  /// Freeze [day] as manually resolved (called from the check-in path). Clears
  /// any couldn't-verify marker for the same day.
  ///
  /// [status] is the verdict the user chose — `done` or `missed`. Pass it
  /// whenever it is known: it is what lets reconcile RESTORE the day if the
  /// `goal_logs` write did not land, instead of having to choose between
  /// leaving the day pending forever and overwriting the user's answer with the
  /// sensor's. Null is accepted so a caller that genuinely does not know cannot
  /// be forced to invent one; such a freeze is simply never healed.
  Future<void> markManual(String goalId, DateTime day, {String? status});

  /// Undo a manual freeze (e.g. the user cleared their check-in).
  Future<void> clearManual(String goalId, DateTime day);

  /// Record that [day] could not be verified. Idempotent; a no-op if the day is
  /// already frozen manual.
  Future<void> recordCouldNotVerify(String goalId, DateTime day);

  /// Clear a couldn't-verify marker once the day resolves to a real verdict.
  Future<void> resolveCouldNotVerify(String goalId, DateTime day);

  /// Delete every couldn't-verify marker for [goalId] strictly before [day].
  /// Reconcile calls this to drop markers that have aged out of the backfill
  /// window (they can never resolve — reconcile no longer revisits them), so the
  /// bookkeeping table doesn't grow without bound.
  Future<void> pruneCouldNotVerifyBefore(String goalId, DateTime day);

  /// The couldn't-verify days for [goalId] that have already fired a "did you
  /// keep it?" nudge. Lets the caller suppress re-nudging the same day on every
  /// foreground within the nag window (the notification id alone only prevents
  /// *stacking*, not *re-alerting*).
  Future<Set<DateTime>> nudgedDays(String goalId);

  /// Mark a couldn't-verify [day] as already nudged. A no-op if the day is not
  /// currently couldn't-verify (only a live "?" day can be nudged). The mark is
  /// dropped automatically when the day resolves or is frozen manual, so a day
  /// that lapses back into couldn't-verify can nudge afresh.
  Future<void> markNudged(String goalId, DateTime day);

  /// Drop all bookkeeping for a deleted goal.
  Future<void> deleteGoal(String goalId);
}
