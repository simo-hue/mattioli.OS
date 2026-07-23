import 'dart:async';
import 'dart:convert';
import 'package:evolve_verification/evolve_verification.dart';
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

/// Whether the on-disk cache may be served to [userId] as their initial state.
/// Mirror of [cacheOverwriteAllowed] for the READ side: because a single cache
/// is shared by every account on the device, only the account recorded in
/// [kCacheOwnerKey] may be seeded from it — otherwise the previous account's
/// habits and completion history become the next account's initial state.
///
/// A blob with no recorded owner is refused rather than trusted. Every write of
/// the blob now records the owner alongside it, so an unmarked blob can only be
/// a leftover from a build that didn't, and its account is unknowable. Refusing
/// costs that user one empty cold start before their first sync re-seeds both.
Future<bool> cacheSeedAllowed(String? userId) async {
  if (userId == null) return false;
  final owner = await SecureStorageUtils.read(kCacheOwnerKey);
  return owner != null && owner == userId;
}

Future<void> rememberCacheOwner(String userId) => SecureStorageUtils.tryWrite(
      kCacheOwnerKey,
      userId,
      context: 'cache owner',
    );

// ─── Goals Provider (Offline-First) ─────────────────────────────────────────

class GoalsNotifier extends Notifier<List<Goal>> {
  static const String _cacheKey = 'goals_cache';

  /// Set once the server's answer has been applied, so a cache seed that
  /// resolves after it can't overwrite fresher state with the mirror.
  bool _serverStateApplied = false;

  @override
  List<Goal> build() {
    final dataMode = ref.watch(activeDataModeProvider);
    if (dataMode == AppDataMode.private) {
      _loadFromPrivateStore();
      return [];
    }

    _serverStateApplied = false;

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
    final user = authState.user;
    if (authState.isLoggedIn && user != null) {
      _seedFromCache(user.id);
      _syncFromSupabase();
    }

    return [];
  }

  /// Serves the offline mirror as initial state, but only once the cache is
  /// confirmed to belong to [userId] — the owner marker lives in the keychain,
  /// so the check is async and the notifier starts empty rather than showing
  /// whatever the last account left behind (see [cacheSeedAllowed]).
  Future<void> _seedFromCache(String userId) async {
    if (!await cacheSeedAllowed(userId)) return;
    // The provider may have been disposed, or the session moved on, while the
    // marker was being read.
    if (!ref.mounted ||
        _serverStateApplied ||
        supabase.auth.currentUser?.id != userId) {
      return;
    }
    final cached = _loadFromCache();
    if (cached.isEmpty) return;
    state = cached;
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
    unawaited(_writeCache(jsonEncode(jsonList), isEmpty: goals.isEmpty));
  }

