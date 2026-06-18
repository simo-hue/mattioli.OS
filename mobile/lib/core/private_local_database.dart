import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/goal.dart';
import '../models/macro_goal.dart';
import '../models/daily_mood.dart';
import 'app_logger.dart';
import 'secure_storage_utils.dart';

final privateLocalDatabaseProvider = Provider<PrivateLocalDatabase>((ref) {
  return PrivateLocalDatabase();
});

class PrivateLocalDatabase {
  PrivateLocalDatabase._();

  static final PrivateLocalDatabase _instance = PrivateLocalDatabase._();

  factory PrivateLocalDatabase() => _instance;

  static const _dbName = 'private_mode_v1.db';
  static const _dbPasswordKey = 'private_mode_db_password_v1';
  static const _ownerIdKey = 'private_mode_owner_id_v1';

  final _uuid = const Uuid();
  static const _platform = MethodChannel('evolve/private_storage');
  Database? _db;
  Future<Database>? _opening;
  String? _ownerId;

  Future<String> ownerId() async {
    final existing = _ownerId ?? await SecureStorageUtils.read(_ownerIdKey);
    if (existing != null && existing.isNotEmpty) {
      _ownerId = existing;
      return existing;
    }

    final id = _uuid.v4();
    await SecureStorageUtils.write(
      _ownerIdKey,
      id,
      context: '[PrivateDB] owner id',
    );
    _ownerId = id;
    return id;
  }

  Future<void> ensureReady() async {
    final db = await _database();
    await _ensureProfile(db);
  }

  Future<Database> _database() {
    final opened = _db;
    if (opened != null) return Future.value(opened);

    final inFlight = _opening;
    if (inFlight != null) return inFlight;

    final future = _open().whenComplete(() {
      _opening = null;
    });
    _opening = future;
    return future;
  }

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final dbPath = p.join(dir.path, _dbName);
    await _excludeFromBackup(File(dbPath));

    final password = await _databasePassword();
    final db = await openDatabase(
      dbPath,
      password: password,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
    );
    _db = db;
    await _ensureProfile(db);
    return db;
  }

  Future<String> _databasePassword() async {
    final existing = await SecureStorageUtils.read(_dbPasswordKey);
    if (existing != null && existing.length >= 32) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(48, (_) => random.nextInt(256));
    final password = base64UrlEncode(bytes);
    await SecureStorageUtils.write(
      _dbPasswordKey,
      password,
      context: '[PrivateDB] password',
    );
    return password;
  }

  Future<void> _excludeFromBackup(File file) async {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    try {
      final directory = file.parent;
      await directory.create(recursive: true);
      await _platform.invokeMethod<void>('excludeFromBackup', {
        'path': directory.path,
      });
      final marker = File(p.join(directory.path, '.private_mode_local_only'));
      if (!await marker.exists()) {
        await marker.writeAsString(
          'Private mode database. Exclude this directory from device backups.',
        );
      }
    } catch (e, stack) {
      AppLogger.warning('[PrivateDB] backup exclusion marker failed', e, stack);
    }
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
CREATE TABLE profiles (
  id TEXT PRIMARY KEY,
  username TEXT,
  full_name TEXT,
  avatar_url TEXT,
  language TEXT NOT NULL DEFAULT 'it',
  theme_mode TEXT NOT NULL DEFAULT 'dark'
    CHECK (theme_mode IN ('dark', 'light', 'system')),
  accent_color TEXT NOT NULL DEFAULT '#FFFFFF',
  pref_glass_effects INTEGER NOT NULL DEFAULT 1,
  pref_default_calendar_view TEXT NOT NULL DEFAULT 'settimana',
  pref_start_week_on_monday INTEGER NOT NULL DEFAULT 1,
  pref_show_weekend INTEGER NOT NULL DEFAULT 1,
  pref_haptic_feedback INTEGER NOT NULL DEFAULT 1,
  pref_time_format_24h INTEGER NOT NULL DEFAULT 1,
  pref_ai_suggestions INTEGER NOT NULL DEFAULT 0,
  pref_focus_mode INTEGER NOT NULL DEFAULT 0,
  pref_milestones INTEGER NOT NULL DEFAULT 1,
  pref_deep_work_insights INTEGER NOT NULL DEFAULT 0,
  is_pro INTEGER NOT NULL DEFAULT 1,
  pro_expires_at TEXT,
  notif_habit_reminders INTEGER NOT NULL DEFAULT 1,
  notif_goal_deadlines INTEGER NOT NULL DEFAULT 1,
  notif_ai_insights INTEGER NOT NULL DEFAULT 0,
  notif_weekly_reports INTEGER NOT NULL DEFAULT 0,
  notif_evening_review INTEGER NOT NULL DEFAULT 1,
  biometric_lock INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  date_of_birth TEXT,
  morning_brief_time TEXT DEFAULT '09:00',
  evening_review_time TEXT DEFAULT '21:00',
  terms_accepted_at TEXT,
  sentry_consent INTEGER NOT NULL DEFAULT 0,
  private_ai_external_consent INTEGER NOT NULL DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE goals (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  color TEXT NOT NULL,
  icon TEXT,
  frequency_days TEXT,
  start_date TEXT NOT NULL,
  end_date TEXT,
  display_order INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  reminder_time TEXT
)
''');

    await db.execute('''
CREATE TABLE goal_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('done', 'missed', 'skipped')),
  value REAL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  streak INTEGER DEFAULT 0,
  UNIQUE(goal_id, date)
)
''');

    await db.execute('''
