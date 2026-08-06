import 'dart:async';
import 'dart:convert';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/goal.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import 'shared_prefs_provider.dart';
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

/// Joins the loaders a notifier kicks off in `build()` into one barrier future.
///
/// The property that matters, and the one that is easy to get wrong: the barrier
/// must not resolve until **every** loader has settled. The loaders are
/// independent and the fast one is routinely the one that FAILS — a Supabase call
/// returns in milliseconds when offline, while the cache seed first awaits a
/// Keychain round trip to confirm ownership. Barriering on the server call alone
/// therefore resolves with empty state on exactly the degraded networks where the
/// offline mirror matters most, and a caller that treats empty as real then acts
/// destructively on it.
///
/// Errors are contained per-future so one failure cannot short-circuit the join
/// (`Future.wait` completes with the first error otherwise). Each loader already
/// handles its own errors internally; this only stops them escaping.
///
/// Shared rather than inlined because it was inlined, and the second notifier
/// silently got a different — wrong — composition.
@visibleForTesting
Future<void> loadBarrier(Iterable<Future<void>> loaders) =>
    Future.wait([for (final f in loaders) f.catchError((Object _) {})]);

/// Awaits [current] until the barrier it captured is still the current one.
///
/// `build()` re-runs on the SAME notifier instance (Riverpod reuses it across
/// `invalidate`), reassigning the barrier and resetting state to empty — so a
/// rebuild landing mid-await would otherwise let a caller return satisfied by a
/// stale load while the fresh one is still in flight, holding exactly the empty
/// state the barrier exists to disbelieve.
///
/// Bounded rather than `while (true)`: a caller without its own timeout must not
/// be able to wait forever if invalidations keep outpacing loads.
///
/// Returns **true if the barrier settled**, false if it gave up. That return is
/// load-bearing, not informational: every caller of this treats "state is empty"
/// as destructive (stop monitoring / sweep and delete), so a give-up that looked
/// like a settle would hand them a possibly-unloaded state with the confidence of
/// a loaded one — resolving the ambiguity in the one direction that loses data.
Future<bool> awaitStableBarrier(Future<void>? Function() current) async {
  for (var i = 0; i < 5; i++) {
    final pending = current();
    if (pending == null) return true;
    try {
      await pending;
    } catch (_) {
      // The loaders handle their own errors; this is only a barrier.
    }
    if (identical(current(), pending)) return true;
  }
  return false;
}

/// Whether a settled load left behind a map that may be READ AS EVIDENCE — that
/// is, one where an absent entry can be trusted to mean "the user recorded
/// nothing" rather than "the load did not answer".
///
/// The loaders swallow their own errors and leave an empty map, so the barrier
/// settles either way and [awaitStableBarrier] alone cannot tell the two apart.
/// This is the rule that can:
///
///  * [settled] false — the barrier gave up. Never trustworthy.
///  * [syncFailed] with [cacheSeeded] — offline, or a 5xx, but the on-disk
///    mirror populated the map. **Trustworthy**, and deliberately so: this is
///    what shipped before the flag existed, and it is what keeps a limit habit's
///    quiet days resolving on a phone with no signal. The alternative — treating
///    every failed server leg as a failed load — silently stops resolving
///    anything for offline users.
///  * [syncFailed] without [cacheSeeded] — nothing loaded. The map is empty
///    BECAUSE it failed, which is the one case that must never be read as
///    evidence. Not trustworthy.
///
/// Shared by both notifiers rather than inlined twice, for the reason
/// [loadBarrier]'s own doc records about the second copy.
bool loadIsTrustworthy({
  required bool settled,
  required bool syncFailed,
  required bool cacheSeeded,
}) =>
    settled && (!syncFailed || cacheSeeded);

class GoalsNotifier extends Notifier<List<Goal>> {
  static const String _cacheKey = 'goals_cache';

  /// Set once the server's answer has been applied, so a cache seed that
  /// resolves after it can't overwrite fresher state with the mirror.
  bool _serverStateApplied = false;

  /// The in-flight initial load, so a caller that must not mistake "not loaded
  /// yet" for "this user has no habits" can wait for the real list.
  ///
  /// [build] returns `[]` and fills in asynchronously, and it re-runs far more
  /// often than a launch: `invalidatePrivateDataProviders` invalidates this
  /// provider on every applied iCloud sync (sync_refresh.dart), which the 60s
  /// poll can reach once a minute. Every one of those passes back through the
  /// empty state. The Screen Time monitoring sync is destructive on empty — an
  /// empty spec list means "stop monitoring everything" — so it awaits this
  /// before believing a `[]`. Mirrors [HabitProgressNotifier._initialLoad],
  /// which exists for the identical hazard on the progress sweep.
  Future<void>? _initialLoad;

  /// The twin of [HabitLogsNotifier._syncFailed] and
  /// [HabitProgressNotifier._syncFailed], needed here for exactly the same
  /// reason — and its absence was a real defect, not a symmetry gap.
  ///
  /// [ensureLoaded]'s contract is "returns false if the load never settled, so a
  /// caller that would act destructively on an empty list can decline to". But
  /// [_loadFromPrivateStore] CATCHES its error and leaves `[]`, so the future
  /// settles *successfully* on a failure and the barrier returned true over an
  /// empty list. Both Screen Time callers guard with `if (!loaded &&
  /// goals.isEmpty)` — and `!loaded` could never happen, so a failed load handed
  /// DeviceActivity `syncMonitoredGoals([])`: the "you deleted your last
  /// verifiable habit, stop watching" signal, for habits that plainly still
  /// exist. The teardown was then cached as the desired state, and re-registering
  /// re-zeroes each goal's accrued usage for the day, so a limit habit that had
  /// already breached its threshold got a fresh clock.
  bool _syncFailed = false;

