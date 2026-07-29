import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/translations.g.dart';
import '../models/goal.dart';
import '../providers/goal_provider.dart';
import '../providers/settings_provider.dart';
import 'app_logger.dart';
import 'notifications.dart';
import 'verification_config.dart';
import 'verification_providers.dart';

/// Application glue for auto-verified habits: the pure input builders, the
/// `VerificationLogWriter` adapter over the habit-log store, and the
/// foreground reconcile entry point. Everything gated by [VerificationConfig] at
/// the call site (the foreground hook) so this stays testable regardless of the
/// flag.

// ── Pure builders (unit-tested in isolation) ────────────────────────────────

/// `max(startDate, verifyEffectiveFrom)` — the forward-only rule-edit anchor
/// (D10). Null `edited` (pre-v7 habits, or rules not yet re-stamped) ⇒
/// `startDate`. Clamped so a stray earlier edit-date can never pull evaluation
/// before the habit's own start.
DateTime _ruleEffectiveFrom(DateTime startDate, DateTime? edited) {
  if (edited == null) return startDate;
  return edited.isAfter(startDate) ? edited : startDate;
}

/// The verifiable goals to reconcile, honoring the per-provider feature flags
/// and skipping manual habits. `effectiveFrom` is `max(startDate,
/// verifyEffectiveFrom)` — the forward-only rule-edit anchor (D10): reconcile
/// never rewrites days before the current rule took effect. A null
/// `verifyEffectiveFrom` (a habit that predates the v7 column, or one not yet
/// re-stamped) falls back to `startDate`, preserving the pre-D10 behavior.
/// `frequency_days` becomes the scheduled-days set (D6).
List<VerifiableGoal> verifiableGoalsFrom(
  List<Goal> goals, {
  required bool healthKitEnabled,
  required bool screenTimeAppsEnabled,
  required bool screenTimeTotalEnabled,
  bool compoundEnabled = false,
  String? Function(String goalId)? screenTimeSelectionFor,
}) {
  final out = <VerifiableGoal>[];
  for (final g in goals) {
    final rule = g.verificationRule;
    if (rule == null) continue;

    // Compound habits (Q1–Q5): every condition is HealthKit, so gate on both the
    // compound flag and HealthKit. Skipped entirely when either is off — e.g. a
    // compound goal synced from a device where the feature is live must not
    // half-verify here. No Screen Time machinery applies.
    if (g.isCompoundVerified) {
      if (!compoundEnabled || !healthKitEnabled) continue;
      out.add(VerifiableGoal(
        goalId: g.id,
        rule: rule,
        additionalConditions: g.additionalConditions ?? const [],
        join: g.verificationJoin ?? VerificationJoin.or,
        effectiveFrom: _ruleEffectiveFrom(g.startDate, g.verifyEffectiveFrom),
        activeWeekdays: g.frequencyDays?.toSet() ?? const {},
      ));
      continue;
    }

    if (rule.isHealthKit && !healthKitEnabled) continue;
    if (rule.isScreenTime) {
      // Per-template gating so Mode A can be live while Mode B stays dark. An
      // unknown screen-time key (a newer client's template) can't be monitored,
      // so it is skipped rather than guessed at.
      final key = rule.metricKey;
      if (key == screenTimeAppsKey) {
        if (!screenTimeAppsEnabled) continue;
      } else if (key == screenTimeTotalKey) {
        if (!screenTimeTotalEnabled) continue;
      } else {
        continue;
      }
    }
    // A Mode-A goal with no resolvable device-local selection is not being
    // monitored; flag it so the engine records couldn't-verify (never a silent
    // pass). Mode B and HealthKit goals are never "selection missing".
    final selectionMissing = rule.isScreenTime &&
        rule.metricKey == screenTimeAppsKey &&
        (screenTimeSelectionFor?.call(g.id) == null);
    out.add(VerifiableGoal(
      goalId: g.id,
      rule: rule,
      effectiveFrom: _ruleEffectiveFrom(g.startDate, g.verifyEffectiveFrom),
      activeWeekdays: g.frequencyDays?.toSet() ?? const {},
      screenTimeSelectionMissing: selectionMissing,
    ));
  }
  return out;
}