CREATE TABLE long_term_goals (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'completed', 'failed')),
  type TEXT NOT NULL
    CHECK (type IN ('lifetime', 'annual', 'quarterly', 'monthly', 'weekly')),
  year INTEGER,
  month INTEGER CHECK (month >= 1 AND month <= 12),
  week_number INTEGER CHECK (week_number >= 1 AND week_number <= 6),
  quarter INTEGER CHECK (quarter >= 1 AND quarter <= 4),
  color TEXT,
  category_key TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  category_id TEXT REFERENCES macro_goal_categories(id) ON DELETE SET NULL
)
''');

    await db.execute('''
CREATE TABLE daily_moods (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  mood_score INTEGER NOT NULL CHECK (mood_score >= 0 AND mood_score <= 10),
  energy_score INTEGER NOT NULL CHECK (energy_score >= 0 AND energy_score <= 10),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(user_id, date)
)
''');

    await db.execute('''
CREATE TABLE goal_category_settings (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  mappings TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE macro_goal_categories (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  created_at TEXT NOT NULL,
  archived_at TEXT,
  UNIQUE(user_id, name)
)
''');

    await db.execute(
      'CREATE INDEX idx_goals_user_order ON goals (user_id, display_order)',
    );
    await db.execute(
      'CREATE INDEX idx_goal_logs_user_date ON goal_logs (user_id, date DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_ltg_user_type_year ON long_term_goals (user_id, type, year)',
    );
    await db.execute(
      'CREATE INDEX idx_ltg_user_status ON long_term_goals (user_id, status)',
    );
    await db.execute(
      'CREATE INDEX idx_moods_user_date ON daily_moods (user_id, date DESC)',
    );
    await db.execute(
      'CREATE INDEX macro_goal_categories_active_idx ON macro_goal_categories (user_id, created_at) WHERE archived_at IS NULL',
    );
  }

  Future<void> _ensureProfile(Database db) async {
    final id = await ownerId();
    final now = _now();
    await db.insert('profiles', {
      'id': id,
      'language': 'system',
      'theme_mode': 'dark',
      'accent_color': '#FFFFFF',
      'pref_default_calendar_view': 'settimana',
      'is_pro': 1,
      'created_at': now,
      'updated_at': now,
      'sentry_consent': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('goal_category_settings', {
      'id': _uuid.v4(),
      'user_id': id,
      'mappings': '{}',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Goal>> loadGoals() async {
    final db = await _database();
    final owner = await ownerId();
    final rows = await db.query(
      'goals',
      where: 'user_id = ?',
      whereArgs: [owner],
      orderBy: 'display_order ASC, created_at ASC',
    );
    return rows.map(_goalFromRow).toList();
  }

  Future<void> upsertGoal(Goal goal) async {
    final db = await _database();
    final owner = await ownerId();
    final now = _now();
    final existing = await db.query(
      'goals',
      columns: ['created_at'],
      where: 'id = ?',
      whereArgs: [goal.id],
      limit: 1,
    );
    await db.insert('goals', {
      ..._goalToRow(goal),
      'user_id': owner,
      'created_at': existing.isNotEmpty
          ? existing.first['created_at'] as String
          : now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteGoal(String id) async {
    final db = await _database();
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, Map<String, String>>> loadHabitLogs() async {
    final db = await _database();
    final owner = await ownerId();
    final rows = await db.query(
      'goal_logs',
      where: 'user_id = ?',
      whereArgs: [owner],
    );
    final result = <String, Map<String, String>>{};
    for (final row in rows) {
      final date = row['date'] as String;
      final goalId = row['goal_id'] as String;
      final status = row['status'] as String;
      result.putIfAbsent(date, () => <String, String>{})[goalId] = status;
    }
    return result;
  }

  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int streak = 0,
  }) async {
    final db = await _database();
    final owner = await ownerId();
    final now = _now();
    final existing = await db.query(
      'goal_logs',
      columns: ['id', 'created_at'],
      where: 'goal_id = ? AND date = ?',
      whereArgs: [goalId, date],
      limit: 1,
    );
    await db.insert('goal_logs', {
      'id': existing.isNotEmpty ? existing.first['id'] : _uuid.v4(),
      'user_id': owner,
      'goal_id': goalId,
      'date': date,
      'status': status,
      'created_at': existing.isNotEmpty
          ? existing.first['created_at'] as String
          : now,
      'updated_at': now,
      'streak': streak,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteHabitLog({
    required String goalId,
    required String date,
  }) async {
    final db = await _database();
    await db.delete(
      'goal_logs',
      where: 'goal_id = ? AND date = ?',
      whereArgs: [goalId, date],
    );
  }

  Future<List<MacroGoal>> loadMacroGoals() async {
    final db = await _database();
    final owner = await ownerId();
    final rows = await db.query(
      'long_term_goals',
      where: 'user_id = ?',
      whereArgs: [owner],
      orderBy: 'created_at ASC',
    );
    return rows.map(_macroGoalFromRow).toList();
  }

  Future<void> upsertMacroGoal(MacroGoal goal) async {
    final db = await _database();
    final owner = await ownerId();
    final now = _now();
    final existing = await db.query(
      'long_term_goals',
      columns: ['created_at'],
      where: 'id = ?',
      whereArgs: [goal.id],
      limit: 1,
    );
    await db.insert('long_term_goals', {
      'id': goal.id,
      'user_id': owner,
      'title': goal.title,
      'status': goal.status.name,
      'type': goal.type.name,
      'year': goal.year,
      'month': goal.month,
      'week_number': goal.weekNumber,
      'quarter': goal.quarter,
      'category_key': goal.categoryKey,
      'category_id': goal.categoryId,
      'created_at': existing.isNotEmpty
          ? existing.first['created_at'] as String
          : goal.createdAt.toIso8601String(),
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMacroGoal(String id) async {
    final db = await _database();
    await db.delete('long_term_goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<GoalCategory>> loadMacroGoalCategories({
    bool includeArchived = false,
  }) async {
    final db = await _database();
    final owner = await ownerId();
    final rows = await db.query(
      'macro_goal_categories',
      where: includeArchived
          ? 'user_id = ?'
          : 'user_id = ? AND archived_at IS NULL',
      whereArgs: [owner],
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => GoalCategory.fromJson(row)).toList();
  }

  Future<String> addMacroGoalCategory(String name, String colorHex) async {
    final db = await _database();
    final owner = await ownerId();
    final now = _now();
    final id = _uuid.v4();
    await db.insert('macro_goal_categories', {
      'id': id,
      'user_id': owner,
      'name': name,
      'color': colorHex,
      'created_at': now,
    });
    return id;
  }

  Future<void> updateMacroGoalCategory(
    String id,
    String name,
    String colorHex,
  ) async {
    final db = await _database();
    await db.update(
      'macro_goal_categories',
      {'name': name, 'color': colorHex},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> archiveMacroGoalCategory(String id) async {
    final db = await _database();
    await db.update(
      'macro_goal_categories',
      {'archived_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, DailyMood>> loadDailyMoods() async {
    final db = await _database();
    final owner = await ownerId();
    final rows = await db.query(
      'daily_moods',
      where: 'user_id = ?',
      whereArgs: [owner],
    );
    return {
      for (final row in rows) row['date'] as String: _dailyMoodFromRow(row),
    };
  }

  Future<DailyMood> saveMood(DateTime date, int mood, int energy) async {
    final db = await _database();
    final owner = await ownerId();
    final dateKey = _dateKey(date);
    final now = _now();
    final existing = await db.query(
      'daily_moods',
      columns: ['id', 'created_at'],
      where: 'user_id = ? AND date = ?',
      whereArgs: [owner, dateKey],
      limit: 1,
    );
    final row = {
      'id': existing.isNotEmpty ? existing.first['id'] : _uuid.v4(),
      'user_id': owner,
      'date': dateKey,
      'mood_score': mood,
      'energy_score': energy,
      'created_at': existing.isNotEmpty
          ? existing.first['created_at'] as String
          : now,
      'updated_at': now,
    };
    await db.insert(
      'daily_moods',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return _dailyMoodFromRow(row);
  }

  Future<Map<String, dynamic>> loadProfileRow() async {
    final db = await _database();
    final owner = await ownerId();
    final rows = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [owner],
      limit: 1,
    );
    if (rows.isEmpty) {
      await _ensureProfile(db);
      return loadProfileRow();
    }
    return rows.first;
  }

  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? dateOfBirth,
    bool clearDateOfBirth = false,
  }) async {
    final db = await _database();
    final owner = await ownerId();
    final values = <String, Object?>{'updated_at': _now()};
    if (fullName != null) values['full_name'] = fullName;
    if (avatarUrl != null) values['avatar_url'] = avatarUrl;
    if (dateOfBirth != null || clearDateOfBirth) {
      values['date_of_birth'] = clearDateOfBirth ? null : dateOfBirth;
    }
    await db.update('profiles', values, where: 'id = ?', whereArgs: [owner]);
  }

  Future<Map<String, dynamic>> loadSettingsRow() => loadProfileRow();

  Future<void> updateSettingsRow(Map<String, Object?> values) async {
    final db = await _database();
    final owner = await ownerId();
    await db.update(
      'profiles',
      {...values, 'updated_at': _now(), 'is_pro': 1, 'sentry_consent': 0},
      where: 'id = ?',
      whereArgs: [owner],
    );
  }

  Future<bool> hasPrivateAiExternalConsent() async {
    final row = await loadProfileRow();
    return row['private_ai_external_consent'] == 1;
  }

  Future<void> setPrivateAiExternalConsent(bool value) async {
    await updateSettingsRow({'private_ai_external_consent': value ? 1 : 0});
  }

  Future<Map<String, dynamic>> exportData() async {
    return {
      'exportDate': DateTime.now().toIso8601String(),
      'mode': 'private',
      'profile': await loadProfileRow(),
      'settings': await loadSettingsRow(),
      'habits': (await loadGoals()).map((g) => g.toJson()).toList(),
      'habitLogs': await loadHabitLogs(),
      'macroGoals': (await loadMacroGoals()).map((g) => g.toJson()).toList(),
      'macroGoalCategories':
          (await loadMacroGoalCategories(includeArchived: true))
              .map(
                (c) => {
                  'id': c.key,
                  'name': c.label,
                  'color': _colorToHex(c.color),
                  if (c.archivedAt != null)
                    'archived_at': c.archivedAt!.toIso8601String(),
                },
              )
              .toList(),
      'dailyMoods': (await loadDailyMoods()).map(
        (key, value) => MapEntry(key, {
          'id': value.id,
          'user_id': value.userId,
          'date': value.date,
          'mood_score': value.moodScore,
          'energy_score': value.energyScore,
        }),
      ),
    };
  }

  Future<void> deleteAllPrivateData() async {
    final db = await _database();
    final profileRow = await loadProfileRow();
    await db.transaction((txn) async {
      await txn.delete('goal_logs');
      await txn.delete('daily_moods');
      await txn.delete('long_term_goals');
      await txn.delete('macro_goal_categories');
      await txn.delete('goals');
      await txn.delete('goal_category_settings');
      await txn.delete('profiles');
    });
    await _deletePrivateProfileFiles(profileRow['avatar_url'] as String?);
    await _ensureProfile(db);
  }

  Future<void> _deletePrivateProfileFiles(String? avatarPath) async {
    try {
      if (avatarPath != null && avatarPath.isNotEmpty) {
        final avatarFile = File(avatarPath);
        if (await avatarFile.exists()) {
          await avatarFile.delete();
        }
      }

      final dir = await getApplicationSupportDirectory();
      final profileDir = Directory(p.join(dir.path, 'private_profile'));
      if (await profileDir.exists()) {
        await profileDir.delete(recursive: true);
      }
    } catch (e, stack) {
      AppLogger.warning(
        '[PrivateDB] private profile file cleanup failed',
        e,
        stack,
      );
    }
  }

  Future<List<Map<String, dynamic>>> habitStats() async {
    final db = await _database();
    final owner = await ownerId();
    final rows = await db.rawQuery(
      '''
SELECT
  g.id AS goal_id,
  COUNT(l.id) AS total,
  SUM(CASE WHEN l.status = 'done' THEN 1 ELSE 0 END) AS done,
  SUM(CASE WHEN l.status = 'missed' THEN 1 ELSE 0 END) AS missed,
  MAX(COALESCE(l.streak, 0)) AS streak
FROM goals g
LEFT JOIN goal_logs l ON l.goal_id = g.id
WHERE g.user_id = ?
GROUP BY g.id
''',
      [owner],
    );
    return rows.map((row) {
      final total = (row['total'] as num?)?.toInt() ?? 0;
      final done = (row['done'] as num?)?.toInt() ?? 0;
      return {
        ...row,
        'completion_rate': total == 0 ? 0 : (done / total * 100).round(),
      };
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> habitAnalytics() async {
    final logs = await loadHabitLogs();
    final result = <String, Map<String, dynamic>>{};
    final missedByGoalDow = <String, Map<int, int>>{};

    logs.forEach((dateStr, habits) {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed == null) return;
      final dow = parsed.weekday;
      habits.forEach((goalId, status) {
        if (status == 'missed') {
          missedByGoalDow
              .putIfAbsent(goalId, () => <int, int>{})
              .update(dow, (v) => v + 1, ifAbsent: () => 1);
        }
      });
    });

    for (final entry in missedByGoalDow.entries) {
      var worstDow = 1;
      var worstCount = -1;
      for (final dowEntry in entry.value.entries) {
        if (dowEntry.value > worstCount) {
          worstDow = dowEntry.key;
          worstCount = dowEntry.value;
        }
      }
      result[entry.key] = {
        'goal_id': entry.key,
        'worst_dow': worstDow,
        'avg_recovery_days': 0,
      };
    }
    return result;
  }

  Future<String> globalCriticalDay() async {
    final logs = await loadHabitLogs();
    final counts = <int, int>{};
    logs.forEach((dateStr, habits) {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed == null) return;
      final missed = habits.values.where((status) => status == 'missed').length;
      if (missed > 0) {
        counts.update(
          parsed.weekday,
          (v) => v + missed,
          ifAbsent: () => missed,
        );
      }
    });
    if (counts.isEmpty) return 'N/A';
    final worst = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][worst.key - 1];
  }

  Future<List<Map<String, dynamic>>> globalTrend(String timeframe) async {
    final logs = await loadHabitLogs();
    final days = switch (timeframe) {
      '7d' || '7D' => 7,
      '30d' || '30D' => 30,
      '90d' || '90D' => 90,
      _ => 30,
    };
    final today = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (var i = days - 1; i >= 0; i--) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: i));
      final key = _dateKey(date);
      final statuses = logs[key]?.values.toList() ?? const <String>[];
      final done = statuses.where((s) => s == 'done').length;
      final total = statuses.length;
      result.add({
        'point_index': days - 1 - i,
        'date': key,
        'rate': total == 0 ? 0 : done / total * 100,
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> criticalHabits() async {
    final stats = await habitStats();
    stats.sort((a, b) {
      final aRate = (a['completion_rate'] as num?) ?? 0;
      final bRate = (b['completion_rate'] as num?) ?? 0;
      return aRate.compareTo(bRate);
    });
    return stats.take(5).map((row) {
      final rate = (row['completion_rate'] as num?) ?? 0;
      return {
        'goal_id': row['goal_id'],
        'drop': 100 - rate,
        'neg_streak': row['missed'] ?? 0,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> bestHabits(String timeframe) async {
    final stats = await habitStats();
    stats.sort((a, b) {
      final aRate = (a['completion_rate'] as num?) ?? 0;
      final bRate = (b['completion_rate'] as num?) ?? 0;
      return bRate.compareTo(aRate);
    });
    return stats.take(5).map((row) {
      return {
        'goal_id': row['goal_id'],
        'rate': row['completion_rate'] ?? 0,
        'streak': row['streak'] ?? 0,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> habitPerformanceByDay(
    String goalId,
  ) async {
    final db = await _database();
    return db.rawQuery(
      '''
SELECT
  CAST(strftime('%w', date) AS INTEGER) AS day_index,
  SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) AS done_count,
  COUNT(*) AS total_count
