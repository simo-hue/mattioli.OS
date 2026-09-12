import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/macro_goal.dart';
import '../core/macro_goal_calendar.dart';
import '../core/macro_targets_config.dart';
import 'shared_prefs_provider.dart';
import 'auth_provider.dart';
import 'goal_provider.dart'
    show
        GoalLogPageFetcher,
        awaitStableBarrier,
        cacheSeedAllowed,
        loadBarrier,
        rememberCacheOwner;
import '../core/navigator_key.dart';
import '../core/app_logger.dart';
import '../core/data_mode.dart';
import '../core/private_local_database.dart';
import '../ui/widgets/error_modal.dart';
import '../i18n/translations.g.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class MacroGoalsState {
  final List<MacroGoal> goals;
  final bool isLoading;
  final String? error;

  const MacroGoalsState({
    required this.goals,
    this.isLoading = false,
    this.error,
  });

  MacroGoalsState copyWith({
    List<MacroGoal>? goals,
    bool? isLoading,
    String? error,
  }) => MacroGoalsState(
    goals: goals ?? this.goals,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

/// Page size for the windowed `long_term_goals` sync. A single unbounded
/// PostgREST select is capped by the project's `db-max-rows` (1000 by default)
/// and truncates SILENTLY — and this table grows one row per goal AND one more
/// per reschedule, so a long-running weekly-goal user reaches the cap. Because
/// the read is ordered oldest-first, truncation drops the NEWEST goals: the
/// current period's board. Mirrors `kGoalLogsSyncPageSize` and
/// `kMacroGoalProgressPageSize`.
const int kMacroGoalsSyncPageSize = 1000;

/// Accumulates every page [fetchPage] returns, requesting successive ranges
/// until a short (final) page comes back. Kept separate from the notifier —
/// like [fetchGoalLogsPaginated] — so the paging is deterministic and testable
/// without a live client, and so the caller can assign state ONCE at the end: a
/// partial page written mid-loop would be cached as if it were the whole list.
Future<List<Map<String, dynamic>>> fetchMacroGoalsPaginated(
  GoalLogPageFetcher fetchPage, {
  int pageSize = kMacroGoalsSyncPageSize,
}) async {
  final rows = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    final page = await fetchPage(offset, pageSize);
    rows.addAll(page);
    if (page.length < pageSize) break;
    offset += pageSize;
  }
  return rows;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MacroGoalsNotifier extends Notifier<MacroGoalsState> {
  static const String _cacheKey = 'macro_goals_cache';
  static const String _tutorialGoalId = 'tutorial_fake_goal';

  /// Set once the server's answer has been applied, so the owner-gated cache
  /// seed — which now awaits a Keychain read and can therefore land after the
  /// sync — cannot overwrite fresher state with the mirror. Mirrors
  /// [GoalsNotifier]'s flag of the same name.
  bool _serverStateApplied = false;

  /// The in-flight initial load, so a caller that must not mistake "not loaded
  /// yet" for "this account has no macro goals" can wait for the real list.
  ///
  /// [build] returns an empty state and fills it in asynchronously — the cache
  /// seed is gated on a Keychain round trip — so a `ref.read` that BUILDS this
  /// provider gets `[]` synchronously, every time. That is only a frame of
  /// blank UI for a widget, but [GoalsNotifier.deleteHabit] reads this state as
  /// EVIDENCE (see [ensureLoaded]), and this provider is routinely never built
  /// before that read: MacroGoalsScreen is index 2 of a lazy PageView. Mirrors
  /// [GoalsNotifier._initialLoad], which exists for the identical hazard.
  Future<void>? _initialLoad;

  /// Awaits the loaders [build] started, if any.
  ///
  /// Callers that act destructively on an empty `state.goals` must use this
  /// first. The one today is [GoalsNotifier.deleteHabit]: an empty list there
  /// means "no macro goal is linked to this habit", which skips the delete-time
  /// snapshot — and the habit DELETE then cascades `goal_progress` away while
  /// the `ON DELETE SET NULL` FK un-links the macro goal, collapsing a "500 km"
  /// goal that had reached 320 to 0 with nothing left to re-derive it from.
  Future<bool> ensureLoaded() => awaitStableBarrier(() => _initialLoad);

  @override
  MacroGoalsState build() {
    final dataMode = ref.watch(activeDataModeProvider);
    if (dataMode == AppDataMode.private) {
      _loadFromPrivateStore();
      return const MacroGoalsState(goals: []);
    }

    _serverStateApplied = false;
    _initialLoad = null;

    // 2. Ascolta i cambi di autenticazione per scaricare i dati dal cloud
    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        _syncFromSupabase();
      } else if (!next.isLoggedIn) {
        // Clear state on logout
        state = const MacroGoalsState(goals: []);
        _saveToCache([]);
      }
    });

    // 1./3. Offline-first seed AND the initial sync, if a session is signed in.
    // The seed is now asynchronous because the cache's owner marker lives in the
    // Keychain: `macro_goals_cache` is one blob shared by every account on the
    // device, so seeding it unconditionally handed the next account the previous
    // one's long-term goals. Costs the owning user one empty frame before the
    // marker read returns — the same trade `GoalsNotifier._seedFromCache` makes.
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (authState.isLoggedIn && user != null) {
      // Joined into one barrier so [ensureLoaded] cannot resolve before BOTH
      // legs have settled — the seed's Keychain round trip routinely outlives
      // the server call, which returns in milliseconds when it fails.
      _initialLoad = loadBarrier([_seedFromCache(user.id), _syncFromSupabase()]);
    }

    return const MacroGoalsState(goals: []);
  }

  /// See [GoalsNotifier._seedFromCache] — same shared blob, same owner guard.
  ///
  /// Contains its own errors even though [loadBarrier] would also swallow them:
  /// the marker read is a Keychain round trip, and an unreadable marker means
  /// "not provably this account's cache" — a refusal, not a crash, and one the
  /// log has to record.
  Future<void> _seedFromCache(String userId) async {
    try {
      if (!await cacheSeedAllowed(userId)) return;
      if (!ref.mounted ||
          _serverStateApplied ||
          supabase.auth.currentUser?.id != userId) {
        return;
      }
      final cached = _loadFromCache();
      if (cached.goals.isEmpty) return;
      state = cached;
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Cache seed error', e, stack);
    }
  }

  Future<void> _loadFromPrivateStore() async {
    try {
      final goals = await ref
          .read(privateLocalDatabaseProvider)
          .loadMacroGoals();
      state = MacroGoalsState(goals: goals);
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Private load error', e, stack);
      state = const MacroGoalsState(goals: []);
    }
  }

  // ── Cache Locale ──────────────────────────────────────────────────────────

  MacroGoalsState _loadFromCache() {
    final prefs = ref.read(sharedPrefsProvider);
    final cache = prefs.getString(_cacheKey);
    if (cache == null) return const MacroGoalsState(goals: []);

    try {
      final List<dynamic> jsonList = jsonDecode(cache);
      final goals = jsonList.map((j) => MacroGoal.fromJson(j)).toList();
      return MacroGoalsState(goals: goals);
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Cache parsing error', e, stack);
      return const MacroGoalsState(goals: []);
    }
  }

  void _saveToCache(List<MacroGoal> goals) {
    final prefs = ref.read(sharedPrefsProvider);
    final jsonList = goals.map((g) => g.toJson()).toList();
    prefs.setString(_cacheKey, jsonEncode(jsonList));
    // The blob and its owner marker move together, or [_seedFromCache] refuses
    // this account's own mirror on the next cold start. An EMPTY blob is left
    // unowned (nothing to protect, and the logout arm above writes one with no
    // session at all) — same rule as `GoalsNotifier._writeCache`.
    if (goals.isEmpty) return;
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) rememberCacheOwner(userId);
  }

  /// Surface a Private-mode persistence failure to the user, mirroring the
  /// Supabase error paths (strings via the global `t`). Used after the caller
  /// has already rolled the optimistic state back.
  void _showMacroGoalError(String title, String message, Object error) {
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

  MacroGoal? _goalById(String id) {
    for (final goal in state.goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  bool _shouldIgnoreMissingGoalMutation(String id, String action) {
    if (_goalById(id) != null) return false;
    if (id == _tutorialGoalId) return true;

    AppLogger.warning('[MacroGoals] Ignoring $action for missing goal: $id');
    return true;
  }

  // ── Sync da Supabase ──────────────────────────────────────────────────────

  Future<void> _syncFromSupabase() async {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Windowed, not one unbounded select — see [kMacroGoalsSyncPageSize]. The
      // `id` tiebreaker makes the sort total across pages (created_at alone is
      // not unique: a reschedule mints its rows together), so no row is served
      // twice or skipped. State and the cache are written once, AFTER the last
      // page: assigning per page would cache a partial list.
      final response = await fetchMacroGoalsPaginated((offset, limit) async {
        final page = await supabase
            .from('long_term_goals')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + limit - 1);
        return List<Map<String, dynamic>>.from(page);
      });

      final goals = response.map((j) => MacroGoal.fromJson(j)).toList();

      _serverStateApplied = true;
      state = state.copyWith(goals: goals);
      _saveToCache(goals);
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Sync error', e, stack);
      // In caso di errore manteniamo la cache locale
    }
  }

  // ── CRUD (Optimistic Updates) ─────────────────────────────────────────────

  Future<void> addGoal(MacroGoal goal) async {
    // 1. Aggiornamento ottimistico
    final previousState = state;
    final newGoals = [...state.goals, goal];
    state = state.copyWith(goals: newGoals);

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        await ref.read(privateLocalDatabaseProvider).upsertMacroGoal(goal);
      } catch (e, stack) {
        AppLogger.error('[MacroGoals] Private insert error', e, stack);
        state = previousState;
        _showMacroGoalError(
          t.common.errorDuringSaving,
          t.common.macroGoalSaveFailed,
          e,
        );
      }
      return;
    }

    _saveToCache(newGoals);

    // 2. Invio al server
    final user = supabase.auth.currentUser;
    if (user == null) {
      // No session (token expiry/rotation race between opening the composer and
      // saving): undo the optimistic insert instead of stranding a ghost goal in
      // state + the cache written just above, and surface the failure — matching
      // the catch block below and GoalsNotifier.addHabit. Left in place the goal
      // is shown as saved, is never uploaded, and the next successful
      // _syncFromSupabase replaces state.goals wholesale and drops it silently.
      AppLogger.error(
        '[MacroGoals] Insert skipped: no authenticated user',
        StateError('no authenticated user'),
        StackTrace.current,
      );
      state = previousState;
      _saveToCache(previousState.goals);
      _showMacroGoalError(
        t.common.errorDuringSaving,
        t.common.macroGoalSaveFailed,
        StateError('no authenticated user'),
      );
      return;
    }

    try {
      final payload = goal.toJson();
      payload['user_id'] = user.id; // forza l'id utente
      payload.remove('id'); // Lasciamo generare l'UUID a Supabase se vuoto

      final result = await supabase
          .from('long_term_goals')
          .insert(payload)
          .select()
          .single();

      // 3. Sostituisci l'ID locale (che potrebbe essere fittizio) con quello reale
      final realGoal = MacroGoal.fromJson(result);
      final updatedGoals = state.goals
          .map((g) => g.id == goal.id ? realGoal : g)
          .toList();
      state = state.copyWith(goals: updatedGoals);
      _saveToCache(updatedGoals);
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Insert error', e, stack);
      // Remove the optimistic (temp-id) ghost row on failure: the id the add-bar
      // mints is not a uuid — only the success path above swaps in the one
      // Supabase assigns — so a row left behind here can never be updated or
      // deleted server-side (22P02 on `long_term_goals.id uuid`), and the cache
      // write above would carry it across a restart. Filtered by id rather than
      // restored from `previousState`, so a mutation that landed during the
      // insert await is not reverted along with it.
      final rolledBack = state.goals.where((g) => g.id != goal.id).toList();
      state = state.copyWith(goals: rolledBack);
      _saveToCache(rolledBack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: context.t.common.errorDuringSaving,
          message: context.t.common.macroGoalSaveFailed,
          details: e.toString(),
        );
      }
    }
  }

  Future<void> updateStatus(String id, GoalStatus status) async {
    if (_shouldIgnoreMissingGoalMutation(id, 'status update')) return;

    final previousState = state;
    final newGoals = state.goals
        .map((g) => g.id == id ? g.copyWith(status: status) : g)
        .toList();
    state = state.copyWith(goals: newGoals);

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        final goal = newGoals.firstWhere((g) => g.id == id);
        await ref.read(privateLocalDatabaseProvider).upsertMacroGoal(goal);
      } catch (e, stack) {
        AppLogger.error('[MacroGoals] Private update status error', e, stack);
        state = previousState;
        _showMacroGoalError(
          t.common.errorDuringUpdate,
          t.common.macroGoalStatusSaveFailed,
          e,
        );
      }
      return;
    }

    _saveToCache(newGoals);

    try {
      await supabase
          .from('long_term_goals')
          .update({'status': status.name})
          .eq('id', id);
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Update status error', e, stack);
      // Undo the optimistic write, like the Private branch above and addGoal:
      // the UPDATE never landed, so leaving it in state — and in the cache
      // written just above, which is what build() seeds from — shows a status
      // the server does not have across restarts, until some later
      // _syncFromSupabase replaces state.goals wholesale and drops it silently.
      // Only THIS goal's status is restored rather than `state = previousState`
      // (which the Private branch can afford, having written no cache): a
      // whole-state restore would also revert a mutation that landed on another
      // goal during this await — the hazard addGoal's catch documents.
      final previousStatus = previousState.goals
          .firstWhere((g) => g.id == id)
          .status;
      final rolledBack = state.goals
          .map((g) => g.id == id ? g.copyWith(status: previousStatus) : g)
          .toList();
      state = state.copyWith(goals: rolledBack);
      _saveToCache(rolledBack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: context.t.common.errorDuringUpdate,
          message: context.t.common.macroGoalStatusSaveFailed,
          details: e.toString(),
        );
      }
    }
  }

  Future<void> updateTitle(String id, String title) async {
    if (_shouldIgnoreMissingGoalMutation(id, 'title update')) return;

    final previousState = state;
    final newGoals = state.goals
        .map((g) => g.id == id ? g.copyWith(title: title) : g)
        .toList();
    state = state.copyWith(goals: newGoals);

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        final goal = newGoals.firstWhere((g) => g.id == id);
        await ref.read(privateLocalDatabaseProvider).upsertMacroGoal(goal);
      } catch (e, stack) {
        AppLogger.error('[MacroGoals] Private update title error', e, stack);
        state = previousState;
        _showMacroGoalError(
          t.common.errorDuringUpdate,
          t.common.macroGoalTitleSaveFailed,
          e,
        );
      }
      return;
    }

    _saveToCache(newGoals);

    try {
      await supabase
          .from('long_term_goals')
          .update({'title': title})
          .eq('id', id);
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Update title error', e, stack);
      // Undo the optimistic write (state + the cache above), restoring only this
      // goal's title — see updateStatus's catch for why not `previousState`.
      final previousTitle = previousState.goals
          .firstWhere((g) => g.id == id)
          .title;
      final rolledBack = state.goals
          .map((g) => g.id == id ? g.copyWith(title: previousTitle) : g)
          .toList();
      state = state.copyWith(goals: rolledBack);
      _saveToCache(rolledBack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: context.t.common.errorDuringUpdate,
          message: context.t.common.macroGoalTitleSaveFailed,
          details: e.toString(),
        );
      }
    }
  }

  Future<void> updateCategory(String id, String? categoryId) async {
    if (_shouldIgnoreMissingGoalMutation(id, 'category update')) return;

    final previousState = state;
    final newGoals = state.goals.map((g) {
      if (g.id != id) return g;
      return categoryId == null
          ? g.copyWith(clearCategory: true)
          : g.copyWith(categoryId: categoryId);
    }).toList();
    state = state.copyWith(goals: newGoals);

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        final goal = newGoals.firstWhere((g) => g.id == id);
        await ref.read(privateLocalDatabaseProvider).upsertMacroGoal(goal);
      } catch (e, stack) {
        AppLogger.error('[MacroGoals] Private update category error', e, stack);
        state = previousState;
        _showMacroGoalError(
          t.common.errorDuringUpdate,
          t.common.macroGoalCategorySaveFailed,
          e,
        );
      }
      return;
    }

    _saveToCache(newGoals);

    try {
      await supabase
          .from('long_term_goals')
          .update({
            'category_id': categoryId,
            // Clearing nulls the KEY as well as the id (the optimistic
            // `copyWith(clearCategory: true)` above, and the private branch's
            // whole-row upsert). A payload that omits category_key leaves a
            // legacy built-in slug on the row, and the next _syncFromSupabase
            // brings the chip straight back.
            if (categoryId == null) 'category_key': null,
          })
          .eq('id', id);
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Update category error', e, stack);
      // Undo the optimistic write (state + the cache above), restoring only this
      // goal's category — see updateStatus's catch for why not `previousState`.
      // Both columns are re-applied together because the clearing direction
      // above (`clearCategory`) nulls the KEY as well as the id, and copyWith
      // cannot set either back to null on its own.
      final previousGoal = previousState.goals.firstWhere((g) => g.id == id);
      final rolledBack = state.goals
          .map(
            (g) => g.id == id
                ? g.copyWith(clearCategory: true).copyWith(
                    categoryKey: previousGoal.categoryKey,
                    categoryId: previousGoal.categoryId,
                  )
                : g,
          )
          .toList();
      state = state.copyWith(goals: rolledBack);
      _saveToCache(rolledBack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: context.t.common.errorDuringUpdate,
          message: context.t.common.macroGoalCategorySaveFailed,
          details: e.toString(),
        );
      }
    }
  }

  /// Sets or clears a macro goal's NUMERIC target (amount + unit), stored manual
  /// progress and/or its linked habit — the edit counterpart of creating one
  /// with a target. Pass [clearTarget] to revert to a plain boolean goal, or
  /// [clearLink] to detach the habit while keeping the target (pass a
  /// [progressAmount] snapshot so the derived value survives as a manual one).
  ///
  /// On the Supabase UPDATE the numeric columns are FORCE-WRITTEN (null clears),
  /// because [MacroGoal.toJson] only EMITS them when non-null and an UPDATE
  /// leaves omitted columns untouched — so without this it could never actively
  /// clear a target or break a link. Mirrors the habit `target` force-write and
  /// desktop's updateGoal. The column write is gated on [MacroTargetsConfig]:
  /// the columns exist only after the (pending) macro-target migration, so a
  /// dark build never sends them.
  Future<void> updateGoalTarget(
    String id, {
    double? targetAmount,
    String? targetUnit,
    String? linkedGoalId,
    double? progressAmount,
    bool clearTarget = false,
    bool clearLink = false,
  }) async {
    if (_shouldIgnoreMissingGoalMutation(id, 'target update')) return;

    final previousState = state;
    final newGoals = state.goals.map((g) {
      if (g.id != id) return g;
      if (clearTarget) return g.copyWith(clearTarget: true);
      return g.copyWith(
        targetAmount: targetAmount,
        targetUnit: targetUnit,
        progressAmount: progressAmount,
        linkedGoalId: linkedGoalId,
        clearLink: clearLink,
      );
    }).toList();
    state = state.copyWith(goals: newGoals);

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        final goal = newGoals.firstWhere((g) => g.id == id);
        await ref.read(privateLocalDatabaseProvider).upsertMacroGoal(goal);
      } catch (e, stack) {
        AppLogger.error('[MacroGoals] Private target update error', e, stack);
        state = previousState;
        _showMacroGoalError(
          t.common.errorDuringUpdate,
          t.common.macroGoalSaveFailed,
          e,
        );
      }
      return;
    }

    _saveToCache(newGoals);

    // Nothing to persist to the cloud while the feature is dark (the columns may
    // not exist yet). The optimistic in-memory + cache write above still holds.
    if (!MacroTargetsConfig.enabled) return;

    try {
      final goal = newGoals.firstWhere((g) => g.id == id);
      await supabase.from('long_term_goals').update({
        'target_amount': goal.targetAmount,
        'target_unit': goal.targetUnit,
        'progress_amount': goal.progressAmount,
        'linked_goal_id': goal.linkedGoalId,
      }).eq('id', id);
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Update target error', e, stack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: context.t.common.errorDuringUpdate,
          message: context.t.common.macroGoalSaveFailed,
          details: e.toString(),
        );
      }
    }
  }

  Future<void> deleteGoal(String id) async {
    if (_shouldIgnoreMissingGoalMutation(id, 'delete')) return;

    final previousState = state;
    final newGoals = state.goals.where((g) => g.id != id).toList();
    state = state.copyWith(goals: newGoals);

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        await ref.read(privateLocalDatabaseProvider).deleteMacroGoal(id);
      } catch (e, stack) {
        AppLogger.error('[MacroGoals] Private delete error', e, stack);
        state = previousState;
        _showMacroGoalError(
          t.common.macroGoalDeleteErrorTitle,
          t.common.macroGoalDeleteFailed,
          e,
        );
      }
      return;
    }

    _saveToCache(newGoals);

    try {
      await supabase.from('long_term_goals').delete().eq('id', id);
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Delete error', e, stack);
      // Put the row back: the DELETE never landed, so state and the cache above
      // hide a goal the server still has — and the cache is what build() seeds
      // from, so it stays hidden across restarts until some later
      // _syncFromSupabase brings it back unannounced. Re-inserted at its old
      // index into the CURRENT list rather than via `state = previousState`, so
      // a mutation that landed on another goal during this await survives (see
      // updateStatus's catch). Nothing can have edited THIS goal meanwhile: it
      // was absent from state, and _shouldIgnoreMissingGoalMutation drops
      // mutations for goals that are not there.
      if (!state.goals.any((g) => g.id == id)) {
        final previousIndex = previousState.goals.indexWhere((g) => g.id == id);
        final rolledBack = [...state.goals];
        rolledBack.insert(
          previousIndex.clamp(0, rolledBack.length),
          previousState.goals[previousIndex],
        );
        state = state.copyWith(goals: rolledBack);
        _saveToCache(rolledBack);
      }
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: context.t.common.macroGoalDeleteErrorTitle,
          message: context.t.common.macroGoalDeleteFailed,
          details: e.toString(),
        );
      }
    }
  }

  Future<void> rescheduleGoal(MacroGoal goal) async {
    if (_shouldIgnoreMissingGoalMutation(goal.id, 'reschedule')) return;

    // 1. Mark current as failed
    await updateStatus(goal.id, GoalStatus.failed);

    // 2. Calculate next period
    int nextY = goal.year ?? DateTime.now().year;
    int nextM = goal.month ?? 1;
    int nextW = goal.weekNumber ?? 1;
    int nextQ = goal.quarter ?? 1;

    switch (goal.type) {
      case GoalType.lifetime:
        return;
      case GoalType.annual:
        nextY++;
        break;
      case GoalType.quarterly:
        if (nextQ < 4) {
          nextQ++;
        } else {
          nextY++;
          nextQ = 1;
        }
        // Sync month to the start of the new quarter for consistency
        nextM = ((nextQ - 1) * 3) + 1;
        break;
      case GoalType.monthly:
        if (nextM < 12) {
          nextM++;
        } else {
          nextY++;
          nextM = 1;
        }
        nextQ = ((nextM - 1) ~/ 3) + 1;
        break;
      case GoalType.weekly:
        // Advance the BUCKET. A legacy goal stored at week 5 already IS the
        // next month's week 1, so bumping its number would reschedule it into
        // the very week it just failed in.
        //
        // A NULL week_number (allowed by both schemas, and reachable via
        // import) has no week to advance from, so it anchors on TODAY's bucket
        // rather than pairing a guessed week with the goal's own year/month —
        // that pairing can land on a week that has already ended.
        final next = nextWeekBucket(
          goal.weekNumber == null
              ? weekBucketOf(DateTime.now())
              : canonicalWeekBucket(nextY, nextM, goal.weekNumber!),
        );
        nextY = next.year;
        nextM = next.month;
        nextW = next.week;
        nextQ = ((nextM - 1) ~/ 3) + 1;
        break;
    }

    // 3. Create the new goal
    final newGoal = MacroGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: goal.title,
      status: GoalStatus.active,
      type: goal.type,
      year: nextY,
      quarter: nextQ,
      month: nextM,
      weekNumber: nextW,
      categoryKey: goal.categoryKey,
      categoryId: goal.categoryId,
      createdAt: DateTime.now(),
    );

    await addGoal(newGoal);
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<MacroGoal> getFilteredGoals({
    required GoalType type,
    required int year,
    int? quarter,
    int? month,
    int? weekNumber,
  }) {
    return state.goals.where((g) {
      if (g.type != type) return false;
      if (type == GoalType.lifetime) return true;
      // Weekly matches on the canonical BUCKET, which can cross the year: a
      // goal stored at (2026, 12, 5) is really January 2027 week 1. That has to
      // be settled before the plain year guard below, which would otherwise
      // reject exactly those goals for carrying the "wrong" stored year.
      if (type == GoalType.weekly) {
        final gy = g.year;
        final gm = g.month;
        final gw = g.weekNumber;
        if (gy == null || gm == null || gw == null) return false;
        if (month == null || weekNumber == null) return false;
        return canonicalWeekBucket(gy, gm, gw) ==
            canonicalWeekBucket(year, month, weekNumber);
      }
      if (g.year != year) return false;
      if (type == GoalType.quarterly && g.quarter != quarter) return false;
      if (type == GoalType.monthly && g.month != month) return false;
      return true;
    }).toList()..sort(_sortGoals);
  }

  int _sortGoals(MacroGoal a, MacroGoal b) {
    int statusOrder(GoalStatus s) {
      switch (s) {
        case GoalStatus.active:
          return 0;
        case GoalStatus.completed:
          return 1;
        case GoalStatus.failed:
          return 2;
      }
    }

    final aOrder = statusOrder(a.status);
    final bOrder = statusOrder(b.status);
    if (aOrder != bOrder) return aOrder.compareTo(bOrder);
    return a.createdAt.compareTo(b.createdAt);
  }

  void clearAll() {
    state = const MacroGoalsState(goals: []);
    if (ref.read(activeDataModeProvider) != AppDataMode.private) {
      _saveToCache([]);
    }
  }
}