/// The catalog keys for the two Screen Time templates, used to derive mode and
/// gate per-template. Kept here so the wiring doesn't depend on catalog order.
const String screenTimeAppsKey = 'screen_time_apps';
const String screenTimeTotalKey = 'screen_time_total';

/// The app's terminal outcomes per goal-day (done→pass, missed→fail), restricted
/// to [goalIds]. `skipped`/unknown statuses are ignored.
Map<String, Map<DateTime, VerificationOutcome>> loggedOutcomesFrom(
  Map<String, Map<String, String>> logs,
  Set<String> goalIds,
) {
  final out = <String, Map<DateTime, VerificationOutcome>>{};
  logs.forEach((dateKey, dayLogs) {
    final day = _parseDate(dateKey);
    if (day == null) return;
    dayLogs.forEach((goalId, status) {
      if (!goalIds.contains(goalId)) return;
      final outcome = switch (status) {
        'done' => VerificationOutcome.pass,
        'missed' => VerificationOutcome.fail,
        _ => null,
      };
      if (outcome == null) return;
      (out[goalId] ??= {})[day] = outcome;
    });
  });
  return out;
}

/// Couldn't-verify days per goal (goalId → date-only days) for the "?"
/// affordance (D6), read from the local bookkeeping store for the currently
/// verified goals. Returns empty when the feature is off, there are no verified
/// goals, or the store can't open (e.g. in a widget test) — so the UI degrades
/// to "no ?" rather than erroring. Reactive to goal changes; the reconcile
/// entry point invalidates it after each pass so freshly recorded days appear.
///
/// The result is bounded to the **resolvable window** (today + yesterday, the
/// same window the day-details check-in guard allows): a "?" only ever renders
/// on a day the user can actually resolve, so the "tap to resolve" affordance
/// never dead-ends on an older, non-editable day.
final couldNotVerifyDaysProvider =
    FutureProvider<Map<String, Set<DateTime>>>((ref) async {
  if (!VerificationConfig.enabled) return const {};
  final goals = verifiableGoalsFrom(
    ref.watch(goalsProvider),
    healthKitEnabled: VerificationConfig.healthKitEnabled,
    screenTimeAppsEnabled: VerificationConfig.screenTimeAppsEnabled,
    screenTimeTotalEnabled: VerificationConfig.screenTimeTotalEnabled,
    compoundEnabled: VerificationConfig.compoundVerificationEnabled,
    screenTimeSelectionFor: (id) =>
        ref.watch(screenTimeSelectionsProvider)[id]?.blob,
  );
  if (goals.isEmpty) return const {};
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  try {
    final store = await ref.watch(verificationStateStoreProvider.future);
    final out = <String, Set<DateTime>>{};
    for (final g in goals) {
      final days = (await store.couldNotVerifyDays(g.goalId))
          .where((d) => d == today || d == yesterday)
          .toSet();
      if (days.isNotEmpty) out[g.goalId] = days;
    }
    return out;
  } catch (e, stack) {
    AppLogger.error('[Verification] couldNotVerifyDays load failed', e, stack);
    return const {};
  }
});

/// The DeviceActivity monitor specs for the current Screen Time goals.
///
/// Mode A (`screen_time_apps`) carries the device-local selection blob resolved
/// by [selectionFor]; a goal with no resolvable selection emits **no spec** —
/// native never registers it, so it stays couldn't-verify rather than being
/// silently monitored as "everything". Mode B (`screen_time_total`) carries a
/// null blob (empty selection = total usage).
List<ScreenTimeGoalSpec> screenTimeSpecsFrom(
  List<VerifiableGoal> goals, {
  String? Function(String goalId)? selectionFor,
}) {
  final out = <ScreenTimeGoalSpec>[];
  for (final g in goals) {
    if (!g.rule.isScreenTime) continue;
    final isApps = g.rule.metricKey == screenTimeAppsKey;
    String? blob;
    if (isApps) {
      blob = selectionFor?.call(g.goalId);
      if (blob == null) continue; // nothing to monitor → couldn't-verify
    }
    out.add(ScreenTimeGoalSpec(
      goalId: g.goalId,
      thresholdMinutes: g.rule.threshold.round(),
      activeWeekdays: g.activeWeekdays,
      mode: isApps
          ? ScreenTimeMode.appsAndCategories
          : ScreenTimeMode.totalUsage,
      selectionBlob: blob,
    ));
  }
  return out;
}