FROM goal_logs
WHERE goal_id = ?
GROUP BY day_index
ORDER BY day_index ASC
''',
      [goalId],
    );
  }

  Future<Map<String, dynamic>> habitAlerts(String goalId) async {
    final db = await _database();
    final rows = await db.query(
      'goal_logs',
      where: 'goal_id = ? AND status = ?',
      whereArgs: [goalId, 'missed'],
      orderBy: 'date ASC',
    );
    return {
      'worst_negative_days': rows.length,
      'worst_negative_start': rows.isEmpty ? null : rows.first['date'],
      'broken_streaks': <Map<String, dynamic>>[],
    };
  }

  Future<List<int>> habitYearlyGrid(String goalId) async {
    final db = await _database();
    final year = DateTime.now().year;
    final rows = await db.query(
      'goal_logs',
      columns: ['date', 'status'],
      where: 'goal_id = ? AND date >= ? AND date <= ?',
      whereArgs: [goalId, '$year-01-01', '$year-12-31'],
    );
    final byDate = {
      for (final row in rows) row['date'] as String: row['status'] as String,
    };
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);
    final result = <int>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      result.add(switch (byDate[_dateKey(d)]) {
        'done' => 1,
        'missed' => -1,
        'skipped' => 0,
        _ => 0,
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> habitCorrelations(
    String targetGoalId,
  ) async {
    final logs = await loadHabitLogs();
    final together = <String, int>{};
    var targetDone = 0;

    logs.forEach((date, habits) {
      if (habits[targetGoalId] != 'done') return;
      targetDone++;
      habits.forEach((goalId, status) {
        if (goalId != targetGoalId && status == 'done') {
          together.update(goalId, (v) => v + 1, ifAbsent: () => 1);
        }
      });
    });

    return together.entries.map((entry) {
      return {
        'goal_id': entry.key,
        'together_count': entry.value,
        'percentage': targetDone == 0
            ? 0
            : (entry.value / targetDone * 100).round(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> allHabitCorrelations() async {
    final goals = await loadGoals();
    final result = <Map<String, dynamic>>[];
    for (final goal in goals) {
      for (final correlation in await habitCorrelations(goal.id)) {
        result.add({
          'goal_id': goal.id,
          'other_goal_id': correlation['goal_id'],
          'percentage': correlation['percentage'],
          'together_count': correlation['together_count'],
        });
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> macroGoalsStats(String year) async {
    final goals = await loadMacroGoals();
    final filtered = year == 'all'
        ? goals
        : goals.where((g) => g.year?.toString() == year).toList();
    final completed = filtered
        .where((goal) => goal.status == GoalStatus.completed)
        .length;
    final byType = <String, int>{};
    final byCategory = <String, int>{};
    for (final goal in filtered) {
      byType.update(goal.type.name, (v) => v + 1, ifAbsent: () => 1);
      final category = goal.categoryId ?? goal.categoryKey ?? 'uncategorized';
      byCategory.update(category, (v) => v + 1, ifAbsent: () => 1);
    }
    return {
      'total_goals': filtered.length,
      'completed_goals': completed,
      'active_goals': filtered
          .where((goal) => goal.status == GoalStatus.active)
          .length,
      'failed_goals': filtered
          .where((goal) => goal.status == GoalStatus.failed)
          .length,
      'completion_rate': filtered.isEmpty
          ? 0
          : (completed / filtered.length * 100).round(),
      'by_type': byType,
      'by_category': byCategory,
      'monthly_trend': <Map<String, dynamic>>[],
      'yearly_comparison': <Map<String, dynamic>>[],
    };
  }

  Goal _goalFromRow(Map<String, Object?> row) {
    final json = <String, dynamic>{
      'id': row['id'],
      'title': row['title'],
      'description': row['description'],
      'icon': row['icon'],
      'color': row['color'],
      'frequency_days': row['frequency_days'] == null
          ? null
          : List<int>.from(jsonDecode(row['frequency_days'] as String)),
      'start_date': row['start_date'],
      'end_date': row['end_date'],
      'display_order': row['display_order'],
      'reminder_time': row['reminder_time'],
    };
    return Goal.fromJson(json);
  }

  Map<String, Object?> _goalToRow(Goal goal) {
    return {
      'id': goal.id.isEmpty ? _uuid.v4() : goal.id,
      'title': goal.title,
      'description': goal.description,
      'icon': goal.icon,
      'color': _colorToHex(goal.color),
      'frequency_days': goal.frequencyDays == null
          ? null
          : jsonEncode(goal.frequencyDays),
      'start_date': goal.startDate.toIso8601String(),
      'end_date': goal.endDate?.toIso8601String(),
      'display_order': goal.displayOrder,
      'reminder_time': goal.reminderTime,
    };
  }

  MacroGoal _macroGoalFromRow(Map<String, Object?> row) {
    return MacroGoal.fromJson({
      'id': row['id'],
      'title': row['title'],
      'status': row['status'],
      'type': row['type'],
      'year': row['year'],
      'month': row['month'],
      'week_number': row['week_number'],
      'quarter': row['quarter'],
      'category_key': row['category_key'],
      'category_id': row['category_id'],
      'created_at': row['created_at'],
    });
  }

  DailyMood _dailyMoodFromRow(Map<String, Object?> row) {
    return DailyMood(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      date: row['date'] as String,
      moodScore: (row['mood_score'] as num).toInt(),
      energyScore: (row['energy_score'] as num).toInt(),
    );
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';
}
