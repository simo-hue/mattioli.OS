import 'dart:async';
import 'dart:math';

import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/clock.dart';
import 'package:evolve_desktop/core/streak_utils.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardSnapshot>(
      DashboardController.new,
    );

class DashboardController extends Notifier<DashboardSnapshot> {
  DashboardRepository get _repository => ref.read(dashboardRepositoryProvider);

  /// The app's clock. Defaults to `DateTime.now` (see core/clock.dart); tests
  /// override it so the unawaited reconcile tail of [refresh] resolves days
  /// against the same date the test asserts on.
  DateTime _now() => ref.read(clockProvider)();

  /// Set once the notifier is torn down (data-mode switch, sign-out, test
  /// teardown). The manual-target reconcile is a fire-and-forget async tail of
  /// [refresh]; without this guard it can touch `state` after disposal and throw.
  bool _disposed = false;

  @override
  DashboardSnapshot build() {
    final repository = ref.watch(dashboardRepositoryProvider);
    ref.onDispose(() => _disposed = true);
    final snapshot = repository.load();
    // load() is only ever a synchronous best-effort cache: Supabase has nothing
    // until it hits the network, and the private proxy returns empty until
    // refresh() has resolved the owner ID and built the real repository. Both
    // modes need this async follow-up, so it is never gated.
    unawaited(Future<void>.microtask(refresh));
    return snapshot;
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final snapshot = await _repository.refresh();
      state = snapshot.copyWith(isRefreshing: false, clearError: true);
    } catch (error, stack) {
      AppLogger.error('Unable to refresh dashboard state', error, stack);
      final cachedSnapshot = error is DashboardRefreshException
          ? error.cachedSnapshot
          : null;
      state = (cachedSnapshot ?? state).copyWith(
        isRefreshing: false,
        errorMessage: t.sync.syncFailed,
      );
    }
    // Once the snapshot is in place (fresh or cached), resolve any manual-target
    // days that closed while the app was shut — above all a limit habit's quiet
    // successes. Fire-and-forget: a reconcile failure must not surface as a
    // refresh error, and it is a no-op until a habit has a manual target.
    unawaited(() async {
      try {
        if (_disposed) return;
        await reconcileManualTargets();
      } catch (error, stack) {
        AppLogger.error('Manual-target reconcile failed', error, stack);
      }
    }());
  }

  Future<void> toggleHabit(String id) async {
    await toggleHabitForDay(id, _now());
  }

  Future<void> toggleHabitForDay(String id, DateTime date) async {
    // One owner per habit-day. Both sibling writers already enforce this triple;
    // this one did not, which is how a macOS check-in on a VERIFIED habit got
    // silently reverted by the iPhone's next reconcile (manual provenance is a
    // device-local mobile table, so a Mac tap can never record the freeze that
    // would protect it), and how toggling a QUANTITATIVE habit's day appeared to
    // do nothing — the manual-target sweep recomputes the verdict from
    // goal_progress on the next refresh and writes it straight back.
    final owner = state.habits.where((h) => h.id == id).firstOrNull;
    if (owner != null &&
        (owner.verificationRule != null ||
            (owner.target?.isUserEnterable ?? false))) {
      AppLogger.info(
        'Ignoring manual toggle for habit $id: its verdict is owned by '
        '${owner.verificationRule != null ? 'the verification pipeline' : 'its quantitative target'}.',
      );
      return;
    }

    final dateKey = dashboardDateKey(date);
    final weekdayIndex = date.weekday - 1;
    final currentStatus =
        state.habitStatusFor(id, date) ??
        ((_isToday(date)
                ? state.habits.firstWhere((habit) => habit.id == id).state ==
                      HabitState.completed
                : _isCurrentWeek(date) &&
                      state.habits
                          .firstWhere((habit) => habit.id == id)
                          .weeklyProgress[weekdayIndex])
            ? 'done'
            : null);
    final nextStatus = _nextHabitStatus(currentStatus);
    final logs = {
      for (final entry in state.habitLogs.entries)
        entry.key: Map<String, String>.from(entry.value),
    };
    final dayLogs = logs.putIfAbsent(dateKey, () => {});
    if (nextStatus == null) {
      dayLogs.remove(id);
    } else {
      dayLogs[id] = nextStatus;
    }
    // Deterministic streak for the toggled day, derived from the full ordered
    // log history via the shared `computeStreak` (same helper the persistence
    // layer / mobile use). Mirrors mobile's `cycleStatus`: 0 when the day is
    // un-completed, otherwise the signed streak over the updated logs.
    final habit = state.habits.firstWhere((habit) => habit.id == id);
    final nextStreak = nextStatus == null
        ? 0
        : computeStreak(
            habitId: id,
            date: date,
            logs: logs,
            startDate: habit.startDate ?? date,
            frequencyDays: habit.frequencyDays,
          );
    final habits = [
      for (final habit in state.habits)
        if (habit.id == id)
          _setHabitForWeekday(
            habit,
            weekdayIndex,
            _isToday(date),
            nextStatus == 'done',
            nextStreak,
            inCurrentWeek: _isCurrentWeek(date),
          )
        else
          habit,
    ];
    state = state.copyWith(habits: habits, habitLogs: logs);
    await _saveLocal();
    await _syncRemote(
      () => _repository.setHabitStatus(
        habitId: id,
        date: date,
        currentStatus: currentStatus,
      ),
    );
  }

  /// Sets a quantitative habit's accumulated progress for [date] to [amount],
  /// then DERIVES and applies the day's verdict — the desktop counterpart of
  /// mobile's `HabitProgressNotifier.setProgress`. Optimistic + local-first like
  /// [toggleHabitForDay]: updates the progress map, the logs map, the weekly
  /// grid and the streak in one state write, saves locally, then syncs.
  ///
  /// Only manual targets are user-enterable — a measured target's ring is filled
  /// by the verification pipeline, so this is a no-op for one. [now] is injectable
  /// for tests.
  Future<void> setHabitProgressForDay(
    String id,
    DateTime date,
    double amount, {
    DateTime? now,
  }) async {
    final habit = state.habits.firstWhere((habit) => habit.id == id);
    final target = habit.displayTarget;
    // A verified habit's goal_logs verdict is owned by the verification pipeline
    // (one owner per habit-day) — never let a manual increment derive/overwrite
    // it. A purely-verified habit already returns here (its displayTarget is the
    // measured projection, not user-enterable); this also covers a synced habit
    // carrying BOTH a manual target and a rule. macOS can't author rules, and the
    // class picker keeps the two mutually exclusive.
    if (target == null ||
        !target.isUserEnterable ||
        habit.verificationRule != null) {
      return;
    }

    final clamped = amount < 0 ? 0.0 : amount;
    final dateKey = dashboardDateKey(date);
    final weekdayIndex = date.weekday - 1;

    // Optimistic progress map (deep copy so the old state stays intact).
    final progress = {
      for (final entry in state.habitProgress.entries)
        entry.key: Map<String, double>.from(entry.value),
    };
    if (clamped == 0) {
      progress[dateKey]?.remove(id);
      if (progress[dateKey]?.isEmpty ?? false) progress.remove(dateKey);
    } else {
      (progress[dateKey] ??= {})[id] = clamped;
    }

    // Derive the verdict. "Today" is an open period, so an atLeast day flips to
    // done the moment the target is reached while a limit day stays pending; a
    // past day resolves. The mapping to a goal_logs status lives in one place
    // (TargetVerdict.logStatus).
    final over = periodIsOver(target.period, date, now ?? _now());
    final verdict = evaluateTarget(
      target: target,
      progress: clamped,
      periodIsOver: over,
    );
    final derivedStatus = verdict.logStatus;

    // Move the verdict (goal_logs) + weekly grid + streak, mirroring the toggle
    // path but with the DERIVED status instead of the tri-state cycle.
    final logs = {
      for (final entry in state.habitLogs.entries)
        entry.key: Map<String, String>.from(entry.value),
    };
    final dayLogs = logs.putIfAbsent(dateKey, () => {});
    if (derivedStatus == null) {
      dayLogs.remove(id);
    } else {
      dayLogs[id] = derivedStatus;
    }
    final nextStreak = derivedStatus == null
        ? 0
        : computeStreak(
            habitId: id,
            date: date,
            logs: logs,
            startDate: habit.startDate ?? date,
            frequencyDays: habit.frequencyDays,
          );
    final habits = [
      for (final item in state.habits)
        if (item.id == id)
          _setHabitForWeekday(
            item,
            weekdayIndex,
            _isToday(date),
            derivedStatus == 'done',
            nextStreak,
            inCurrentWeek: _isCurrentWeek(date),
          )
        else
          item,
    ];
    state = state.copyWith(
      habits: habits,
      habitLogs: logs,
      habitProgress: progress,
    );
    await _saveLocal();
    await _syncRemote(
      () => _repository.setHabitProgress(
        habitId: id,
        date: date,
        amount: clamped,
        derivedStatus: derivedStatus,
        streak: nextStreak,
      ),
    );
  }

  /// End-of-day resolution for manual targets — the desktop counterpart of
  /// mobile's `HabitProgressNotifier.reconcileManualTargets`. Materialises the
  /// `goal_logs` verdict for every CLOSED day whose live-derived verdict never
  /// caught up (a limit habit's quiet days above all). Reuses
  /// [setHabitProgressForDay] as the applier, so each corrected day re-derives
  /// and persists exactly as a live edit would. No-op when there are no manual
  /// targets or nothing changed. [now] is injectable for tests.
  ///
  /// Runs on macOS too, deliberately: unlike verification (a device measurement
  /// iOS owns), a manual target is plain local data already synced to the Mac,
  /// so a Mac-primary user's limit habits must resolve here or they would look
  /// perpetually unlogged.
  Future<void> reconcileManualTargets({DateTime? now}) async {
    // Never sweep when the goal_progress read FAILED. For an atMost target an
    // absent entry means a quiet SUCCESS, so a degraded map resolves every
    // recorded breach to 'done' and applies it as amount 0 — which DELETES the
    // real row on the server, irreversibly and idempotently (a later healthy
    // refresh sees no progress and status 'done', so nothing restores it).
    if (state.progressStale) {
      AppLogger.info(
        'Manual-target reconcile skipped: goal_progress is stale, so absence '
        'cannot be read as "no progress".',
      );
      return;
    }
    final today = now ?? _now();
    final changes = <TargetReconcileChange>[];
    for (final habit in state.habits) {
      final target = habit.target;
      // A verified habit is owned by the verification pipeline — never sweep it
      // here, or the two pipelines fight over goal_logs.status. (Both set only via
      // legacy/synced data; the class picker keeps them mutually exclusive.)
      if (target == null ||
          !target.isUserEnterable ||
          habit.verificationRule != null) {
        continue;
      }
      changes.addAll(reconcileManualTargetDays(
        goalId: habit.id,
        target: target,
        today: today,
        start: habit.startDate ?? today,
        effectiveFrom: habit.targetEffectiveFrom,
        isScheduled: habit.isScheduledOn,
        progressFor: (dateKey) =>
            state.habitProgress[dateKey]?[habit.id],
        statusFor: (dateKey) => state.habitLogs[dateKey]?[habit.id],
      ));
    }
    // Sequential so each day's streak builds on the last (setHabitProgressForDay
    // recomputes from the running state). Bail if the notifier was torn down
    // between awaits — this runs as a fire-and-forget tail of refresh().
    for (final change in changes) {
      if (_disposed) return;
      final date = DateTime.parse(change.dateKey);
      await setHabitProgressForDay(
        change.goalId,
        date,
        change.amount,
        now: today,
      );
    }
  }

  /// Creates a habit. Returns `false` — without persisting — when the free-tier
  /// 5-habit cap is reached, so the caller (which has a BuildContext) can
  /// present the paywall. Private mode is always Pro via [desktopIsProProvider],
  /// so it is never capped. Mirrors mobile's habit gate.
  Future<bool> addHabit({
    required String title,
    required Color color,
    String? reminderTime,
    List<int>? frequencyDays,
    HabitTarget? target,
  }) async {
    if (!ref.read(desktopIsProProvider) && state.habits.length >= 5) {
      return false;
    }
    // A new target takes effect today (v11, forward-only), so the local sweep
    // never rewrites pre-creation days. Stamped centrally, never by the editor.
    final draft = stampTargetEffectiveFrom(
      DashboardHabit(
        id: _newLocalId(),
        title: title,
        color: color,
        streak: 0,
        weeklyProgress: const [false, false, false, false, false, false, false],
        state: HabitState.pending,
        reminderTime: reminderTime,
        frequencyDays: _canonicalFrequencyDays(frequencyDays),
        startDate: _now(),
        target: target,
      ),
      previous: null,
      today: _now(),
    );
    state = state.copyWith(habits: [...state.habits, draft]);
    await _saveLocal();
    _rescheduleNotifications();
    try {
      final habit = await _repository.createHabit(draft);
      state = state.copyWith(
        habits: [
          for (final item in state.habits)
            if (item.id == draft.id) habit else item,
        ],
      );
      await _saveLocal();
    } catch (error, stack) {
      _recordSyncError('Unable to sync the new habit', error, stack);
    }
    return true;
  }

  Future<void> updateHabit({
    required String id,
    required String title,
    required Color color,
    String? reminderTime,
    List<int>? frequencyDays,
    HabitTarget? target,
  }) async {
    final canonicalDays = _canonicalFrequencyDays(frequencyDays);
    final priorMatches = state.habits.where((h) => h.id == id);
    final previous = priorMatches.isEmpty ? null : priorMatches.first;
    final habits = [
      for (final habit in state.habits)
        if (habit.id == id)
          // Forward-only target edit (v11): stamp the anchor to today when the
          // target's content changed (or was just set), else preserve the prior
          // anchor so a title/schedule edit can't re-derive past days.
          stampTargetEffectiveFrom(
            habit.copyWith(
              title: title,
              color: color,
              reminderTime: reminderTime,
              clearReminder: reminderTime == null,
              frequencyDays: canonicalDays,
              clearFrequencyDays: canonicalDays == null,
              target: target,
              // A newer-client target this build can't decode reads as
              // target == null and shows as Checkbox — clearTarget:true would
              // wipe its rawTargetBlob and strip the target for good. Preserve
              // the blob on an unrelated edit; only clear when a real target is
              // set (target != null) or the habit isn't a preserved-blob one.
              clearTarget: target == null &&
                  !(habit.verificationRule == null &&
                      hasUnreadableTarget(habit.rawTargetBlob)),
            ),
            previous: previous,
            today: _now(),
          )
        else
          habit,
    ];
    state = state.copyWith(habits: habits);
    await _saveLocal();
    _rescheduleNotifications();
    await _syncRemote(
      () =>
          _repository.updateHabit(habits.firstWhere((habit) => habit.id == id)),
    );
  }

  Future<void> deleteHabit(String id) async {
    state = state.copyWith(
      habits: state.habits.where((habit) => habit.id != id).toList(),
    );
    await _saveLocal();
    _rescheduleNotifications();
    await _syncRemote(() => _repository.deleteHabit(id));
  }

  /// Drag-to-reorder: move the habit at [oldIndex] to [newIndex], reassign every
  /// habit's `displayOrder` to its new position, and persist the new order to
  /// the active repository (cloud batch or private DB). Optimistic + local-first
  /// like the other mutations (a remote failure keeps the local order and flags
  /// the sync warning via [_syncRemote]).
  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    final habits = List<DashboardHabit>.from(state.habits);
    if (oldIndex < 0 || oldIndex >= habits.length) return;
    // `onReorderItem` already adjusts newIndex for the removed item, so it is the
    // final target index (0..length-1) — no extra decrement needed.
    newIndex = newIndex.clamp(0, habits.length - 1);
    if (newIndex == oldIndex) return;

    final moved = habits.removeAt(oldIndex);
    habits.insert(newIndex, moved);
    await reorderHabitsList(habits);
  }

  /// Persist an already-reordered *full* habit list: reassign every habit's
  /// `displayOrder` to its new position, then save (optimistic + local-first,
  /// exactly like [reorderHabits]).
  ///
  /// The Habits › Protocol tab renders a filtered, active-only subset, so it
  /// can't express a reorder as two indices into [state.habits]. It rebuilds the
  /// complete order itself — keeping hidden habits pinned in place — and hands
  /// the whole list here.
  Future<void> reorderHabitsList(List<DashboardHabit> reordered) async {
    final withOrder = [
      for (var i = 0; i < reordered.length; i++)
        reordered[i].copyWith(displayOrder: i),
    ];

    state = state.copyWith(habits: withOrder);
    await _saveLocal();
    await _syncRemote(() => _repository.reorderHabits(withOrder));
  }

  /// Re-schedule the OS daily notifications after a habit add/edit/delete so a
  /// habit's reminder is (un)registered immediately, rather than only after the
  /// user re-saves the Settings page. Reads the user's notification prefs;
  /// fire-and-forget so it never blocks the mutation.
  void _rescheduleNotifications() {
    final prefs = ref.read(sharedPreferencesProvider);
    unawaited(
      DesktopNotificationService.instance
          .sync(
            habitReminders: prefs?.getBool('notif_habit_reminders') ?? true,
            eveningReview: prefs?.getBool('notif_evening_review') ?? true,
            morningBriefTime:
                prefs?.getString('notif_morning_brief_time') ?? '09:00',
            eveningReviewTime:
                prefs?.getString('notif_evening_review_time') ?? '21:00',
            // Honor Focus Mode here too — otherwise any habit edit would
            // re-schedule the notifications the mode is suppressing.
            focusMode: prefs?.getBool('pref_focus_mode') ?? false,
            habits: state.habits,
          )
          .catchError((Object error, StackTrace stack) {
            // Rescheduling is best-effort; a platform/plugin failure must never
            // break the habit mutation (or a test without notification channels).
            AppLogger.error('Failed to reschedule notifications', error, stack);
          }),
    );
  }

  Future<void> updateCheckIn({required int mood, required int energy}) async {
    final checkIn = DailyCheckIn(mood: mood, energy: energy);
    final moods = Map<String, DailyCheckIn>.from(state.moods)
      ..[dashboardDateKey(_now())] = checkIn;
    state = state.copyWith(checkIn: checkIn, moods: moods);
    await _saveLocal();
    await _syncRemote(() => _repository.saveCheckIn(_now(), checkIn));
  }

  Future<void> completeGoal(String id) async {
    await updateGoalState(id, GoalState.completed);
  }

  Future<void> addGoal({
    required String title,
    required String category,
    required Color color,
    required GoalType type,
    required String dueLabel,
    String? categoryId,
    int? year,
    int? quarter,
    int? month,
    int? weekNumber,
    // Optional cumulative NUMERIC target (behind DesktopMacroTargetsConfig).
    // Null [targetAmount] ⇒ an ordinary boolean macro goal, exactly as today.
    double? targetAmount,
    String? targetUnit,
    String? linkedGoalId,
  }) async {
    final now = _now();
    final draft = DashboardGoal(
      id: _newLocalId(),
      title: title,
      category: category,
      color: color,
      progress: 0,
      dueLabel: dueLabel,
      type: type,
      categoryId: categoryId,
      year: type == GoalType.lifetime ? null : (year ?? now.year),
      quarter: type == GoalType.quarterly
          ? (quarter ?? ((now.month - 1) ~/ 3) + 1)
          : null,
      month: type == GoalType.monthly || type == GoalType.weekly
          ? (month ?? now.month)
          : null,
      weekNumber: type == GoalType.weekly
          ? (weekNumber ?? logicalWeekOfMonth(now))
          : null,
      createdAt: now,
      targetAmount: targetAmount,
      targetUnit: targetUnit,
      linkedGoalId: linkedGoalId,
    );
    await _createGoalOptimistically(draft);
  }

  Future<void> updateGoal({
    required String id,
    required String title,
    required String category,
    required Color color,
    String? categoryId,
    // Numeric-target edit (behind DesktopMacroTargetsConfig). When [applyTarget]
    // is false the goal's existing target is left untouched (a plain rename /
    // recategorise). When true the caller is authoritative: a null [targetAmount]
    // reverts to a boolean goal, else the amount/unit/link are set (a null
    // [linkedGoalId] detaches to manual entry).
    bool applyTarget = false,
    double? targetAmount,
    String? targetUnit,
    String? linkedGoalId,
  }) async {
    final goals = [
      for (final goal in state.goals)
        if (goal.id == id)
          _applyGoalEdit(
            goal,
            title: title,
            category: category,
            color: color,
            categoryId: categoryId,
            applyTarget: applyTarget,
            targetAmount: targetAmount,
            targetUnit: targetUnit,
            linkedGoalId: linkedGoalId,
          )
        else
          goal,
    ];
    state = state.copyWith(goals: goals);
    await _saveLocal();
    await _syncRemote(
      () => _repository.updateGoal(goals.firstWhere((goal) => goal.id == id)),
    );
  }

  DashboardGoal _applyGoalEdit(
    DashboardGoal goal, {
    required String title,
    required String category,
    required Color color,
    String? categoryId,
    required bool applyTarget,
    double? targetAmount,
    String? targetUnit,
    String? linkedGoalId,
  }) {
    var updated = goal.copyWith(
      title: title,
      category: category,
      color: color,
      categoryId: categoryId,
      clearCategory: category.isEmpty && categoryId == null,
      clearCategoryId: categoryId == null,
    );
    if (!applyTarget) return updated;
    if (targetAmount == null) {
      // Revert to an ordinary boolean goal (target + unit + link all cleared).
      return updated.copyWith(clearTarget: true);
    }
    return updated.copyWith(
      targetAmount: targetAmount,
      targetUnit: targetUnit,
      linkedGoalId: linkedGoalId,
      // A null link means manual: force it off so linked → manual detaches
      // (copyWith otherwise keeps the existing link on a null argument).
      clearLink: linkedGoalId == null,
    );
  }

  Future<void> updateGoalState(String id, GoalState goalState) async {
    final goals = [
      for (final goal in state.goals)
        if (goal.id == id)
          goal.copyWith(
            state: goalState,
            progress: goalState == GoalState.completed ? 1 : goal.progress,
          )
        else
          goal,
    ];
    state = state.copyWith(goals: goals);
    await _saveLocal();
    await _syncRemote(
      () => _repository.updateGoal(goals.firstWhere((goal) => goal.id == id)),
    );
  }

  Future<void> rescheduleGoal(String id) async {
    final goal = state.goals.firstWhere((goal) => goal.id == id);
    if (goal.type == GoalType.lifetime) return;

    await updateGoalState(id, GoalState.failed);
    final next = _nextGoalPeriod(goal);
    final draft = goal.copyWith(
      id: _newLocalId(),
      state: GoalState.active,
      progress: 0,
      dueLabel: dashboardGoalDueLabel(
        type: goal.type,
        year: next.year,
        quarter: next.quarter,
        month: next.month,
        weekNumber: next.weekNumber,
      ),
      year: next.year,
      quarter: next.quarter,
      month: next.month,
      weekNumber: next.weekNumber,
      createdAt: _now(),
    );
    await _createGoalOptimistically(draft);
  }

  Future<void> deleteGoal(String id) async {
    state = state.copyWith(
      goals: state.goals.where((goal) => goal.id != id).toList(),
    );
    await _saveLocal();
    await _syncRemote(() => _repository.deleteGoal(id));
  }

  Future<void> resetData() async {
    await _repository.resetData();
    state = DashboardSnapshot.empty;
  }

  Future<void> _createGoalOptimistically(DashboardGoal draft) async {
    state = state.copyWith(goals: [...state.goals, draft]);
    await _saveLocal();
    try {
      final goal = await _repository.createGoal(draft);
      state = state.copyWith(
        goals: [
          for (final item in state.goals)
            if (item.id == draft.id) goal else item,
        ],
      );
      await _saveLocal();
    } catch (error, stack) {
      _recordSyncError('Unable to sync the new macro goal', error, stack);
    }
  }

  Future<void> _saveLocal() async {
    try {
      await _repository.save(state);
    } catch (error, stack) {
      AppLogger.error('Unable to save the local dashboard cache', error, stack);
    }
  }

  Future<void> _syncRemote(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      _recordSyncError('Unable to sync dashboard mutation', error, stack);
    }
  }

  void _recordSyncError(String message, Object error, StackTrace stack) {
    AppLogger.error(message, error, stack);
    state = state.copyWith(errorMessage: t.sync.editSavedLocally);
  }

  /// Canonical `goals.frequency_days` shape for the shared private DB: sorted
  /// ISO weekdays (1 = Monday), with an every-day habit stored as null rather
  /// than [1..7]. Null is the encoding the scheduled-day guards on both
  /// platforms already read (`frequencyDays == null` ⇒ due every day), so
  /// normalizing here keeps a full selection from writing a value that means
  /// the same thing but churns sync.
  static const _everyWeekday = {1, 2, 3, 4, 5, 6, 7};

  static List<int>? _canonicalFrequencyDays(List<int>? days) {
    if (days == null || days.isEmpty) return null;
    final unique = days.toSet();
    if (unique.containsAll(_everyWeekday)) return null;
    return unique.toList()..sort();
  }

  String? _nextHabitStatus(String? currentStatus) {
    return switch (currentStatus) {
      null => 'done',
      'done' => 'missed',
      _ => null,
    };
  }

  String _newLocalId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  /// Applies a day's outcome to the habit's cached CURRENT-week grid.
  ///
  /// [inCurrentWeek] is what stops a backfilled day from colliding with this
  /// week's slot for the same weekday. `weeklyProgress` is a 7-slot Mon..Sun
  /// list for the CURRENT week only, so writing index `date.weekday - 1` for an
  /// arbitrary past date silently marks that weekday of THIS week done — which
  /// the manual-target sweep did on every launch after a quiet stretch, showing
  /// completions on days that have not happened yet. `streak` is gated with it:
  /// the streak computed for a swept past day is not today's streak.
  DashboardHabit _setHabitForWeekday(
    DashboardHabit habit,
    int weekdayIndex,
    bool updateToday,
    bool completed,
    int streak, {
    required bool inCurrentWeek,
  }) {
    if (!inCurrentWeek) return habit;

    final progress = [...habit.weeklyProgress];
    progress[weekdayIndex] = completed;

    return habit.copyWith(
      weeklyProgress: progress,
      state: updateToday
          ? (completed ? HabitState.completed : HabitState.pending)
          : habit.state,
      streak: streak,
    );
  }

  bool _isToday(DateTime date) {
    final now = _now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isCurrentWeek(DateTime date) {
    final now = _now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final normalized = DateTime(date.year, date.month, date.day);
    return !normalized.isBefore(monday) && !normalized.isAfter(sunday);
  }

  _GoalPeriod _nextGoalPeriod(DashboardGoal goal) {
    var year = goal.year ?? _now().year;
    var month = goal.month ?? _now().month;
    var quarter = goal.quarter ?? ((month - 1) ~/ 3) + 1;
    var weekNumber = goal.weekNumber ?? ((_now().day - 1) ~/ 7) + 1;

    switch (goal.type) {
      case GoalType.lifetime:
        break;
      case GoalType.annual:
        year++;
      case GoalType.quarterly:
        if (quarter < 4) {
          quarter++;
        } else {
          year++;
          quarter = 1;
        }
        month = (quarter - 1) * 3 + 1;
      case GoalType.monthly:
        if (month < 12) {
          month++;
        } else {
          year++;
          month = 1;
        }
        quarter = ((month - 1) ~/ 3) + 1;
      case GoalType.weekly:
        final maximumWeek = logicalWeeksInMonth(year, month);
        if (weekNumber < maximumWeek) {
          weekNumber++;
        } else if (month < 12) {
          month++;
          weekNumber = 1;
        } else {
          year++;
          month = 1;
          weekNumber = 1;
        }
        quarter = ((month - 1) ~/ 3) + 1;
    }

    return _GoalPeriod(
      year: year,
      quarter: quarter,
      month: month,
      weekNumber: weekNumber,
    );
  }
}

class _GoalPeriod {
  const _GoalPeriod({
    required this.year,
    required this.quarter,
    required this.month,
    required this.weekNumber,
  });

  final int year;
  final int quarter;
  final int month;
  final int weekNumber;
}
