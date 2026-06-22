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
import 'private_analytics.dart';
import 'secure_storage_utils.dart';
import 'streak_utils.dart';

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
    final existing =
        _ownerId ?? await SecureStorageUtils.readDeviceLocal(_ownerIdKey);
    if (existing != null && existing.isNotEmpty) {
      _ownerId = existing;
      return existing;
    }

    final id = _uuid.v4();
    await SecureStorageUtils.writeDeviceLocal(
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
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _onUpgrade,
    );
    _db = db;
    await _ensureProfile(db);
    return db;
  }

  Future<String> _databasePassword() async {
    final existing = await SecureStorageUtils.readDeviceLocal(_dbPasswordKey);
    if (existing != null && existing.length >= 32) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(48, (_) => random.nextInt(256));
    final password = base64UrlEncode(bytes);
    await SecureStorageUtils.writeDeviceLocal(
      _dbPasswordKey,
      password,
      context: '[PrivateDB] password',
    );
    return password;
  }

  Future<void> _excludeFromBackup(File file) async {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    try {
      // Exclude the whole Application Support directory rather than the single
      // .db file. This is intentional: it also covers SQLite's -wal/-shm
      // sidecars (which may not exist yet when this runs) and the
      // `private_profile` avatar folder — i.e. exactly the private data we must
      // keep out of iCloud/iTunes backups while sync is off. Only Private-mode
      // data lives here, so nothing else is affected. Moving the DB into a
      // dedicated subfolder would orphan existing installs' databases, so the
      // path is kept stable.
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

  /// DDL for `long_term_goals`. Shared between [_createSchema] and the v2
  /// upgrade so the CHECK constraints can't drift between fresh installs and
  /// migrated databases.
  static const String _longTermGoalsTableDdl = '''
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
  -- week_number is a week-of-month index (the app emits 1..6 via weeksInMonth).
  -- The 1..53 bound matches cloud schema.sql to avoid cross-backend CHECK drift.
  week_number INTEGER CHECK (week_number >= 1 AND week_number <= 53),
  quarter INTEGER CHECK (quarter >= 1 AND quarter <= 4),
  -- color is legacy/vestigial: macro goals derive their color from their
  -- category (GoalCategory.color); the app never writes this column.
  color TEXT,
  category_key TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  category_id TEXT REFERENCES macro_goal_categories(id) ON DELETE SET NULL
)
''';

  static const List<String> _longTermGoalsIndexes = [
    'CREATE INDEX idx_ltg_user_type_year ON long_term_goals (user_id, type, year)',
    'CREATE INDEX idx_ltg_user_status ON long_term_goals (user_id, status)',
  ];

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v2: widen long_term_goals.week_number CHECK from 1..6 to 1..53 to match
    // cloud schema.sql. SQLite can't ALTER a CHECK constraint, so rebuild the
    // table. Nothing references long_term_goals via FK, so a rename/copy/drop is
    // safe; existing rows (week-of-month, always <= 6) all satisfy the new bound.
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE long_term_goals RENAME TO long_term_goals_old',
      );
      await db.execute(_longTermGoalsTableDdl);
      await db.execute('''
INSERT INTO long_term_goals (
  id, user_id, title, status, type, year, month, week_number, quarter,
  color, category_key, created_at, updated_at, category_id
)
SELECT
  id, user_id, title, status, type, year, month, week_number, quarter,
  color, category_key, created_at, updated_at, category_id
FROM long_term_goals_old
''');
      await db.execute('DROP TABLE long_term_goals_old');
      for (final ddl in _longTermGoalsIndexes) {
        await db.execute(ddl);
      }
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

    await db.execute(_longTermGoalsTableDdl);

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

    // NOTE: goal_category_settings mirrors the cloud table for schema parity
    // and future iCloud-sync completeness, but the mobile app does not currently
    // read or write its `mappings` (no provider touches it — category data lives
    // in macro_goal_categories). It is seeded once in _ensureProfile and wiped by
    // deleteAllPrivateData. Kept intentionally; if the cloud feature is ever
    // wired into mobile, the storage is already here.
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
    for (final ddl in _longTermGoalsIndexes) {
      await db.execute(ddl);
    }
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

  /// Sets a habit log and computes its signed [computeStreak] from the full
  /// persisted history plus the goal's start date, so a Done/Skip triggered
  /// from a notification stores the same streak the foreground toggle would
  /// (parity with `goal_provider.cycleStatus`). Safe to call from the
  /// notification background isolate — it only touches the local DB.
  Future<void> setHabitLogWithStreak({
    required String goalId,
    required String date,
    required String status,
  }) async {
    final logs = await loadHabitLogs();
    // Apply the new status in-memory so computeStreak sees the toggled day.
    (logs[date] ??= <String, String>{})[goalId] = status;

    Goal? goal;
    for (final g in await loadGoals()) {
      if (g.id == goalId) {
        goal = g;
        break;
      }
    }

    final parsedDate = DateTime.tryParse(date) ?? DateTime.now();
    final streak = computeStreak(
      habitId: goalId,
      date: parsedDate,
      logs: logs,
      startDate: goal?.startDate ?? parsedDate,
    );

    await setHabitLog(
      goalId: goalId,
      date: date,
      status: status,
      streak: streak,
    );
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

  /// Loads `goal_logs` (optionally for a single [goalId]) as normalised entries,
  /// including the signed `streak`, for the parity computations.
  Future<List<HabitLogEntry>> _loadLogEntries({String? goalId}) async {
    final db = await _database();
    final owner = await ownerId();
    final rows = await db.query(
      'goal_logs',
      columns: ['goal_id', 'date', 'status', 'streak'],
      where: goalId == null ? 'user_id = ?' : 'user_id = ? AND goal_id = ?',
      whereArgs: goalId == null ? [owner] : [owner, goalId],
    );
    final entries = <HabitLogEntry>[];
    for (final row in rows) {
      final date = DateTime.tryParse(row['date'] as String);
      if (date == null) continue;
      entries.add(HabitLogEntry(
        goalId: row['goal_id'] as String,
        date: date,
        status: row['status'] as String,
        streak: (row['streak'] as num?)?.toInt() ?? 0,
      ));
    }
    return entries;
  }

  Map<String, List<HabitLogEntry>> _groupByGoal(List<HabitLogEntry> entries) {
    final map = <String, List<HabitLogEntry>>{};
    for (final e in entries) {
      (map[e.goalId] ??= <HabitLogEntry>[]).add(e);
    }
    return map;
  }

  List<GoalInput> _goalInputs(List<Goal> goals) => [
        for (final g in goals)
          GoalInput(
            id: g.id,
            startDate: g.startDate,
            endDate: g.endDate,
            frequencyDays: g.frequencyDays,
          ),
      ];

  // Mirrors the cloud `habit_stats` view.
  Future<List<Map<String, dynamic>>> habitStats() async {
    final owner = await ownerId();
    final goals = await loadGoals();
    final byGoal = _groupByGoal(await _loadLogEntries());
    final today = DateTime.now();
    return [
      for (final g in goals)
        computeHabitStatsRow(
          goalId: g.id,
          userId: owner,
          title: g.title,
          startDate: g.startDate,
          logs: byGoal[g.id] ?? const [],
          today: today,
        ),
    ];
  }

  // Mirrors the cloud `get_habit_analytics` RPC (one row per goal).
  Future<Map<String, Map<String, dynamic>>> habitAnalytics() async {
    final goals = await loadGoals();
    final byGoal = _groupByGoal(await _loadLogEntries());
    return {
      for (final g in goals)
        g.id: computeAnalyticsRow(goalId: g.id, logs: byGoal[g.id] ?? const []),
    };
  }

  // Mirrors the cloud `get_global_critical_day` RPC.
  Future<String> globalCriticalDay() async {
    return computeGlobalCriticalDay(await _loadLogEntries());
  }

  // Mirrors the cloud `get_global_trend` RPC.
  Future<List<Map<String, dynamic>>> globalTrend(String timeframe) async {
    final goals = await loadGoals();
    final logs = await loadHabitLogs();
    return computeGlobalTrend(
      goals: _goalInputs(goals),
      logs: logs,
      timeframe: timeframe,
      today: DateTime.now(),
    );
  }

  // Mirrors the cloud `get_critical_habits` RPC.
  Future<List<Map<String, dynamic>>> criticalHabits() async {
    final goals = await loadGoals();
    final byGoal = _groupByGoal(await _loadLogEntries());
    return computeCriticalHabits(
      goals: _goalInputs(goals),
      logsByGoal: byGoal,
      today: DateTime.now(),
    );
  }

  // Mirrors the cloud `get_best_habits` RPC.
  Future<List<Map<String, dynamic>>> bestHabits(String timeframe) async {
    final goals = await loadGoals();
    final byGoal = _groupByGoal(await _loadLogEntries());
    return computeBestHabits(
      goals: _goalInputs(goals),
      logsByGoal: byGoal,
      timeframe: timeframe,
      today: DateTime.now(),
    );
  }

  // Mirrors the cloud `get_habit_performance_by_day` RPC (ISODOW day_index).
  Future<List<Map<String, dynamic>>> habitPerformanceByDay(
    String goalId,
  ) async {
    return computePerformanceByDay(await _loadLogEntries(goalId: goalId));
  }

  // Mirrors the cloud `get_habit_alerts` RPC.
  Future<Map<String, dynamic>> habitAlerts(String goalId) async {
    return computeHabitAlerts(await _loadLogEntries(goalId: goalId));
  }

  // Mirrors the cloud `get_habit_yearly_grid` RPC (done=1, missed=2, 365 days).
  Future<List<int>> habitYearlyGrid(String goalId) async {
    return computeYearlyGrid(
      await _loadLogEntries(goalId: goalId),
      DateTime.now(),
    );
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
