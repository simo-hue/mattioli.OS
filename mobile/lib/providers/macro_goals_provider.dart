import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/macro_goal.dart';
import '../core/macro_goal_calendar.dart';
import 'shared_prefs_provider.dart';
import 'auth_provider.dart';
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

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MacroGoalsNotifier extends Notifier<MacroGoalsState> {
  static const String _cacheKey = 'macro_goals_cache';
  static const String _tutorialGoalId = 'tutorial_fake_goal';

  @override
  MacroGoalsState build() {
    final dataMode = ref.watch(activeDataModeProvider);
    if (dataMode == AppDataMode.private) {
      _loadFromPrivateStore();
      return const MacroGoalsState(goals: []);
    }

    // 1. Caricamento sincrono iniziale dalla cache (Offline-First)
    final initialState = _loadFromCache();

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

    // 3. Sincronizzazione iniziale se l'utente è già loggato
    final authState = ref.read(authProvider);
    if (authState.isLoggedIn && authState.user != null) {
      _syncFromSupabase();
    }

    return initialState;
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
      final response = await supabase
          .from('long_term_goals')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final goals = (response as List)
          .map((j) => MacroGoal.fromJson(j))
          .toList();

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
    final newGoals = [...state.goals, goal];
    state = state.copyWith(goals: newGoals);

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      await ref.read(privateLocalDatabaseProvider).upsertMacroGoal(goal);
      return;
    }

    _saveToCache(newGoals);

    // 2. Invio al server
    final user = supabase.auth.currentUser;
    if (user == null) return;

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

    final newGoals = state.goals
        .map((g) => g.id == id ? g.copyWith(status: status) : g)
        .toList();
    state = state.copyWith(goals: newGoals);

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      final goal = newGoals.firstWhere((g) => g.id == id);
      await ref.read(privateLocalDatabaseProvider).upsertMacroGoal(goal);
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

    final newGoals = state.goals
        .map((g) => g.id == id ? g.copyWith(title: title) : g)
        .toList();
    state = state.copyWith(goals: newGoals);

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      final goal = newGoals.firstWhere((g) => g.id == id);
      await ref.read(privateLocalDatabaseProvider).upsertMacroGoal(goal);
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

    final newGoals = state.goals.map((g) {
      if (g.id != id) return g;
      return categoryId == null
          ? g.copyWith(clearCategory: true)
          : g.copyWith(categoryId: categoryId);
    }).toList();
    state = state.copyWith(goals: newGoals);

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      final goal = newGoals.firstWhere((g) => g.id == id);
      await ref.read(privateLocalDatabaseProvider).upsertMacroGoal(goal);
      return;
    }

    _saveToCache(newGoals);

    try {
      await supabase
          .from('long_term_goals')
          .update({'category_id': categoryId})
          .eq('id', id);
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Update category error', e, stack);
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

  Future<void> deleteGoal(String id) async {
    if (_shouldIgnoreMissingGoalMutation(id, 'delete')) return;

    final newGoals = state.goals.where((g) => g.id != id).toList();
    state = state.copyWith(goals: newGoals);

    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      await ref.read(privateLocalDatabaseProvider).deleteMacroGoal(id);
      return;
    }

    _saveToCache(newGoals);

    try {
      await supabase.from('long_term_goals').delete().eq('id', id);
    } catch (e, stack) {
      AppLogger.error('[MacroGoals] Delete error', e, stack);
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
        final maxW = weeksInMonth(nextY, nextM);
        if (nextW < maxW) {
          nextW++;
        } else {
          if (nextM < 12) {
            nextM++;
            nextW = 1;
          } else {
            nextY++;
            nextM = 1;
            nextW = 1;
          }
        }
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
      if (g.year != year) return false;
      if (type == GoalType.quarterly && g.quarter != quarter) return false;
      if (type == GoalType.monthly && g.month != month) return false;
      if (type == GoalType.weekly &&
          (g.month != month || g.weekNumber != weekNumber)) {
        return false;
      }
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
}

class MacroGoalsViewNotifier extends Notifier<MacroGoalsViewState> {
  @override
  MacroGoalsViewState build() {
    final now = DateTime.now();
    return MacroGoalsViewState(
      selectedType: GoalType.weekly,
      selectedYear: now.year,
      selectedQuarter: _quarter(now.month),
      selectedMonth: now.month,
      selectedWeek: logicalWeekOfMonth(now),
    );
  }

  void setType(GoalType t) => state = state.copyWith(selectedType: t);
  void setYear(int y) {
    state = state.copyWith(
      selectedYear: y,
      selectedWeek: _clampWeek(y, state.selectedMonth, state.selectedWeek),
    );
  }

  void setQuarter(int q) => state = state.copyWith(selectedQuarter: q);
  void setMonth(int m) =>
      state = state.copyWith(selectedMonth: m, selectedWeek: 1);
  void setWeek(int w) {
    state = state.copyWith(
      selectedWeek: _clampWeek(state.selectedYear, state.selectedMonth, w),
    );
  }

  int _quarter(int month) => ((month - 1) ~/ 3) + 1;

  int _clampWeek(int year, int month, int week) {
    return week.clamp(1, weeksInMonth(year, month));
  }

  void nextPeriod() {
    final s = state;
    final int y = s.selectedYear;
    final int q = s.selectedQuarter;
    final int m = s.selectedMonth;
    final int w = s.selectedWeek;

    switch (s.selectedType) {
      case GoalType.lifetime:
        break;
      case GoalType.annual:
        setYear(y + 1);
        break;
      case GoalType.quarterly:
        if (q < 4) {
          setQuarter(q + 1);
        } else {
          state = s.copyWith(selectedYear: y + 1, selectedQuarter: 1);
        }
        break;
      case GoalType.monthly:
        if (m < 12) {
          setMonth(m + 1);
        } else {
          state = s.copyWith(selectedYear: y + 1, selectedMonth: 1);
        }
        break;
      case GoalType.weekly:
        final maxW = weeksInMonth(y, m);
        if (w < maxW) {
          setWeek(w + 1);
        } else {
          if (m < 12) {
            state = s.copyWith(selectedMonth: m + 1, selectedWeek: 1);
          } else {
            state = s.copyWith(
              selectedYear: y + 1,
              selectedMonth: 1,
              selectedWeek: 1,
            );
          }
        }
        break;
    }
  }

  void prevPeriod() {
    final s = state;
    final int y = s.selectedYear;
    final int q = s.selectedQuarter;
    final int m = s.selectedMonth;
    final int w = s.selectedWeek;

    switch (s.selectedType) {
      case GoalType.lifetime:
        break;
      case GoalType.annual:
        setYear(y - 1);
        break;
      case GoalType.quarterly:
        if (q > 1) {
          setQuarter(q - 1);
        } else {
          state = s.copyWith(selectedYear: y - 1, selectedQuarter: 4);
        }
        break;
      case GoalType.monthly:
        if (m > 1) {
          setMonth(m - 1);
        } else {
          state = s.copyWith(selectedYear: y - 1, selectedMonth: 12);
        }
        break;
      case GoalType.weekly:
        if (w > 1) {
          setWeek(w - 1);
        } else {
          if (m > 1) {
            final prevMonth = m - 1;
            final maxW = weeksInMonth(y, prevMonth);
            state = s.copyWith(selectedMonth: prevMonth, selectedWeek: maxW);
          } else {
            final maxW = weeksInMonth(y - 1, 12);
            state = s.copyWith(
              selectedYear: y - 1,
              selectedMonth: 12,
              selectedWeek: maxW,
            );
          }
        }
        break;
    }
  }
}

final macroGoalsViewProvider =
    NotifierProvider<MacroGoalsViewNotifier, MacroGoalsViewState>(
      MacroGoalsViewNotifier.new,
    );

// ─── Helpers ─────────────────────────────────────────────────────────────────

int weeksInMonth(int year, int month) {
  return logicalWeeksInMonth(year, month);
}
