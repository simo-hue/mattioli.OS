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
  /// The set of manually-resolved (frozen) days for each of [goalIds] within
  /// the inclusive range [from]..[to]. Keys omit goals with no manual days.
  Future<Map<String, Set<DateTime>>> manualDays({
    required Iterable<String> goalIds,
    required DateTime from,
    required DateTime to,
  });

  /// The unresolved couldn't-verify days for [goalId] (drives the "?" UI).
  Future<Set<DateTime>> couldNotVerifyDays(String goalId);

  /// Freeze [day] as manually resolved (called from the check-in path). Clears
  /// any couldn't-verify marker for the same day.
  Future<void> markManual(String goalId, DateTime day);

  /// Undo a manual freeze (e.g. the user cleared their check-in).
  Future<void> clearManual(String goalId, DateTime day);

  /// Record that [day] could not be verified. Idempotent; a no-op if the day is
  /// already frozen manual.
  Future<void> recordCouldNotVerify(String goalId, DateTime day);

  /// Clear a couldn't-verify marker once the day resolves to a real verdict.
  Future<void> resolveCouldNotVerify(String goalId, DateTime day);

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