/// Whether [next] differs from the specs last handed to DeviceActivity, and so
/// whether the native sync is worth doing at all.
///
/// **`last == null` always re-syncs**, and that is the load-bearing case: the
/// cache is per-process, so the first reconcile after any launch re-registers
/// unconditionally. iOS may have dropped the monitoring while we were not
/// running (reboot, force-quit, an OS purge) and nothing tells us. A persisted
/// cache would let a stale entry convince us monitoring was live when it was
/// not — the one failure this guard must never introduce.
///
/// Compared order-independently: the spec list is built from goal order, which
/// changes on an unrelated reorder and means nothing to DeviceActivity.
@visibleForTesting
bool screenTimeSpecsChanged(
  List<ScreenTimeGoalSpec>? last,
  List<ScreenTimeGoalSpec> next,
) {
  if (last == null) return true;
  if (last.length != next.length) return true;
  final a = [...last]..sort((x, y) => x.goalId.compareTo(y.goalId));
  final b = [...next]..sort((x, y) => x.goalId.compareTo(y.goalId));
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return true;
  }
  return false;
}

/// Remembers the Screen Time specs last successfully handed to DeviceActivity in
/// THIS process.
///
/// Deliberately in memory and never persisted — see [screenTimeSpecsChanged].
class ScreenTimeSyncCache {
  List<ScreenTimeGoalSpec>? _last;

  List<ScreenTimeGoalSpec>? get last => _last;

  /// Records a sync that actually succeeded. A failed sync must NOT be recorded:
  /// it has to be retried on the next foreground, not remembered as done.
  void record(List<ScreenTimeGoalSpec> specs) => _last = List.of(specs);

  @visibleForTesting
  void reset() => _last = null;
}

final screenTimeSyncCacheProvider = Provider<ScreenTimeSyncCache>(
  (_) => ScreenTimeSyncCache(),
);

/// Reconciles DeviceActivity monitoring with [goals].
///
/// Two bugs this exists to fix:
///
///  1. **The sync used to sit after `if (goals.isEmpty) return`**, so deleting
///     your last verifiable habit never called `syncMonitoredGoals([])` — and
///     the native side only stops monitoring when it is called. DeviceActivity
///     went on watching for a goal that no longer existed, for the life of the
///     install, with no UI anywhere admitting it. Syncing an empty list is the
///     whole point of the empty case, not a case to skip.
///  2. **It ran on every single foreground.** The native handler used to answer
///     with a bare `center.stopMonitoring()` — every activity, unconditionally —
///     and re-register the set from scratch, which resets each goal's accrued
///     usage for the day. `ScreenTimeBridge.syncMonitoredGoals` now DIFFS
///     instead: it stops only what is no longer wanted and leaves an unchanged,
///     still-live goal alone. This guard is therefore no longer load-bearing for
///     correctness, but it is still worth keeping — it avoids a channel round
///     trip and a native reconcile when nothing the app knows about has changed.
/// Takes its collaborators directly rather than a `WidgetRef` so the ordering
/// above — the part that actually broke — is testable without pumping a widget.
@visibleForTesting
Future<void> syncScreenTimeMonitoring({
  required ScreenTimeBridge bridge,
  required ScreenTimeSyncCache cache,
  required List<VerifiableGoal> goals,
  String? Function(String goalId)? selectionFor,
  void Function(ScreenTimeMonitorLimitException)? onMonitorLimit,
}) async {
  final specs = screenTimeSpecsFrom(goals, selectionFor: selectionFor);
  if (!screenTimeSpecsChanged(cache.last, specs)) return;

  try {
    // Checked before dialling: the native side calls `center.startMonitoring`
    // with no authorization check of its own (`ScreenTimeBridge.syncMonitoredGoals`), and
    // DeviceActivity throws when unauthorized. The request itself lives at the
    // two opt-in points, where the user has just asked for the feature and a
    // system prompt makes sense (`screen_time_form.dart:36`,
    // `habit_management_modal.dart:604`); a prompt fired from a background
    // reconcile would arrive out of nowhere. This stays a check, not a request,
    // so an unauthorized install degrades to "no signal" rather than to a thrown
    // channel call on every foreground.
    //
    // Skipping an empty sync would strand monitoring (bug 1 above), so the
    // authorization gate deliberately does not apply to it: telling
    // DeviceActivity to stop needs no permission.
    if (specs.isNotEmpty) {
      final status = await bridge.authorizationStatus();
      if (status != ScreenTimeAuthorizationStatus.approved) {
        AppLogger.warning(
          '[Verification] Screen Time not authorized ($status) — '
          'skipping sync of ${specs.length} goal(s)',
        );
        return;
      }
    }
    await bridge.syncMonitoredGoals(specs);
    cache.record(specs);
  } on ScreenTimeMonitorLimitException catch (e) {
    // Apple's 20-activity cap (D10). Surface it to the UI and DO NOT cache —
    // the sync must retry next foreground once the user removes a habit.
    AppLogger.warning('[Verification] Screen Time monitor limit: $e');
    onMonitorLimit?.call(e);
  } catch (e, stack) {
    AppLogger.error('[Verification] syncMonitoredGoals failed', e, stack);
  }
}

