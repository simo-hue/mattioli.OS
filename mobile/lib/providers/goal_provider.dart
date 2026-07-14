import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/goal.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import '../core/notifications.dart';
import '../core/navigator_key.dart';
import '../core/app_logger.dart';
import '../core/verification_config.dart';
import '../core/verification_providers.dart';
import '../core/secure_storage_utils.dart';
import '../core/data_mode.dart';
import '../core/private_local_database.dart';
import '../core/streak_utils.dart';
import '../ui/widgets/error_modal.dart';
import '../i18n/translations.g.dart';

final initialGoalsProvider = Provider<String>((ref) => '[]');
final initialLogsProvider = Provider<String>((ref) => '{}');

/// The Supabase `user.id` the offline caches ('goals_cache' / 'goal_logs_cache')
/// currently belong to. Used to refuse overwriting one account's populated cache
/// with a DIFFERENT account's empty fetch result (which otherwise reads as "my
/// logs vanished"). A single, non-user-keyed cache is shared across accounts, so
/// this marker is what distinguishes a genuine same-user clear from cross-account
/// contamination.
const String kCacheOwnerKey = 'cache_owner_user_id';

/// Whether a fetched result for [userId] may overwrite the on-disk cache.
/// A non-empty result always may (it's this account's real data). An EMPTY
/// result may only when it belongs to the same account the cache already holds
/// (a genuine "all cleared" for this user) — never when a DIFFERENT account
/// returns nothing, which would clobber the current cache and read as data loss.
/// A first-ever write (no recorded owner) is allowed.
Future<bool> cacheOverwriteAllowed(
  String userId, {
  required bool isEmptyResult,
}) async {
  if (!isEmptyResult) return true;
  final owner = await SecureStorageUtils.read(kCacheOwnerKey);
  return owner == null || owner == userId;
}

Future<void> rememberCacheOwner(String userId) => SecureStorageUtils.tryWrite(
      kCacheOwnerKey,
      userId,
      context: 'cache owner',
    );

// ─── Goals Provider (Offline-First) ─────────────────────────────────────────

class GoalsNotifier extends Notifier<List<Goal>> {
  static const String _cacheKey = 'goals_cache';

