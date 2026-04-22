import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/goal.dart';

// --- Goals provider (mock data, will be replaced with Supabase) ---
final goalsProvider = Provider<List<Goal>>((ref) {
  final now = DateTime.now();
  final startDate =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

  return [
    Goal(
      id: '1',
      title: 'Meditazione',
      description: '10 minuti',
      icon: 'heart',
      color: const Color(0xFF7C3AED), // purple
      isCompleted: true,
      startDate: startDate,
    ),
    Goal(
      id: '2',
      title: 'Lettura',
      description: '20 pagine',
      icon: 'book',
      color: const Color(0xFF3B82F6), // blue
      isCompleted: false,
      startDate: startDate,
    ),
    Goal(
      id: '3',
      title: 'Allenamento',
      description: '45 minuti',
      icon: 'dumbbell',
      color: const Color(0xFF10B981), // green
      isCompleted: false,
      startDate: startDate,
    ),
    Goal(
      id: '4',
      title: 'Diario',
      description: 'Riflessione quotidiana',
      icon: 'pencil',
      color: const Color(0xFFF59E0B), // amber
      isCompleted: true,
      startDate: startDate,
    ),
    Goal(
      id: '5',
      title: 'Camminata',
      description: '30 minuti',
      icon: 'footprints',
      color: const Color(0xFFEC4899), // pink
      isCompleted: false,
      startDate: startDate,
    ),
  ];
});

// --- Habit logs provider: Map<dateKey, Map<habitId, status>> ---
// status: 'done' | 'missed'
typedef HabitLogsMap = Map<String, Map<String, String>>;

final habitLogsProvider = StateProvider<HabitLogsMap>((ref) {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month;

  // Generate some mock data for the current month
  final logs = <String, Map<String, String>>{};

  // Helper
  String dateKey(int day) =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  // Mock completions for past days
  final mockData = {
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

  mockData.forEach((day, habits) {
    if (day <= now.day) {
      logs[dateKey(day)] = habits;
    }
  });

  return logs;
});

// --- View tab provider ---
enum CalendarView { month, week, year, vita }

final calendarViewProvider = StateProvider<CalendarView>(
  (_) => CalendarView.month,
);

// --- Privacy mode provider ---
final privacyModeProvider = StateProvider<bool>((_) => false);

// --- Toggle habit action ---
final toggleHabitProvider = Provider<Function(DateTime, String)>((ref) {
  return (DateTime date, String habitId) {
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    ref.read(habitLogsProvider.notifier).update((state) {
      final newState = Map<String, Map<String, String>>.from(state);
      final dayLogs = Map<String, String>.from(newState[dateKey] ?? {});

      if (dayLogs[habitId] == 'done') {
        dayLogs.remove(habitId);
      } else {
        dayLogs[habitId] = 'done';
      }

      newState[dateKey] = dayLogs;
      return newState;
    });
  };
});
