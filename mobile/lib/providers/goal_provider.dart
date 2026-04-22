import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/goal.dart';

// ─── Goals provider (mock data, future: Supabase) ───────────────────────────

class GoalsNotifier extends Notifier<List<Goal>> {
  @override
  List<Goal> build() {
    final now = DateTime.now();
    final startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

    return [
      Goal(
        id: '1',
        title: 'Meditazione',
        description: '10 minuti',
        icon: 'heart',
        color: const Color(0xFF7C3AED),
        isCompleted: true,
        startDate: startDate,
      ),
      Goal(
        id: '2',
        title: 'Lettura',
        description: '20 pagine',
        icon: 'book',
        color: const Color(0xFF3B82F6),
        isCompleted: false,
        startDate: startDate,
      ),
      Goal(
        id: '3',
        title: 'Allenamento',
        description: '45 minuti',
        icon: 'dumbbell',
        color: const Color(0xFF10B981),
        isCompleted: false,
        startDate: startDate,
      ),
      Goal(
        id: '4',
        title: 'Diario',
        description: 'Riflessione quotidiana',
        icon: 'pencil',
        color: const Color(0xFFF59E0B),
        isCompleted: true,
        startDate: startDate,
      ),
      Goal(
        id: '5',
        title: 'Camminata',
        description: '30 minuti',
        icon: 'footprints',
        color: const Color(0xFFEC4899),
        isCompleted: false,
        startDate: startDate,
      ),
    ];
  }

  void addHabit(Goal habit) {
    state = [...state, habit];
  }

  void updateHabit(Goal updatedHabit) {
    state = state.map((h) => h.id == updatedHabit.id ? updatedHabit : h).toList();
  }

  void deleteHabit(String id) {
    state = state.where((h) => h.id != id).toList();
  }

  void reorder(int oldIndex, int newIndex) {
    final list = List<Goal>.from(state);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
  }
}

final goalsProvider =
    NotifierProvider<GoalsNotifier, List<Goal>>(GoalsNotifier.new);

// ─── Habit logs: Map<dateKey, Map<habitId, status>> ─────────────────────────

typedef HabitLogsMap = Map<String, Map<String, String>>;

class HabitLogsNotifier extends Notifier<HabitLogsMap> {
  @override
  HabitLogsMap build() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    String dateKey(int day) =>
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    final mockData = <int, Map<String, String>>{
      1: {'1': 'done', '2': 'done', '3': 'missed', '4': 'done'},
      2: {'1': 'done', '2': 'missed', '4': 'done', '5': 'done'},
      3: {'1': 'done', '3': 'done'},
      4: {'2': 'done', '4': 'done', '5': 'missed'},
      5: {'1': 'done', '2': 'done', '3': 'done', '4': 'done', '5': 'done'},
      6: {'1': 'missed', '3': 'done', '4': 'done'},
      7: {'1': 'done', '2': 'done', '3': 'done', '4': 'missed', '5': 'done'},
      8: {'1': 'done', '2': 'done', '3': 'done', '4': 'done', '5': 'done'},
      9: {'1': 'done', '2': 'missed', '3': 'done', '5': 'done'},
      10: {'2': 'done', '3': 'done', '4': 'done'},
      11: {'1': 'done', '3': 'done', '4': 'done', '5': 'done'},
      12: {'1': 'done', '2': 'done', '3': 'done', '4': 'done'},
      13: {'1': 'done', '2': 'done', '3': 'done', '4': 'done', '5': 'done'},
      14: {'1': 'done', '2': 'done', '3': 'done', '4': 'missed', '5': 'done'},
      15: {'1': 'done', '2': 'done', '3': 'done', '4': 'done', '5': 'done'},
      16: {'1': 'done', '2': 'done', '3': 'done', '4': 'done', '5': 'done'},
      17: {'1': 'done', '2': 'missed', '3': 'done', '4': 'done'},
      18: {'1': 'done', '3': 'done', '4': 'done', '5': 'done'},
      19: {'1': 'done', '2': 'done', '3': 'missed', '4': 'done', '5': 'done'},
      20: {'1': 'done', '2': 'done', '3': 'done', '4': 'done', '5': 'done'},
      21: {'1': 'done', '2': 'done', '3': 'done', '4': 'done'},
    };

    final logs = <String, Map<String, String>>{};
    mockData.forEach((day, habits) {
      if (day <= now.day) {
        logs[dateKey(day)] = habits;
      }
    });
    return logs;
  }

  void cycleStatus(DateTime date, String habitId) {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final newState = Map<String, Map<String, String>>.from(state);
    final dayLogs = Map<String, String>.from(newState[dateKey] ?? {});

    final currentStatus = dayLogs[habitId];
    if (currentStatus == null) {
      dayLogs[habitId] = 'done';
    } else if (currentStatus == 'done') {
      dayLogs[habitId] = 'missed';
    } else {
      dayLogs.remove(habitId);
    }

    newState[dateKey] = dayLogs;
    state = newState;
  }
}

final habitLogsProvider =
    NotifierProvider<HabitLogsNotifier, HabitLogsMap>(HabitLogsNotifier.new);

// ─── Calendar view enum & provider ───────────────────────────────────────────

enum CalendarView { month, week, year, vita }

class CalendarViewNotifier extends Notifier<CalendarView> {
  @override
  CalendarView build() => CalendarView.month;
  void setView(CalendarView v) => state = v;
}

final calendarViewProvider =
    NotifierProvider<CalendarViewNotifier, CalendarView>(
        CalendarViewNotifier.new);

// ─── Privacy mode provider ────────────────────────────────────────────────────

class PrivacyModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool v) => state = v;
}

final privacyModeProvider =
    NotifierProvider<PrivacyModeNotifier, bool>(PrivacyModeNotifier.new);