  @override
  List<Goal> build() {
    final dataMode = ref.watch(activeDataModeProvider);
    if (dataMode == AppDataMode.private) {
      _loadFromPrivateStore();
      return [];
    }

    final initialState = _loadFromCache();

    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        _syncFromSupabase();
      } else if (!next.isLoggedIn) {
        // Clear only the in-memory state for the /login redirect. Do NOT wipe the
        // on-disk cache: a transient logout (refresh-token expiry / rotation
        // race) would otherwise destroy the offline mirror, so the user opens to
        // an empty app even though their data is safe in the cloud. The cache is
        // refreshed on the next successful sync and only replaced on a real
        // account switch (see _syncFromSupabase) or explicit reset (clearAll).
        state = [];
      }
    });

    final authState = ref.read(authProvider);
    if (authState.isLoggedIn && authState.user != null) {
      _syncFromSupabase();
    }

    return initialState;
  }

  Future<void> _loadFromPrivateStore() async {
    try {
      state = await ref.read(privateLocalDatabaseProvider).loadGoals();
    } catch (e, stack) {
      AppLogger.error('[Goals] Private load error', e, stack);
      state = [];
    }
  }

  List<Goal> _loadFromCache() {
    final cache = ref.read(initialGoalsProvider);
    if (cache == '[]') return [];

    try {
      final List<dynamic> jsonList = jsonDecode(cache);
      return jsonList.map((j) => Goal.fromJson(j)).toList();
    } catch (e, stack) {
      AppLogger.error('[Goals] Cache parsing error', e, stack);
      return [];
    }
  }

  void _saveToCache(List<Goal> goals) {
    final jsonList = goals.map((g) => g.toJson()).toList();
    // Salva in modo asincrono nel portachiavi sicuro senza propagare errori UI.
    SecureStorageUtils.tryWrite(
      _cacheKey,
      jsonEncode(jsonList),
      context: '[Goals] cache',
    );
  }

  /// Surface a persistence failure to the user (strings via the global `t`).
  void _showGoalError(String title, String message, Object error) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ErrorModal.show(
        context,
        title: title,
        message: message,
        details: error.toString(),
      );
    }
  }

  Future<void> _syncFromSupabase() async {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('goals')
          .select()
          .eq('user_id', user.id)
          .order('display_order', ascending: true)
          .order('created_at', ascending: true);

      final goals = (response as List).map((j) => Goal.fromJson(j)).toList();
      state = goals;
      if (await cacheOverwriteAllowed(user.id, isEmptyResult: goals.isEmpty)) {
        _saveToCache(goals);
        await rememberCacheOwner(user.id);
      }
    } catch (e, stack) {
      AppLogger.error('[Goals] Sync error', e, stack);
    }
  }

  Future<void> addHabit(Goal habit) async {
    // Snapshot for optimistic rollback if persistence fails.
    final previousGoals = state;
    final newGoals = [...state, habit];
    state = newGoals;

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        await ref.read(privateLocalDatabaseProvider).upsertGoal(habit);
        if (habit.reminderTime != null) {
          unawaited(
            NotificationService().scheduleHabitReminder(
              habit.id,
              habit.title,
              habit.reminderTime,
            ),
          );
        }
      } catch (e, stack) {
        AppLogger.error('[Goals] Private insert error', e, stack);
        state = previousGoals;
        _showGoalError(
          t.common.errorDuringSaving,
          t.common.habitSaveFailed,
          e,
        );
      }
      return;
    }

    _saveToCache(newGoals);

    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final payload = habit.toJson();
      payload['user_id'] = user.id;
      payload.remove('id');

      final result = await supabase
          .from('goals')
          .insert(payload)
          .select()
          .single();
      final realGoal = Goal.fromJson(result);

      final updatedGoals = state
          .map((g) => g.id == habit.id ? realGoal : g)
          .toList();
      state = updatedGoals;
      _saveToCache(updatedGoals);

      // Schedula promemoria se presente
      if (realGoal.reminderTime != null) {
        unawaited(
          NotificationService().scheduleHabitReminder(
            realGoal.id,
            realGoal.title,
            realGoal.reminderTime,
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error('[Goals] Insert error', e, stack);
      // Remove the optimistic (temp-id) ghost row on failure.
      state = previousGoals;
      _saveToCache(previousGoals);
      _showGoalError(
        t.common.errorDuringSaving,
        t.common.habitSaveFailed,
        e,
      );
    }
  }

  Future<void> updateHabit(Goal updatedHabit) async {
    // Snapshot for optimistic rollback if persistence fails.
    final previousGoals = state;
    final newGoals = state
        .map((h) => h.id == updatedHabit.id ? updatedHabit : h)
        .toList();
    state = newGoals;

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        await ref.read(privateLocalDatabaseProvider).upsertGoal(updatedHabit);
        unawaited(NotificationService().cancelHabitReminder(updatedHabit.id));
        if (updatedHabit.reminderTime != null) {
          unawaited(
            NotificationService().scheduleHabitReminder(
              updatedHabit.id,
              updatedHabit.title,
              updatedHabit.reminderTime,
            ),
          );
        }
      } catch (e, stack) {
        AppLogger.error('[Goals] Private update error', e, stack);
        state = previousGoals;
        _showGoalError(
          t.common.errorDuringUpdate,
          t.common.habitUpdateFailed,
          e,
        );
      }
      return;
    }

    _saveToCache(newGoals);

    try {
      final payload = updatedHabit.toJson();
      payload.remove('id');
      await supabase.from('goals').update(payload).eq('id', updatedHabit.id);

      // Schedula promemoria
      unawaited(NotificationService().cancelHabitReminder(updatedHabit.id));
      if (updatedHabit.reminderTime != null) {
        unawaited(
          NotificationService().scheduleHabitReminder(
            updatedHabit.id,
            updatedHabit.title,
            updatedHabit.reminderTime,
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error('[Goals] Update error', e, stack);
      state = previousGoals;
      _saveToCache(previousGoals);
      _showGoalError(
        t.common.errorDuringUpdate,
        t.common.habitUpdateFailed,
        e,
      );
    }
  }

  Future<void> deleteHabit(String id) async {
    // Snapshot for optimistic rollback if persistence fails.
    final previousGoals = state;
    final newGoals = state.where((h) => h.id != id).toList();
    state = newGoals;

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        await ref.read(privateLocalDatabaseProvider).deleteGoal(id);
        unawaited(NotificationService().cancelHabitReminder(id));
      } catch (e, stack) {
        AppLogger.error('[Goals] Private delete error', e, stack);
        state = previousGoals;
        _showGoalError(
          t.common.errorDuringDeletion,
          t.common.habitDeleteFailed,
          e,
        );
      }
      return;
    }

    _saveToCache(newGoals);

    try {
      await supabase.from('goals').delete().eq('id', id);
      // Cancella promemoria
      unawaited(NotificationService().cancelHabitReminder(id));
    } catch (e, stack) {
      AppLogger.error('[Goals] Delete error', e, stack);
      // Restore the habit that failed to delete.
      state = previousGoals;
      _saveToCache(previousGoals);
      _showGoalError(
        t.common.errorDuringDeletion,
        t.common.habitDeleteFailed,
        e,
      );
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    // Snapshot for optimistic rollback if persistence fails.
    final previousGoals = state;
    final list = List<Goal>.from(state);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // Aggiorna gli order localmente
    for (int i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(displayOrder: i);
    }

    state = list;

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        await ref.read(privateLocalDatabaseProvider).reorderGoals(list);
      } catch (e, stack) {
        AppLogger.error('[Goals] Private reorder error', e, stack);
        state = previousGoals;
        _showGoalError(
          t.common.errorDuringUpdate,
          t.common.habitUpdateFailed,
          e,
        );
      }
      return;
    }

    _saveToCache(list);

    // Sync massivo degli order su Supabase
    try {
      final updates = list
          .map((g) => {'id': g.id, 'display_order': g.displayOrder})
          .toList();
      await supabase.from('goals').upsert(updates);
    } catch (e, stack) {
      AppLogger.error('[Goals] Reorder error', e, stack);
      state = previousGoals;
      _saveToCache(previousGoals);
      _showGoalError(
        t.common.errorDuringUpdate,
        t.common.habitUpdateFailed,
        e,
      );
    }
  }

  void clearAll() {
    state = [];
    if (ref.read(activeDataModeProvider) != AppDataMode.private) {
      _saveToCache([]);
    }
  }
}