/// Reconciles DeviceActivity monitoring with the CURRENT goal list, without
/// running a verdict pass.
///
/// This is the registration half of [runVerificationReconcile], split out so it
/// can be driven by goal-list changes rather than only by a foreground resume.
/// Before this existed, `syncScreenTimeMonitoring` was reachable from exactly
/// one place — the `AppLifecycleState.resumed` hook in `main.dart` — which meant
/// a habit created, edited or deleted in an ordinary session was not registered
/// with (or removed from) DeviceActivity until the user happened to background
/// the app and come back. A cold-launched session that never backgrounded never
/// registered anything at all.
///
/// Takes its collaborators directly rather than a `WidgetRef`/`Ref` so it can be
/// driven from either layer — Riverpod gives those two no common supertype — and
/// so the goal-list → spec-list derivation is testable without pumping a widget.
///
/// Also refreshes the extension's localized notification copy, because this is
/// now a path on which a habit can become monitored: the DeviceActivityMonitor
/// extension cannot read Flutter's translations and falls back to hard-coded
/// English, so a user who cold-launches, creates a Screen Time habit and crosses
/// the limit without ever backgrounding would otherwise get an English banner.
Future<void> syncScreenTimeMonitoringFor({
  required List<Goal> goals,
  required ScreenTimeBridge bridge,
  required ScreenTimeSyncCache cache,
  required String? Function(String goalId) selectionFor,
  void Function(ScreenTimeMonitorLimitException)? onMonitorLimit,
}) async {
  if (!VerificationConfig.screenTimeEnabled) return;
  // Isolated: the copy is cosmetic (the extension has an English fallback), so a
  // channel failure here must never stop the registration below — and must never
  // escape to abort a coalescing caller's queued re-run.
  try {
    await bridge.setLocalizedNotificationCopy(
      title: t.verification.screenTime.limitReachedTitle,
      body: t.verification.screenTime.limitReachedBody,
    );
  } catch (e, stack) {
    AppLogger.error('[Verification] notification copy write failed', e, stack);
  }
  await syncScreenTimeMonitoring(
    bridge: bridge,
    cache: cache,
    goals: verifiableGoalsFrom(
      goals,
      healthKitEnabled: VerificationConfig.healthKitEnabled,
      screenTimeAppsEnabled: VerificationConfig.screenTimeAppsEnabled,
      screenTimeTotalEnabled: VerificationConfig.screenTimeTotalEnabled,
      compoundEnabled: VerificationConfig.compoundVerificationEnabled,
      screenTimeSelectionFor: selectionFor,
    ),
    selectionFor: selectionFor,
    onMonitorLimit: onMonitorLimit,
  );
}

/// A single couldn't-verify nudge to surface to the user (D11).
class VerificationNudge {
  const VerificationNudge({
    required this.goalId,
    required this.title,
    required this.day,
  });

  final String goalId;
  final String title;
  final DateTime day;
}

