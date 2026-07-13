import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// The verifiable goals to reconcile, honoring the per-provider feature flags
/// and skipping manual habits. `effectiveFrom` is the goal's start date
/// (forward-only rule edits would move this once edit-dates are tracked, D10);
/// `frequency_days` becomes the scheduled-days set (D6).
List<VerifiableGoal> verifiableGoalsFrom(
  List<Goal> goals, {
  required bool healthKitEnabled,
  required bool screenTimeEnabled,
}) {
  final out = <VerifiableGoal>[];
  for (final g in goals) {
    final rule = g.verificationRule;
    if (rule == null) continue;
    if (rule.isHealthKit && !healthKitEnabled) continue;
    if (rule.isScreenTime && !screenTimeEnabled) continue;
    out.add(VerifiableGoal(
      goalId: g.id,
      rule: rule,
      effectiveFrom: g.startDate,
      activeWeekdays: g.frequencyDays?.toSet() ?? const {},
    ));
  }
  return out;
}

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

/// The DeviceActivity monitor specs for the current Screen Time goals.
List<ScreenTimeGoalSpec> screenTimeSpecsFrom(List<VerifiableGoal> goals) => [
      for (final g in goals)
        if (g.rule.isScreenTime)
          ScreenTimeGoalSpec(
            goalId: g.goalId,
            thresholdMinutes: g.rule.threshold.round(),
            activeWeekdays: g.activeWeekdays,
          ),
    ];

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
    screenTimeEnabled: VerificationConfig.screenTimeEnabled,
  );
  if (goals.isEmpty) return const ReconcileReport();

  // Keep DeviceActivity monitoring in sync with the current Screen Time goals —
  // but only when Screen Time is enabled, so a HealthKit-only build never calls
  // into FamilyControls/DeviceActivity (no entitlement there yet).
  if (VerificationConfig.screenTimeEnabled) {
    final specs = screenTimeSpecsFrom(goals);
    try {
      await ref.read(screenTimeBridgeProvider).syncMonitoredGoals(specs);
    } catch (e, stack) {
      AppLogger.error('[Verification] syncMonitoredGoals failed', e, stack);
    }
  }

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
  if (settings.verificationFailureSummary) {
    final fails = report.writes
        .where((w) => w.outcome == VerificationOutcome.fail)
        .toList();
    if (fails.isNotEmpty) {
      await notifications.showVerificationFailureSummary(
        count: fails.length,
        title: titles[fails.first.goalId] ?? '',
      );
    }
  }

  return report;
}