  Future<void> _writeCache(String blob, {required bool isEmpty}) async {
    await SecureStorageUtils.tryWrite(
      _cacheKey,
      blob,
      context: '[Goals] cache',
    );
    // The blob and its owner marker must move together: the marker is what both
    // the cold-start seed and the empty-fetch overwrite guard read, so a write
    // that leaves it naming another account either strands this account's
    // mirror or offers it to theirs. An EMPTY blob is deliberately left
    // unowned — there is nothing to protect, and claiming it would resurrect
    // the marker that account deletion clears right after calling clearAll().
    if (isEmpty) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) await rememberCacheOwner(userId);
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
        // Surface the real exception on-device (even in release/TestFlight) so a
        // habit-save failure is self-diagnosing instead of a silent no-op.
        forceDetails: true,
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
      _serverStateApplied = true;
      state = goals;
      if (await cacheOverwriteAllowed(user.id, isEmptyResult: goals.isEmpty)) {
        _saveToCache(goals);
      }
    } catch (e, stack) {
      AppLogger.error('[Goals] Sync error', e, stack);
    }
  }

  /// Adds [habit], returning the PERSISTED goal (with its final id) on success,
  /// or null on failure. In cloud mode the client mints a throwaway temp id and
  /// Supabase assigns the real UUID, so the persisted goal — not the input — is
  /// what carries the id a caller must key any per-goal local state by (e.g. a
  /// Mode-A Screen Time selection blob). Failures already surface their own
  /// error modal + optimistic rollback here.
  Future<Goal?> addHabit(Goal habit) async {
    // A new rule takes effect today (D10, forward-only): stamp the effective-from
    // anchor centrally so reconcile can't retroactively verify pre-creation days.
    habit = stampVerificationEffectiveFrom(
      habit,
      previous: null,
      today: DateTime.now(),
    );
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
              frequencyDays: habit.frequencyDays,
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
        return null;
      }
      return habit; // private mode keeps the client id
    }

    _saveToCache(newGoals);

    final user = supabase.auth.currentUser;
    if (user == null) {
      // No session (token expiry/rotation race between opening the modal and
      // saving): undo the optimistic insert instead of stranding a ghost
      // temp-id habit in state + cache, and surface the failure — matching this
      // method's contract and the catch block below.
      state = previousGoals;
      _saveToCache(previousGoals);
      _showGoalError(
        t.common.errorDuringSaving,
        t.common.habitSaveFailed,
        StateError('no authenticated user'),
      );
      return null;
    }

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
            frequencyDays: realGoal.frequencyDays,
          ),
        );
      }
      return realGoal; // cloud mode: the server-assigned id
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
      return null;
    }
  }

  /// Cancels then (if set) reschedules [habit]'s reminder, **sequenced**: the
  /// cancel now clears the every-day id plus all 7 per-weekday ids, so racing it
  /// against the schedule (two independent unawaited futures on the same method
  /// channel) could let a late cancel delete a freshly-registered weekday
  /// reminder. Awaiting cancel first guarantees the new reminders survive.
  Future<void> _rescheduleReminder(Goal habit) async {
    final notifications = NotificationService();
    await notifications.cancelHabitReminder(habit.id);
    if (habit.reminderTime != null) {
      await notifications.scheduleHabitReminder(
        habit.id,
        habit.title,
        habit.reminderTime,
        frequencyDays: habit.frequencyDays,
      );
    }
  }

  Future<bool> updateHabit(Goal updatedHabit) async {
    // Forward-only rule edits (D10): if the rule's verifiable content changed
    // (or was just enabled), it takes effect today; otherwise the prior anchor
    // is preserved so a title/colour/schedule edit never rewrites history.
    final priorMatches = state.where((h) => h.id == updatedHabit.id);
    updatedHabit = stampVerificationEffectiveFrom(
      updatedHabit,
      previous: priorMatches.isEmpty ? null : priorMatches.first,
      today: DateTime.now(),
    );
    // Snapshot for optimistic rollback if persistence fails.
    final previousGoals = state;
    final newGoals = state
        .map((h) => h.id == updatedHabit.id ? updatedHabit : h)
        .toList();
    state = newGoals;

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        await ref.read(privateLocalDatabaseProvider).upsertGoal(updatedHabit);
        unawaited(_rescheduleReminder(updatedHabit));
      } catch (e, stack) {
        AppLogger.error('[Goals] Private update error', e, stack);
        state = previousGoals;
        _showGoalError(
          t.common.errorDuringUpdate,
          t.common.habitUpdateFailed,
          e,
        );
        return false;
      }
      return true;
    }

    _saveToCache(newGoals);

    try {
      final payload = updatedHabit.toJson();
      payload.remove('id');
      // Goal.toJson OMITS the verify_* columns when the rule is null, and a
      // Supabase UPDATE leaves omitted columns untouched — so clearing a rule
      // would leave the server row still verified, and it would resurrect on the
      // next sync (a Mode-A habit would come back with no selection → stuck at
      // couldn't-verify forever). Explicitly null them, mirroring the private
      // path (private_local_database writes VerificationRule.nullColumns).
      if (updatedHabit.verificationRule == null) {
        payload.addAll(VerificationRule.nullColumns);
        // Goal.toJson omits the verification columns when the rule is null; a
        // Supabase UPDATE leaves omitted columns untouched, so clear them
        // explicitly or a stale anchor / compound blob would linger and resurrect
        // on sync. (A compound→single transition is safe without this: toJson
        // then emits verify_conditions: null alongside the flat columns.)
        payload['verify_effective_from'] = null;
        payload['verify_conditions'] = null;
      }
      // Goal.toJson OMITS frequency_days when null (every-day), and an UPDATE
      // leaves omitted columns untouched — so clearing a restricted schedule to
      // every-day would keep the old days on the server and resurrect on the
      // next sync. Write it explicitly (null clears the column) — same reasoning
      // as the verify_* columns above.
      payload['frequency_days'] = updatedHabit.frequencyDays;
      await supabase.from('goals').update(payload).eq('id', updatedHabit.id);

      // Schedule the reminder(s); cancel → schedule is sequenced inside.
      unawaited(_rescheduleReminder(updatedHabit));
      return true;
    } catch (e, stack) {
      AppLogger.error('[Goals] Update error', e, stack);
      state = previousGoals;
      _saveToCache(previousGoals);
      _showGoalError(
        t.common.errorDuringUpdate,
        t.common.habitUpdateFailed,
        e,
      );
      return false;
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
        // Drop any device-local Mode-A Screen Time selection for this goal.
        unawaited(ref.read(screenTimeSelectionsProvider.notifier).remove(id));
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
      // Drop any device-local Mode-A Screen Time selection for this goal.
      unawaited(ref.read(screenTimeSelectionsProvider.notifier).remove(id));
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

  /// Every write mirrors the user's WHOLE (unbounded) history, so a burst of
  /// check-ins — or a reconcile pass applying one verdict per pending day —
  /// would re-encode and rewrite the entire keychain item once per write.
  /// Coalescing them is not a durability trade: the blob only ever mirrors
  /// state already accepted by the server (a rejected write is rolled back
  /// before it is saved), so an unwritten tail is re-derived by the next sync.
  static const Duration _cacheWriteDebounce = Duration(seconds: 2);

  Timer? _cacheWriteTimer;
  HabitLogsMap? _pendingCacheWrite;

  /// See [GoalsNotifier._serverStateApplied].
  bool _serverStateApplied = false;

  @override
  HabitLogsMap build() {
    final dataMode = ref.watch(activeDataModeProvider);
    ref.onDispose(_flushCache);

    if (dataMode == AppDataMode.private) {
      _loadFromPrivateStore();
      return {};
    }

    _serverStateApplied = false;

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
    final user = authState.user;
    if (authState.isLoggedIn && user != null) {
      _seedFromCache(user.id);
      _syncFromSupabase();
    }

    return {};
  }

  /// See [GoalsNotifier._seedFromCache] — the logs cache is the same shared,
  /// non-user-keyed blob and needs the same owner guard.
  Future<void> _seedFromCache(String userId) async {
    if (!await cacheSeedAllowed(userId)) return;
    if (!ref.mounted ||
        _serverStateApplied ||
        supabase.auth.currentUser?.id != userId) {
      return;
    }
    final cached = _loadFromCache();
    if (cached.isEmpty) return;
    state = cached;
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

  /// Queues [logs] to be mirrored to the keychain, collapsing anything already
  /// queued into it (see [_cacheWriteDebounce]).
  void _saveToCache(HabitLogsMap logs) {
    _pendingCacheWrite = logs;
    _cacheWriteTimer?.cancel();
    _cacheWriteTimer = Timer(_cacheWriteDebounce, _flushCache);
  }

  void _flushCache() {
    _cacheWriteTimer?.cancel();
    _cacheWriteTimer = null;
    final logs = _pendingCacheWrite;
    if (logs == null) return;
    _pendingCacheWrite = null;
    // Salva in modo asincrono nel portachiavi sicuro senza propagare errori UI.
    unawaited(_writeCache(jsonEncode(logs), isEmpty: logs.isEmpty));
  }

  Future<void> _writeCache(String blob, {required bool isEmpty}) async {
    await SecureStorageUtils.tryWrite(
      _cacheKey,
      blob,
      context: '[HabitLogs] cache',
    );
    // See GoalsNotifier._writeCache: the blob and its owner marker move
    // together, and an empty blob is left unowned.
    if (isEmpty) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) await rememberCacheOwner(userId);
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

      _serverStateApplied = true;
      state = newLogs;
      if (await cacheOverwriteAllowed(user.id, isEmptyResult: newLogs.isEmpty)) {
        _saveToCache(newLogs);
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
            frequencyDays: goal?.frequencyDays,
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
  ///
  /// A HealthKit-measured [value] is persisted only by the private (SQLCipher +
  /// end-to-end-encrypted iCloud) backend, never by the Supabase one — see the
  /// cloud branch below.
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
      frequencyDays: goal?.frequencyDays,
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
        // A HealthKit measurement must never reach Supabase: the verdict is
        // uploaded, the quantity behind it stays on the device that read it. An
        // unresolvable goal is treated as health-derived — this path only ever
        // carries a value for HealthKit rules, Screen Time verdicts and manual
        // check-ins both leave it null. Written as an explicit null rather than
        // omitted from the payload so a value a previous build uploaded is
        // cleared on the next verdict.
        final isHealthDerived = goal?.verificationRule?.isHealthKit ?? true;
        await supabase.from('goal_logs').upsert({
          'user_id': user!.id,
          'goal_id': goalId,
          'date': dateKey,
          'status': status,
          'streak': newStreak,
          'value': isHealthDerived ? null : value,
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

  final userId = ref.watch(authProvider.select((s) => s.userId));
  if (userId == null) return [];

  final response = await Supabase.instance.client
      .from('habit_stats')
      .select('*')
      .eq('user_id', userId);

  return List<Map<String, dynamic>>.from(response);
});

final habitAnalyticsProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
      ref.keepAlive();
      if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
        return ref.read(privateLocalDatabaseProvider).habitAnalytics();
      }

      final userId = ref.watch(authProvider.select((s) => s.userId));
      if (userId == null) return {};

      final response = await Supabase.instance.client.rpc(
        'get_habit_analytics',
        params: {'p_user_id': userId},
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

  final userId = ref.watch(authProvider.select((s) => s.userId));
  if (userId == null) return 'N/A';

  try {
    final response = await Supabase.instance.client.rpc(
      'get_global_critical_day',
      params: {'p_user_id': userId},
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

      final userId = ref.watch(authProvider.select((s) => s.userId));
      if (userId == null) return [];

      final response = await Supabase.instance.client.rpc(
        'get_global_trend',
        params: {'p_user_id': userId, 'p_timeframe': timeframe},
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

  final userId = ref.watch(authProvider.select((s) => s.userId));
  if (userId == null) return [];

  final response = await Supabase.instance.client.rpc(
    'get_critical_habits',
    params: {'p_user_id': userId},
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

      final userId = ref.watch(authProvider.select((s) => s.userId));
      if (userId == null) return [];

      final response = await Supabase.instance.client.rpc(
        'get_best_habits',
        params: {'p_user_id': userId, 'p_timeframe': canonical},
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

      final userId = ref.watch(authProvider.select((s) => s.userId));
      if (userId == null) return [];

      final response = await Supabase.instance.client.rpc(
        'get_habit_performance_by_day',
        params: {'p_user_id': userId, 'p_goal_id': goalId},
      );

      return List<Map<String, dynamic>>.from(response);
    });

final habitAlertsProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, goalId) async {
    ref.keepAlive();
    if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
      return ref.read(privateLocalDatabaseProvider).habitAlerts(goalId);
    }

    final userId = ref.watch(authProvider.select((s) => s.userId));
    if (userId == null) return {};

    final response = await Supabase.instance.client.rpc(
      'get_habit_alerts',
      params: {'p_user_id': userId, 'p_goal_id': goalId},
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

  final userId = ref.watch(authProvider.select((s) => s.userId));
  if (userId == null) return [];

  final response = await Supabase.instance.client.rpc(
    'get_habit_yearly_grid',
    params: {'p_user_id': userId, 'p_goal_id': goalId},
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

      final userId = ref.watch(authProvider.select((s) => s.userId));
      if (userId == null) return [];

      final response = await Supabase.instance.client.rpc(
        'get_habit_correlations',
        params: {'p_user_id': userId, 'p_target_goal_id': goalId},
      );

      return List<Map<String, dynamic>>.from(response);
    });

final allHabitCorrelationsProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) async {
    ref.keepAlive();
    if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
      return ref.read(privateLocalDatabaseProvider).allHabitCorrelations();
    }

    final userId = ref.watch(authProvider.select((s) => s.userId));
    if (userId == null) return [];

    try {
      final response = await Supabase.instance.client.rpc(
        'get_all_habit_correlations',
        params: {'p_user_id': userId},
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
