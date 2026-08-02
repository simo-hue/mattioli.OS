import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/secure_storage_utils.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/core/macro_targets_config.dart';
import 'package:evolve_desktop/core/targets_config.dart';
import 'package:evolve_desktop/features/dashboard/data/private_dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:evolve_desktop/features/dashboard/domain/macro_goal_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/calendar_days.dart';

abstract class DashboardRepository {
  bool get isCloudBacked => false;

  DashboardSnapshot load();

  Future<DashboardSnapshot> refresh() async => load();

  Future<void> save(DashboardSnapshot snapshot);

  Future<DashboardHabit> createHabit(DashboardHabit habit) async => habit;

  Future<void> updateHabit(DashboardHabit habit) async {}

  Future<void> deleteHabit(String id) async {}

  /// Persists the `display_order` of each habit to its position in [habits].
  Future<void> reorderHabits(List<DashboardHabit> habits) async {}

  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) async {
    return switch (currentStatus) {
      null => 'done',
      'done' => 'missed',
      _ => null,
    };
  }

  Future<void> saveCheckIn(DateTime date, DailyCheckIn checkIn) async {}

  /// Persists a quantitative habit's accumulated progress for a day AND the
  /// verdict derived from it: writes/deletes the `goal_progress` row (the
  /// number) and writes/deletes the `goal_logs` row ([derivedStatus] — already
  /// evaluated by the controller via `evaluateTarget`/`TargetVerdict.logStatus`,
  /// null ⇒ no verdict yet). [streak] is the controller's `computeStreak` result
  /// for the day, written directly. Base is a no-op (used by the offline proxy
  /// before the real repository resolves).
  ///
  /// [verdictOnly] skips the `goal_progress` leg entirely and writes the verdict
  /// alone. It exists for the auto-fail sweep, whose days have NO stored number
  /// by definition — going through the normal path would issue `amount 0`, and
  /// `amount 0` *deletes*. On a day that really has no row that delete is a
  /// no-op, but if the in-memory map were ever wrong it would destroy a real
  /// count and tombstone the deletion to sync. Not writing is the only way to be
  /// sure. See `TargetReconcileChange.verdictOnly`.
  Future<void> setHabitProgress({
    required String habitId,
    required DateTime date,
    required double amount,
    required String? derivedStatus,
    required int streak,
    bool verdictOnly = false,
  }) async {}

  Future<DashboardGoal> createGoal(DashboardGoal goal) async => goal;

  Future<void> updateGoal(DashboardGoal goal) async {}

  Future<void> deleteGoal(String id) async {}

  Future<void> resetData() async {
    await save(DashboardSnapshot.empty);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final dataMode = ref.watch(activeDesktopDataModeProvider);

  if (dataMode.isPrivate) {
    // Private mode: use the local encrypted database.
    // The owner ID is resolved asynchronously on first refresh; we provide a
    // placeholder here that PrivateDashboardRepository will replace.
    return _PrivateRepositoryProxy();
  }

  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(
    desktopAuthControllerProvider.select((state) => state.user?.id),
  );
  if (client == null || userId == null) {
    return UnavailableDashboardRepository();
  }
  return SupabaseDashboardRepository(client: client, userId: userId);
});

/// A proxy that resolves the private owner ID lazily.  The provider is
/// synchronous so we cannot `await` during construction; instead the
/// first call to [refresh] bootstraps the real repository.
class _PrivateRepositoryProxy extends DashboardRepository {
  PrivateDashboardRepository? _inner;

  @override
  DashboardSnapshot load() => _inner?.load() ?? DashboardSnapshot.empty;

  @override
  Future<DashboardSnapshot> refresh() async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    return _inner!.refresh();
  }

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.save(snapshot);
  }

  @override
  Future<DashboardHabit> createHabit(DashboardHabit habit) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    return _inner!.createHabit(habit);
  }

  @override
  Future<void> updateHabit(DashboardHabit habit) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.updateHabit(habit);
  }

  @override
  Future<void> deleteHabit(String id) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.deleteHabit(id);
  }

  @override
  Future<void> reorderHabits(List<DashboardHabit> habits) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.reorderHabits(habits);
  }

  @override
  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    return _inner!.setHabitStatus(
      habitId: habitId,
      date: date,
      currentStatus: currentStatus,
    );
  }

  @override
  Future<void> setHabitProgress({
    required String habitId,
    required DateTime date,
    required double amount,
    required String? derivedStatus,
    required int streak,
    bool verdictOnly = false,
  }) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.setHabitProgress(
      habitId: habitId,
      date: date,
      amount: amount,
      derivedStatus: derivedStatus,
      streak: streak,
      verdictOnly: verdictOnly,
    );
  }

  @override
  Future<void> saveCheckIn(DateTime date, DailyCheckIn checkIn) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.saveCheckIn(date, checkIn);
  }

  @override
  Future<DashboardGoal> createGoal(DashboardGoal goal) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    return _inner!.createGoal(goal);
  }

  @override
  Future<void> updateGoal(DashboardGoal goal) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.updateGoal(goal);
  }

  @override
  Future<void> deleteGoal(String id) async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.deleteGoal(id);
  }

  @override
  Future<void> resetData() async {
    _inner ??= PrivateDashboardRepository(
      ownerId: await DesktopPrivateDb.instance.ownerId,
    );
    await _inner!.resetData();
  }
}

