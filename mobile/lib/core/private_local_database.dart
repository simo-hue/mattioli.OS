import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:evolve_sync/evolve_sync.dart';
import 'package:evolve_verification/evolve_verification.dart';
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
import 'import_merge.dart';
import 'import_merge_stats.dart';
import 'private_analytics.dart';
import 'private_data_store.dart';
import 'secure_storage_utils.dart';
import 'streak_utils.dart';

final privateLocalDatabaseProvider = Provider<PrivateDataStore>((ref) {
  return PrivateLocalDatabase();
});

class PrivateLocalDatabase implements PrivateDataStore {
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

  /// After-write sync hook (iCloud sync trigger #2): set at app bootstrap to
  /// the [SyncWriteDebouncer]'s notifyWrite, called by every mutating method
  /// below. Deliberately NOT invoked by the sync engine's own applies (those
  /// go through [SyncLocalStore.applyUpsert], not these methods), so a pull
  /// can never re-trigger a push. Null (default, and in the notification
  /// background isolate) → no-op; those writes sync on the next trigger.
  static void Function()? onPrivateWrite;

  void _notifyWrite() => onPrivateWrite?.call();

  @override
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

  /// Persist [canonical] as this device's owner id after the sync engine
  /// re-keyed all local rows onto the canonical sync-owner (second-device
  /// merge). Without this, [ownerId] keeps returning the old device-local id
  /// and every owner-filtered query misses the re-keyed rows.
  Future<void> adoptOwner(String canonical) async {
    await SecureStorageUtils.writeDeviceLocal(
      _ownerIdKey,
      canonical,
      context: '[PrivateDB] adopt canonical owner',
    );
    _ownerId = canonical;
  }

  @override
  Future<void> ensureReady() async {
    final db = await _database();
    await _ensureProfile(db);
  }

  /// A [SyncLocalStore] over the opened private database, for the iCloud sync
  /// engine. Opens the DB if needed.
  Future<SyncLocalStore> syncStore() async => SyncLocalStore(await _database());

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
      version: PrivateDbSchema.version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: PrivateDbSchema.onCreate,
      onUpgrade: PrivateDbSchema.onUpgrade,
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

  @override
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

