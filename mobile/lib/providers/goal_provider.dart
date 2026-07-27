import 'dart:async';
import 'dart:convert';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/goal.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import '../core/notifications.dart';
import '../core/navigator_key.dart';
import '../core/app_logger.dart';
import '../core/targets_config.dart';
import '../core/verification_config.dart';
import '../core/verification_providers.dart';
import '../core/secure_storage_utils.dart';
import '../core/data_mode.dart';
import '../core/private_local_database.dart';
import '../core/streak_utils.dart';
import '../core/supabase_macro_goal_progress.dart';
import '../ui/widgets/error_modal.dart';
import 'macro_goals_provider.dart';
import '../i18n/translations.g.dart';

final initialGoalsProvider = Provider<String>((ref) => '[]');
final initialLogsProvider = Provider<String>((ref) => '{}');

/// The prewarmed `goal_progress_cache` blob (quantitative-habit daily numbers),
/// overridden at startup exactly like [initialLogsProvider]. Parallel to the
/// logs cache because progress is a parallel table, read and synced on its own.
final initialProgressProvider = Provider<String>((ref) => '{}');

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
    // A new target likewise takes effect today (v11, forward-only): stamp its
    // anchor so the manual-target sweep can't rewrite pre-creation days.
    habit = stampTargetEffectiveFrom(
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
              isLimit: habit.target?.isLimit ?? false,
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
            isLimit: realGoal.target?.isLimit ?? false,
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
        isLimit: habit.target?.isLimit ?? false,
      );
    }
  }

  Future<bool> updateHabit(Goal updatedHabit) async {
    // Forward-only rule edits (D10): if the rule's verifiable content changed
    // (or was just enabled), it takes effect today; otherwise the prior anchor
    // is preserved so a title/colour/schedule edit never rewrites history.
    final priorMatches = state.where((h) => h.id == updatedHabit.id);
    final previous = priorMatches.isEmpty ? null : priorMatches.first;
    updatedHabit = stampVerificationEffectiveFrom(
      updatedHabit,
      previous: previous,
      today: DateTime.now(),
    );
    // Forward-only target edits (v11): if the target's content changed (or was
    // just set), it takes effect today; otherwise the prior anchor is preserved
    // so a non-target edit never re-derives past days against the new target.
    updatedHabit = stampTargetEffectiveFrom(
      updatedHabit,
      previous: previous,
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
        // An undecodable newer-client compound (>3 conditions) reads as rule ==
        // null here but must NOT be treated as a cleared rule: toJson already put
        // the blob in payload['verify_conditions'] and omitted verify_effective_
        // from (leaving the server's untouched), so nulling either would strip
        // the newer client's compound on the next sync.
        final preservesCompound = updatedHabit.targetColumnValue == null &&
            hasUnreadableVerifyConditions(updatedHabit.rawVerifyConditionsBlob);
        // Goal.toJson omits the verification columns when the rule is null; a
        // Supabase UPDATE leaves omitted columns untouched, so clear them
        // explicitly or a stale anchor / compound blob would linger and resurrect
        // on sync. (A compound→single transition is safe without this: toJson
        // then emits verify_conditions: null alongside the flat columns.)
        //
        // GATED behind the compound flag — which only flips AFTER the still-open
        // 20260723 migrations (verify_effective_from = v7, verify_conditions = v8)
        // are applied — exactly like the `target` write below. Ungated, these two
        // explicit nulls make a pre-migration Supabase project reject EVERY
        // manual-habit edit (rename/recolour) with PGRST204 on an unknown column.
        // The flat verify_* nullColumns above come from the already-applied
        // 20260713 migration, so they stay ungated.
        if (VerificationConfig.compoundVerificationEnabled && !preservesCompound) {
          payload['verify_effective_from'] = null;
          payload['verify_conditions'] = null;
        }
      }
      // Goal.toJson OMITS frequency_days when null (every-day), and an UPDATE
      // leaves omitted columns untouched — so clearing a restricted schedule to
      // every-day would keep the old days on the server and resurrect on the
      // next sync. Write it explicitly (null clears the column) — same reasoning
      // as the verify_* columns above.
      payload['frequency_days'] = updatedHabit.frequencyDays;
      // Same omitted-column hazard for the quantitative target: Goal.toJson emits
      // `target` only when non-null, and a Supabase UPDATE leaves an omitted
      // column untouched — so REMOVING a habit's target would leave the stale one
      // on the server to resurrect on the next sync. Force-write it (null clears)
      // — but GATED behind the flag, exactly like the desktop client: `goals.target`
      // exists only after the v9 migration, so an ungated explicit `target: null`
      // on every plain-habit edit would make a pre-migration project reject the
      // unknown column and lose the edit. Inert while dark; correct once live.
      if (TargetsConfig.enabled) {
        payload['target'] = updatedHabit.targetColumnValue;
        // Force-write the anchor too (same omitted-column hazard as `target`):
        // removing a target must clear its effective-from, or a stale anchor
        // orphans on the server. Mirrors the private write and the sibling
        // verify_effective_from clear. Same flag gate — the v11 column exists
        // only after the migration that the flag flip depends on.
        payload['target_effective_from'] = updatedHabit.targetColumnValue !=
                    null &&
                updatedHabit.targetEffectiveFrom != null
            ? updatedHabit.targetEffectiveFrom!.toIso8601String().substring(0, 10)
            : null;
      }
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
      // ACCOUNT-mode counterpart of the private store's delete-time snapshot:
      // before the habit row is deleted (its goal_progress cascades away and the
      // ON DELETE SET NULL FK un-links any macro goal it fed), snapshot the
      // derived total into each linked macro goal's progress_amount so a "500 km"
      // goal that reached 320 keeps 320 as a now-manual value. Only runs when a
      // loaded macro goal is actually linked to this habit — so it is a no-op
      // (no extra round-trip) while the feature is dark and no links exist. Its
      // failure must not block the delete (the FK still un-links server-side).
      final user = supabase.auth.currentUser;
      final hasLinkedMacroGoal = ref
          .read(macroGoalsProvider)
          .goals
          .any((g) => g.linkedGoalId == id);
      if (user != null && hasLinkedMacroGoal) {
        try {
          await snapshotCloudLinkedMacroGoals(supabase, user.id, id);
        } catch (e, stack) {
          AppLogger.error('[Goals] Linked macro-goal snapshot failed', e, stack);
        }
      }
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

  /// Moves a habit-day's VERDICT to match a target's evaluation: sets the
  /// `goal_logs` row to [status] ('done'|'missed'), or DELETES it when [status]
  /// is null (the day is pending — a partial count, or a limit day not yet
  /// closed). The progress NUMBER lives in `goal_progress` and is owned by
  /// [HabitProgressNotifier]; this only ever moves the verdict, so streaks,
  /// heatmaps and the analytics RPCs keep seeing an ordinary done/missed row.
  ///
  /// Never writes `goal_logs.value`: a manual target's number is not a health
  /// measurement and does not belong on the verdict row. Idempotent — a no-op
  /// when the stored status already matches, so the reconcile/increment paths
  /// can call it freely.
  Future<void> setDerivedStatus({
    required String goalId,
    required String dateKey,
    required String? status,
  }) async {
    final isPrivateMode =
        ref.read(activeDataModeProvider) == AppDataMode.private;
    final user = isPrivateMode ? null : supabase.auth.currentUser;
    if (!isPrivateMode && user == null) return;

    if (state[dateKey]?[goalId] == status) return; // already correct

    final previousState = state;
    final newState = Map<String, Map<String, String>>.from(state);
    final dayLogs = Map<String, String>.from(newState[dateKey] ?? {});
    if (status != null) {
      dayLogs[goalId] = status;
    } else {
      dayLogs.remove(goalId);
    }
    newState[dateKey] = dayLogs;
    state = newState;

    final goal =
        ref.read(goalsProvider).where((g) => g.id == goalId).firstOrNull;
    final parsedDate = DateTime.tryParse(dateKey) ?? DateTime.now();
    final newStreak = status == null
        ? 0
        : computeStreak(
            habitId: goalId,
            date: parsedDate,
            logs: newState,
            startDate: goal?.startDate ?? parsedDate,
            frequencyDays: goal?.frequencyDays,
          );

    try {
      if (isPrivateMode) {
        if (status != null) {
          await ref.read(privateLocalDatabaseProvider).setHabitLog(
                goalId: goalId,
                date: dateKey,
                status: status,
                streak: newStreak,
              );
        } else {
          await ref
              .read(privateLocalDatabaseProvider)
              .deleteHabitLog(goalId: goalId, date: dateKey);
        }
      } else {
        _saveToCache(newState);
        if (status != null) {
          await supabase.from('goal_logs').upsert({
            'user_id': user!.id,
            'goal_id': goalId,
            'date': dateKey,
            'status': status,
            'streak': newStreak,
          }, onConflict: 'goal_id, date');
        } else {
          await supabase
              .from('goal_logs')
              .delete()
              .eq('goal_id', goalId)
              .eq('date', dateKey);
        }
      }
      ref.invalidate(habitStatsProvider);
    } catch (e, stack) {
      AppLogger.error('[HabitLogs] setDerivedStatus error', e, stack);
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

// ─── Habit Progress Provider (quantitative targets) ─────────────────────────

/// `dateKey ('YYYY-MM-DD') -> goalId -> accumulated amount` for the day.
///
/// The parallel of [HabitLogsMap] for the `goal_progress` table: the raw number
/// a quantitative habit reached that day. Deliberately a SEPARATE map, not a
/// field folded into the log entry — a partial day has a number but no verdict,
/// the two tables sync independently, and keeping them apart means the ~96
/// call sites that read the verdict string never had to change.
typedef HabitProgressMap = Map<String, Map<String, double>>;

/// Folds paginated `{goal_id, date, amount}` rows into a [HabitProgressMap].
/// Mirrors [fetchGoalLogsPaginated] so the cloud progress history is fetched
/// past PostgREST's row cap the same way the logs history is.
Future<HabitProgressMap> fetchGoalProgressPaginated(
  GoalLogPageFetcher fetchPage, {
  int pageSize = kGoalLogsSyncPageSize,
}) async {
  final HabitProgressMap progress = {};
  var offset = 0;
  while (true) {
    final page = await fetchPage(offset, pageSize);
    for (final row in page) {
      final date = row['date'] as String;
      final goalId = row['goal_id'] as String;
      final amount = (row['amount'] as num).toDouble();
      (progress[date] ??= <String, double>{})[goalId] = amount;
    }
    if (page.length < pageSize) break;
    offset += pageSize;
  }
  return progress;
}

class HabitProgressNotifier extends Notifier<HabitProgressMap> {
  static const String _cacheKey = 'goal_progress_cache';
  static const Duration _cacheWriteDebounce = Duration(seconds: 2);

  Timer? _cacheWriteTimer;
  HabitProgressMap? _pendingCacheWrite;
  bool _serverStateApplied = false;

  /// The initial population of [state] for the current data mode, still in
  /// flight.
  ///
  /// [build] MUST return synchronously, so it returns `{}` and loads in the
  /// background — meaning "the map is empty" and "the map has not loaded yet"
  /// look identical to any reader. For most readers that is harmless (a widget
  /// rebuilds when the load lands). For [reconcileManualTargets] it is
  /// destructive: an `atMost` habit-day with no progress entry resolves to a
  /// quiet SUCCESS, and applying that verdict writes amount 0, which DELETES the
  /// stored row. Sweeping an unloaded map therefore erases every limit-habit
  /// entry in the backfill window and tombstones the deletions to CloudKit.
  ///
  /// So the sweep awaits this first. See [_ensureLoaded].
  Future<void>? _initialLoad;

  @override
  HabitProgressMap build() {
    final dataMode = ref.watch(activeDataModeProvider);
    ref.onDispose(_flushCache);

    if (dataMode == AppDataMode.private) {
      _initialLoad = _loadFromPrivateStore();
      return {};
    }

    _serverStateApplied = false;
    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        _syncFromSupabase();
      } else if (!next.isLoggedIn) {
        state = {};
      }
    });

    final authState = ref.read(authProvider);
    final user = authState.user;
    if (authState.isLoggedIn && user != null) {
      _seedFromCache(user.id);
      _initialLoad = _syncFromSupabase();
    } else {
      _initialLoad = null;
    }
    return {};
  }

  /// Awaits the in-flight initial load, if any, so a caller that must not
  /// mistake "not loaded yet" for "no data" can wait for the real map. Failures
  /// are already swallowed by the loaders (which fall back to an empty map), so
  /// this never rethrows.
  Future<void> _ensureLoaded() async {
    final pending = _initialLoad;
    if (pending == null) return;
    try {
      await pending;
    } catch (_) {
      // The loaders handle their own errors; this is only a barrier.
    }
  }

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
      state = await ref.read(privateLocalDatabaseProvider).loadHabitProgress();
    } catch (e, stack) {
      AppLogger.error('[HabitProgress] Private load error', e, stack);
      state = {};
    }
  }

  HabitProgressMap _loadFromCache() {
    final cache = ref.read(initialProgressProvider);
    if (cache == '{}') return {};
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(cache);
      final HabitProgressMap result = {};
      jsonMap.forEach((dateKey, habitsData) {
        result[dateKey] = {
          for (final e in (habitsData as Map).entries)
            e.key as String: (e.value as num).toDouble(),
        };
      });
      return result;
    } catch (e, stack) {
      AppLogger.error('[HabitProgress] Cache parsing error', e, stack);
      return {};
    }
  }

  void _saveToCache(HabitProgressMap progress) {
    _pendingCacheWrite = progress;
    _cacheWriteTimer?.cancel();
    _cacheWriteTimer = Timer(_cacheWriteDebounce, _flushCache);
  }

  void _flushCache() {
    _cacheWriteTimer?.cancel();
    _cacheWriteTimer = null;
    final progress = _pendingCacheWrite;
    if (progress == null) return;
    _pendingCacheWrite = null;
    unawaited(_writeCache(jsonEncode(progress), isEmpty: progress.isEmpty));
  }

  Future<void> _writeCache(String blob, {required bool isEmpty}) async {
    await SecureStorageUtils.tryWrite(
      _cacheKey,
      blob,
      context: '[HabitProgress] cache',
    );
    if (isEmpty) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) await rememberCacheOwner(userId);
  }

  Future<void> _syncFromSupabase() async {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final newProgress = await fetchGoalProgressPaginated((offset, limit) async {
        final page = await supabase
            .from('goal_progress')
            .select('goal_id, date, amount')
            .eq('user_id', user.id)
            .order('date', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + limit - 1);
        return List<Map<String, dynamic>>.from(page);
      });
      _serverStateApplied = true;
      state = newProgress;
      if (await cacheOverwriteAllowed(user.id,
          isEmptyResult: newProgress.isEmpty)) {
        _saveToCache(newProgress);
      }
    } catch (e, stack) {
      AppLogger.error('[HabitProgress] Sync error', e, stack);
    }
  }

  /// Records [amount] as the day's accumulated progress for [goalId], persists
  /// it to the active backend, and moves the day's VERDICT to match by handing
  /// the evaluated status to [HabitLogsNotifier.setDerivedStatus].
  ///
  /// [target] is the habit's target (needed to evaluate the verdict); [now] is
  /// injectable for tests. A [amount] of zero removes the progress row and, for
  /// most targets, clears the verdict too. Only ever writes a `'manual'` source
  /// — a measured target's number never flows through here.
  Future<void> setProgress({
    required String dateKey,
    required String goalId,
    required double amount,
    required HabitTarget target,
    DateTime? now,
  }) async {
    final isPrivateMode =
        ref.read(activeDataModeProvider) == AppDataMode.private;
    final user = isPrivateMode ? null : supabase.auth.currentUser;
    if (!isPrivateMode && user == null) return;

    final clamped = amount < 0 ? 0.0 : amount;
    final previousState = state;
    final newState = <String, Map<String, double>>{
      for (final e in state.entries) e.key: Map<String, double>.from(e.value),
    };
    if (clamped == 0) {
      newState[dateKey]?.remove(goalId);
      if (newState[dateKey]?.isEmpty ?? false) newState.remove(dateKey);
    } else {
      (newState[dateKey] ??= <String, double>{})[goalId] = clamped;
    }
    state = newState;

    try {
      if (isPrivateMode) {
        if (clamped == 0) {
          await ref
              .read(privateLocalDatabaseProvider)
              .deleteHabitProgress(goalId: goalId, date: dateKey);
        } else {
          await ref.read(privateLocalDatabaseProvider).setHabitProgress(
                goalId: goalId,
                date: dateKey,
                amount: clamped,
                source: TargetFillSource.manual.wireName,
              );
        }
      } else {
        _saveToCache(newState);
        if (clamped == 0) {
          await supabase
              .from('goal_progress')
              .delete()
              .eq('goal_id', goalId)
              .eq('date', dateKey);
        } else {
          await supabase.from('goal_progress').upsert({
            // The SAME deterministic id the private store mints
            // (PrivateDbSchema.goalProgressId) — inlined rather than importing
            // evolve_sync into the provider for one pure string. Kept identical
            // on purpose: a divergent spelling would let the two backends mint
            // different ids for one habit-day and defeat the whole point.
            'id': '$goalId:$dateKey',
            'user_id': user!.id,
            'goal_id': goalId,
            'date': dateKey,
            'amount': clamped,
            'source': TargetFillSource.manual.wireName,
          }, onConflict: 'goal_id, date');
        }
      }
    } catch (e, stack) {
      AppLogger.error('[HabitProgress] setProgress error', e, stack);
      state = previousState; // roll back the optimistic update
      if (!isPrivateMode) _saveToCache(previousState);
      return;
    }

    // One owner of goal_logs.status per habit-day: a verified habit's verdict is
    // owned by the verification pipeline. Store the manual number (done above) but
    // do NOT derive a target verdict into goal_logs — a manual 'pending' would
    // delete a sensor-earned 'done' and the two pipelines would oscillate. (Only
    // reachable for a habit that carries both a target and a rule — legacy/synced
    // data; the class picker keeps them mutually exclusive going forward.)
    final goalMatches = ref.read(goalsProvider).where((g) => g.id == goalId);
    if (goalMatches.isNotEmpty && goalMatches.first.verificationRule != null) {
      return;
    }

    // Move the verdict to match the new number. "Today" is not a closed period,
    // so an atLeast day flips to done the moment the target is reached while a
    // limit day stays pending (no row) until it closes; a past day resolves.
    final parsedDate = DateTime.tryParse(dateKey);
    final over = parsedDate == null
        ? false
        : periodIsOver(target.period, parsedDate, now ?? DateTime.now());
    final verdict = evaluateTarget(
      target: target,
      progress: clamped,
      periodIsOver: over,
    );
    await ref.read(habitLogsProvider.notifier).setDerivedStatus(
          goalId: goalId,
          dateKey: dateKey,
          status: verdict.logStatus,
        );
  }

  /// End-of-day resolution for manual targets: materialises the `goal_logs`
  /// verdict for every CLOSED day whose live-derived verdict never caught up —
  /// above all a limit habit's quiet days, which are successes only knowable
  /// once the day is over. Call on foreground; a no-op when there are no manual
  /// targets or nothing changed.
  ///
  /// Reuses [setProgress] as the applier (one write path), so each corrected day
  /// re-derives and persists exactly as a live edit would, streaks included.
  /// [now] is injectable for tests.
  Future<void> reconcileManualTargets({DateTime? now}) async {
    await _ensureLoaded();
    if (!ref.mounted) return;
    // Never sweep a map that has not finished loading: for an `atMost` target an
    // absent entry means "quiet success", so an unloaded map resolves every
    // stored breach to 'done' and DELETES the amount behind it. See
    // [_initialLoad].
    final today = now ?? DateTime.now();
    final logs = ref.read(habitLogsProvider);
    final changes = <TargetReconcileChange>[];
    for (final goal in ref.read(goalsProvider)) {
      final target = goal.target;
      // Only own MANUAL targets: a projected verification rule is resolved by the
      // reconcile pass, not here. And a VERIFIED habit's goal_logs verdict is
      // owned by the verification pipeline (one owner per habit-day) — never sweep
      // it here, or the two pipelines fight and flip the day's status every
      // foreground. (A habit carries both a target and a rule only via legacy or
      // synced data; the class picker keeps them mutually exclusive.)
      if (target == null ||
          !target.isUserEnterable ||
          goal.verificationRule != null) {
        continue;
      }
      changes.addAll(reconcileManualTargetDays(
        goalId: goal.id,
        target: target,
        today: today,
        start: goal.startDate,
        effectiveFrom: goal.targetEffectiveFrom,
        isScheduled: goal.isScheduledOn,
        progressFor: (dateKey) => state[dateKey]?[goal.id],
        statusFor: (dateKey) => logs[dateKey]?[goal.id],
      ));
    }
    if (changes.isEmpty) return;

    // Sequential: each setProgress recomputes the streak from the running state,
    // so applying in date order builds streaks correctly rather than racing.
    final byGoal = {for (final g in ref.read(goalsProvider)) g.id: g};
    for (final change in changes) {
      final target = byGoal[change.goalId]?.target;
      if (target == null) continue;
      await setProgress(
        dateKey: change.dateKey,
        goalId: change.goalId,
        amount: change.amount,
        target: target,
        now: today,
      );
    }
  }

  void clearAll() {
    state = {};
    if (ref.read(activeDataModeProvider) != AppDataMode.private) {
      _saveToCache({});
    }
  }
}

final habitProgressProvider =
    NotifierProvider<HabitProgressNotifier, HabitProgressMap>(
  HabitProgressNotifier.new,
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