class UnavailableDashboardRepository extends DashboardRepository {
  @override
  DashboardSnapshot load() => DashboardSnapshot.empty;

  @override
  Future<DashboardSnapshot> refresh() async => DashboardSnapshot.empty;

  @override
  Future<void> save(DashboardSnapshot snapshot) => _requireSession();

  @override
  Future<DashboardHabit> createHabit(DashboardHabit habit) => _requireSession();

  @override
  Future<void> updateHabit(DashboardHabit habit) => _requireSession();

  @override
  Future<void> deleteHabit(String id) => _requireSession();

  @override
  Future<void> reorderHabits(List<DashboardHabit> habits) => _requireSession();

  @override
  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) => _requireSession();

  @override
  Future<void> setHabitProgress({
    required String habitId,
    required DateTime date,
    required double amount,
    required String? derivedStatus,
    required int streak,
    bool verdictOnly = false,
  }) => _requireSession();

  @override
  Future<void> saveCheckIn(DateTime date, DailyCheckIn checkIn) =>
      _requireSession();

  @override
  Future<DashboardGoal> createGoal(DashboardGoal goal) => _requireSession();

  @override
  Future<void> updateGoal(DashboardGoal goal) => _requireSession();

  @override
  Future<void> deleteGoal(String id) => _requireSession();

  @override
  Future<void> resetData() => _requireSession();

  Future<T> _requireSession<T>() {
    throw StateError('An authenticated Supabase session is required.');
  }
}

class SupabaseDashboardRepository extends DashboardRepository {
  SupabaseDashboardRepository({required SupabaseClient client, required userId})
    : _client = client,
      _userId = userId;

  final SupabaseClient _client;
  final String _userId;
  DashboardSnapshot _snapshot = DashboardSnapshot.empty;

  String get _cacheKey => 'desktop_dashboard_cache_$_userId';
  String get _pendingKey => 'desktop_dashboard_pending_$_userId';

  @override
  bool get isCloudBacked => true;

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<DashboardSnapshot> refresh() async {
    final cached = await _readCache();
    if (cached != null) _snapshot = cached;

    try {
      await _flushPendingMutations();
      // `goal_progress` is a NEW table (schema v9 / the 20260724 migration). Its
      // read is isolated in its own try/catch (below) and NOT part of this
      // Future.wait: if the migration has not been applied to this project yet,
      // `from('goal_progress')` returns "relation does not exist", and a rejected
      // member of Future.wait would sink the ENTIRE dashboard refresh — leaving
      // every account-mode desktop user on a permanent "sync failed" empty state,
      // for existing goals/logs/moods too. Kicked off concurrently, awaited after.
      // Mirrors mobile, which degrades progress to empty on the same failure.
      final progressFuture = _fetchProgressRows();
      final responses = await Future.wait([
        _client
            .from('goals')
            .select()
            .eq('user_id', _userId)
            .order('display_order', ascending: true)
            .order('created_at', ascending: true),
        _client.from('goal_logs').select().eq('user_id', _userId),
        _client
            .from('long_term_goals')
            .select()
            .eq('user_id', _userId)
            .order('created_at', ascending: true),
        _client.from('daily_moods').select().eq('user_id', _userId),
      ]);
      final progressRows = await progressFuture;
      _snapshot = _fromRemote(
        habitRows: _rows(responses[0]),
        logRows: _rows(responses[1]),
        goalRows: _rows(responses[2]),
        moodRows: _rows(responses[3]),
        progressRows: progressRows ?? const [],
      ).copyWith(progressStale: progressRows == null);
      await _writeCache(_snapshot);
      return _snapshot;
    } catch (error, stack) {
      AppLogger.error('Unable to refresh the desktop dashboard', error, stack);
      Error.throwWithStackTrace(
        DashboardRefreshException(cachedSnapshot: cached, cause: error),
        stack,
      );
    }
  }