  @override
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
    _notifyWrite();
  }

  @override
  Future<void> deleteGoal(String id) async {
    final db = await _database();
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
    _notifyWrite();
  }

  @override
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

  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int streak = 0,
    double? value,
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
      // The measured HealthKit quantity for an auto-verified verdict (null for
      // manual check-ins and Screen Time). REPLACE rewrites the whole row, so we
      // always set it — a manual toggle intentionally clears any prior value.
      'value': value,
      'created_at': existing.isNotEmpty
          ? existing.first['created_at'] as String
          : now,
      'updated_at': now,
      'streak': streak,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyWrite();
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

  @override
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
    _notifyWrite();
  }

  @override
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

  @override
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
    _notifyWrite();
  }

  @override
  Future<void> deleteMacroGoal(String id) async {
    final db = await _database();
    await db.delete('long_term_goals', where: 'id = ?', whereArgs: [id]);
    _notifyWrite();
  }

  @override
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

  @override
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
      'updated_at': now,
    });
    _notifyWrite();
    return id;
  }

  @override
  Future<void> updateMacroGoalCategory(
    String id,
    String name,
    String colorHex,
  ) async {
    final db = await _database();
    await db.update(
      'macro_goal_categories',
      {'name': name, 'color': colorHex, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyWrite();
  }

  @override
  Future<void> archiveMacroGoalCategory(String id) async {
    final db = await _database();
    final now = _now();
    await db.update(
      'macro_goal_categories',
      {'archived_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notifyWrite();
  }

  @override
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

  @override
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
    _notifyWrite();
    return _dailyMoodFromRow(row);
  }

  @override
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

  @override
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
    if (avatarUrl != null) {
      // The avatar image itself syncs as an encrypted CKAsset under its own
      // record; no trigger covers that pseudo-record, so mark it here.
      await SyncLocalStore(db).markAvatarDirty(owner);
    }
    _notifyWrite();
  }

  @override
  Future<Map<String, dynamic>> loadSettingsRow() => loadProfileRow();

  @override
  Future<void> updateSettingsRow(Map<String, Object?> values) async {
    final db = await _database();
    final owner = await ownerId();
    await db.update(
      'profiles',
      {...values, 'updated_at': _now(), 'is_pro': 1, 'sentry_consent': 0},
      where: 'id = ?',
      whereArgs: [owner],
    );
    _notifyWrite();
  }

  @override
  Future<bool> hasPrivateAiExternalConsent() async {
    final row = await loadProfileRow();
    return row['private_ai_external_consent'] == 1;
  }

  @override
  Future<void> setPrivateAiExternalConsent(bool value) async {
    await updateSettingsRow({'private_ai_external_consent': value ? 1 : 0});
  }

  @override
  Future<Map<String, dynamic>> exportData() async {
    final db = await _database();
    final owner = await ownerId();
    Future<List<Map<String, Object?>>> rows(String table, {String? orderBy}) =>
        db.query(
          table,
          where: 'user_id = ?',
          whereArgs: [owner],
          orderBy: orderBy,
        );

    final goals = await rows(
      'goals',
      orderBy: 'display_order ASC, created_at ASC',
    );
    final logs = await rows('goal_logs');
    final macros = await rows('long_term_goals', orderBy: 'created_at ASC');
    final cats = await rows('macro_goal_categories', orderBy: 'created_at ASC');
    final moods = await rows('daily_moods');

    // Full rows (ids + timestamps) so this export round-trips losslessly and an
    // import can reconcile by identity + last-write-wins. `frequency_days` is
    // stored JSON-encoded; decode it back to a list for the portable file.
    return {
      'schemaVersion': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'mode': 'private',
      'profile': await loadProfileRow(),
      'settings': await loadSettingsRow(),
      'habits': [
        for (final g in goals)
          {
            'id': g['id'],
            'title': g['title'],
            'description': g['description'],
            'icon': g['icon'],
            'color': g['color'],
            'frequency_days': g['frequency_days'] == null
                ? null
                : jsonDecode(g['frequency_days'] as String),
            'start_date': g['start_date'],
            'end_date': g['end_date'],
            'display_order': g['display_order'],
            'created_at': g['created_at'],
            'updated_at': g['updated_at'],
            'reminder_time': g['reminder_time'],
          },
      ],
      'habitLogs': [
        for (final l in logs)
          {
            'id': l['id'],
            'goal_id': l['goal_id'],
            'date': l['date'],
            'status': l['status'],
            'value': l['value'],
            'created_at': l['created_at'],
            'updated_at': l['updated_at'],
            'streak': l['streak'],
          },
      ],
      'macroGoals': [
        for (final g in macros)
          {
            'id': g['id'],
            'title': g['title'],
            'status': g['status'],
            'type': g['type'],
            'year': g['year'],
            'month': g['month'],
            'week_number': g['week_number'],
            'quarter': g['quarter'],
            'category_key': g['category_key'],
            'category_id': g['category_id'],
            'created_at': g['created_at'],
            'updated_at': g['updated_at'],
          },
      ],
      'macroGoalCategories': [
        for (final c in cats)
          {
            'id': c['id'],
            'name': c['name'],
            'color': c['color'],
            'created_at': c['created_at'],
            'updated_at': c['updated_at'],
            'archived_at': c['archived_at'],
          },
      ],
      'dailyMoods': [
        for (final m in moods)
          {
            'id': m['id'],
            'date': m['date'],
            'mood_score': m['mood_score'],
            'energy_score': m['energy_score'],
            'created_at': m['created_at'],
            'updated_at': m['updated_at'],
          },
      ],
    };
  }

  @override
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

    // Reset sync bookkeeping after the wipe. The domain deletes above each fired
    // a tombstone trigger, and _ensureProfile re-queued a fresh profile — drop
    // ALL of sync_state so a future re-enable starts from a clean slate, and
    // clear the delta-fetch token + last-full-sync. PRESERVE pending_zone_wipe:
    // requestFullReset (called just before this) queued the cloud-zone wipe and
    // a later syncNow must still carry it out; clearing it here would orphan the
    // user's data in iCloud forever.
    await db.delete(PrivateDbSchema.syncStateTable);
    await db.update(
      PrivateDbSchema.syncMetaTable,
      {'server_change_token': null, 'last_full_sync_at': null},
      where: 'id = 1',
    );
  }

  @override
  Future<ImportMergeStats> importData({
    required Map<String, dynamic> backupData,
    required bool replaceExisting,
  }) async {
    final db = await _database();
    final owner = await ownerId();
    // The whole import is one transaction: on any failure nothing is applied,
    // and the post-merge streak recompute reads back its own writes.
    final stats = await db.transaction<ImportMergeStats>(
      (txn) => applyPrivateImportMerge(
        txn: txn,
        owner: owner,
        canonical: backupData,
        replaceExisting: replaceExisting,
        now: _now(),
        newId: () => _uuid.v4(),
      ),
    );
    _notifyWrite();
    return stats;
  }

  // ── Avatar bytes (file side of the encrypted-CKAsset avatar sync) ─────────

  /// Plaintext bytes of the current local avatar, or null when none is set or
  /// the file has gone missing (the engine then pushes a tombstone).
  Future<Uint8List?> readAvatarBytes() async {
    final row = await loadProfileRow();
    final path = row['avatar_url'] as String?;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Persist a PULLED avatar: write the image under `private_profile/` with a
  /// fresh name (so stale `FileImage` caches can't show the old picture),
  /// point `profiles.avatar_url` at it WITHOUT re-dirtying the profile row
  /// (setLocalOnlyColumn), and delete the previous file.
  Future<void> applyPulledAvatar(Uint8List bytes) async {
    final db = await _database();
    final owner = await ownerId();
    final previous =
        (await loadProfileRow())['avatar_url'] as String?;

    final dir = await getApplicationSupportDirectory();
    final avatarDir = Directory(p.join(dir.path, 'private_profile'));
    await avatarDir.create(recursive: true);
    final path = p.join(
      avatarDir.path,
      'avatar_sync_${DateTime.now().millisecondsSinceEpoch}.img',
    );
    await File(path).writeAsBytes(bytes, flush: true);

    await SyncLocalStore(db)
        .setLocalOnlyColumn('profiles', owner, 'avatar_url', path);

    if (previous != null && previous.isNotEmpty && previous != path) {
      try {
        final old = File(previous);
        if (await old.exists()) await old.delete();
      } catch (e, stack) {
        AppLogger.warning('[PrivateDB] stale avatar cleanup failed', e, stack);
      }
    }
  }

  /// Apply a PULLED avatar tombstone: remove the local file and clear
  /// `profiles.avatar_url` without re-dirtying the profile row.
  Future<void> removePulledAvatar() async {
    final db = await _database();
    final owner = await ownerId();
    final current = (await loadProfileRow())['avatar_url'] as String?;
    await SyncLocalStore(db)
        .setLocalOnlyColumn('profiles', owner, 'avatar_url', null);
    if (current != null && current.isNotEmpty) {
      try {
        final file = File(current);
        if (await file.exists()) await file.delete();
      } catch (e, stack) {
        AppLogger.warning('[PrivateDB] avatar removal cleanup failed', e, stack);
      }
    }
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
      entries.add(
        HabitLogEntry(
          goalId: row['goal_id'] as String,
          date: date,
          status: row['status'] as String,
          streak: (row['streak'] as num?)?.toInt() ?? 0,
        ),
      );
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
  @override
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
  @override
  Future<Map<String, Map<String, dynamic>>> habitAnalytics() async {
    final goals = await loadGoals();
    final byGoal = _groupByGoal(await _loadLogEntries());
    return {
      for (final g in goals)
        g.id: computeAnalyticsRow(goalId: g.id, logs: byGoal[g.id] ?? const []),
    };
  }

  // Mirrors the cloud `get_global_critical_day` RPC.
  @override
  Future<String> globalCriticalDay() async {
    return computeGlobalCriticalDay(await _loadLogEntries());
  }

  // Mirrors the cloud `get_global_trend` RPC.
  @override
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
  @override
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
  @override
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
  @override
  Future<List<Map<String, dynamic>>> habitPerformanceByDay(
    String goalId,
  ) async {
    return computePerformanceByDay(await _loadLogEntries(goalId: goalId));
  }

  // Mirrors the cloud `get_habit_alerts` RPC.
  @override
  Future<Map<String, dynamic>> habitAlerts(String goalId) async {
    return computeHabitAlerts(await _loadLogEntries(goalId: goalId));
  }

  // Mirrors the cloud `get_habit_yearly_grid` RPC (done=1, missed=2, 365 days).
  @override
  Future<List<int>> habitYearlyGrid(String goalId) async {
    return computeYearlyGrid(
      await _loadLogEntries(goalId: goalId),
      DateTime.now(),
    );
  }

  @override
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

  @override
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

  @override
  Future<Map<String, dynamic>> macroGoalsStats(String year) async {
    final allGoals = await loadMacroGoals();

    if (year == 'all') {
      final totalGoals = allGoals.length;
      final completedGoals = allGoals
          .where((g) => g.status == GoalStatus.completed)
          .length;
      final successRate = totalGoals > 0
          ? (completedGoals / totalGoals * 100).round()
          : 0;

      final yearStats = <int, Map<String, int>>{};
      for (final g in allGoals) {
        if (g.year != null) {
          yearStats.putIfAbsent(g.year!, () => {'total': 0, 'completed': 0});
          yearStats[g.year!]!['total'] = yearStats[g.year!]!['total']! + 1;
          if (g.status == GoalStatus.completed) {
            yearStats[g.year!]!['completed'] =
                yearStats[g.year!]!['completed']! + 1;
          }
        }
      }

      int? bestYear;
      int bestYearRate = -1;
      int? mostProdYear;
      int mostProdCount = -1;

      final yearProgression = <Map<String, dynamic>>[];
      final sortedYears = yearStats.keys.toList()..sort();
      for (final y in sortedYears) {
        final t = yearStats[y]!['total']!;
        final c = yearStats[y]!['completed']!;
        final r = t > 0 ? (c / t * 100).round() : 0;

        if (r > bestYearRate ||
            (r == bestYearRate && t > (yearStats[bestYear]?['total'] ?? 0))) {
          bestYearRate = r;
          bestYear = y;
        }
        if (c > mostProdCount) {
          mostProdCount = c;
          mostProdYear = y;
        }
        yearProgression.add({
          'year': y,
          'active': allGoals
              .where((g) => g.year == y && g.status == GoalStatus.active)
              .length,
          'failed': allGoals
              .where((g) => g.year == y && g.status == GoalStatus.failed)
              .length,
          'completed': c,
          'total': t,
        });
      }

      final categoryStats = <String, Map<String, int>>{};
      for (final g in allGoals) {
        final cat = g.categoryId ?? g.categoryKey;
        if (cat != null) {
          categoryStats.putIfAbsent(cat, () => {'total': 0, 'completed': 0});
          categoryStats[cat]!['total'] = categoryStats[cat]!['total']! + 1;
          if (g.status == GoalStatus.completed) {
            categoryStats[cat]!['completed'] =
                categoryStats[cat]!['completed']! + 1;
          }
        }
      }

      final categoryPerformance = categoryStats.entries.map((e) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        return {'category': e.key, 'rate': t > 0 ? (c / t * 100).round() : 0};
      }).toList();

      final typeDistribution = <String, int>{};
      for (final g in allGoals) {
        typeDistribution.update(g.type.name, (v) => v + 1, ifAbsent: () => 1);
      }

      final seasonalityStats = <int, Map<String, int>>{};
      for (final g in allGoals) {
        if (g.quarter != null) {
          seasonalityStats.putIfAbsent(
            g.quarter!,
            () => {'active': 0, 'failed': 0, 'completed': 0},
          );
          if (g.status == GoalStatus.active)
            seasonalityStats[g.quarter!]!['active'] =
                seasonalityStats[g.quarter!]!['active']! + 1;
          if (g.status == GoalStatus.failed)
            seasonalityStats[g.quarter!]!['failed'] =
                seasonalityStats[g.quarter!]!['failed']! + 1;
          if (g.status == GoalStatus.completed)
            seasonalityStats[g.quarter!]!['completed'] =
                seasonalityStats[g.quarter!]!['completed']! + 1;
        }
      }
      final seasonality =
          seasonalityStats.entries
              .map(
                (e) => {
                  'quarter': e.key,
                  'active': e.value['active'],
                  'failed': e.value['failed'],
                  'completed': e.value['completed'],
                },
              )
              .toList()
            ..sort(
              (a, b) => (a['quarter'] as int).compareTo(b['quarter'] as int),
            );

      final monthlyStats = <int, Map<String, int>>{};
      for (final g in allGoals) {
        if (g.month != null) {
          monthlyStats.putIfAbsent(
            g.month!,
            () => {'total': 0, 'completed': 0},
          );
          monthlyStats[g.month!]!['total'] =
              monthlyStats[g.month!]!['total']! + 1;
          if (g.status == GoalStatus.completed) {
            monthlyStats[g.month!]!['completed'] =
                monthlyStats[g.month!]!['completed']! + 1;
          }
        }
      }
      final monthlyHistory =
          monthlyStats.entries.map((e) {
            final t = e.value['total']!;
            final c = e.value['completed']!;
            return {'month': e.key, 'rate': t > 0 ? (c / t * 100).round() : 0};
          }).toList()..sort(
            (a, b) => (a['month'] as int).compareTo(b['month'] as int),
          );

      final interestEvolution = <Map<String, dynamic>>[];
      for (final y in sortedYears) {
        final catsForYear = <String, int>{};
        for (final g in allGoals.where((g) => g.year == y)) {
          final cat = g.categoryId ?? g.categoryKey;
          if (cat != null) {
            catsForYear.update(cat, (v) => v + 1, ifAbsent: () => 1);
          }
        }
        interestEvolution.add({'year': y, 'categories': catsForYear});
      }

      return {
        'total_goals': totalGoals,
        'completed_goals': completedGoals,
        'success_rate': successRate,
        'best_year': bestYear,
        'best_year_rate': bestYearRate,
        'most_productive_year': mostProdYear,
        'most_productive_count': mostProdCount,
        'year_progression': yearProgression,
        'category_performance': categoryPerformance,
        'type_distribution': typeDistribution,
        'seasonality': seasonality,
        'monthly_history': monthlyHistory,
        'interest_evolution': interestEvolution,
      };
    } else {
      final yInt = int.tryParse(year);
      final yearGoals = allGoals.where((g) => g.year == yInt).toList();

      final totalGoals = yearGoals.length;
      final completedGoals = yearGoals
          .where((g) => g.status == GoalStatus.completed)
          .length;
      final successRate = totalGoals > 0
          ? (completedGoals / totalGoals * 100).round()
          : 0;

      final categoryStats = <String, Map<String, int>>{};
      for (final g in yearGoals) {
        final cat = g.categoryId ?? g.categoryKey;
        if (cat != null) {
          categoryStats.putIfAbsent(cat, () => {'total': 0, 'completed': 0});
          categoryStats[cat]!['total'] = categoryStats[cat]!['total']! + 1;
          if (g.status == GoalStatus.completed) {
            categoryStats[cat]!['completed'] =
                categoryStats[cat]!['completed']! + 1;
          }
        }
      }

      String? bestCategory;
      int bestCategoryRate = -1;
      int maxCatTotal = -1;
      for (final e in categoryStats.entries) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        final r = t > 0 ? (c / t * 100).round() : 0;
        if (r > bestCategoryRate ||
            (r == bestCategoryRate && t > maxCatTotal)) {
          bestCategoryRate = r;
          bestCategory = e.key;
          maxCatTotal = t;
        }
      }

      final monthStats = <int, Map<String, int>>{};
      for (final g in yearGoals) {
        if (g.month != null) {
          monthStats.putIfAbsent(
            g.month!,
            () => {'total': 0, 'completed': 0, 'active': 0, 'failed': 0},
          );
          monthStats[g.month!]!['total'] = monthStats[g.month!]!['total']! + 1;
          if (g.status == GoalStatus.completed)
            monthStats[g.month!]!['completed'] =
                monthStats[g.month!]!['completed']! + 1;
          if (g.status == GoalStatus.active)
            monthStats[g.month!]!['active'] =
                monthStats[g.month!]!['active']! + 1;
          if (g.status == GoalStatus.failed)
            monthStats[g.month!]!['failed'] =
                monthStats[g.month!]!['failed']! + 1;
        }
      }

      int? bestMonth;
      int bestMonthRate = -1;
      int maxMonthTotal = -1;
      for (final e in monthStats.entries) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        final r = t > 0 ? (c / t * 100).round() : 0;
        if (r > bestMonthRate || (r == bestMonthRate && t > maxMonthTotal)) {
          bestMonthRate = r;
          bestMonth = e.key;
          maxMonthTotal = t;
        }
      }

      final typeStats = <String, Map<String, int>>{};
      for (final g in yearGoals) {
        typeStats.putIfAbsent(g.type.name, () => {'total': 0, 'completed': 0});
        typeStats[g.type.name]!['total'] =
            typeStats[g.type.name]!['total']! + 1;
        if (g.status == GoalStatus.completed)
          typeStats[g.type.name]!['completed'] =
              typeStats[g.type.name]!['completed']! + 1;
      }

      String? bestType;
      int bestTypeRate = -1;
      int maxTypeTotal = -1;
      for (final e in typeStats.entries) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        final r = t > 0 ? (c / t * 100).round() : 0;
        if (r > bestTypeRate || (r == bestTypeRate && t > maxTypeTotal)) {
          bestTypeRate = r;
          bestType = e.key;
          maxTypeTotal = t;
        }
      }

      final quarterlyStats = <int, Map<String, int>>{};
      for (final g in yearGoals) {
        if (g.quarter != null) {
          quarterlyStats.putIfAbsent(
            g.quarter!,
            () => {'total': 0, 'completed': 0, 'active': 0, 'failed': 0},
          );
          quarterlyStats[g.quarter!]!['total'] =
              quarterlyStats[g.quarter!]!['total']! + 1;
          if (g.status == GoalStatus.completed)
            quarterlyStats[g.quarter!]!['completed'] =
                quarterlyStats[g.quarter!]!['completed']! + 1;
          if (g.status == GoalStatus.active)
            quarterlyStats[g.quarter!]!['active'] =
                quarterlyStats[g.quarter!]!['active']! + 1;
          if (g.status == GoalStatus.failed)
            quarterlyStats[g.quarter!]!['failed'] =
                quarterlyStats[g.quarter!]!['failed']! + 1;
        }
      }
      final quarterlyActivity =
          quarterlyStats.entries
              .map(
                (e) => {
                  'quarter': e.key,
                  'total': e.value['total'],
                  'completed': e.value['completed'],
                  'active': e.value['active'],
                  'failed': e.value['failed'],
                },
              )
              .toList()
            ..sort(
              (a, b) => (a['quarter'] as int).compareTo(b['quarter'] as int),
            );

      final monthlyComposed = <Map<String, dynamic>>[];
      final cumulativeMonthly = <Map<String, dynamic>>[];
      int cumTotal = 0;
      int cumCompleted = 0;
      for (int m = 1; m <= 12; m++) {
        final s =
            monthStats[m] ??
            {'total': 0, 'completed': 0, 'active': 0, 'failed': 0};
        monthlyComposed.add({
          'month': m,
          'total': s['total'],
          'completed': s['completed'],
          'active': s['active'],
          'failed': s['failed'],
        });
        cumTotal += s['total']!;
        cumCompleted += s['completed']!;
        cumulativeMonthly.add({
          'month': m,
          'total': cumTotal,
          'completed': cumCompleted,
        });
      }

      final categoryRates = categoryStats.entries.map((e) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        return {'category': e.key, 'rate': t > 0 ? (c / t * 100).round() : 0};
      }).toList();

      final categoryDistribution = categoryStats.entries
          .map((e) => {'category': e.key, 'count': e.value['total']})
          .toList();

      return {
        'total_goals': totalGoals,
        'completed_goals': completedGoals,
        'success_rate': successRate,
        'best_category': bestCategory,
        'best_category_rate': bestCategoryRate,
        'best_month': bestMonth,
        'best_month_rate': bestMonthRate,
        'best_type': bestType,
        'best_type_rate': bestTypeRate,
        'cumulative_monthly': cumulativeMonthly,
        'category_rates': categoryRates,
        'quarterly_activity': quarterlyActivity,
        'monthly_composed': monthlyComposed,
        'category_distribution': categoryDistribution,
      };
    }
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
      'verify_provider': row['verify_provider'],
      'verify_metric': row['verify_metric'],
      'verify_comparator': row['verify_comparator'],
      'verify_threshold': row['verify_threshold'],
      'verify_unit': row['verify_unit'],
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
      // Always write the verify_* columns (null when manual): upsertGoal uses
      // ConflictAlgorithm.replace, so an omitted column would be wiped to NULL
      // on every edit. The SQLite columns exist after the evolve_sync v4
      // migration (run automatically on open).
      ...(goal.verificationRule?.toColumns() ?? VerificationRule.nullColumns),
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
