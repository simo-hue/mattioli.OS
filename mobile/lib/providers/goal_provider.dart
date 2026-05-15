import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/goal.dart';
import 'shared_prefs_provider.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import '../core/notifications.dart';
import '../core/navigator_key.dart';
import '../core/app_logger.dart';
import '../ui/widgets/error_modal.dart';

// ─── Goals Provider (Offline-First) ─────────────────────────────────────────

class GoalsNotifier extends Notifier<List<Goal>> {
  static const String _cacheKey = 'goals_cache';

  @override
  List<Goal> build() {
    final initialState = _loadFromCache();

    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        _syncFromSupabase();
      } else if (!next.isLoggedIn) {
        state = [];
        _saveToCache([]);
      }
    });

    final authState = ref.read(authProvider);
    if (authState.isLoggedIn && authState.user != null) {
      _syncFromSupabase();
    }

    return initialState;
  }

  List<Goal> _loadFromCache() {
    final prefs = ref.read(sharedPrefsProvider);
    final cache = prefs.getString(_cacheKey);
    if (cache == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(cache);
      return jsonList.map((j) => Goal.fromJson(j)).toList();
    } catch (e, stack) {
      AppLogger.error('[Goals] Cache parsing error', e, stack);
      return [];
    }
  }

  void _saveToCache(List<Goal> goals) {
    final prefs = ref.read(sharedPrefsProvider);
    final jsonList = goals.map((g) => g.toJson()).toList();
    prefs.setString(_cacheKey, jsonEncode(jsonList));
  }

  Future<void> _syncFromSupabase() async {
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
      _saveToCache(goals);
    } catch (e, stack) {
      AppLogger.error('[Goals] Sync error', e, stack);
    }
  }

  Future<void> addHabit(Goal habit) async {
    final newGoals = [...state, habit];
    state = newGoals;
    _saveToCache(newGoals);

    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final payload = habit.toJson();
      payload['user_id'] = user.id;
      payload.remove('id'); 
      
      final result = await supabase.from('goals').insert(payload).select().single();
      final realGoal = Goal.fromJson(result);
      
      final updatedGoals = state.map((g) => g.id == habit.id ? realGoal : g).toList();
      state = updatedGoals;
      _saveToCache(updatedGoals);

      // Schedula promemoria se presente
      if (realGoal.reminderTime != null) {
        NotificationService().scheduleHabitReminder(realGoal.id, realGoal.title, realGoal.reminderTime);
      }
    } catch (e, stack) {
      AppLogger.error('[Goals] Insert error', e, stack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: 'Errore durante il salvataggio',
          message: 'Non siamo riusciti a salvare l\'abitudine. Riprova.',
          details: e.toString(),
        );
      }
    }
  }

  Future<void> updateHabit(Goal updatedHabit) async {
    final newGoals = state.map((h) => h.id == updatedHabit.id ? updatedHabit : h).toList();
    state = newGoals;
    _saveToCache(newGoals);

    try {
      final payload = updatedHabit.toJson();
      payload.remove('id');
      await supabase.from('goals').update(payload).eq('id', updatedHabit.id);

      // Schedula promemoria
      NotificationService().cancelHabitReminder(updatedHabit.id);
      if (updatedHabit.reminderTime != null) {
        NotificationService().scheduleHabitReminder(updatedHabit.id, updatedHabit.title, updatedHabit.reminderTime);
      }
    } catch (e, stack) {
      AppLogger.error('[Goals] Update error', e, stack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: 'Errore durante l\'aggiornamento',
          message: 'Non siamo riusciti a salvare le modifiche. Riprova.',
          details: e.toString(),
        );
      }
    }
  }

  Future<void> deleteHabit(String id) async {
    final newGoals = state.where((h) => h.id != id).toList();
    state = newGoals;
    _saveToCache(newGoals);

    try {
      await supabase.from('goals').delete().eq('id', id);
      // Cancella promemoria
      NotificationService().cancelHabitReminder(id);
    } catch (e, stack) {
      AppLogger.error('[Goals] Delete error', e, stack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: 'Errore durante l\'eliminazione',
          message: 'Non siamo riusciti a eliminare l\'abitudine. Riprova.',
          details: e.toString(),
        );
      }
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = List<Goal>.from(state);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // Aggiorna gli order localmente
    for (int i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(displayOrder: i);
    }
    
    state = list;
    _saveToCache(list);

    // Sync massivo degli order su Supabase
    try {
      final updates = list.map((g) => {'id': g.id, 'display_order': g.displayOrder}).toList();
      await supabase.from('goals').upsert(updates);
    } catch (e, stack) {
      AppLogger.error('[Goals] Reorder error', e, stack);
    }
  }

  void clearAll() {
    state = [];
    _saveToCache([]);
  }
}