/// Reduces a [ReconcileReport]'s nudges to at most one per goal (its latest
/// couldn't-verify day), dropping any goal with no known title. Keeping the
/// mapping pure makes the "one banner per goal, not per day" policy testable.
List<VerificationNudge> couldNotVerifyNudges(
  ReconcileReport report,
  Map<String, String> titlesById,
) {
  final latest = <String, DateTime>{};
  for (final n in report.nudges) {
    final current = latest[n.goalId];
    if (current == null || n.day.isAfter(current)) latest[n.goalId] = n.day;
  }
  final out = <VerificationNudge>[];
  latest.forEach((goalId, day) {
    final title = titlesById[goalId];
    if (title != null) {
      out.add(VerificationNudge(goalId: goalId, title: title, day: day));
    }
  });
  return out;
}

/// Drops nudge [candidates] whose (goalId, day) has already fired a nudge, per
/// [alreadyNudged] (goalId → nudged days). Keeps the cross-foreground de-dup
/// policy pure and testable (the persisted marker lives in the state store).
List<VerificationNudge> unnudgedNudges(
  List<VerificationNudge> candidates,
  Map<String, Set<DateTime>> alreadyNudged,
) =>
    [
      for (final n in candidates)
        if (!(alreadyNudged[n.goalId]
                ?.contains(DateTime(n.day.year, n.day.month, n.day.day)) ??
            false))
          n,
    ];

/// A verdict worth a celebration/failure notification (D11), with its habit
/// title resolved.
class VerificationVerdictNotice {
  const VerificationVerdictNotice({
    required this.goalId,
    required this.dateKey,
    required this.title,
  });

  final String goalId;
  final String dateKey;
  final String title;
}

/// Today's celebratable passes (D11): a `pass` write dated [todayKey] whose goal
/// has a known title. Backfilled passes from earlier days are intentionally not
/// celebrated (only a goal reached *today* is fresh news).
List<VerificationVerdictNotice> celebrationNotices(
  List<LogWrite> writes,
  Map<String, String> titles,
  String todayKey,
) {
  final out = <VerificationVerdictNotice>[];
  for (final w in writes) {
    if (w.outcome != VerificationOutcome.pass) continue;
    final key = dateKeyOf(w.day);
    if (key != todayKey) continue;
    final title = titles[w.goalId];
    if (title == null) continue;
    out.add(VerificationVerdictNotice(
        goalId: w.goalId, dateKey: key, title: title));
  }
  return out;
}

