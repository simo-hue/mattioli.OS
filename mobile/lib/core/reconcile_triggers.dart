import 'dart:convert';

import '../models/goal.dart';

/// Pure trigger policy for the two end-of-day reconcile passes — the
/// auto-verified verdict reconcile (`runVerificationReconcile`) and the
/// manual-target sweep (`HabitProgressNotifier.reconcileManualTargets`).
///
/// Both passes shipped with exactly ONE trigger: `AppLifecycleState.resumed`.
/// iOS does not deliver that on a cold start — `ServicesBinding.initInstances`
/// seeds the binding from `platformDispatcher.initialLifecycleState` during
/// `ensureInitialized()`, i.e. BEFORE `runApp` and therefore before any
/// `WidgetsBindingObserver` is registered, and `handleAppLifecycleStateChanged`
/// then early-returns on `lifecycleState == state`. The same fact is recorded
/// for the iCloud sync in `main.dart`, which grew a launch `postFrameCallback`
/// because of it; neither verdict pass ever got the same treatment.
///
/// The consequence was not subtle: a force-quit → launch loop — the dominant
/// pattern while testing a build on device — never ran either pass. A verified
/// habit's day never became done/missed, and a count habit's closed day kept no
/// verdict, which is exactly the "it stays pending forever" both bug reports
/// describe. An app left open across midnight had the same hole from the other
/// side: no lifecycle event fires at 00:00, so yesterday was never resolved.
///
/// The policy lives here rather than inline in the widget so it can be tested
/// without pumping an app or faking a lifecycle transition.

/// Whether a pass is due because the calendar day rolled over since the last
/// one, given the day [lastReconciledDay] the previous pass ran for.
///
/// Null means nothing has run yet in this session, which is NOT a rollover: the
/// goal-list trigger owns the first pass, and firing here as well would race it
/// on every launch.
///
/// Compared with `!=` rather than `isAfter` deliberately. A clock that moves
/// BACKWARDS (date-line travel, a manual date change, an RTC that lost power)
/// must also re-run: both passes are idempotent — they write only when the
/// derived verdict differs from the stored one — so a redundant pass costs a few
/// queries, while a missed one leaves a day unresolved with nothing to retry it.
bool shouldReconcileForDayChange({
  required DateTime? lastReconciledDay,
  required DateTime now,
}) {
  if (lastReconciledDay == null) return false;
  final today = DateTime(now.year, now.month, now.day);
  final last = DateTime(
    lastReconciledDay.year,
    lastReconciledDay.month,
    lastReconciledDay.day,
  );
  return today != last;
}

/// A content signature of [goals] covering exactly the fields the two passes
/// read: the verification conditions and their forward-only anchor, the
/// quantitative target and its anchor, and the schedule bounds that decide which
/// days are in scope.
///
/// The goal LIST changes identity far more often than its content — a cache seed
/// and then a server answer at launch, an optimistic insert with a temporary id
/// and then the persisted row on every mutation, and a fresh `build()` on every
/// applied iCloud sync, which the 60-second poll can reach once a minute.
/// Triggering on identity would run a full HealthKit pass (7 days × every
/// condition) once a minute forever; triggering on CONTENT runs one pass per
/// launch plus one per real habit edit, which is all the trigger is for.
///
/// Order-independent (the per-goal parts are sorted), for the same reason
/// `screenTimeSpecsChanged` sorts: a drag-reorder changes `display_order`, which
/// means nothing to either pass and must not cost a round of Health queries.
///
/// Built from the PERSISTED column forms (`verifyColumnValues`,
/// `targetColumnValue`, the two effective-from column values) rather than from
/// the model fields, so a habit that round-trips through storage unchanged
/// signs identically — including a newer client's undecodable blob, which is
/// preserved verbatim and would otherwise be invisible here.
String goalReconcileSignature(List<Goal> goals) {
  final parts = [for (final g in goals) _signatureOf(g)]..sort();
  return parts.join(';');
}

String _signatureOf(Goal g) => [
  g.id,
  _dayKey(g.startDate),
  g.endDate == null ? '' : _dayKey(g.endDate!),
  // Copied before sorting: `frequencyDays` is the goal's own list, and
  // sorting it in place would mutate shared model state from a predicate.
  ([...?g.frequencyDays]..sort()).join(','),
  jsonEncode(g.verifyColumnValues),
  g.verifyEffectiveFromColumnValue ?? '',
  g.targetColumnValue ?? '',
  g.targetEffectiveFrom == null ? '' : _dayKey(g.targetEffectiveFrom!),
].join('|');

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