  /// Set when the offline mirror populated [state]. See [loadIsTrustworthy]: a
  /// cache-seeded list is real data, so a failed server sync on top of it is
  /// still trustworthy enough to act on.
  bool _cacheSeeded = false;

  @override
  List<Goal> build() {
    final dataMode = ref.watch(activeDataModeProvider);
    // Re-arm BOTH flags. The `_cacheSeeded` half is the load-bearing one and is
    // easy to mistake for redundant: `_seedFromCache` only ever sets it TRUE, so
    // this and the auth listener are its only clear sites — and `build()` re-runs
    // on the `activeDataModeProvider` watch above, so a cloud→private switch
    // carrying a stale `true` would let `loadIsTrustworthy` vouch for the `[]` a
    // FAILED private load left behind, resurrecting the exact defect these flags
    // exist to prevent. (`_syncFailed` is additionally reset by each loader's
    // success path, so only this one is strictly required.) Pinned by
    // goals_load_trustworthy_cloud_test.dart's mode-switch test.
    _syncFailed = false;
    _cacheSeeded = false;
    if (dataMode == AppDataMode.private) {
      _initialLoad = _loadFromPrivateStore();
      return [];
    }

    _serverStateApplied = false;

    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        // Re-arm the barrier: a transient logout empties `state` (below) without
        // rebuilding the notifier, so without this `ensureLoaded` would be
        // satisfied by the PREVIOUS, already-completed load and a caller would
        // read the empty list as "this user has no habits". The flags are
        // re-armed with it — a fresh attempt is not yet a failure, and the
        // previous account's seed says nothing about this one.
        _syncFailed = false;
        _cacheSeeded = false;
        _initialLoad = _syncFromSupabase();
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
      // BOTH loaders — see [loadBarrier].
      _initialLoad = loadBarrier([_seedFromCache(user.id), _syncFromSupabase()]);
    } else {
      _initialLoad = null;
    }