final goalsProvider = NotifierProvider<GoalsNotifier, List<Goal>>(
  GoalsNotifier.new,
);

// ─── Habit Logs Provider (Offline-First) ────────────────────────────────────

typedef HabitLogsMap = Map<String, Map<String, String>>;

/// Page size for the windowed `goal_logs` sync. A single unbounded PostgREST
/// `select` is capped by the project's `db-max-rows`, which would silently
/// truncate the heatmap/yearly views for users with long histories, so the full
/// history is fetched in ranges instead.
const int kGoalLogsSyncPageSize = 1000;

/// Fetches a single page of `{id, goal_id, date, status}` rows. Abstracted so
/// the pagination loop can be unit-tested without a live Supabase client.
typedef GoalLogPageFetcher =
    Future<List<Map<String, dynamic>>> Function(int offset, int limit);

/// Folds every page returned by [fetchPage] into a [HabitLogsMap], requesting
/// successive ranges until a short (final) page is returned. Keeping this pure
/// makes the paging behaviour deterministic and testable.
Future<HabitLogsMap> fetchGoalLogsPaginated(
  GoalLogPageFetcher fetchPage, {
  int pageSize = kGoalLogsSyncPageSize,
}) async {
  final HabitLogsMap logs = {};
  var offset = 0;
  while (true) {
    final page = await fetchPage(offset, pageSize);
    for (final row in page) {
      final date = row['date'] as String; // YYYY-MM-DD
      final goalId = row['goal_id'] as String;
      final status = row['status'] as String;
      (logs[date] ??= <String, String>{})[goalId] = status;
    }
    if (page.length < pageSize) break;
    offset += pageSize;
  }
  return logs;
}