DateTime? _parseDate(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String dateKeyOf(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

// ── Log-writer adapter ──────────────────────────────────────────────────────

/// Bridges the pure [VerificationLogWriter] contract to the app's habit-log
/// store: maps pass/fail → done/missed and delegates to
/// [HabitLogsNotifier.applyAutoVerdict] (which persists to the active backend
/// and recomputes the streak).
class GoalLogVerificationWriter implements VerificationLogWriter {
  GoalLogVerificationWriter(this._ref);

  final WidgetRef _ref;

  @override
  Future<void> writeVerdict({
    required String goalId,
    required DateTime day,
    required VerificationOutcome outcome,
    double? value,
  }) async {
    final status = outcome == VerificationOutcome.pass ? 'done' : 'missed';
    await _ref.read(habitLogsProvider.notifier).applyAutoVerdict(
          goalId: goalId,
          dateKey: dateKeyOf(day),
          status: status,
          value: value,
        );
  }
}

// ── Reconcile entry point ───────────────────────────────────────────────────

/// Runs one foreground reconcile pass. Call site (the lifecycle hook) is
/// responsible for the [VerificationConfig.enabled] gate — keeping this function
/// flag-free makes it directly testable. Returns an empty report when there is
/// nothing verifiable.
Future<ReconcileReport> runVerificationReconcile(WidgetRef ref) async {
  final goals = verifiableGoalsFrom(
    ref.read(goalsProvider),
    healthKitEnabled: VerificationConfig.healthKitEnabled,
    screenTimeAppsEnabled: VerificationConfig.screenTimeAppsEnabled,
    screenTimeTotalEnabled: VerificationConfig.screenTimeTotalEnabled,
    compoundEnabled: VerificationConfig.compoundVerificationEnabled,
    screenTimeSelectionFor: (id) =>
        ref.read(screenTimeSelectionsProvider)[id]?.blob,
  );

  // BEFORE the empty-goals return, not after. An empty list is exactly when
  // DeviceActivity most needs telling: it is the "you deleted your last Screen
  // Time habit, stop watching" case, and the native side only stops when it is
  // called. Returning first left monitoring running forever — see
  // [_syncScreenTimeMonitoring].
  //
  // Gated on the flag so a HealthKit-only build never calls into
  // FamilyControls/DeviceActivity at all.
  if (VerificationConfig.screenTimeEnabled) {
    final bridge = ref.read(screenTimeBridgeProvider);
    // Hand the extension the current-locale copy for its "limit reached" local
    // notification — the DeviceActivityMonitor extension can't read Flutter's
    // translations, so the app writes them into the shared App Group.
    await bridge.setLocalizedNotificationCopy(
      title: t.verification.screenTime.limitReachedTitle,
      body: t.verification.screenTime.limitReachedBody,
    );
    await syncScreenTimeMonitoring(
      bridge: bridge,
      cache: ref.read(screenTimeSyncCacheProvider),
      goals: goals,
      selectionFor: (id) => ref.read(screenTimeSelectionsProvider)[id]?.blob,
      onMonitorLimit: (e) =>
          ref.read(screenTimeMonitorLimitProvider.notifier).report(e),
    );
  }

  if (goals.isEmpty) return const ReconcileReport();

  final store = await ref.read(verificationStateStoreProvider.future);
  final controller = VerificationController(
    service: ref.read(verificationServiceProvider),
    store: store,
    logWriter: GoalLogVerificationWriter(ref),
  );

  final logged = loggedOutcomesFrom(
    ref.read(habitLogsProvider),
    goals.map((g) => g.goalId).toSet(),
  );

  final now = DateTime.now();
  final report = await controller.reconcile(
    goals: goals,
    loggedOutcomes: logged,
    today: now,
  );

  // Refresh the "?" affordance with any days this pass recorded / resolved.
  if (report.changedAnything) ref.invalidate(couldNotVerifyDaysProvider);

  if (report.nudges.isEmpty && report.writes.isEmpty) return report;

  final settings = ref.read(settingsProvider);
  final titles = {for (final g in ref.read(goalsProvider)) g.id: g.title};
  final notifications = NotificationService();

  // Couldn't-verify nudges (D6/D11) — one banner per goal (latest day), gated by
  // the user pref and de-duped across foregrounds via the store's nudged marker
  // so an unresolved day isn't re-alerted every time the app opens.
  if (settings.verificationNudges && report.nudges.isNotEmpty) {
    final candidates = couldNotVerifyNudges(report, titles);
    final alreadyNudged = <String, Set<DateTime>>{};
    for (final c in candidates) {
      alreadyNudged[c.goalId] = await store.nudgedDays(c.goalId);
    }
    for (final nudge in unnudgedNudges(candidates, alreadyNudged)) {
      await notifications.showVerificationNudge(
        goalId: nudge.goalId,
        title: nudge.title,
      );
      await store.markNudged(nudge.goalId, nudge.day);
    }
  }

  // Opt-in celebration for goals reached today (D11). Driven by the idempotent
  // write list, so each pass celebrates at most once.
  if (settings.verificationCelebrations) {
    final todayKey = dateKeyOf(now);
    for (final notice in celebrationNotices(report.writes, titles, todayKey)) {
      await notifications.showVerificationCelebration(
        goalId: notice.goalId,
        dateKey: notice.dateKey,
        title: notice.title,
      );
    }
  }

  // Opt-in end-of-day failure summary (D11) — one banner covering the fresh
  // `missed` verdicts this pass (all such writes are for completed past days).
  // Count DISTINCT goals, not writes: a single habit that missed several
  // backfilled days produces one fail write per day, and the copy speaks of
  // "habits", not "days".
  if (settings.verificationFailureSummary) {
    final failedGoals = report.writes
        .where((w) => w.outcome == VerificationOutcome.fail)
        .map((w) => w.goalId)
        .toSet();
    if (failedGoals.isNotEmpty) {
      await notifications.showVerificationFailureSummary(
        count: failedGoals.length,
        title: titles[failedGoals.first] ?? '',
      );
    }
  }

  return report;
}