final macroGoalsProvider =
    NotifierProvider<MacroGoalsNotifier, MacroGoalsState>(
      MacroGoalsNotifier.new,
    );

// ─── View state provider ──────────────────────────────────────────────────────

class MacroGoalsViewState {
  final GoalType selectedType;
  final int selectedYear;
  final int selectedQuarter;
  final int selectedMonth;
  final int selectedWeek;

  const MacroGoalsViewState({
    required this.selectedType,
    required this.selectedYear,
    required this.selectedQuarter,
    required this.selectedMonth,
    required this.selectedWeek,
  });

  MacroGoalsViewState copyWith({
    GoalType? selectedType,
    int? selectedYear,
    int? selectedQuarter,
    int? selectedMonth,
    int? selectedWeek,
  }) => MacroGoalsViewState(
    selectedType: selectedType ?? this.selectedType,
    selectedYear: selectedYear ?? this.selectedYear,
    selectedQuarter: selectedQuarter ?? this.selectedQuarter,
    selectedMonth: selectedMonth ?? this.selectedMonth,
    selectedWeek: selectedWeek ?? this.selectedWeek,
  );

  MacroGoalsViewState getNextPeriod() {
    final int y = selectedYear;
    final int q = selectedQuarter;
    final int m = selectedMonth;
    final int w = selectedWeek;

    switch (selectedType) {
      case GoalType.lifetime:
        return this;
      case GoalType.annual:
        return _clamp(copyWith(selectedYear: y + 1));
      case GoalType.quarterly:
        if (q < 4) {
          return _clamp(copyWith(selectedQuarter: q + 1));
        } else {
          return _clamp(copyWith(selectedYear: y + 1, selectedQuarter: 1));
        }
      case GoalType.monthly:
        if (m < 12) {
          return _clamp(copyWith(selectedMonth: m + 1, selectedWeek: 1));
        } else {
          return _clamp(copyWith(selectedYear: y + 1, selectedMonth: 1, selectedWeek: 1));
        }
      case GoalType.weekly:
        final next = nextWeekBucket(WeekBucket(year: y, month: m, week: w));
        return _clamp(
          copyWith(
            selectedYear: next.year,
            selectedMonth: next.month,
            selectedWeek: next.week,
          ),
        );
    }
  }

