import 'dart:convert';

import 'dart:math';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Manages the encrypted local SQLite database used by Private mode.
///
/// The database is encrypted at rest via SQLCipher.  The encryption key is
/// generated once and stored in macOS Keychain through [FlutterSecureStorage].
/// The owner UUID is also stored in secure storage so that it survives database
/// resets while remaining stable across restarts.
class DesktopPrivateDb {
  DesktopPrivateDb._();

  static DesktopPrivateDb? _instance;
  Database? _db;

  static const _dbFileName = 'evolve_private.db';
  static const _keyStorageKey = 'evolve_private_db_key';
  static const _ownerStorageKey = 'evolve_private_owner_id';
  static const _currentVersion = 1;

  static DesktopPrivateDb get instance {
    _instance ??= DesktopPrivateDb._();
    return _instance!;
  }

  /// Returns the open database, initializing it on first call.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _open();
    return _db!;
  }

  /// The stable local owner UUID (created once, reused forever).
  Future<String> get ownerId async {
    const storage = FlutterSecureStorage();
    var id = await storage.read(key: _ownerStorageKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await storage.write(key: _ownerStorageKey, value: id);
    }
    return id;
  }

  /// Closes the database (e.g. before deleting private data).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Deletes all private data: closes the DB, removes the file, and clears
  /// the owner UUID so a new identity is created on next entry.
  Future<void> deleteAll() async {
    await close();
    try {
      final dir = await getApplicationSupportDirectory();
      final file = p.join(dir.path, _dbFileName);
      await databaseFactory.deleteDatabase(file);
    } catch (error, stack) {
      AppLogger.error('Unable to delete private database', error, stack);
    }
    const storage = FlutterSecureStorage();
    await storage.delete(key: _ownerStorageKey);
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbFileName);
    final key = await _encryptionKey();

    return openDatabase(
      dbPath,
      version: _currentVersion,
      password: key,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<String> _encryptionKey() async {
    const storage = FlutterSecureStorage();
    var key = await storage.read(key: _keyStorageKey);
    if (key == null || key.isEmpty) {
      key = _generateKey(32);
      await storage.write(key: _keyStorageKey, value: key);
    }
    return key;
  }

  static String _generateKey(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // ── profiles ─────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS profiles (
        id               TEXT PRIMARY KEY,
        full_name        TEXT,
        email            TEXT,
        date_of_birth    TEXT,
        avatar_path      TEXT,
        morning_brief_time TEXT DEFAULT '09:00',
        evening_review_time TEXT DEFAULT '21:00',
        terms_accepted_at TEXT,
        sentry_consent   INTEGER DEFAULT 0,
        created_at       TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── goals (habits) ───────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id              TEXT PRIMARY KEY,
        user_id         TEXT NOT NULL REFERENCES profiles(id),
        title           TEXT NOT NULL,
        description     TEXT,
        icon            TEXT,
        color           TEXT,
        frequency_days  TEXT,
        start_date      TEXT,
        end_date        TEXT,
        display_order   INTEGER,
        reminder_time   TEXT,
        is_active       INTEGER DEFAULT 1,
        created_at      TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── goal_logs ────────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS goal_logs (
        id        TEXT PRIMARY KEY,
        user_id   TEXT NOT NULL REFERENCES profiles(id),
        goal_id   TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
        date      TEXT NOT NULL,
        status    TEXT NOT NULL DEFAULT 'done',
        streak    INTEGER DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE(goal_id, date)
      )
    ''');

    // ── long_term_goals (macro goals) ────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS long_term_goals (
        id            TEXT PRIMARY KEY,
        user_id       TEXT NOT NULL REFERENCES profiles(id),
        title         TEXT NOT NULL,
        status        TEXT NOT NULL DEFAULT 'active',
        type          TEXT NOT NULL DEFAULT 'annual',
        year          INTEGER,
        quarter       INTEGER,
        month         INTEGER,
        week_number   INTEGER,
        category_key  TEXT,
        category_id   TEXT,
        created_at    TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ── daily_moods ──────────────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS daily_moods (
        id            TEXT PRIMARY KEY,
        user_id       TEXT NOT NULL REFERENCES profiles(id),
        date          TEXT NOT NULL,
        mood_score    INTEGER,
        energy_score  INTEGER,
        created_at    TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at    TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE(user_id, date)
      )
    ''');

    // ── macro_goal_categories ────────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS macro_goal_categories (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES profiles(id),
        name        TEXT NOT NULL,
        color       TEXT,
        archived_at TEXT,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE(user_id, name)
      )
    ''');

    // ── goal_category_settings ───────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS goal_category_settings (
        id          TEXT PRIMARY KEY,
        user_id     TEXT NOT NULL REFERENCES profiles(id),
        category_key TEXT NOT NULL,
        is_visible  INTEGER DEFAULT 1,
        sort_order  INTEGER DEFAULT 0,
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
        UNIQUE(user_id, category_key)
      )
    ''');

    // ── Indexes ──────────────────────────────────────────────────────────────
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_goals_user ON goals(user_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_goal_logs_user ON goal_logs(user_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_goal_logs_goal_date ON goal_logs(goal_id, date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_long_term_goals_user ON long_term_goals(user_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_moods_user_date ON daily_moods(user_id, date)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_macro_goal_categories_user ON macro_goal_categories(user_id)',
    );

    await batch.commit(noResult: true);

    debugPrint('[DesktopPrivateDb] Schema v$version created.');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here.
    debugPrint(
      '[DesktopPrivateDb] Upgraded from v$oldVersion to v$newVersion.',
    );
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<void> importData({
    required Map<String, dynamic> backupData,
    required bool replaceExisting,
  }) async {
    final db = await database;
    final now = _now();
    // Default desktop owner id for local
    final owner = 'local_user';

    await db.transaction((txn) async {
      if (replaceExisting) {
        // Wipe existing user data (except profiles and settings)
        await txn.delete('goal_logs');
        await txn.delete('daily_moods');
        await txn.delete('long_term_goals');
        await txn.delete('macro_goal_categories');
        await txn.delete('goals');
      }

      // Insert Categories
      if (backupData.containsKey('macro_goal_categories')) {
        for (final cat in (backupData['macro_goal_categories'] as List).cast<Map<String, dynamic>>()) {
          final catRow = {
            'id': cat['id'],
            'user_id': owner,
            'name': cat['name'],
            'color': cat['color'],
            'created_at': cat['created_at'] ?? now,
            'archived_at': cat['archived_at'],
          };
          await txn.insert('macro_goal_categories', catRow, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Insert Goals (Habits)
      if (backupData.containsKey('goals')) {
        for (final g in (backupData['goals'] as List).cast<Map<String, dynamic>>()) {
          final goalRow = {
            'id': g['id'],
            'user_id': owner,
            'title': g['title'],
            'description': g['description'],
            'icon': g['icon'],
            'color': g['color'],
            'frequency_days': g['frequency_days'] != null ? jsonEncode(g['frequency_days']) : null,
            'start_date': g['start_date'],
            'end_date': g['end_date'],
            'display_order': g['display_order'],
            'created_at': g['created_at'] ?? now,
            'updated_at': g['updated_at'] ?? now,
            'reminder_time': g['reminder_time'],
          };
          await txn.insert('goals', goalRow, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Insert Goal Logs
      if (backupData.containsKey('goal_logs')) {
        for (final l in (backupData['goal_logs'] as List).cast<Map<String, dynamic>>()) {
          final logRow = {
            'id': l['id'],
            'user_id': owner,
            'goal_id': l['goal_id'],
            'date': l['date'],
            'status': l['status'],
            'value': l['value'],
            'created_at': l['created_at'] ?? now,
            'updated_at': l['updated_at'] ?? now,
            'streak': l['streak'] ?? 0,
          };
          await txn.insert('goal_logs', logRow, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Insert Macro Goals
      if (backupData.containsKey('long_term_goals')) {
        for (final g in (backupData['long_term_goals'] as List).cast<Map<String, dynamic>>()) {
          final ltgRow = {
            'id': g['id'],
            'user_id': owner,
            'title': g['title'],
            'status': g['status'],
            'type': g['type'],
            'year': g['year'],
            'month': g['month'],
            'week_number': g['week_number'],
            'quarter': g['quarter'],
            'category_key': g['category_key'],
            'category_id': g['category_id'],
            'created_at': g['created_at'] ?? now,
            'updated_at': g['updated_at'] ?? now,
          };
          await txn.insert('long_term_goals', ltgRow, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Insert Daily Moods
      if (backupData.containsKey('daily_moods')) {
        for (final m in (backupData['daily_moods'] as List).cast<Map<String, dynamic>>()) {
          final moodRow = {
            'id': m['id'],
            'user_id': owner,
            'date': m['date'],
            'mood_score': m['mood_score'],
            'energy_score': m['energy_score'],
            'created_at': m['created_at'] ?? now,
            'updated_at': m['updated_at'] ?? now,
          };
          await txn.insert('daily_moods', moodRow, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }
}
