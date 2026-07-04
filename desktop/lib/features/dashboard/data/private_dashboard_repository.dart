import 'dart:convert';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

/// [DashboardRepository] backed by the local encrypted SQLite database.
///
/// All data is stored and read locally — no network calls are made.
class PrivateDashboardRepository extends DashboardRepository {
  PrivateDashboardRepository({required this.ownerId});

  final String ownerId;
  DashboardSnapshot _snapshot = DashboardSnapshot.empty;
  static const _uuid = Uuid();

  @override
  bool get isCloudBacked => false;

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<DashboardSnapshot> refresh() async {
    try {
      final db = await DesktopPrivateDb.instance.database;
      final habitRows =
          await db.query('goals', where: 'user_id = ?', whereArgs: [ownerId], orderBy: 'display_order ASC, created_at ASC');
      final logRows =
          await db.query('goal_logs', where: 'user_id = ?', whereArgs: [ownerId]);
      final goalRows =
          await db.query('long_term_goals', where: 'user_id = ?', whereArgs: [ownerId], orderBy: 'created_at ASC');
      final moodRows =
          await db.query('daily_moods', where: 'user_id = ?', whereArgs: [ownerId]);

      _snapshot = _buildSnapshot(
        habitRows: habitRows,
        logRows: logRows,
        goalRows: goalRows,
        moodRows: moodRows,
      );
      return _snapshot;
    } catch (error, stack) {
      AppLogger.error('Private dashboard refresh failed', error, stack);
      return _snapshot;
    }
  }

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<DashboardHabit> createHabit(DashboardHabit habit) async {
    final db = await DesktopPrivateDb.instance.database;
    final id = habit.id.isEmpty ? _uuid.v4() : habit.id;
    final frequencyDays = habit.frequencyDays != null
        ? jsonEncode(habit.frequencyDays)
        : null;
    await db.insert('goals', {
      'id': id,
      'user_id': ownerId,
      'title': habit.title,
      'description': habit.category,
      'icon': habit.icon,
      'color': dashboardColorToHex(habit.color),
      'frequency_days': frequencyDays,
      'start_date': habit.startDate?.toIso8601String(),
      'end_date': habit.endDate?.toIso8601String(),
      'display_order': habit.displayOrder,
      'reminder_time': habit.reminderTime,
      'is_active': habit.isActive ? 1 : 0,
    });
    return habit.copyWith(id: id);
  }