    return [];
  }

  /// Awaits the in-flight initial load, if any, so a caller can tell "no habits"
  /// apart from "not loaded yet" AND from "the load failed". Returns false in
  /// both of the latter cases, so a caller that would act destructively on an
  /// empty list can decline to. Never rethrows — see [awaitStableBarrier].
  ///
  /// Settling is NOT sufficient on its own: both loaders swallow their error and
  /// leave `[]` behind, so the barrier completes cleanly over a failure. See
  /// [_syncFailed].
  Future<bool> ensureLoaded() async {
    final settled = await awaitStableBarrier(() => _initialLoad);
    return loadIsTrustworthy(
      settled: settled,
      syncFailed: _syncFailed,
      cacheSeeded: _cacheSeeded,
    );
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
    // Real habits, from the offline mirror. A server sync that fails on top of
    // this is still trustworthy to act on — see [loadIsTrustworthy].
    _cacheSeeded = true;
  }

  Future<void> _loadFromPrivateStore() async {
    try {
      state = await ref.read(privateLocalDatabaseProvider).loadGoals();
      _syncFailed = false;
    } catch (e, stack) {
      AppLogger.error('[Goals] Private load error', e, stack);
      state = [];
      // The `[]` below is the FAILURE, not an empty habit list. Without this
      // flag the barrier settles cleanly over it and every caller guarding on
      // "did the load settle?" acts on an empty list — which, for the Screen
      // Time sync, means tearing down monitoring for habits that still exist.
      _syncFailed = true;
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
      _syncFailed = false;
      if (await cacheOverwriteAllowed(user.id, isEmptyResult: goals.isEmpty)) {
        _saveToCache(goals);
      }
    } catch (e, stack) {
      AppLogger.error('[Goals] Sync error', e, stack);
      // Offline, a 5xx, an expired token: `state` keeps whatever it held, which
      // on a cold launch is the empty list `build` returned. Absence is not
      // evidence — say so, so `ensureLoaded` reports the list as untrustworthy
      // unless the cache seeded it. See [loadIsTrustworthy].
      _syncFailed = true;
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
    // ONE clock for the whole edit. Read separately, the materialise window and
    // the two anchors could straddle midnight on a slow save: the sweep would
    // settle up to day D while the anchor landed on D+1, leaving D in a gap
    // covered by neither — stranded at pending, which is the bug this method
    // exists to close.
    final editedAt = DateTime.now();
    updatedHabit = stampVerificationEffectiveFrom(
      updatedHabit,
      previous: previous,
      today: editedAt,
    );
    // Score whatever the OLD target still owes before the anchor moves past it.
    //
    // Once `stampTargetEffectiveFrom` below sets the anchor to today, the sweep
    // can never reach an earlier day again, so any day not yet materialised is
    // stranded at pending for good. Scoring them here — rather than letting the
    // sweep fill them afterwards — is what keeps them judged by the target that
    // was actually in force on them; filling them later would score them against
    // the NEW target and invent verdicts. See
    // [HabitProgressNotifier.materialiseDaysBeforeTargetChange].
    //
    // The old target and anchor are read from `previous`, so this is correct
    // wherever it sits in this method. It goes BEFORE the stamp and the write
    // anyway, so that a crash or a failed save between the two cannot leave a
    // moved anchor with the days it outran still unscored.
    //
    // Only when the scoring meaning is actually changing: a rename, recolour or
    // reschedule preserves the anchor, so nothing is about to become
    // unreachable and there is nothing to rush.
    //
    // Guarded AND bounded. This is history bookkeeping, not the user's edit —
    // it must never fail the save, and it must never hang it behind a barrier
    // that is waiting on a stalled network.
    final previousTarget = previous?.target;
    if (previousTarget != null &&
        !(updatedHabit.target?.hasSameScoringMeaningAs(previousTarget) ??
            false)) {
      try {
        // Awaited without an outer deadline: its own barriers are bounded, and
        // `Future.timeout` would not stop it anyway — it would only let this
        // method race ahead and stamp the anchor while the sweep was still
        // writing days against a habit whose shape had changed underneath it.
        await ref
            .read(habitProgressProvider.notifier)
            .materialiseDaysBeforeTargetChange(previous!, now: editedAt);
      } catch (e, stack) {
        AppLogger.error(
          '[Targets] could not materialise ${updatedHabit.id}\'s days before '
          'its target edit — earlier unscored days will stay pending',
          e,
          stack,
        );
      }
    }

    // Forward-only target edits (v11): if the target's content changed (or was
    // just set), it takes effect today; otherwise the prior anchor is preserved
    // so a non-target edit never re-derives past days against the new target.
    updatedHabit = stampTargetEffectiveFrom(
      updatedHabit,
      previous: previous,
      today: editedAt,
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

/// The streak to record for a habit-day whose goal could not be resolved, so
/// its true run length is unknowable.
///
/// Returns null — "keep whatever is stored" — ONLY when the verdict is
/// UNCHANGED. The run that value belongs to has not moved, so the stored number
/// remains both the best estimate available and sign-consistent with the row.
///
/// When the verdict FLIPS, the stored value is known to be WRONG.
/// `goal_logs.streak` is SIGNED — positive is a consecutive 'done' run,
/// negative a 'missed' run (see `computeStreak` in streak_utils.dart) — so
/// preserving +40 onto a day that has just become 'missed' would assert a
/// 40-day fire run on a day the user missed. That is not a stale number, it is
/// a self-contradicting row, and it is read as evidence: `private_analytics`
/// derives `current_streak` from the latest row's streak and `worst_streak`
/// from `min(streak)` over 'missed' rows, and the cloud `habit_stats` view does
/// the same.
///
/// ±1 is the sign-consistent MINIMUM: the day taken on its own. It is exactly
/// what this code produced before the absent-goal guard existed, so this branch
/// is never worse than what it replaced — and it keeps the ±1 signature the
/// streak audit looks for, so the repair pass can restore the magnitude.
/// The shared `goal_logs` upsert payload for all three cloud write paths.
///
/// Exists so the streak-omission rule lives in ONE place. These three payloads
/// used to be written out separately and one of them drifted: it kept sending
/// `'streak': newStreak` after that variable became nullable, so an unknown
/// streak was POSTed as an explicit null. PostgREST puts every key present in
/// the payload into the generated `ON CONFLICT (goal_id,date) DO UPDATE SET`,
/// so that assigns SQL NULL and DESTROYS the stored value — worse than the
/// fabricated integer the guard replaced, and invisible because `streak` is a
/// nullable column with no constraint to trip.
///
/// A null [streak] therefore OMITS the key, leaving the stored value untouched
/// on the conflict path and taking the column default (0) on a fresh insert.
///
/// Callers needing extra columns spread this and add their own (see
/// `applyAutoVerdict`, which always writes `value` — including an explicit null
/// to clear a measurement a previous build uploaded).
Map<String, Object?> goalLogUpsertPayload({
  required String userId,
  required String goalId,
  required String dateKey,
  required String status,
  required int? streak,
}) =>
    {
      'user_id': userId,
      'goal_id': goalId,
      'date': dateKey,
      'status': status,
      'streak': ?streak,
    };

int? unknownStreakFor({
  required String? previousStatus,
  required String newStatus,
}) {
  if (previousStatus == newStatus) return null;
  return switch (newStatus) {
    'done' => 1,
    'missed' => -1,
    // 'skipped' is allowed by the schema's CHECK but belongs to neither a
    // done-run nor a miss-run, so there is no sign to assert.
    _ => 0,
  };
}

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

  /// The initial population of [state] for the current data mode, still in
  /// flight — the same barrier [HabitProgressNotifier._initialLoad] keeps, and
  /// for a sibling reason.
  ///
  /// [build] returns `{}` synchronously, so "no verdict stored" and "the verdicts
  /// have not loaded yet" are indistinguishable to any reader. Widgets don't care
  /// (they rebuild when the load lands). The manual-target sweep does: it decides
  /// whether to write by comparing the derived verdict against the STORED one, so
  /// an unloaded map makes every closed day look pending — and auto-fail would
  /// then stamp `missed` over real `done` days and sync it. The progress barrier
  /// alone doesn't cover this: the two maps load independently, so progress can
  /// be ready while logs are still in flight.
  Future<void>? _initialLoad;

  /// Set when a loader GAVE UP, and cleared by a load that answers. Both loaders
  /// swallow their own errors and leave `{}` behind, so the barrier settles
  /// either way — meaning "the load finished" and "the load failed" are
  /// otherwise indistinguishable, and a caller that reads an absent verdict as
  /// permission to write one would act on a map that never loaded. The mobile
  /// counterpart of the desktop snapshot's `progressStale`.
  bool _syncFailed = false;

  /// Awaits the in-flight initial load and reports whether [state] is the
  /// STORED TRUTH — settled, and answered by its real source rather than
  /// degraded to the offline mirror.
  ///
  /// Deliberately stricter than [loadIsTrustworthy], which the progress map
  /// uses, and the asymmetry is the point. Both maps gate the same sweep, but
  /// they gate different risks:
  ///
  ///  * The progress map drives limit resolution, which derives every verdict
  ///    from a NUMBER. A stale-but-real mirror produces the same answer the
  ///    server would, and refusing it just stops an offline phone resolving
  ///    anything — a regression with no safety payoff.
  ///  * This map gates AUTO-FAIL, the one rule that reads an ABSENT verdict as
  ///    permission to write one. The verdict it would destroy is a 'done' with
  ///    no number behind it, which nothing can re-derive. The mirror cannot see
  ///    a check-in made on another device since the last successful sync, so
  ///    accepting it means overwriting that check-in with 'missed', for good.
  ///
  /// Deferring auto-fail costs nothing: the day stays pending and is scored by
  /// the next sweep that does reach the server, still inside the backfill
  /// window. Never rethrows — see [awaitStableBarrier].
  Future<bool> ensureLoaded() async {
    final settled = await awaitStableBarrier(() => _initialLoad);
    return settled && !_syncFailed;
  }

  @override
  HabitLogsMap build() {
    final dataMode = ref.watch(activeDataModeProvider);
    ref.onDispose(_flushCache);
    _syncFailed = false;

    if (dataMode == AppDataMode.private) {
      _initialLoad = _loadFromPrivateStore();
      return {};
    }

    _serverStateApplied = false;

    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        // Re-arm the barrier: the logout branch below empties `state` without
        // rebuilding the notifier, so leaving the old completed future in place
        // would let the sweep read `{}` as "no verdicts stored". The flags are
        // re-armed with it — a fresh attempt is not yet a failure.
        _syncFailed = false;
        _initialLoad = _syncFromSupabase();
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
      // BOTH loaders, like the progress barrier: waiting on the server call
      // alone resolves early whenever it fails fast (offline, a 5xx) while the
      // cache seed is still in flight, which is exactly the empty-map read this
      // barrier exists to prevent.
      _initialLoad = loadBarrier([_seedFromCache(user.id), _syncFromSupabase()]);
    } else {
      _initialLoad = null;
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
      // `{}` here is the FAILURE state, not an empty history — flag it, or a
      // reader cannot tell "this user has no verdicts" from "the store did not
      // answer". Private mode has no mirror to fall back on, so this is fatal
      // to trust. See [loadIsTrustworthy].
      _syncFailed = true;
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
      // A later success must re-enable what an earlier failure disabled, or one
      // bad cold-start sync keeps the sweep off for the whole session.
      _syncFailed = false;
      if (await cacheOverwriteAllowed(user.id, isEmptyResult: newLogs.isEmpty)) {
        _saveToCache(newLogs);
      }
    } catch (e, stack) {
      AppLogger.error('[HabitLogs] Sync error', e, stack);
      // Offline or a 5xx. Survivable IF the mirror seeded — see
      // [loadIsTrustworthy]; fatal to trust if it did not.
      _syncFailed = true;
    }
  }

  /// Advances a habit-day through the manual check-in cycle:
  /// none → `done` → `missed` → none.
  ///
  /// For a VERIFIED habit the first two steps also freeze the day against auto
  /// verdicts (D9) and the third releases it — see [_setManualStatus].
  Future<void> cycleStatus(DateTime date, String habitId) {
    final dateKey = _logDateKey(date);
    final currentStatus = state[dateKey]?[habitId];
    final nextStatus = switch (currentStatus) {
      null => 'done',
      'done' => 'missed',
      _ => null, // rimosso
    };
    return _setManualStatus(date, habitId, nextStatus);
  }

  /// Hands a verified habit-day back to auto-verification: drops the user's
  /// verdict AND the D9 manual freeze that came with it, so the next reconcile
  /// pass scores the day from Apple Health again.
  ///
  /// Identical in effect to cycling round to "no status", and deliberately
  /// implemented as exactly that rather than as a second write path. It exists
  /// as its own entry point because the cycle is not a discoverable way to say
  /// "I did not mean to take this day over": a user who taps a verified habit
  /// once has silently disabled automation for that day, and needs a control
  /// that says so rather than a third tap they have to guess at.
  Future<void> releaseToAutoVerification(DateTime date, String habitId) =>
      _setManualStatus(date, habitId, null);

  String _logDateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// The single manual write path behind [cycleStatus] and
  /// [releaseToAutoVerification]: persists [nextStatus] (null ⇒ delete the row),
  /// recomputes the streak, and sets or clears the D9 manual freeze to match.
  Future<void> _setManualStatus(
    DateTime date,
    String habitId,
    String? nextStatus,
  ) async {
    final isPrivateMode =
        ref.read(activeDataModeProvider) == AppDataMode.private;
    final user = isPrivateMode ? null : supabase.auth.currentUser;
    if (!isPrivateMode && user == null) return;

    final dateKey = _logDateKey(date);

    // Snapshot for optimistic rollback if the persistence layer fails.
    final previousState = state;

    final newState = Map<String, Map<String, String>>.from(state);
    final dayLogs = Map<String, String>.from(newState[dateKey] ?? {});

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
      _markManualProvenance(habitId, date,
          set: nextStatus != null, status: nextStatus);
    }

    // Deterministic streak for the toggled day, computed from the full ordered
    // log history (shared with the web app + Private Mode). See streak_utils.dart.
    final goal = ref
        .read(goalsProvider)
        .where((g) => g.id == habitId)
        .firstOrNull;
    // ABSENCE IS NOT EVIDENCE: a habit missing from goalsProvider is not a
    // habit with no start date. Substituting [date] for the start date makes
    // computeStreak's backward walk break on its first step, persisting a real
    // streak as ±1. See [unknownStreakFor] for what is written instead.
    final int? newStreak = nextStatus == null
        ? 0
        : goal == null
            ? unknownStreakFor(
                previousStatus: previousState[dateKey]?[habitId],
                newStatus: nextStatus,
              )
            : computeStreak(
                habitId: habitId,
                date: date,
                logs: newState,
                startDate: goal.startDate,
                frequencyDays: goal.frequencyDays,
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
        await supabase.from('goal_logs').upsert(
              goalLogUpsertPayload(
                userId: user!.id,
                goalId: habitId,
                dateKey: dateKey,
                status: nextStatus,
                streak: newStreak,
              ),
              onConflict: 'goal_id, date',
            );
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
  void _markManualProvenance(
    String goalId,
    DateTime date, {
    required bool set,
    String? status,
  }) {
    final goal =
        ref.read(goalsProvider).where((g) => g.id == goalId).firstOrNull;
    if (!(goal?.isVerified ?? false)) return;
    final day = DateTime(date.year, date.month, date.day);
    () async {
      try {
        final store = await ref.read(verificationStateStoreProvider.future);
        if (set) {
          // The verdict travels WITH the freeze. A freeze whose `goal_logs` row
          // later turns out to be invisible can then be restored to what the
          // user actually chose, instead of being judged by the sensor.
          await store.markManual(goalId, day, status: status);
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
    // ABSENCE IS NOT EVIDENCE. This runs inside the reconcile's sequential
    // write loop, long after that pass took its goals barrier, and it re-reads
    // goalsProvider LIVE per write — so an applied sync landing mid-loop
    // resolves `goal` to null for a habit that plainly exists. Substituting
    // [parsedDate] for the start date makes computeStreak's backward walk break
    // on its first step (`if (cursor.isBefore(start)) break;`), turning a
    // 40-day streak into 1 and PERSISTING it to a table that syncs to every
    // device, where nothing re-derives it. Null ⇒ keep the stored value.
    final int? newStreak = goal == null
        ? unknownStreakFor(
            previousStatus: previousState[dateKey]?[goalId],
            newStatus: status,
          )
        : computeStreak(
            habitId: goalId,
            date: parsedDate,
            logs: newState,
            startDate: goal.startDate,
            frequencyDays: goal.frequencyDays,
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
          ...goalLogUpsertPayload(
            userId: user!.id,
            goalId: goalId,
            dateKey: dateKey,
            status: status,
            streak: newStreak,
          ),
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
    // ABSENCE IS NOT EVIDENCE — same hazard as applyAutoVerdict above, reached
    // from the manual-target sweep's apply loop, which awaits one persistence
    // round trip per change and so spans many event-loop turns. Null ⇒ keep the
    // stored streak rather than persisting one computed from a fabricated start
    // date. (The status == null branch is a genuine 0: the row is deleted.)
    final int? newStreak = status == null
        ? 0
        : goal == null
            ? unknownStreakFor(
                previousStatus: previousState[dateKey]?[goalId],
                newStatus: status,
              )
            : computeStreak(
                habitId: goalId,
                date: parsedDate,
                logs: newState,
                startDate: goal.startDate,
                frequencyDays: goal.frequencyDays,
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
          await supabase.from('goal_logs').upsert(
                goalLogUpsertPayload(
                  userId: user!.id,
                  goalId: goalId,
                  dateKey: dateKey,
                  status: status,
                  streak: newStreak,
                ),
                onConflict: 'goal_id, date',
              );
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

  /// The twin of [HabitLogsNotifier._syncFailed], needed for the same reason:
  /// both loaders swallow their error and leave `{}`, so the barrier settles on
  /// a failure and "loaded, nothing stored" and "never loaded" stay
  /// indistinguishable. Awaiting the barrier alone is therefore NOT enough to
  /// earn the right to read absence as evidence, which is exactly what the
  /// paragraph above says this map must not do.
  bool _syncFailed = false;

  /// Set when the offline mirror populated [state]. See [loadIsTrustworthy]:
  /// sweeping a cache-seeded map is what shipped, and is what keeps limit
  /// habits resolving with no signal.
  bool _cacheSeeded = false;

  @override
  HabitProgressMap build() {
    final dataMode = ref.watch(activeDataModeProvider);
    ref.onDispose(_flushCache);
    _syncFailed = false;
    _cacheSeeded = false;

    if (dataMode == AppDataMode.private) {
      _initialLoad = _loadFromPrivateStore();
      return {};
    }

    _serverStateApplied = false;
    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        // Re-arm the barrier: the logout branch below empties `state` without
        // rebuilding the notifier, so leaving the old completed future in place
        // would let the sweep read `{}` as "no progress recorded" and delete
        // real rows. The flags are re-armed with it — a fresh attempt is not yet
        // a failure, and the previous account's seed says nothing about this one.
        _syncFailed = false;
        _cacheSeeded = false;
        _initialLoad = _syncFromSupabase();
      } else if (!next.isLoggedIn) {
        state = {};
      }
    });

    final authState = ref.read(authProvider);
    final user = authState.user;
    if (authState.isLoggedIn && user != null) {
      // BOTH loaders — see [loadBarrier]. Barriering on the server call alone
      // resolves with an empty map whenever it fails fast (offline, a 5xx) while
      // the cache seed is still awaiting its Keychain round trip. Here that is
      // not churn but DATA LOSS: an `atMost` habit-day with no progress entry
      // resolves to a quiet success, and applying that verdict writes amount 0,
      // which deletes the stored row and tombstones the deletion to CloudKit.
      _initialLoad = loadBarrier([_seedFromCache(user.id), _syncFromSupabase()]);
    } else {
      _initialLoad = null;
    }
    return {};
  }

  /// Awaits the in-flight initial load, if any, so a caller that must not
  /// mistake "not loaded yet" for "no data" can wait for the real map. Returns
  /// false if it never settled. Never rethrows — see [awaitStableBarrier].
  Future<bool> _ensureLoaded() async {
    final settled = await awaitStableBarrier(() => _initialLoad);
    return loadIsTrustworthy(
      settled: settled,
      syncFailed: _syncFailed,
      cacheSeeded: _cacheSeeded,
    );
  }

  Future<void> _seedFromCache(String userId) async {
    if (!await cacheSeedAllowed(userId)) return;
    if (!ref.mounted ||
        _serverStateApplied ||
        supabase.auth.currentUser?.id != userId) {
      return;
    }
    final cached = _loadFromCache();
    // Deliberately NOT flagged for an empty mirror, and it is worth recording
    // why, because "the mirror answered, and it says nothing is stored" is a
    // tempting reading that is wrong here.
    //
    // An empty local mirror does NOT mean the account has no progress — it also
    // describes a device that has never completed a sync. Pair that with a
    // FAILED server leg (the only case this flag is consulted in) and the empty
    // map is empty because nothing was ever downloaded, while the account may
    // hold real rows. Treating that as trustworthy would let the sweep resolve
    // every `atMost` day to a quiet 'done' — writing success over breaches this
    // device simply could not see. Declining the sweep is the conservative
    // direction and the intended one. See [loadIsTrustworthy].
    if (cached.isEmpty) return;
    state = cached;
    // The mirror answered: a failed server leg is now survivable.
    _cacheSeeded = true;
  }

  Future<void> _loadFromPrivateStore() async {
    try {
      state = await ref.read(privateLocalDatabaseProvider).loadHabitProgress();
    } catch (e, stack) {
      AppLogger.error('[HabitProgress] Private load error', e, stack);
      // See [loadIsTrustworthy]: `{}` here is the failure, not an empty history,
      // and for an atMost target absence means "quiet success" — the single most
      // destructive thing this map can be wrong about. Private mode has no
      // mirror to fall back on.
      _syncFailed = true;
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
      // A later success re-enables what an earlier failure disabled.
      _syncFailed = false;
      if (await cacheOverwriteAllowed(user.id,
          isEmptyResult: newProgress.isEmpty)) {
        _saveToCache(newProgress);
      }
    } catch (e, stack) {
      AppLogger.error('[HabitProgress] Sync error', e, stack);
      // Offline or a 5xx. Survivable IF the mirror seeded — see
      // [loadIsTrustworthy]; otherwise the sweep must stand down rather than
      // read absence as "no progress".
      _syncFailed = true;
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
  /// a limit habit's quiet days (successes only knowable once the day is over)
  /// and, from the auto-fail anchor on, a count habit's untouched days (misses
  /// for the same reason). Call on foreground; a no-op when there are no manual
  /// targets or nothing changed.
  ///
  /// Reuses [setProgress] as the applier (one write path), so each corrected day
  /// re-derives and persists exactly as a live edit would, streaks included —
  /// EXCEPT for a `verdictOnly` change, which had no stored number and so writes
  /// the verdict alone rather than "setting" a progress of 0. See
  /// [TargetReconcileChange.verdictOnly]. [now] is injectable for tests.
  ///
  /// [allowAutoFail] lets the caller withhold auto-fail for one pass while still
  /// running the rest of the sweep — used when the notification queue could not
  /// be READ AT ALL, i.e. when it is unknown which habit-days the user has
  /// already decided.
  ///
  /// [pendingVerdicts] carries the decided-but-unwritten days the caller DOES
  /// know about (`dateKey → goalId → status`), drained from the notification
  /// queue. They are overlaid on the stored verdict map, so auto-fail's existing
  /// "only ever FILL an empty verdict" rule sees them as the verdicts they are.
  ///
  /// This replaces switching auto-fail off whenever the queue was non-empty.
  /// That was the right instinct applied at the wrong granularity: some entries
  /// never drain — `goal_logs.goal_id` is a foreign key onto `goals`, so a
  /// queued Done for a habit the user later DELETED is rejected on every replay
  /// forever — and a single one of them disabled auto-fail for every habit and
  /// every day, permanently. Overlaying protects exactly the days the user
  /// decided and leaves the rest scoreable.
  Future<void> reconcileManualTargets({
    DateTime? now,
    bool allowAutoFail = true,
    Map<String, Map<String, String>> pendingVerdicts = const {},
  }) async {
    // ORDER MATTERS HERE, and it is the whole reason this reads oddly.
    //
    // `awaitStableBarrier` proves a map is loaded *as of the moment it returns*.
    // Riverpod reuses a notifier across `invalidate`, so any await between that
    // proof and the synchronous read below reopens the exact window the barrier
    // exists to close — and `ref.mounted` cannot see it, because the notifier
    // was never disposed. The progress barrier therefore has to be the LAST
    // await before the reads, with nothing between them.
    //
    // So the logs barrier and the anchor (a platform-channel round trip on its
    // first run) are settled FIRST, and the logs map is captured the instant its
    // barrier returns. Then the progress barrier, then straight into the loop.

    // AUTO-FAIL alone needs the VERDICT map to be trustworthy, and it is the only
    // part of this sweep that does: it is the only rule that reads an ABSENT
    // verdict as permission to write one. An unloaded or failed logs map makes
    // every closed day look untouched, and the day it would destroy is the one
    // that cannot heal — a 'done' with no number behind it (the reminder's Done
    // action writes exactly that), which no later sweep can re-derive.
    //
    // The rest of the sweep is unharmed by a thin logs map, because it derives
    // from goal_progress: a quiet limit day resolves to 'done' and a recorded
    // breach re-derives to 'missed' whether or not the stored verdict was
    // visible. So a bad logs read disables auto-fail for this pass and leaves
    // shipped behaviour exactly as it was, rather than standing the whole sweep
    // down and leaving limit habits unresolved offline.
    final logsTrustworthy = allowAutoFail &&
        await ref.read(habitLogsProvider.notifier).ensureLoaded();
    if (!ref.mounted) return;
    // Captured NOW, while the barrier's proof still holds — not re-read after
    // the anchor await below.
    final logs = ref.read(habitLogsProvider);
    if (!logsTrustworthy) {
      AppLogger.warning(
        '[Targets] the verdict map is not trustworthy for this pass '
        '(allowAutoFail=$allowAutoFail) — auto-fail is off rather than reading '
        'an unloaded or incomplete map as "no verdict stored"',
      );
    }
    final today = now ?? DateTime.now();
    final autoFailFrom =
        logsTrustworthy ? await _resolveAutoFailAnchor(today) : null;
    if (!ref.mounted) return;

    // Never sweep a map that has not finished loading: for an `atMost` target an
    // absent entry means "quiet success", so an unloaded map resolves every
    // stored breach to 'done' — and, before the verdict-only path, applied that
    // as amount 0, which DELETES the amount behind it. See [_initialLoad]. A
    // barrier that gave up is NOT a load — decline the sweep rather than run it
    // on a map that may be mid-flight; the next foreground will try again.
    if (!await _ensureLoaded()) {
      AppLogger.warning(
        '[Targets] goal progress did not settle — skipping the manual-target '
        'sweep rather than resolving days from a possibly-unloaded map',
      );
      return;
    }
    if (!ref.mounted) return;
    // NO awaits from here to the end of the loop.
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
        // Stored verdict, or the one still sitting in the notification queue.
        // A queued Done IS the user's verdict — it just hasn't reached the
        // server — so auto-fail must read it as one and leave the day alone.
        // Order matters: the stored map wins, because an entry that has already
        // been replayed is in BOTH, and the stored row is the one the rest of
        // the sweep derives from.
        statusFor: (dateKey) =>
            logs[dateKey]?[goal.id] ?? pendingVerdicts[dateKey]?[goal.id],
        autoFailUnmetFrom: autoFailFrom,
      ));
    }
    if (changes.isEmpty) return;
    await _applyTargetChanges(
      changes,
      {for (final g in ref.read(goalsProvider)) g.id: g},
      today,
    );
  }

  /// Applies [changes] through the one write path, in order.
  ///
  /// [byGoal] resolves each change's habit — and, with it, the TARGET the day is
  /// scored against. Passed in rather than read from `goalsProvider` so a caller
  /// can score days against a target the habit is being edited away from; see
  /// [materialiseDaysBeforeTargetChange].
  Future<void> _applyTargetChanges(
    List<TargetReconcileChange> changes,
    Map<String, Goal> byGoal,
    DateTime today,
  ) async {
    // Sequential: each setProgress recomputes the streak from the running state,
    // so applying in date order builds streaks correctly rather than racing.
    for (final change in changes) {
      final goal = byGoal[change.goalId];
      final target = goal?.target;
      if (target == null) continue;
      // One owner per habit-day, re-checked at APPLY time. `setProgress` makes
      // this check itself, so the ordinary path is covered; the verdict-only
      // path writes the log directly and would otherwise inherit only the
      // snapshot taken before the awaits above. A habit that gained a rule mid
      // sweep must be left to the verification pipeline.
      if (goal!.verificationRule != null) continue;
      if (change.verdictOnly) {
        // No stored number, so there is nothing to "set" — writing the verdict
        // alone keeps this path incapable of deleting a real count. Still the
        // one goal_logs writer setProgress itself delegates to, so streaks and
        // the stats invalidation behave identically. The status is re-derived
        // rather than spelled 'missed' here: evaluateTarget owns the whole
        // progress→status mapping, and a second copy of it is exactly the drift
        // that mapping was centralised to stop. `progress: null` is the honest
        // input — there is no row — and for a manual target it resolves to 0.
        final verdict = evaluateTarget(
          target: target,
          progress: null,
          periodIsOver: true,
        );
        await ref.read(habitLogsProvider.notifier).setDerivedStatus(
              goalId: change.goalId,
              dateKey: change.dateKey,
              status: verdict.logStatus,
            );
        continue;
      }
      await setProgress(
        dateKey: change.dateKey,
        goalId: change.goalId,
        amount: change.amount,
        target: target,
        now: today,
      );
    }
  }

  /// Scores [previous]'s outstanding closed days against the target it is about
  /// to be edited AWAY from, so nothing is stranded when the v11 anchor moves.
  ///
  /// The anchor is forward-only: editing a target's amount (or its direction,
  /// unit, period or aggregation) stamps `target_effective_from = today`, and
  /// the sweep never looks before it. That is exactly right for a day that
  /// ALREADY carries a verdict — it must keep the one it earned under the old
  /// target, which is what the anchor exists for. It is wrong for a day that
  /// never got one: the sweep can no longer reach it, so it stays pending
  /// forever, with no way back short of re-entering the number by hand.
  ///
  /// The tempting fix — let the sweep fill empty days before the anchor — is a
  /// trap, and is deliberately NOT what this does. Those days would be scored
  /// against the NEW target, which was not in force when they happened: raise a
  /// goal from 3 to 10 and a day that did 3 is written `missed`, having actually
  /// been met. That fabricates a verdict, and a wrong verdict is worse than an
  /// absent one — `null` writes no `goal_logs` row at all, so a pending day is
  /// merely invisible, while a fabricated one poisons streaks and every rate
  /// that counts it.
  ///
  /// So the days are scored HERE, while the old target is still in hand and
  /// still correct. Every day ends up judged by the target that was actually in
  /// force on it, nothing is invented, and nothing is stranded.
  ///
  /// Best-effort by contract: guarded and bounded by the caller, because failing
  /// to materialise history must never cost the user the edit they asked for.
  Future<void> materialiseDaysBeforeTargetChange(
    Goal previous, {
    DateTime? now,
  }) async {
    final target = previous.target;
    // Nothing to strand: no target, a measured one (owned by the verification
    // pipeline), or a habit whose verdicts that pipeline owns outright.
    if (target == null ||
        !target.isUserEnterable ||
        previous.verificationRule != null) {
      return;
    }

    // Same barriers, and the same order, as the ordinary sweep — this writes
    // through the identical path, so it inherits the identical hazards. See
    // [reconcileManualTargets] for why the progress barrier must be last.
    // The BARRIERS are bounded, not the write loop. `Future.timeout` does not
    // cancel the future it wraps, so bounding the whole operation would let the
    // caller move on — stamping the new anchor and saving the goal — while this
    // carried on writing days against a habit that had since changed shape.
    // Bounding the load instead means this either declines promptly or runs to
    // completion. Same pattern, and the same 10s, as `_runScreenTimeSync`.
    const loadDeadline = Duration(seconds: 10);
    final logsLoaded = await ref
        .read(habitLogsProvider.notifier)
        .ensureLoaded()
        .timeout(loadDeadline, onTimeout: () => false);
    if (!logsLoaded) {
      AppLogger.warning(
        '[Targets] the verdict map is not trustworthy — not materialising '
        '${previous.id}\'s days before its target edit; they will stay pending',
      );
      return;
    }
    if (!ref.mounted) return;
    final logs = ref.read(habitLogsProvider);
    final today = now ?? DateTime.now();
    if (!await _ensureLoaded().timeout(loadDeadline, onTimeout: () => false)) {
      AppLogger.warning(
        '[Targets] goal progress did not settle — not materialising '
        '${previous.id}\'s days before its target edit; they will stay pending',
      );
      return;
    }
    if (!ref.mounted) return;

    final changes = reconcileManualTargetDays(
      goalId: previous.id,
      target: target,
      today: today,
      start: previous.startDate,
      effectiveFrom: previous.targetEffectiveFrom,
      isScheduled: previous.isScheduledOn,
      progressFor: (dateKey) => state[dateKey]?[previous.id],
      statusFor: (dateKey) => logs[dateKey]?[previous.id],
      // NO auto-fail here, deliberately.
      //
      // This pass exists to preserve what the old target already DECIDED — the
      // days it can still score from a stored number. Auto-fail is the opposite
      // kind of claim: it reads an ABSENT number as "the user did zero", which
      // is only safe with a verdict map that includes the notification queue's
      // decided-but-unwritten days. This path has no access to that queue, so
      // an untouched day here could be one the user already tapped Done on from
      // a reminder — and scoring it would write `missed` over their answer, at
      // the exact moment they are editing the habit, as a wall of red.
      //
      // Nothing is lost by declining: untouched days are the ordinary sweep's
      // job, it runs on the very next trigger, and this edit does not put them
      // out of its reach (auto-fail has its own anchor, independent of the v11
      // one this is racing).
      autoFailUnmetFrom: null,
    );
    if (changes.isEmpty) return;
    AppLogger.info(
      '[Targets] materialising ${changes.length} outstanding day(s) for '
      '${previous.id} under its previous target before the anchor moves',
    );
    // Keyed to the PREVIOUS goal, so every change is scored against the old
    // target even though the caller is mid-edit.
    await _applyTargetChanges(changes, {previous.id: previous}, today);
  }

  /// Reads the auto-fail anchor, stamping today the first time it is missing.
  /// The RULE lives in [resolveAndStampAutoFailAnchor], shared with macOS; only
  /// the preference plumbing is local.
  Future<DateTime?> _resolveAutoFailAnchor(DateTime today) =>
      resolveAndStampAutoFailAnchor(
        today: today,
        read: () => ref.read(sharedPrefsProvider).getString(kAutoFailAnchorPrefKey),
        write: (value) =>
            ref.read(sharedPrefsProvider).setString(kAutoFailAnchorPrefKey, value),
        // Warning, not error: a handled degradation with a safe outcome —
        // auto-fail stays off this pass and the next foreground tries again.
        onError: (e) => AppLogger.warning(
            '[Targets] auto-fail anchor unavailable — auto-fail off for this '
            'pass: $e'),
      );

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