final goalsProvider = NotifierProvider<GoalsNotifier, List<Goal>>(GoalsNotifier.new);

// ─── Habit Logs Provider (Offline-First) ────────────────────────────────────

typedef HabitLogsMap = Map<String, Map<String, String>>;

class HabitLogsNotifier extends Notifier<HabitLogsMap> {
  static const String _cacheKey = 'goal_logs_cache';

  @override
  HabitLogsMap build() {
    final initialState = _loadFromCache();

    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        _syncFromSupabase();
      } else if (!next.isLoggedIn) {
        state = {};
        _saveToCache({});
      }
    });

    final authState = ref.read(authProvider);
    if (authState.isLoggedIn && authState.user != null) {
      _syncFromSupabase();
    }

    return initialState;
  }

  HabitLogsMap _loadFromCache() {
    final prefs = ref.read(sharedPrefsProvider);
    final cache = prefs.getString(_cacheKey);
    if (cache == null) return {};

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
    final prefs = ref.read(sharedPrefsProvider);
    prefs.setString(_cacheKey, jsonEncode(logs));
  }

  Future<void> _syncFromSupabase() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Per ottimizzare, potremmo scaricare solo gli ultimi X giorni, 
      // ma per ora sincronizziamo tutto per la heatmap.
      final response = await supabase
          .from('goal_logs')
          .select('id, goal_id, date, status')
          .eq('user_id', user.id);

      final HabitLogsMap newLogs = {};
      
      for (final row in response) {
        final date = row['date'] as String; // YYYY-MM-DD
        final goalId = row['goal_id'] as String;
        final status = row['status'] as String;
        
        if (!newLogs.containsKey(date)) {
          newLogs[date] = {};
        }
        newLogs[date]![goalId] = status;
      }

      state = newLogs;
      _saveToCache(newLogs);
    } catch (e, stack) {
      AppLogger.error('[HabitLogs] Sync error', e, stack);
    }
  }

  Future<void> cycleStatus(DateTime date, String habitId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
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

    // Get previous streak
    int prevStreak = 0;
    try {
      final lastLogResponse = await supabase
          .from('goal_logs')
          .select('streak, date')
          .eq('goal_id', habitId)
          .eq('user_id', user.id)
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastLogResponse != null) {
        final lastDateStr = lastLogResponse['date'] as String;
        final lastStreak = lastLogResponse['streak'] as int? ?? 0;
        
        final lastDate = DateTime.parse(lastDateStr);
        final diffDays = date.difference(lastDate).inDays;

        if (diffDays == 1) {
          prevStreak = lastStreak;
        } else {
          // Non consecutivo. Per ora azzeriamo lo streak se non è il giorno dopo.
          // Si potrebbe affinare controllando la frequenza dell'abitudine.
          prevStreak = 0;
        }
      }
    } catch (e, stack) {
      AppLogger.error('[HabitLogs] Error getting previous streak', e, stack);
    }

    int newStreak = 0;
    if (nextStatus == 'done') {
      newStreak = prevStreak >= 0 ? prevStreak + 1 : 1;
    } else if (nextStatus == 'missed') {
      newStreak = prevStreak > 0 ? -1 : prevStreak - 1;
    }

    if (nextStatus != null) {
      dayLogs[habitId] = nextStatus;
    } else {
      dayLogs.remove(habitId);
    }

    newState[dateKey] = dayLogs;
    state = newState;
    _saveToCache(newState);

    // Sync con Supabase
    try {
      if (nextStatus != null) {
        await supabase.from('goal_logs').upsert({
          'user_id': user.id,
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
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: 'Errore durante l\'aggiornamento dello stato',
          message: 'Non siamo riusciti a salvare lo stato dell\'abitudine. Riprova.',
          details: e.toString(),
        );
      }
    }
  }

  void clearAll() {
    state = {};
    _saveToCache({});
  }
}