class HabitLogsNotifier extends Notifier<HabitLogsMap> {
  static const String _cacheKey = 'goal_logs_cache';

  @override
  HabitLogsMap build() {
    final dataMode = ref.watch(activeDataModeProvider);
    if (dataMode == AppDataMode.private) {
      _loadFromPrivateStore();
      return {};
    }

    final initialState = _loadFromCache();

    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        _syncFromSupabase();
      } else if (!next.isLoggedIn) {
        // Clear only in-memory state for the /login redirect; keep the on-disk
        // cache so a transient logout doesn't destroy the offline mirror (see
        // GoalsNotifier for the full rationale).
        state = {};
      }
    });

    final authState = ref.read(authProvider);
    if (authState.isLoggedIn && authState.user != null) {
      _syncFromSupabase();
    }

    return initialState;
  }

  Future<void> _loadFromPrivateStore() async {
    try {
      state = await ref.read(privateLocalDatabaseProvider).loadHabitLogs();
    } catch (e, stack) {
      AppLogger.error('[HabitLogs] Private load error', e, stack);
      state = {};
    }
  }

  HabitLogsMap _loadFromCache() {
    final cache = ref.read(initialLogsProvider);
    if (cache == '{}') return {};

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(cache);
      final HabitLogsMap result = {};
      jsonMap.forEach((dateKey, habitsData) {
        result[dateKey] = Map<String, String>.from(habitsData as Map);
      });
      return result;
    } catch (e, stack) {
      AppLogger.error('[HabitLogs] Cache parsing error', e, stack);
      return {};
    }
  }

  void _saveToCache(HabitLogsMap logs) {
    // Salva in modo asincrono nel portachiavi sicuro senza propagare errori UI.
    SecureStorageUtils.tryWrite(
      _cacheKey,
      jsonEncode(logs),
      context: '[HabitLogs] cache',
    );
  }

  Future<void> _syncFromSupabase() async {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Fetch the full history in deterministically-ordered pages so the
      // heatmap / yearly views stay complete past PostgREST's per-request row
      // cap. The id tiebreaker guarantees a stable total order across pages.
      final newLogs = await fetchGoalLogsPaginated((offset, limit) async {
        final page = await supabase
            .from('goal_logs')
            .select('id, goal_id, date, status')
            .eq('user_id', user.id)
            .order('date', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + limit - 1);
        return List<Map<String, dynamic>>.from(page);
      });

      state = newLogs;
      if (await cacheOverwriteAllowed(user.id, isEmptyResult: newLogs.isEmpty)) {
        _saveToCache(newLogs);
        await rememberCacheOwner(user.id);
      }
    } catch (e, stack) {
      AppLogger.error('[HabitLogs] Sync error', e, stack);
    }
  }

  Future<void> cycleStatus(DateTime date, String habitId) async {
    final isPrivateMode =
        ref.read(activeDataModeProvider) == AppDataMode.private;
    final user = isPrivateMode ? null : supabase.auth.currentUser;
    if (!isPrivateMode && user == null) return;

    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // Snapshot for optimistic rollback if the persistence layer fails.
    final previousState = state;

    final newState = Map<String, Map<String, String>>.from(state);
    final dayLogs = Map<String, String>.from(newState[dateKey] ?? {});

    final currentStatus = dayLogs[habitId];
    String? nextStatus;

    if (currentStatus == null) {
      nextStatus = 'done';
    } else if (currentStatus == 'done') {
      nextStatus = 'missed';
    } else {
      nextStatus = null; // rimosso
    }

    if (nextStatus != null) {
      dayLogs[habitId] = nextStatus;
    } else {
      dayLogs.remove(habitId);
    }

    newState[dateKey] = dayLogs;
    state = newState;

    // Auto-verified habits: a manual check-in freezes the day so the reconcile
    // pass can't overwrite it with an auto verdict (D9). Fire-and-forget; gated
    // and inert while the feature is off.
    if (VerificationConfig.enabled) {
      _markManualProvenance(habitId, date, set: nextStatus != null);
    }

    // Deterministic streak for the toggled day, computed from the full ordered
    // log history (shared with the web app + Private Mode). See streak_utils.dart.
    final goal = ref
        .read(goalsProvider)
        .where((g) => g.id == habitId)
        .firstOrNull;
    final newStreak = nextStatus == null
        ? 0
        : computeStreak(
            habitId: habitId,
            date: date,
            logs: newState,
            startDate: goal?.startDate ?? date,
          );

    if (isPrivateMode) {
      try {
        if (nextStatus != null) {
          await ref
              .read(privateLocalDatabaseProvider)
              .setHabitLog(
                goalId: habitId,
                date: dateKey,
                status: nextStatus,
                streak: newStreak,
              );
        } else {
          await ref
              .read(privateLocalDatabaseProvider)
              .deleteHabitLog(goalId: habitId, date: dateKey);
        }
        ref.invalidate(habitStatsProvider);
      } catch (e, stack) {
        AppLogger.error('[HabitLogs] cycleStatus (private) error', e, stack);
        // Revert the optimistic update so UI and local DB stay in sync.
        state = previousState;
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          ErrorModal.show(
            context,
            title: context.t.common.errorUpdatingState,
            message: context.t.common.habitStatusSaveFailed,
            details: e.toString(),
          );
        }
      }
      return;
    }

    _saveToCache(newState);

    // Sync con Supabase
    try {
      if (nextStatus != null) {
        await supabase.from('goal_logs').upsert({
          'user_id': user!.id,
          'goal_id': habitId,
          'date': dateKey,
          'status': nextStatus,
          'streak': newStreak,
        }, onConflict: 'goal_id, date');
      } else {
        await supabase
            .from('goal_logs')
            .delete()
            .eq('goal_id', habitId)
            .eq('date', dateKey);
      }
      ref.invalidate(habitStatsProvider);
    } catch (e, stack) {
      AppLogger.error('[HabitLogs] cycleStatus error', e, stack);
      // Revert the optimistic update so UI and cache match the server.
      state = previousState;
      _saveToCache(previousState);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: context.t.common.errorUpdatingState,
          message: context.t.common.habitStatusSaveFailed,
          details: e.toString(),
        );
      }
    }
  }

  /// Records (or clears) a manual-provenance freeze for a verified goal-day in
  /// the local verification store, so a subsequent reconcile leaves it alone
  /// (D9). Fire-and-forget — never blocks or fails the check-in.
  void _markManualProvenance(String goalId, DateTime date, {required bool set}) {
    final goal =
        ref.read(goalsProvider).where((g) => g.id == goalId).firstOrNull;
    if (!(goal?.isVerified ?? false)) return;
    final day = DateTime(date.year, date.month, date.day);
    () async {
      try {
        final store = await ref.read(verificationStateStoreProvider.future);
        if (set) {
          await store.markManual(goalId, day);
        } else {
          await store.clearManual(goalId, day);
        }
      } catch (e, stack) {
        AppLogger.error('[Verification] markManual failed', e, stack);
      }
    }();
  }

  /// Applies an auto-verified verdict (D3/D4): sets the log to [status]
  /// ('done'|'missed') directly (not cycling), carries the measured [value] to
  /// `goal_logs.value`, recomputes the streak from full history, and persists to
  /// the active backend. Driven by the verification reconcile pass, not the UI.
  /// Idempotent at the caller (the controller only calls it on a changed verdict).
  Future<void> applyAutoVerdict({
    required String goalId,
    required String dateKey,
    required String status,
    double? value,
  }) async {
    final isPrivateMode =
        ref.read(activeDataModeProvider) == AppDataMode.private;
    final user = isPrivateMode ? null : supabase.auth.currentUser;
    if (!isPrivateMode && user == null) return;

    final previousState = state;
    final newState = Map<String, Map<String, String>>.from(state);
    final dayLogs = Map<String, String>.from(newState[dateKey] ?? {});
    dayLogs[goalId] = status;
    newState[dateKey] = dayLogs;
    state = newState;

    final goal =
        ref.read(goalsProvider).where((g) => g.id == goalId).firstOrNull;
    final parsedDate = DateTime.tryParse(dateKey) ?? DateTime.now();
    final newStreak = computeStreak(
      habitId: goalId,
      date: parsedDate,
      logs: newState,
      startDate: goal?.startDate ?? parsedDate,
    );

    try {
      if (isPrivateMode) {
        await ref.read(privateLocalDatabaseProvider).setHabitLog(
              goalId: goalId,
              date: dateKey,
              status: status,
              streak: newStreak,
              value: value,
            );
      } else {
        _saveToCache(newState);
        await supabase.from('goal_logs').upsert({
          'user_id': user!.id,
          'goal_id': goalId,
          'date': dateKey,
          'status': status,
          'streak': newStreak,
          'value': value,
        }, onConflict: 'goal_id, date');
      }
      ref.invalidate(habitStatsProvider);
    } catch (e, stack) {
      AppLogger.error('[HabitLogs] applyAutoVerdict error', e, stack);
      state = previousState; // roll back the optimistic in-memory update
      if (!isPrivateMode) _saveToCache(previousState);
    }
  }

  void clearAll() {
    state = {};
    if (ref.read(activeDataModeProvider) != AppDataMode.private) {
      _saveToCache({});
    }
  }
}