  MacroGoalsViewState getPrevPeriod() {
    final int y = selectedYear;
    final int q = selectedQuarter;
    final int m = selectedMonth;
    final int w = selectedWeek;

    switch (selectedType) {
      case GoalType.lifetime:
        return this;
      case GoalType.annual:
        return _clamp(copyWith(selectedYear: y - 1));
      case GoalType.quarterly:
        if (q > 1) {
          return _clamp(copyWith(selectedQuarter: q - 1));
        } else {
          return _clamp(copyWith(selectedYear: y - 1, selectedQuarter: 4));
        }
      case GoalType.monthly:
        if (m > 1) {
          return _clamp(copyWith(selectedMonth: m - 1, selectedWeek: 1));
        } else {
          return _clamp(copyWith(selectedYear: y - 1, selectedMonth: 12, selectedWeek: 1));
        }
      case GoalType.weekly:
        final prev = prevWeekBucket(WeekBucket(year: y, month: m, week: w));
        return _clamp(
          copyWith(
            selectedYear: prev.year,
            selectedMonth: prev.month,
            selectedWeek: prev.week,
          ),
        );
    }
  }

  MacroGoalsViewState _clamp(MacroGoalsViewState state) {
    return state.copyWith(
      selectedWeek: state.selectedWeek.clamp(1, macroGoalWeeksInMonth),
    );
  }
}

