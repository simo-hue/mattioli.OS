import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/goal.dart';
import 'shared_prefs_provider.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

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
    } catch (e) {
      debugPrint('[Goals] Cache parsing error: $e');
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
    } catch (e) {
      debugPrint('[Goals] Sync error: $e');
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
    } catch (e) {
      debugPrint('[Goals] Insert error: $e');
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
    } catch (e) {
      debugPrint('[Goals] Update error: $e');
    }
  }

  Future<void> deleteHabit(String id) async {
    final newGoals = state.where((h) => h.id != id).toList();
    state = newGoals;
    _saveToCache(newGoals);

    try {
      await supabase.from('goals').delete().eq('id', id);
    } catch (e) {
      debugPrint('[Goals] Delete error: $e');
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
    } catch (e) {
      debugPrint('[Goals] Reorder error: $e');
    }
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
    } catch (e) {
      debugPrint('[HabitLogs] Cache parsing error: $e');
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
    } catch (e) {
      debugPrint('[HabitLogs] Sync error: $e');
    }
  }

  Future<void> cycleStatus(DateTime date, String habitId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return; // Solo se loggato, o potremmo forzare il login

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
        // Upsert log
        await supabase.from('goal_logs').upsert({
          'user_id': user.id,
          'goal_id': habitId,
          'date': dateKey,
          'status': nextStatus,
        }, onConflict: 'goal_id, date'); // Richiede il vincolo UNIQUE nel db
      } else {
        // Elimina log
        await supabase
            .from('goal_logs')
            .delete()
            .eq('goal_id', habitId)
            .eq('date', dateKey);
      }
    } catch (e) {
      debugPrint('[HabitLogs] cycleStatus error: $e');
    }
  }
}

final habitLogsProvider = NotifierProvider<HabitLogsNotifier, HabitLogsMap>(HabitLogsNotifier.new);

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
