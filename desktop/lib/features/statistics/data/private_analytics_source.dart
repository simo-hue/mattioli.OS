import 'dart:convert';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The private-mode analytics inputs, loaded once from the encrypted DB and
/// shared by every local statistics provider.
class PrivateAnalyticsData {
  final List<HabitLogEntry> allLogs;
  final Map<String, List<HabitLogEntry>> logsByGoal;
  final Map<String, Map<String, String>>
  logsByDate; // dateKey -> goalId -> status
  final List<GoalInput> goals;
  final Map<String, DateTime> startDates; // goalId -> start_date
  final Map<String, String?> titles; // goalId -> title

  const PrivateAnalyticsData({
    required this.allLogs,
    required this.logsByGoal,
    required this.logsByDate,
    required this.goals,
    required this.startDates,
    required this.titles,
  });

  static const empty = PrivateAnalyticsData(
    allLogs: [],
    logsByGoal: {},
    logsByDate: {},
    goals: [],
    startDates: {},
    titles: {},
  );
}

/// Loads the private goal/log rows into the analytics input structures. Watches
/// [dashboardControllerProvider] so it refreshes whenever local data changes
/// (all private writes flow through the dashboard controller / repositories).
final privateAnalyticsDataProvider = FutureProvider<PrivateAnalyticsData>((
  ref,
) async {
  ref.watch(dashboardControllerProvider);
  try {
    final db = await DesktopPrivateDb.instance.database;
    final ownerId = await DesktopPrivateDb.instance.ownerId;
    final goalRows = await db.query(
      'goals',
      where: 'user_id = ?',
      whereArgs: [ownerId],
    );
    final logRows = await db.query(
      'goal_logs',
      where: 'user_id = ?',
      whereArgs: [ownerId],
      orderBy: 'date ASC',
    );

    final allLogs = <HabitLogEntry>[];
    final logsByGoal = <String, List<HabitLogEntry>>{};
    final logsByDate = <String, Map<String, String>>{};
    for (final r in logRows) {
      final parsed = DateTime.tryParse(r['date'] as String? ?? '');
      if (parsed == null) continue;
      final entry = HabitLogEntry(
        goalId: r['goal_id'] as String,
        date: parsed,
        status: r['status'] as String,
        streak: (r['streak'] as int?) ?? 0,
      );
      allLogs.add(entry);
      logsByGoal.putIfAbsent(entry.goalId, () => []).add(entry);
      logsByDate.putIfAbsent(dateKey(parsed), () => {})[entry.goalId] =
          entry.status;
    }

    final goals = <GoalInput>[];
    final startDates = <String, DateTime>{};
    final titles = <String, String?>{};
    for (final r in goalRows) {
      final id = r['id'] as String;
      final start =
          DateTime.tryParse(r['start_date'] as String? ?? '') ?? DateTime.now();
      final end = DateTime.tryParse(r['end_date'] as String? ?? '');
      final freqRaw = r['frequency_days'] as String?;
      List<int>? freq;
      if (freqRaw != null && freqRaw.isNotEmpty) {
        try {
          freq = (jsonDecode(freqRaw) as List).cast<int>();
        } catch (_) {
          freq = null;
        }
      }
      goals.add(
        GoalInput(id: id, startDate: start, endDate: end, frequencyDays: freq),
      );
      startDates[id] = start;
      titles[id] = r['title'] as String?;
    }

    return PrivateAnalyticsData(
      allLogs: allLogs,
      logsByGoal: logsByGoal,
      logsByDate: logsByDate,
      goals: goals,
      startDates: startDates,
      titles: titles,
    );
  } catch (error, stack) {
    AppLogger.error('Unable to load private analytics data', error, stack);
    return PrivateAnalyticsData.empty;
  }
});