final habitLogsProvider = NotifierProvider<HabitLogsNotifier, HabitLogsMap>(HabitLogsNotifier.new);

final habitStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  
  final response = await Supabase.instance.client
      .from('habit_stats')
      .select('*')
      .eq('user_id', user.id);
      
  return List<Map<String, dynamic>>.from(response);
});

final habitAnalyticsProvider = FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  ref.keepAlive();
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return {};
  
  final response = await Supabase.instance.client
      .rpc('get_habit_analytics', params: {'p_user_id': user.id});
      
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
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return 'N/A';
  
  try {
    final response = await Supabase.instance.client
        .rpc('get_global_critical_day', params: {'p_user_id': user.id});
        
    return response as String;
  } catch (e) {
    return 'N/A';
  }
});

final globalTrendProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, timeframe) async {
  ref.keepAlive();
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  
  final response = await Supabase.instance.client
      .rpc('get_global_trend', params: {
        'p_user_id': user.id,
        'p_timeframe': timeframe,
      });
      
  return List<Map<String, dynamic>>.from(response);
});

final criticalHabitsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.keepAlive();
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  
  final response = await Supabase.instance.client
      .rpc('get_critical_habits', params: {
        'p_user_id': user.id,
      });
      
  return List<Map<String, dynamic>>.from(response);
});

final bestHabitsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, timeframe) async {
  ref.keepAlive();
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  
  final response = await Supabase.instance.client
      .rpc('get_best_habits', params: {
        'p_user_id': user.id,
        'p_timeframe': timeframe,
      });
      
  return List<Map<String, dynamic>>.from(response);
});

final habitPerformanceProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, goalId) async {
  ref.keepAlive();
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  
  final response = await Supabase.instance.client
      .rpc('get_habit_performance_by_day', params: {
        'p_user_id': user.id,
        'p_goal_id': goalId,
      });
      
  return List<Map<String, dynamic>>.from(response);
});

final habitAlertsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, goalId) async {
  ref.keepAlive();
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return {};
  
  final response = await Supabase.instance.client
      .rpc('get_habit_alerts', params: {
        'p_user_id': user.id,
        'p_goal_id': goalId,
      });
      
  if (response is List && response.isNotEmpty) {
    return Map<String, dynamic>.from(response.first);
  }
  return {};
});

final habitYearlyGridProvider = FutureProvider.family<List<int>, String>((ref, goalId) async {
  ref.keepAlive();
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  
  final response = await Supabase.instance.client
      .rpc('get_habit_yearly_grid', params: {
        'p_user_id': user.id,
        'p_goal_id': goalId,
      });
      
  if (response is List) {
    return response.map((r) => (r['status_code'] as num).toInt()).toList();
  }
  return [];
});

final habitCorrelationsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, goalId) async {
  ref.keepAlive();
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  
  final response = await Supabase.instance.client
      .rpc('get_habit_correlations', params: {
        'p_user_id': user.id,
        'p_target_goal_id': goalId,
      });
      
  return List<Map<String, dynamic>>.from(response);
});

final allHabitCorrelationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.keepAlive();
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  
  try {
    final response = await Supabase.instance.client
        .rpc('get_all_habit_correlations', params: {'p_user_id': user.id});
        
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    return [];
  }
});

// ─── Calendar view enum & provider ───────────────────────────────────────────

enum CalendarView { month, week, year, vita }

class CalendarViewNotifier extends Notifier<CalendarView> {
  @override
  CalendarView build() {
    final defaultViewStr = ref.watch(settingsProvider.select((s) => s.defaultCalendarView));
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

final calendarViewProvider = NotifierProvider<CalendarViewNotifier, CalendarView>(CalendarViewNotifier.new);

// ─── Privacy mode provider ────────────────────────────────────────────────────

class PrivacyModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool v) => state = v;
}

final privacyModeProvider = NotifierProvider<PrivacyModeNotifier, bool>(PrivacyModeNotifier.new);