  /// Fetches `goal_progress` rows, degrading to an empty list on ANY error
  /// rather than failing the whole refresh — so a pre-migration project (the
  /// table doesn't exist yet) still loads goals/logs/moods normally. Matches the
  /// mobile client's isolation of the same new-table read.
  /// Returns null when the read FAILED, so the caller can tell that apart from
  /// an account with no progress rows. Returning `const []` for both is what
  /// let a failed fetch be read as "every limit day was quiet", which the sweep
  /// then applied as amount 0 and DELETED the real server rows.
  Future<List<Map<String, dynamic>>?> _fetchProgressRows() async {
    try {
      final res = await _client
          .from('goal_progress')
          .select()
          .eq('user_id', _userId);
      return _rows(res);
    } catch (error, stack) {
      AppLogger.error(
        'goal_progress fetch failed (pre-migration?) — degrading to empty, '
        'and marking the snapshot progressStale so nothing writes on absence',
        error,
        stack,
      );
      return null;
    }
  }

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _snapshot = snapshot;
    await _writeCache(snapshot);
  }

  @override
  Future<DashboardHabit> createHabit(DashboardHabit habit) async {
    final payload = habit.toRemoteJson()..['user_id'] = _userId;
    final row = await _runOrQueue(
      _PendingMutation.insert('goals', payload),
      () => _client.from('goals').insert(payload).select().single(),
    );
    return DashboardHabit.fromRemoteJson(
      Map<String, dynamic>.from(row),
      weeklyProgress: habit.weeklyProgress,
      state: habit.state,
      streak: habit.streak,
    );
  }

  @override
  Future<void> updateHabit(DashboardHabit habit) async {
    final payload = habit.toRemoteJson()..remove('id');
    // toRemoteJson OMITS frequency_days when null (every-day), and an UPDATE
    // leaves omitted columns untouched — so clearing a restricted schedule to
    // every-day would keep the old days on the server and resurrect on the next
    // refetch. Write it explicitly (null clears the column).
    payload['frequency_days'] = habit.frequencyDays;
    // Same omitted-column hazard for the target: write it explicitly so removing
    // a habit's target actually clears the column rather than leaving the stale
    // target to resurrect on the next refetch. GATED behind the flag (matching
    // the macro force-write below and the mobile client): `goals.target` exists
    // only after the v9 migration, and an UNGATED explicit `target: null` on
    // every plain-habit edit would make PostgREST reject the unknown column and
    // LOSE the edit on any pre-migration project. While dark, plain edits stay
    // column-free and migration-independent; once live (migration applied) the
    // force-write clears a removed target correctly.
    if (DesktopTargetsConfig.enabled) {
      payload['target'] = habit.targetColumnValue;
      // Force-write the forward-only anchor too (same omitted-column hazard):
      // removing a target must clear its effective-from, or a stale anchor
      // orphans on the server. Mirrors the private write and the mobile client.
      payload['target_effective_from'] =
          habit.targetColumnValue != null && habit.targetEffectiveFrom != null
              ? habit.targetEffectiveFrom!.toIso8601String().substring(0, 10)
              : null;
      // Same omitted-column hazard for the verify columns when the rule is null:
      // toRemoteJson omits verify_conditions/verify_effective_from, so switching a
      // preserved compound to a Number would leave the stale compound on the
      // server to win the read precedence over the new target. Force-null them
      // UNLESS this is a target-free preserved compound we must keep (mirrors the
      // mobile client's preservesCompound guard). Gated with the target write so
      // it only fires once the verify migrations are live (same deploy batch).
      if (habit.verificationRule == null) {
        final preservesCompound = habit.targetColumnValue == null &&
            hasUnreadableVerifyConditions(habit.rawVerifyConditionsBlob);
        if (!preservesCompound) {
          payload['verify_conditions'] = null;
          payload['verify_effective_from'] = null;
        }
      }
    }
    await _runOrQueue(
      _PendingMutation.update('goals', payload, {'id': habit.id}),
      () => _client.from('goals').update(payload).eq('id', habit.id),
    );
  }

  @override
  Future<void> deleteHabit(String id) async {
    // ACCOUNT-mode counterpart of the private repo's delete-time snapshot: before
    // the delete cascades this habit's goal_progress away and the ON DELETE SET
    // NULL FK un-links any macro goal it fed, freeze the derived total into each
    // linked macro goal's progress_amount. Derived from the in-memory snapshot
    // (which already holds every goal_progress row), so it needs no extra read
    // and is a no-op — no round-trip — while the feature is dark and nothing is
    // linked.
    await _snapshotLinkedMacroGoals(id);
    await _runOrQueue(
      _PendingMutation.delete('goals', {'id': id}),
      () => _client.from('goals').delete().eq('id', id),
    );
  }

  Future<void> _snapshotLinkedMacroGoals(String habitId) async {
    final snapshots = linkedMacroGoalSnapshots(
      goals: _snapshot.goals,
      habitProgress: _snapshot.habitProgress,
      habitId: habitId,
    );
    for (final snap in snapshots) {
      final payload = {'progress_amount': snap.total, 'linked_goal_id': null};
      await _runOrQueue(
        _PendingMutation.update('long_term_goals', payload, {'id': snap.goalId}),
        () => _client
            .from('long_term_goals')
            .update(payload)
            .eq('id', snap.goalId),
      );
    }
  }

  @override
  Future<void> reorderHabits(List<DashboardHabit> habits) async {
    if (habits.isEmpty) return;
    // One atomic batch upsert of just {id, display_order} (these are existing
    // rows, so PostgREST takes the ON CONFLICT (id) DO UPDATE path). Mirrors the
    // mobile client against the same Supabase backend. A SINGLE request is
    // deliberate: N separate updates could half-apply on a mid-loop failure and
    // corrupt the persisted order. Not routed through the single-row offline
    // queue — a failed offline reorder simply keeps the local order until the
    // user reorders again (a cheap, idempotent action).
    final updates = [
      for (var i = 0; i < habits.length; i++)
        {'id': habits[i].id, 'display_order': i},
    ];
    await _client.from('goals').upsert(updates, onConflict: 'id');
  }

  @override
  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) async {
    final nextStatus = await super.setHabitStatus(
      habitId: habitId,
      date: date,
      currentStatus: currentStatus,
    );
    final dateKey = dashboardDateKey(date);
    if (nextStatus == null) {
      final filters = {'user_id': _userId, 'goal_id': habitId, 'date': dateKey};
      await _runOrQueue(
        _PendingMutation.delete('goal_logs', filters),
        () => _client
            .from('goal_logs')
            .delete()
            .eq('user_id', _userId)
            .eq('goal_id', habitId)
            .eq('date', dateKey),
      );
      return null;
    }

    final payload = {
      'user_id': _userId,
      'goal_id': habitId,
      'date': dateKey,
      'status': nextStatus,
      'streak': _nextStreak(habitId, date, nextStatus),
    };
    await _runOrQueue(
      _PendingMutation.upsert('goal_logs', payload, onConflict: 'goal_id,date'),
      () =>
          _client.from('goal_logs').upsert(payload, onConflict: 'goal_id,date'),
    );
    return nextStatus;
  }

  @override
  Future<void> setHabitProgress({
    required String habitId,
    required DateTime date,
    required double amount,
    required String? derivedStatus,
    required int streak,
    bool verdictOnly = false,
  }) async {
    final dateKey = dashboardDateKey(date);

    // 1) The progress number (goal_progress). Deterministic id matches the
    // private store's PrivateDbSchema.goalProgressId so the two backends can't
    // mint different ids for one habit-day. Skipped entirely for a verdict-only
    // write — see [progressRowWriteFor].
    final rowWrite = progressRowWriteFor(verdictOnly: verdictOnly, amount: amount);
    if (rowWrite == ProgressRowWrite.none) {
      // nothing to write: the day never had a number
    } else if (rowWrite == ProgressRowWrite.delete) {
      final filters = {'user_id': _userId, 'goal_id': habitId, 'date': dateKey};
      await _runOrQueue(
        _PendingMutation.delete('goal_progress', filters),
        () => _client
            .from('goal_progress')
            .delete()
            .eq('user_id', _userId)
            .eq('goal_id', habitId)
            .eq('date', dateKey),
      );
    } else {
      final payload = {
        'id': '$habitId:$dateKey',
        'user_id': _userId,
        'goal_id': habitId,
        'date': dateKey,
        'amount': amount,
        'source': 'manual',
      };
      await _runOrQueue(
        _PendingMutation.upsert(
          'goal_progress',
          payload,
          onConflict: 'goal_id,date',
        ),
        () => _client
            .from('goal_progress')
            .upsert(payload, onConflict: 'goal_id,date'),
      );
    }

    // 2) The derived verdict (goal_logs) — set or clear. Never writes
    // goal_logs.value: a manual count is not a health measurement.
    if (derivedStatus == null) {
      final filters = {'user_id': _userId, 'goal_id': habitId, 'date': dateKey};
      await _runOrQueue(
        _PendingMutation.delete('goal_logs', filters),
        () => _client
            .from('goal_logs')
            .delete()
            .eq('user_id', _userId)
            .eq('goal_id', habitId)
            .eq('date', dateKey),
      );
    } else {
      final payload = {
        'user_id': _userId,
        'goal_id': habitId,
        'date': dateKey,
        'status': derivedStatus,
        'streak': streak,
      };
      await _runOrQueue(
        _PendingMutation.upsert(
          'goal_logs',
          payload,
          onConflict: 'goal_id,date',
        ),
        () => _client
            .from('goal_logs')
            .upsert(payload, onConflict: 'goal_id,date'),
      );
    }
  }

  @override
  Future<void> saveCheckIn(DateTime date, DailyCheckIn checkIn) async {
    final payload = {
      'user_id': _userId,
      'date': dashboardDateKey(date),
      'mood_score': checkIn.mood,
      'energy_score': checkIn.energy,
    };
    await _runOrQueue(
      _PendingMutation.upsert(
        'daily_moods',
        payload,
        onConflict: 'user_id,date',
      ),
      () => _client
          .from('daily_moods')
          .upsert(payload, onConflict: 'user_id,date'),
    );
  }

  @override
  Future<DashboardGoal> createGoal(DashboardGoal goal) async {
    final payload = goal.toRemoteJson()..['user_id'] = _userId;
    final row = await _runOrQueue(
      _PendingMutation.insert('long_term_goals', payload),
      () => _client.from('long_term_goals').insert(payload).select().single(),
    );
    return DashboardGoal.fromRemoteJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> updateGoal(DashboardGoal goal) async {
    final payload = goal.toRemoteJson()..remove('id');
    // toRemoteJson OMITS the numeric-target columns when null, and an UPDATE
    // leaves omitted columns untouched — so on its own it could never actively
    // CLEAR a target or BREAK a link (reverting a numeric goal to boolean, or
    // unlinking a habit). Force-write them explicitly so null clears the column,
    // exactly as updateHabit force-writes `target`/`frequency_days`.
    //
    // Gated on the feature flag on purpose: the columns only exist after the
    // (still-pending) macro-target Supabase migration, and clearing is only ever
    // needed once the editor can set a target — which is itself flag-gated. While
    // the feature is dark, a plain title/category edit keeps omitting them, so it
    // can't fail against a pre-migration schema. INSERT (createGoal) stays
    // conditional via toRemoteJson for the same pre-migration safety.
    if (DesktopMacroTargetsConfig.enabled) {
      payload['target_amount'] = goal.targetAmount;
      payload['target_unit'] = goal.targetUnit;
      payload['progress_amount'] = goal.progressAmount;
      payload['linked_goal_id'] = goal.linkedGoalId;
    }
    await _runOrQueue(
      _PendingMutation.update('long_term_goals', payload, {'id': goal.id}),
      () => _client.from('long_term_goals').update(payload).eq('id', goal.id),
    );
  }

  @override
  Future<void> deleteGoal(String id) async {
    await _runOrQueue(
      _PendingMutation.delete('long_term_goals', {'id': id}),
      () => _client.from('long_term_goals').delete().eq('id', id),
    );
  }

  @override
  Future<void> resetData() async {
    await _client.from('goals').delete().eq('user_id', _userId);
    await _client.from('long_term_goals').delete().eq('user_id', _userId);
    _snapshot = DashboardSnapshot.empty;
    await SecureStorageUtils.delete(_cacheKey);
    await SecureStorageUtils.delete(_pendingKey);
  }

  Future<T> _runOrQueue<T>(
    _PendingMutation mutation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (error, stack) {
      if (_isRetryable(error)) {
        await _enqueue(mutation);
      }
      AppLogger.error(
        'Unable to sync ${mutation.operation} on ${mutation.table}',
        error,
        stack,
      );
      rethrow;
    }
  }

  Future<void> _flushPendingMutations() async {
    final pending = await _readPendingMutations();
    if (pending.isEmpty) return;

    final remaining = <_PendingMutation>[];
    Object? replayError;
    StackTrace? replayStack;
    for (var index = 0; index < pending.length; index++) {
      final mutation = pending[index];
      try {
        await _applyPending(mutation);
      } catch (error, stack) {
        AppLogger.error(
          'Unable to replay ${mutation.operation} on ${mutation.table}',
          error,
          stack,
        );
        remaining.addAll(pending.skip(index));
        replayError = error;
        replayStack = stack;
        break;
      }
    }
    await _writePendingMutations(remaining);
    if (replayError != null) {
      Error.throwWithStackTrace(replayError, replayStack!);
    }
  }

  Future<void> _applyPending(_PendingMutation mutation) async {
    switch (mutation.operation) {
      case 'insert':
        // A failed response does not prove the insert failed server-side.
        // Replaying it as an upsert keeps the mutation idempotent.
        await _client.from(mutation.table).upsert(mutation.payload);
        return;
      case 'update':
        var query = _client.from(mutation.table).update(mutation.payload);
        for (final filter in mutation.filters.entries) {
          query = query.eq(filter.key, filter.value);
        }
        await query;
        return;
      case 'delete':
        var query = _client.from(mutation.table).delete();
        for (final filter in mutation.filters.entries) {
          query = query.eq(filter.key, filter.value);
        }
        await query;
        return;
      case 'upsert':
        await _client
            .from(mutation.table)
            .upsert(mutation.payload, onConflict: mutation.onConflict);
        return;
      default:
        throw FormatException(
          'Unsupported pending dashboard mutation: ${mutation.operation}',
        );
    }
  }

  Future<List<_PendingMutation>> _readPendingMutations() async {
    final encoded = await SecureStorageUtils.read(_pendingKey);
    if (encoded == null) return [];
    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .map((item) => _PendingMutation.fromJson(item as Map))
        .toList();
  }

  Future<void> _enqueue(_PendingMutation mutation) async {
    final pending = await _readPendingMutations();
    if (pending.any((item) => item.fingerprint == mutation.fingerprint)) {
      return;
    }
    await _writePendingMutations([...pending, mutation]);
  }

  Future<void> _writePendingMutations(List<_PendingMutation> mutations) async {
    if (mutations.isEmpty) {
      await SecureStorageUtils.delete(_pendingKey);
      return;
    }
    await SecureStorageUtils.write(
      _pendingKey,
      jsonEncode([for (final mutation in mutations) mutation.toJson()]),
      context: 'SupabaseDashboardRepository pending mutations',
    );
  }

  bool _isRetryable(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('clientexception') ||
        message.contains('connection closed') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('network request failed') ||
        message.contains('socketexception') ||
        message.contains('timed out') ||
        message.contains('timeout');
  }

  DashboardSnapshot _fromRemote({
    required List<Map<String, dynamic>> habitRows,
    required List<Map<String, dynamic>> logRows,
    required List<Map<String, dynamic>> goalRows,
    required List<Map<String, dynamic>> moodRows,
    required List<Map<String, dynamic>> progressRows,
  }) {
    final logs = <String, Map<String, String>>{};
    for (final row in logRows) {
      final date = row['date'] as String;
      final goalId = row['goal_id'] as String;
      logs.putIfAbsent(date, () => {})[goalId] = row['status'] as String;
    }

    final progress = <String, Map<String, double>>{};
    for (final row in progressRows) {
      final date = row['date'] as String;
      final goalId = row['goal_id'] as String;
      progress.putIfAbsent(date, () => {})[goalId] =
          (row['amount'] as num).toDouble();
    }

    final now = DateTime.now();
    final monday = shiftDays(DateTime(
      now.year,
      now.month,
      now.day,
    ), -(now.weekday - 1));
    final habits = [
      for (final row in habitRows)
        DashboardHabit.fromRemoteJson(
          row,
          weeklyProgress: [
            for (var day = 0; day < 7; day++)
              logs[dashboardDateKey(
                    shiftDays(monday, day),
                  )]?[row['id']] ==
                  'done',
          ],
          state: logs[dashboardDateKey(now)]?[row['id']] == 'done'
              ? HabitState.completed
              : HabitState.pending,
          streak: _latestStreak(row['id'] as String, logRows),
        ),
    ];
    final moods = <String, DailyCheckIn>{};
    for (final row in moodRows) {
      moods[row['date'] as String] = DailyCheckIn(
        mood: row['mood_score'] as int?,
        energy: row['energy_score'] as int?,
      );
    }
    final temporary = DashboardSnapshot(
      habits: habits,
      goals: goalRows.map(DashboardGoal.fromRemoteJson).toList(),
      trend: const [],
      checkIn: moods[dashboardDateKey(now)] ?? const DailyCheckIn(),
      habitLogs: logs,
      habitProgress: progress,
      moods: moods,
    );
    final trendDays = [
      for (var i = 6; i >= 0; i--) shiftDays(now, -i),
    ];

    return temporary.copyWith(
      trend: [
        for (final date in trendDays)
          TrendPoint(
            label: _formatAbbrev(t.habitsPage.weekdayAbbrevUpper[date.weekday - 1]),
            value: temporary.completionFor(date),
          ),
      ],
    );
  }

  String _formatAbbrev(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  int _latestStreak(String habitId, List<Map<String, dynamic>> rows) {
    final matches = rows.where((row) => row['goal_id'] == habitId).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return matches.isEmpty ? 0 : (matches.first['streak'] as int? ?? 0);
  }

  int _nextStreak(String habitId, DateTime date, String nextStatus) {
    final previousDate =
        dashboardDateKey(shiftDays(DateTime(date.year, date.month, date.day), -1));
    final previousStatus = _snapshot.habitLogs[previousDate]?[habitId];
    final previous = _snapshot.habits
        .where((habit) => habit.id == habitId)
        .map((habit) => habit.streak)
        .firstOrNull;
    if (nextStatus == 'done') {
      return previousStatus == 'done' ? (previous ?? 0) + 1 : 1;
    }
    return previous != null && previous > 0 ? -1 : (previous ?? 0) - 1;
  }

  List<Map<String, dynamic>> _rows(dynamic response) {
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<DashboardSnapshot?> _readCache() async {
    try {
      final encoded = await SecureStorageUtils.read(_cacheKey);
      if (encoded == null) return null;
      return _fromCache(Map<String, dynamic>.from(jsonDecode(encoded) as Map));
    } catch (error, stack) {
      AppLogger.error(
        'Unable to read the desktop dashboard cache',
        error,
        stack,
      );
      return null;
    }
  }

  Future<void> _writeCache(DashboardSnapshot snapshot) async {
    await SecureStorageUtils.write(
      _cacheKey,
      jsonEncode(_toCache(snapshot)),
      context: 'SupabaseDashboardRepository cache',
    );
  }

  Map<String, dynamic> _toCache(DashboardSnapshot snapshot) => {
    'habits': [
      for (final habit in snapshot.habits)
        {
          ...habit.toRemoteJson(),
          'streak': habit.streak,
          'weekly_progress': habit.weeklyProgress,
          'state': habit.state.name,
        },
    ],
    'goals': [for (final goal in snapshot.goals) goal.toRemoteJson()],
    'trend': [
      for (final point in snapshot.trend)
        {'label': point.label, 'value': point.value},
    ],
    'check_in': snapshot.checkIn.toJson(),
    'habit_logs': snapshot.habitLogs,
    'habit_progress': snapshot.habitProgress,
    // The staleness of `habit_progress` travels WITH it. A snapshot whose
    // progress fetch failed is cached like any other; without this flag it comes
    // back reporting a healthy empty map, and the sweep's guard — the one thing
    // standing between a failed read and "the user recorded nothing" — passes on
    // data it was written to reject.
    'progress_stale': snapshot.progressStale,
    'moods': {
      for (final mood in snapshot.moods.entries) mood.key: mood.value.toJson(),
    },
  };

  DashboardSnapshot _fromCache(Map<String, dynamic> json) {
    final habits = (json['habits'] as List<dynamic>)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .map(
          (row) => DashboardHabit.fromRemoteJson(
            row,
            weeklyProgress: (row['weekly_progress'] as List<dynamic>)
                .map((value) => value as bool)
                .toList(),
            state: HabitState.values.byName(row['state'] as String),
            streak: row['streak'] as int,
          ),
        )
        .toList();
    final logs = <String, Map<String, String>>{
      for (final entry in Map<String, dynamic>.from(
        json['habit_logs'] as Map,
      ).entries)
        entry.key: Map<String, String>.from(entry.value as Map),
    };
    // `habit_progress` is absent from caches written by a pre-targets build, so
    // default it to empty rather than assuming the key exists.
    final progress = <String, Map<String, double>>{
      for (final entry in Map<String, dynamic>.from(
        (json['habit_progress'] as Map?) ?? const {},
      ).entries)
        entry.key: {
          for (final e in (entry.value as Map).entries)
            e.key as String: (e.value as num).toDouble(),
        },
    };
    final moods = <String, DailyCheckIn>{
      for (final entry in Map<String, dynamic>.from(
        json['moods'] as Map,
      ).entries)
        entry.key: DailyCheckIn.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        ),
    };
    return DashboardSnapshot(
      habits: habits,
      goals: (json['goals'] as List<dynamic>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .map(DashboardGoal.fromRemoteJson)
          .toList(),
      trend: (json['trend'] as List<dynamic>)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .map(
            (row) => TrendPoint(
              label: row['label'] as String,
              value: (row['value'] as num).toDouble(),
            ),
          )
          .toList(),
      checkIn: DailyCheckIn.fromJson(
        Map<String, dynamic>.from(json['check_in'] as Map),
      ),
      habitLogs: logs,
      habitProgress: progress,
      // Absent ⇒ a cache written before this key existed, whose progress map may
      // have been empty-because-it-failed with nothing recording that. Distrust
      // it: the cost is one skipped sweep, and the sweep is idempotent and runs
      // again on the next refresh. The cost of the other default is writing
      // verdicts from a map that never loaded.
      progressStale: json['progress_stale'] as bool? ?? true,
      moods: moods,
    );
  }
}

/// What a `setHabitProgress` call must do to the `goal_progress` ROW.
enum ProgressRowWrite {
  /// Leave the row completely alone — there is no number to record.
  none,

  /// Remove the row: the day's amount went back to zero.
  delete,

  /// Store the amount.
  upsert,
}

/// The one place that decides whether a habit-day's `goal_progress` row is
/// touched, and how. Both backends switch on this rather than each re-deriving
/// it from `verdictOnly` and `amount`.
///
/// It is a shared function and not two `if`s because the [ProgressRowWrite.none]
/// case is the entire safety argument of the auto-fail sweep, and it is the
/// hardest branch to reach in a test: the real backends need a live SQLCipher
/// database or a Supabase client, so nothing in the suite executes those
/// statements. Pulling the DECISION out means the branch that decides whether a
/// DELETE reaches the user's data is covered even though the statement issuing
/// it is not.
///
/// [ProgressRowWrite.none] is not the same as [ProgressRowWrite.delete] against
/// an absent row. They produce the same database on a day that genuinely has no
/// row — and diverge exactly when the in-memory map is WRONG, which is the case
/// the flag exists for: a delete driven by a misread absence destroys a real
/// count and tombstones it to sync, while `none` cannot.
ProgressRowWrite progressRowWriteFor({
  required bool verdictOnly,
  required double amount,
}) {
  if (verdictOnly) return ProgressRowWrite.none;
  return amount <= 0 ? ProgressRowWrite.delete : ProgressRowWrite.upsert;
}

class DashboardRefreshException implements Exception {
  const DashboardRefreshException({
    required this.cachedSnapshot,
    required this.cause,
  });

  final DashboardSnapshot? cachedSnapshot;
  final Object cause;

  @override
  String toString() => 'Dashboard refresh failed: $cause';
}

class _PendingMutation {
  const _PendingMutation({
    required this.operation,
    required this.table,
    required this.payload,
    required this.filters,
    this.onConflict,
  });

  factory _PendingMutation.insert(String table, Map<String, dynamic> payload) {
    return _PendingMutation(
      operation: 'insert',
      table: table,
      payload: payload,
      filters: const {},
    );
  }

  factory _PendingMutation.update(
    String table,
    Map<String, dynamic> payload,
    Map<String, dynamic> filters,
  ) {
    return _PendingMutation(
      operation: 'update',
      table: table,
      payload: payload,
      filters: filters,
    );
  }

  factory _PendingMutation.delete(String table, Map<String, dynamic> filters) {
    return _PendingMutation(
      operation: 'delete',
      table: table,
      payload: const {},
      filters: filters,
    );
  }

  factory _PendingMutation.upsert(
    String table,
    Map<String, dynamic> payload, {
    required String onConflict,
  }) {
    return _PendingMutation(
      operation: 'upsert',
      table: table,
      payload: payload,
      filters: const {},
      onConflict: onConflict,
    );
  }

  factory _PendingMutation.fromJson(Map<dynamic, dynamic> json) {
    return _PendingMutation(
      operation: json['operation'] as String,
      table: json['table'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      filters: Map<String, dynamic>.from(json['filters'] as Map),
      onConflict: json['on_conflict'] as String?,
    );
  }

  final String operation;
  final String table;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> filters;
  final String? onConflict;

  String get fingerprint => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
    'operation': operation,
    'table': table,
    'payload': payload,
    'filters': filters,
    if (onConflict != null) 'on_conflict': onConflict,
  };
}