  @override
  Future<void> updateHabit(DashboardHabit habit) async {
    final db = await DesktopPrivateDb.instance.database;
    final frequencyDays = habit.frequencyDays != null
        ? jsonEncode(habit.frequencyDays)
        : null;
    await db.update(
      'goals',
      {
        'title': habit.title,
        'description': habit.category,
        'icon': habit.icon,
        'color': dashboardColorToHex(habit.color),
        'frequency_days': frequencyDays,
        'start_date': habit.startDate?.toIso8601String(),
        'end_date': habit.endDate?.toIso8601String(),
        'display_order': habit.displayOrder,
        'reminder_time': habit.reminderTime,
        'is_active': habit.isActive ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  @override
  Future<void> deleteHabit(String id) async {
    final db = await DesktopPrivateDb.instance.database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) async {
    final nextStatus = await super.setHabitStatus(
      habitId: habitId,
      date: date,
      currentStatus: currentStatus,
    );
    final db = await DesktopPrivateDb.instance.database;
    final dateKey = dashboardDateKey(date);

    if (nextStatus == null) {
      await db.delete(
        'goal_logs',
        where: 'goal_id = ? AND date = ?',
        whereArgs: [habitId, dateKey],
      );
      return null;
    }

    final streak = _computeNextStreak(habitId, date, nextStatus);
    await db.insert(
      'goal_logs',
      {
        'id': _uuid.v4(),
        'user_id': ownerId,
        'goal_id': habitId,
        'date': dateKey,
        'status': nextStatus,
        'streak': streak,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return nextStatus;
  }

  @override
  Future<void> saveCheckIn(DateTime date, DailyCheckIn checkIn) async {
    final db = await DesktopPrivateDb.instance.database;
    await db.insert(
      'daily_moods',
      {
        'id': _uuid.v4(),
        'user_id': ownerId,
        'date': dashboardDateKey(date),
        'mood_score': checkIn.mood,
        'energy_score': checkIn.energy,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<DashboardGoal> createGoal(DashboardGoal goal) async {
    final db = await DesktopPrivateDb.instance.database;
    final id = goal.id.isEmpty ? _uuid.v4() : goal.id;
    await db.insert('long_term_goals', {
      'id': id,
      'user_id': ownerId,
      'title': goal.title,
      'status': goal.state.name,
      'type': goal.type.name,
      'year': goal.year,
      'quarter': goal.quarter,
      'month': goal.month,
      'week_number': goal.weekNumber,
      'category_key': goal.category,
      'category_id': goal.categoryId,
      'created_at': (goal.createdAt ?? DateTime.now()).toIso8601String(),
    });
    return goal.copyWith(id: id);
  }

  @override
  Future<void> updateGoal(DashboardGoal goal) async {
    final db = await DesktopPrivateDb.instance.database;
    await db.update(
      'long_term_goals',
      {
        'title': goal.title,
        'status': goal.state.name,
        'type': goal.type.name,
        'year': goal.year,
        'quarter': goal.quarter,
        'month': goal.month,
        'week_number': goal.weekNumber,
        'category_key': goal.category,
        'category_id': goal.categoryId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  @override
  Future<void> deleteGoal(String id) async {
    final db = await DesktopPrivateDb.instance.database;
    await db.delete('long_term_goals', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> resetData() async {
    final db = await DesktopPrivateDb.instance.database;
    final batch = db.batch();
    batch.delete('goal_logs');
    batch.delete('goals');
    batch.delete('long_term_goals');
    batch.delete('daily_moods');
    batch.delete('macro_goal_categories');
    batch.delete('goal_category_settings');
    await batch.commit(noResult: true);
    _snapshot = DashboardSnapshot.empty;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  DashboardSnapshot _buildSnapshot({
    required List<Map<String, dynamic>> habitRows,
    required List<Map<String, dynamic>> logRows,
    required List<Map<String, dynamic>> goalRows,
    required List<Map<String, dynamic>> moodRows,
  }) {
    final logs = <String, Map<String, String>>{};
    for (final row in logRows) {
      final date = row['date'] as String;
      final goalId = row['goal_id'] as String;
      logs.putIfAbsent(date, () => {})[goalId] = row['status'] as String;
    }

    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    final habits = [
      for (final row in habitRows)
        _habitFromRow(row, logs, monday, now),
    ];

    final moods = <String, DailyCheckIn>{};
    for (final row in moodRows) {
      moods[row['date'] as String] = DailyCheckIn(
        mood: row['mood_score'] as int?,
        energy: row['energy_score'] as int?,
      );
    }

    final temporary = DashboardSnapshot(
      habits: habits,
      goals: goalRows.map(DashboardGoal.fromRemoteJson).toList(),
      trend: const [],
      checkIn: moods[dashboardDateKey(now)] ?? const DailyCheckIn(),
      habitLogs: logs,
      moods: moods,
    );

    return temporary.copyWith(
      trend: [
        for (var day = 0; day < 7; day++)
          TrendPoint(
            label: const ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'][day],
            value: temporary.completionFor(monday.add(Duration(days: day))),
          ),
      ],
    );
  }

  DashboardHabit _habitFromRow(
    Map<String, dynamic> row,
    Map<String, Map<String, String>> logs,
    DateTime monday,
    DateTime now,
  ) {
    final id = row['id'] as String;
    final frequencyDays = row['frequency_days'] != null
        ? (jsonDecode(row['frequency_days'] as String) as List)
              .cast<int>()
        : null;

    return DashboardHabit(
      id: id,
      title: row['title'] as String,
      category: row['description'] as String? ?? 'Generale',
      color: dashboardColorFromHex(row['color'] as String?),
      streak: _latestStreak(id, logs),
      weeklyProgress: [
        for (var day = 0; day < 7; day++)
          logs[dashboardDateKey(monday.add(Duration(days: day)))]?[id] == 'done',
      ],
      state: logs[dashboardDateKey(now)]?[id] == 'done'
          ? HabitState.completed
          : HabitState.pending,
      description: row['description'] as String?,
      icon: row['icon'] as String?,
      frequencyDays: frequencyDays,
      startDate: DateTime.tryParse(row['start_date'] as String? ?? ''),
      endDate: DateTime.tryParse(row['end_date'] as String? ?? ''),
      displayOrder: row['display_order'] as int?,
      reminderTime: row['reminder_time'] as String?,
      isActive: (row['is_active'] as int?) != 0,
    );
  }

  int _latestStreak(String habitId, Map<String, Map<String, String>> logs) {
    // Walk backward from today to find current streak.
    var streak = 0;
    var date = DateTime.now();
    for (var i = 0; i < 365; i++) {
      final key = dashboardDateKey(date);
      final status = logs[key]?[habitId];
      if (status == 'done') {
        streak++;
        date = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  int _computeNextStreak(String habitId, DateTime date, String nextStatus) {
    if (nextStatus != 'done') return 0;
    final previousDate = date.subtract(const Duration(days: 1));
    final previousKey = dashboardDateKey(previousDate);
    final previousStatus = _snapshot.habitLogs[previousKey]?[habitId];
    final currentStreak = _snapshot.habits
        .where((h) => h.id == habitId)
        .map((h) => h.streak)
        .firstOrNull ?? 0;
    return previousStatus == 'done' ? currentStreak + 1 : 1;
  }
}