final habitLogsProvider = NotifierProvider<HabitLogsNotifier, HabitLogsMap>(
  HabitLogsNotifier.new,
);

final habitStatsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
    return ref.read(privateLocalDatabaseProvider).habitStats();
  }

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final response = await Supabase.instance.client
      .from('habit_stats')
      .select('*')
      .eq('user_id', user.id);

  return List<Map<String, dynamic>>.from(response);
});

final habitAnalyticsProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
      ref.keepAlive();
      if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
        return ref.read(privateLocalDatabaseProvider).habitAnalytics();
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return {};

      final response = await Supabase.instance.client.rpc(
        'get_habit_analytics',
        params: {'p_user_id': user.id},
      );

      final list = List<Map<String, dynamic>>.from(response);

      final result = <String, Map<String, dynamic>>{};
      for (final item in list) {
        final goalId = item['goal_id'] as String;
        result[goalId] = item;
      }
      return result;
    });

final globalCriticalDayProvider = FutureProvider<String>((ref) async {
  ref.keepAlive();
  if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
    return ref.read(privateLocalDatabaseProvider).globalCriticalDay();
  }

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return 'N/A';

  try {
    final response = await Supabase.instance.client.rpc(
      'get_global_critical_day',
      params: {'p_user_id': user.id},
    );

    return response as String;
  } catch (e, stack) {
    AppLogger.error('Errore get_global_critical_day RPC', e, stack);
    return 'N/A';
  }
});

final globalTrendProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      timeframe,
    ) async {
      ref.keepAlive();
      if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
        return ref.read(privateLocalDatabaseProvider).globalTrend(timeframe);
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client.rpc(
        'get_global_trend',
        params: {'p_user_id': user.id, 'p_timeframe': timeframe},
      );

      return List<Map<String, dynamic>>.from(response);
    });

final criticalHabitsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  ref.keepAlive();
  if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
    return ref.read(privateLocalDatabaseProvider).criticalHabits();
  }

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final response = await Supabase.instance.client.rpc(
    'get_critical_habits',
    params: {'p_user_id': user.id},
  );

  return List<Map<String, dynamic>>.from(response);
});

/// The cloud `get_best_habits` RPC (and its Private mirror) filter on the tokens
/// `week` | `month` | `year` | `all`. The statistics UI shares the trend chart's
/// `timeframe_*_short` / `timeframe_all` vocabulary, which those functions don't
/// recognise — so without this mapping every habit comes back with rate 0.
/// Unknown tokens fall back to `all` (lifetime) rather than silently zeroing.
String canonicalBestHabitsTimeframe(String timeframe) => switch (timeframe) {
  'timeframe_week_short' || 'week' => 'week',
  'timeframe_month_short' || 'month' => 'month',
  'timeframe_year_short' || 'year' => 'year',
  _ => 'all', // 'timeframe_all', 'all', and any unrecognised token
};

final bestHabitsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      timeframe,
    ) async {
      ref.keepAlive();
      // Canonicalise once so both backends receive a token the functions accept.
      final canonical = canonicalBestHabitsTimeframe(timeframe);
      if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
        return ref.read(privateLocalDatabaseProvider).bestHabits(canonical);
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client.rpc(
        'get_best_habits',
        params: {'p_user_id': user.id, 'p_timeframe': canonical},
      );

      return List<Map<String, dynamic>>.from(response);
    });

final habitPerformanceProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      goalId,
    ) async {
      ref.keepAlive();
      if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
        return ref
            .read(privateLocalDatabaseProvider)
            .habitPerformanceByDay(goalId);
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client.rpc(
        'get_habit_performance_by_day',
        params: {'p_user_id': user.id, 'p_goal_id': goalId},
      );

      return List<Map<String, dynamic>>.from(response);
    });

final habitAlertsProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, goalId) async {
    ref.keepAlive();
    if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
      return ref.read(privateLocalDatabaseProvider).habitAlerts(goalId);
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {};

    final response = await Supabase.instance.client.rpc(
      'get_habit_alerts',
      params: {'p_user_id': user.id, 'p_goal_id': goalId},
    );

    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first);
    }
    return {};
  },
);

final habitYearlyGridProvider = FutureProvider.family<List<int>, String>((
  ref,
  goalId,
) async {
  ref.keepAlive();
  if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
    return ref.read(privateLocalDatabaseProvider).habitYearlyGrid(goalId);
  }

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final response = await Supabase.instance.client.rpc(
    'get_habit_yearly_grid',
    params: {'p_user_id': user.id, 'p_goal_id': goalId},
  );

  if (response is List) {
    return response.map((r) => (r['status_code'] as num).toInt()).toList();
  }
  return [];
});

final habitCorrelationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      goalId,
    ) async {
      ref.keepAlive();
      if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
        return ref.read(privateLocalDatabaseProvider).habitCorrelations(goalId);
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return [];

      final response = await Supabase.instance.client.rpc(
        'get_habit_correlations',
        params: {'p_user_id': user.id, 'p_target_goal_id': goalId},
      );

      return List<Map<String, dynamic>>.from(response);
    });

final allHabitCorrelationsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    ref.keepAlive();
    if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
      return ref.read(privateLocalDatabaseProvider).allHabitCorrelations();
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await Supabase.instance.client.rpc(
        'get_all_habit_correlations',
        params: {'p_user_id': user.id},
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e, stack) {
      AppLogger.error('Errore get_all_habit_correlations RPC', e, stack);
      return [];
    }
  },
);

// ─── Calendar view enum & provider ───────────────────────────────────────────

enum CalendarView { month, week, year, vita }

class CalendarViewNotifier extends Notifier<CalendarView> {
  @override
  CalendarView build() {
    final defaultViewStr = ref.watch(
      settingsProvider.select((s) => s.defaultCalendarView),
    );
    return _parseView(defaultViewStr);
  }

  CalendarView _parseView(String viewStr) {
    switch (viewStr) {
      case 'mese':
      case 'giorno': // Fallback for old values
        return CalendarView.month;
      case 'settimana':
        return CalendarView.week;
      case 'anno':
        return CalendarView.year;
      case 'vita':
        return CalendarView.vita;
      default:
        return CalendarView.week;
    }
  }

  void setView(CalendarView v) => state = v;
}

final calendarViewProvider =
    NotifierProvider<CalendarViewNotifier, CalendarView>(
      CalendarViewNotifier.new,
    );

// ─── Privacy mode provider ────────────────────────────────────────────────────

class PrivacyModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool v) => state = v;
}

final privacyModeProvider = NotifierProvider<PrivacyModeNotifier, bool>(
  PrivacyModeNotifier.new,
);