class MacroGoalsViewNotifier extends Notifier<MacroGoalsViewState> {
  @override
  MacroGoalsViewState build() {
    final now = DateTime.now();
    // The screen opens on the weekly plan, so year/month seed from the current
    // WEEK bucket — which on the 29th-31st is next month, and on 30 December is
    // next year. Quarter follows TODAY instead: it is never a weekly field, and
    // on 30 September the bucket's October would read Q4 while the current
    // quarter is still Q3. [setType] re-anchors year/month when the user
    // switches to a calendar-shaped plan.
    final bucket = weekBucketOf(now);
    return MacroGoalsViewState(
      selectedType: GoalType.weekly,
      selectedYear: bucket.year,
      selectedQuarter: _quarter(now.month),
      selectedMonth: bucket.month,
      selectedWeek: bucket.week,
    );
  }

  /// Switching plan re-anchors the shared year/month to the new plan's idea of
  /// "today" — see [reanchorPeriod]. Without it, on the 29th-31st the weekly
  /// seed (next month) would leak into the Monthly, Quarterly and Annual views.
  void setType(GoalType t) {
    final wasWeekly = state.selectedType == GoalType.weekly;
    final willBeWeekly = t == GoalType.weekly;
    if (wasWeekly == willBeWeekly) {
      state = state.copyWith(selectedType: t);
      return;
    }
    final anchored = reanchorPeriod(
      now: DateTime.now(),
      toWeekly: willBeWeekly,
      year: state.selectedYear,
      month: state.selectedMonth,
    );
    state = state.copyWith(
      selectedType: t,
      selectedYear: anchored.year,
      selectedMonth: anchored.month,
    );
  }
  void setYear(int y) {
    state = state.copyWith(
      selectedYear: y,
      selectedWeek: _clampWeek(state.selectedWeek),
    );
  }

  void setQuarter(int q) => state = state.copyWith(selectedQuarter: q);
  void setMonth(int m) =>
      state = state.copyWith(selectedMonth: m, selectedWeek: 1);
  void setWeek(int w) {
    state = state.copyWith(
      selectedWeek: _clampWeek(w),
    );
  }

  int _quarter(int month) => ((month - 1) ~/ 3) + 1;

  /// Saturates a picked week at [macroGoalWeeksInMonth]. Deliberately a clamp
  /// and not [canonicalWeekBucket]'s merge-forward: a picked week is an intent
  /// inside the month on screen, not a stored address to be resolved.
  int _clampWeek(int week) => week.clamp(1, macroGoalWeeksInMonth);

  void nextPeriod() {
    state = state.getNextPeriod();
  }

  void prevPeriod() {
    state = state.getPrevPeriod();
  }
}

final macroGoalsViewProvider =
    NotifierProvider<MacroGoalsViewNotifier, MacroGoalsViewState>(
      MacroGoalsViewNotifier.new,
    );

// ─── Helpers ─────────────────────────────────────────────────────────────────
