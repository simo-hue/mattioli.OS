import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:evolve_desktop/core/streak_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Manages the encrypted local SQLite database used by Private mode.
///
/// The schema is [PrivateDbSchema], ported verbatim from the mobile client so
/// both clients share one source of truth (identical tables/columns/constraints
/// and the iCloud-sync bookkeeping objects). The database is encrypted at rest
/// via SQLCipher; the key and the stable owner UUID live in the macOS Keychain
/// (via [FlutterSecureStorage]) and are device-local — they never leave the
/// device and are never wiped by "delete private data".
///
/// The row-level lifecycle logic (seed / wipe / import) is exposed as static
/// helpers that operate on any [DatabaseExecutor], so it can be exercised
/// against an in-memory `sqflite_common_ffi` database in tests.
class DesktopPrivateDb {
  DesktopPrivateDb._();

  static DesktopPrivateDb? _instance;
  Database? _db;
  Future<Database>? _opening;

  /// New baseline file name — the pre-alignment mock used `evolve_private.db`.
  static const _dbFileName = 'evolve_private_v2.db';
  static const _keyStorageKey = 'evolve_private_db_key';
  static const _ownerStorageKey = 'evolve_private_owner_id';
  static const _avatarDirName = 'private_profile';

  static DesktopPrivateDb get instance {
    _instance ??= DesktopPrivateDb._();
    return _instance!;
  }

  /// After-write sync hook (iCloud sync trigger #2): set at app bootstrap to
  /// the [SyncWriteDebouncer]'s notifyWrite. Every private-mode mutation —
  /// here, in `PrivateDashboardRepository`, and in the private branches of the
  /// controllers — calls [notifyWrite] after committing. Deliberately NOT
  /// invoked by the sync engine's own applies (those go through
  /// [SyncLocalStore.applyUpsert]), so a pull can never re-trigger a push.
  static void Function()? onPrivateWrite;

  static void notifyWrite() => onPrivateWrite?.call();

  /// A [SyncLocalStore] over the opened private database, for the sync engine.
  Future<SyncLocalStore> syncStore() async => SyncLocalStore(await database);

  /// Persist [canonical] as this device's owner id after the sync engine
  /// re-keyed all local rows onto the canonical sync-owner (second-device
  /// merge). Without this, [ownerId] keeps returning the old device-local id
  /// and every owner-filtered query misses the re-keyed rows.
  Future<void> adoptOwner(String canonical) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: _ownerStorageKey, value: canonical);
  }

  /// Returns the open database, initializing it on first call. The open is
  /// serialized so concurrent callers share a single connection.
  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  /// The stable local owner UUID (created once, reused forever). Kept in the
  /// Keychain so it survives a data wipe and stays stable across restarts.
  Future<String> get ownerId async {
    const storage = FlutterSecureStorage();
    var id = await storage.read(key: _ownerStorageKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await storage.write(key: _ownerStorageKey, value: id);
    }
    return id;
  }

  /// Closes the database (e.g. before app shutdown).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle: delete / export / import
  // ---------------------------------------------------------------------------

  /// Deletes all private data — wipes every user-data row and the avatar files,
  /// then re-seeds an empty owner profile so the app stays usable **and stays in
  /// Private mode** (mirrors mobile's `deleteAllPrivateData`). The encryption key
  /// and owner UUID are intentionally preserved.
  ///
  /// Sync bookkeeping is reset too (mirrors mobile's fixes #6/#7): the wipe's
  /// delete triggers just queued a tombstone per row and the reseed re-dirtied
  /// a fresh profile — stale state that a later re-enable would push as
  /// deletes for records that no longer exist. `pending_zone_wipe` is
  /// PRESERVED so a full reset queued while offline still wipes the cloud zone
  /// on the next sync.
  Future<void> deleteAllPrivateData() async {
    final db = await database;
    final owner = await ownerId;
    await db.transaction((txn) async {
      await wipeUserData(txn);
      await seedProfile(txn, owner: owner, now: _now());
      await resetSyncBookkeeping(txn);
    });
    await _deletePrivateProfileFiles();
  }

  /// Clears `sync_state` and the delta-fetch token/last-sync in `sync_meta`,
  /// preserving `pending_zone_wipe` (see [deleteAllPrivateData]). Static so the
  /// FFI tests can exercise it against an in-memory database.
  static Future<void> resetSyncBookkeeping(DatabaseExecutor txn) async {
    await txn.delete(PrivateDbSchema.syncStateTable);
    await txn.update(
      PrivateDbSchema.syncMetaTable,
      {'server_change_token': null, 'last_full_sync_at': null},
      where: 'id = 1',
    );
  }

  /// Exports the entire private data space as a JSON-serializable map.
  Future<Map<String, dynamic>> exportData() async {
    final db = await database;
    final owner = await ownerId;
    Future<List<Map<String, dynamic>>> rows(String table) =>
        db.query(table, where: 'user_id = ?', whereArgs: [owner]);

    final profileRows = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [owner],
    );

    return {
      'exportDate': _now(),
      'mode': 'private',
      'profile': profileRows.isNotEmpty ? profileRows.first : null,
      'goals': await rows('goals'),
      'goal_logs': await rows('goal_logs'),
      'long_term_goals': await rows('long_term_goals'),
      'daily_moods': await rows('daily_moods'),
      'macro_goal_categories': await rows('macro_goal_categories'),
    };
  }

  /// Whether the user has opted in to sending private context to the external AI
  /// provider (persisted in the profiles row; false until explicitly granted).
  Future<bool> hasPrivateAiExternalConsent() async {
    final db = await database;
    final owner = await ownerId;
    final rows = await db.query(
      'profiles',
      columns: ['private_ai_external_consent'],
      where: 'id = ?',
      whereArgs: [owner],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first['private_ai_external_consent'] as int? ?? 0) == 1;
  }

  Future<void> setPrivateAiExternalConsent(bool granted) async {
    final db = await database;
    final owner = await ownerId;
    await db.update(
      'profiles',
      {'private_ai_external_consent': granted ? 1 : 0, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [owner],
    );
    notifyWrite();
  }

  /// Updates the profile's name / date of birth, stamping `updated_at` so the
  /// edit wins last-write-wins against older copies from other devices.
  Future<void> updateProfileFields({
    required String fullName,
    String? dateOfBirth,
  }) async {
    final db = await database;
    final owner = await ownerId;
    await db.update(
      'profiles',
      {
        'full_name': fullName,
        'date_of_birth': dateOfBirth,
        'updated_at': _now(),
      },
      where: 'id = ?',
      whereArgs: [owner],
    );
    notifyWrite();
  }

  /// Records a locally-picked avatar: points `profiles.avatar_url` at [path]
  /// (a normal, trigger-visible write — the user really edited their profile)
  /// and marks the avatar pseudo-record dirty so the image itself uploads as
  /// an encrypted CKAsset (no trigger covers that record).
  Future<void> setAvatarPath(String path) async {
    final db = await database;
    final owner = await ownerId;
    await db.update(
      'profiles',
      {'avatar_url': path, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [owner],
    );
    await SyncLocalStore(db).markAvatarDirty(owner);
    notifyWrite();
  }

  // ---------------------------------------------------------------------------
  // Avatar bytes (file side of the encrypted-CKAsset avatar sync)
  // ---------------------------------------------------------------------------

  /// Plaintext bytes of the current local avatar, or null when none is set or
  /// the file has gone missing (the engine then pushes a tombstone).
  Future<Uint8List?> readAvatarBytes() async {
    final db = await database;
    final owner = await ownerId;
    final rows = await db.query(
      'profiles',
      columns: ['avatar_url'],
      where: 'id = ?',
      whereArgs: [owner],
      limit: 1,
    );
    final path = rows.isEmpty ? null : rows.first['avatar_url'] as String?;
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
    final db = await database;
    final owner = await ownerId;
    final previous = await _currentAvatarPath(db, owner);

    final dir = await getApplicationSupportDirectory();
    final avatarDir = Directory(p.join(dir.path, _avatarDirName));
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
      } catch (error, stack) {
        AppLogger.error('Stale avatar cleanup failed', error, stack);
      }
    }
  }

  /// Apply a PULLED avatar tombstone: remove the local file and clear
  /// `profiles.avatar_url` without re-dirtying the profile row.
  Future<void> removePulledAvatar() async {
    final db = await database;
    final owner = await ownerId;
    final current = await _currentAvatarPath(db, owner);
    await SyncLocalStore(db)
        .setLocalOnlyColumn('profiles', owner, 'avatar_url', null);
    if (current != null && current.isNotEmpty) {
      try {
        final file = File(current);
        if (await file.exists()) await file.delete();
      } catch (error, stack) {
        AppLogger.error('Avatar removal cleanup failed', error, stack);
      }
    }
  }

  Future<String?> _currentAvatarPath(Database db, String owner) async {
    final rows = await db.query(
      'profiles',
      columns: ['avatar_url'],
      where: 'id = ?',
      whereArgs: [owner],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['avatar_url'] as String?;
  }

  /// Settings/preference columns that Private mode persists in the profiles row.
  static const _settingsColumns = {
    'username',
    'full_name',
    'language',
    'theme_mode',
    'accent_color',
    'pref_glass_effects',
    'pref_default_calendar_view',
    'pref_start_week_on_monday',
    'pref_show_weekend',
    'pref_haptic_feedback',
    'pref_time_format_24h',
    'pref_ai_suggestions',
    'pref_focus_mode',
    'pref_milestones',
    'pref_deep_work_insights',
    'notif_habit_reminders',
    'notif_goal_deadlines',
    'notif_ai_insights',
    'notif_weekly_reports',
    'notif_evening_review',
    'biometric_lock',
    'morning_brief_time',
    'evening_review_time',
    'date_of_birth',
  };

  /// Pure: filters [values] to known settings columns, coerces bools to 0/1,
  /// and re-forces `is_pro`/`sentry_consent` (unlocked / never-report). Empty
  /// when no known keys are present.
  static Map<String, Object?> sanitizeSettings(Map<String, dynamic> values) {
    final filtered = <String, Object?>{
      for (final e in values.entries)
        if (_settingsColumns.contains(e.key))
          e.key: e.value is bool ? (e.value == true ? 1 : 0) : e.value,
    };
    if (filtered.isEmpty) return const {};
    return {...filtered, 'is_pro': 1, 'sentry_consent': 0};
  }

  /// Persists Private-mode settings to the profiles row (the encrypted, Phase-2
  /// sync-ready store).
  Future<void> updateSettings(Map<String, dynamic> values) async {
    final sanitized = sanitizeSettings(values);
    if (sanitized.isEmpty) return;
    final db = await database;
    final owner = await ownerId;
    await db.update(
      'profiles',
      {...sanitized, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [owner],
    );
    notifyWrite();
  }

  /// Writes a habit log from a macOS notification action (Done/Skip), computing
  /// the streak from the stored history so it matches the foreground toggle.
  ///
  /// Mirrors mobile's `setHabitLogWithStreak`: it loads the habit's full log
  /// history into a `{ dayKey: { goalId: status } }` map, applies the new
  /// [status] for [date] in-memory, and delegates to the shared [computeStreak]
  /// for BOTH 'done' and 'missed' so the stored streak is the correct signed
  /// value (positive 🔥 run for 'done', negative 💔 run for 'missed').
  Future<void> setHabitLogFromNotification({
    required String goalId,
    required String status, // 'done' | 'missed'
    DateTime? date,
  }) async {
    final db = await database;
    final owner = await ownerId;
    final day = date ?? DateTime.now();
    final dayKey = _dayKey(day);
    final now = _now();

    // Load the existing logs for this habit, keyed the same way computeStreak
    // reads them (yyyy-MM-dd, matching the stored `date` values), then apply the
    // new status for `date` so the toggled day is visible to the algorithm.
    final rows = await db.query(
      'goal_logs',
      columns: ['date', 'status'],
      where: 'goal_id = ?',
      whereArgs: [goalId],
    );
    final logs = <String, Map<String, String>>{};
    for (final row in rows) {
      final rowDate = row['date'] as String;
      logs.putIfAbsent(rowDate, () => <String, String>{})[goalId] =
          row['status'] as String;
    }
    (logs[dayKey] ??= <String, String>{})[goalId] = status;

    // Resolve the habit's start_date so the run can't walk before it.
    final goalRows = await db.query(
      'goals',
      columns: ['start_date'],
      where: 'id = ?',
      whereArgs: [goalId],
      limit: 1,
    );
    final startDate = goalRows.isEmpty
        ? DateTime(day.year, day.month, day.day)
        : DateTime.tryParse(goalRows.first['start_date'] as String? ?? '') ??
              DateTime(day.year, day.month, day.day);

    final streak = computeStreak(
      habitId: goalId,
      date: day,
      logs: logs,
      startDate: startDate,
    );

    await db.insert('goal_logs', {
      'id': const Uuid().v4(),
      'user_id': owner,
      'goal_id': goalId,
      'date': dayKey,
      'status': status,
      'streak': streak,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyWrite();
  }

  Future<void> importData({
    required Map<String, dynamic> backupData,
    required bool replaceExisting,
  }) async {
    final db = await database;
    final owner = await ownerId;
    await db.transaction((txn) async {
      await applyImport(
        txn,
        owner: owner,
        backupData: backupData,
        replaceExisting: replaceExisting,
        now: _now(),
      );
    });
    notifyWrite();
  }

  // ---------------------------------------------------------------------------
  // Static row-level helpers (testable against any DatabaseExecutor)
  // ---------------------------------------------------------------------------

  /// Idempotently seeds the owner `profiles` row + the vestigial
  /// `goal_category_settings` row so profile/settings writes and every
  /// `user_id` foreign key have a valid parent.
  static Future<void> seedProfile(
    DatabaseExecutor db, {
    required String owner,
    required String now,
  }) async {
    await db.insert('profiles', {
      'id': owner,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('goal_category_settings', {
      'id': const Uuid().v4(),
      'user_id': owner,
      'mappings': '{}',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Deletes every user-data row (children before parents).
  static Future<void> wipeUserData(DatabaseExecutor txn) async {
    await txn.delete('goal_logs');
    await txn.delete('daily_moods');
    await txn.delete('long_term_goals');
    await txn.delete('macro_goal_categories');
    await txn.delete('goals');
    await txn.delete('goal_category_settings');
    await txn.delete('profiles');
  }

  /// Inserts backup rows under [owner], coalescing every NOT-NULL column so the
  /// aligned schema is satisfied. Parents are inserted before children.
  ///
  /// Import is resilient: a single malformed row is skipped rather than aborting
  /// the whole transaction (which would roll back an otherwise-valid import).
  /// In merge mode ([replaceExisting] false), imported categories whose
  /// `(user_id, name)` collides with an existing row reuse that row instead of
  /// being silently dropped, and referencing macro goals are remapped to the
  /// resolved id so no `category_id` is left dangling.
  static Future<void> applyImport(
    DatabaseExecutor txn, {
    required String owner,
    required Map<String, dynamic> backupData,
    required bool replaceExisting,
    required String now,
  }) async {
    if (replaceExisting) {
      // Wipe existing user data (profiles/settings are preserved).
      await txn.delete('goal_logs');
      await txn.delete('daily_moods');
      await txn.delete('long_term_goals');
      await txn.delete('macro_goal_categories');
      await txn.delete('goals');
    }

    // Maps an imported category id to the id actually used in the DB. In merge
    // mode a name collision resolves to the pre-existing row's id so referencing
    // macro goals can be remapped (Bug 3); otherwise it is the imported id.
    final categoryIdRemap = <String, String>{};

    for (final cat in _listOf(backupData['macro_goal_categories'])) {
      final importedId = (cat['id'] as String?) ?? const Uuid().v4();
      final name = cat['name'] ?? 'Categoria';

      if (!replaceExisting) {
        // Merge mode: reuse an existing category with the same (user_id, name)
        // rather than letting the UNIQUE constraint silently drop this row.
        final existing = await txn.query(
          'macro_goal_categories',
          columns: ['id'],
          where: 'user_id = ? AND name = ?',
          whereArgs: [owner, name],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          categoryIdRemap[importedId] = existing.first['id'] as String;
          continue; // reuse existing; do not insert a duplicate
        }
      }

      categoryIdRemap[importedId] = importedId;
      await txn.insert('macro_goal_categories', {
        'id': importedId,
        'user_id': owner,
        'name': name,
        'color': cat['color'] ?? '#6B7280',
        'created_at': cat['created_at'] ?? now,
        'updated_at': cat['updated_at'] ?? cat['created_at'] ?? now,
        'archived_at': cat['archived_at'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Track which goal ids exist so goal_logs referencing a missing/orphan
    // goal_id can be skipped (the FK would otherwise abort the whole import).
    final importedGoalIds = <String>{};

    for (final g in _listOf(backupData['goals'])) {
      final goalId = (g['id'] as String?) ?? const Uuid().v4();
      importedGoalIds.add(goalId);
      await txn.insert('goals', {
        'id': goalId,
        'user_id': owner,
        'title': g['title'] ?? '',
        'description': g['description'],
        'icon': g['icon'],
        'color': g['color'] ?? '#3B82F6',
        'frequency_days': _encodeFrequency(g['frequency_days']),
        'start_date': g['start_date'] ?? g['created_at'] ?? now,
        'end_date': g['end_date'],
        'display_order': g['display_order'],
        'reminder_time': g['reminder_time'],
        'created_at': g['created_at'] ?? now,
        'updated_at': g['updated_at'] ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final l in _listOf(backupData['goal_logs'])) {
      final goalId = l['goal_id'];
      final date = l['date'];
      // Skip rows that would violate NOT NULL (goal_id, date) or the goal_id FK
      // (a goal that is not part of this import) instead of aborting.
      if (goalId == null || date == null) continue;
      if (!importedGoalIds.contains(goalId)) continue;
      await txn.insert('goal_logs', {
        'id': l['id'] ?? const Uuid().v4(),
        'user_id': owner,
        'goal_id': goalId,
        'date': date,
        'status': l['status'] ?? 'done',
        'value': l['value'],
        'streak': l['streak'] ?? 0,
        'created_at': l['created_at'] ?? now,
        'updated_at': l['updated_at'] ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final g in _listOf(backupData['long_term_goals'])) {
      // Remap the category reference onto the resolved id so merge-mode name
      // collisions don't leave a dangling category_id (Bug 3).
      final importedCategoryId = g['category_id'] as String?;
      final categoryId = importedCategoryId == null
          ? null
          : categoryIdRemap[importedCategoryId] ?? importedCategoryId;
      await txn.insert('long_term_goals', {
        'id': g['id'] ?? const Uuid().v4(),
        'user_id': owner,
        'title': g['title'] ?? '',
        'status': g['status'] ?? 'active',
        'type': g['type'] ?? 'annual',
        'year': g['year'],
        'month': g['month'],
        'week_number': g['week_number'],
        'quarter': g['quarter'],
        'category_key': g['category_key'],
        'category_id': categoryId,
        'created_at': g['created_at'] ?? now,
        'updated_at': g['updated_at'] ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final m in _listOf(backupData['daily_moods'])) {
      final moodScore = _validScore(m['mood_score']);
      final energyScore = _validScore(m['energy_score']);
      // Both scores are NOT NULL with a CHECK (0..10); skip the row if either is
      // missing or out of range instead of aborting the transaction.
      if (moodScore == null || energyScore == null) continue;
      await txn.insert('daily_moods', {
        'id': m['id'] ?? const Uuid().v4(),
        'user_id': owner,
        'date': m['date'],
        'mood_score': moodScore,
        'energy_score': energyScore,
        'created_at': m['created_at'] ?? now,
        'updated_at': m['updated_at'] ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Restore the profile (name / date of birth / settings) onto the owner row.
    // sanitizeSettings filters to known columns, coerces bools, forces the
    // Private-mode invariants (is_pro=1 / sentry_consent=0), and drops the
    // local-path avatar_url — so an import can never smuggle in a foreign id,
    // entitlement, or broken avatar path.
    //
    // Wrapped so a single out-of-domain value from a foreign/older client (e.g.
    // an unknown theme_mode failing the CHECK) can't roll back the whole import,
    // honoring the same row-level resilience as the data inserts above.
    final profile = backupData['profile'];
    if (profile is Map) {
      final sanitized = sanitizeSettings(Map<String, dynamic>.from(profile));
      if (sanitized.isNotEmpty) {
        try {
          await txn.update(
            'profiles',
            {...sanitized, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [owner],
          );
        } catch (error, stack) {
          AppLogger.error('Skipped invalid profile on import', error, stack);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<Database> _open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbFileName);
    final key = await _encryptionKey();

    final db = await openDatabase(
      dbPath,
      version: PrivateDbSchema.version,
      password: key,
      onConfigure: PrivateDbSchema.onConfigure,
      onCreate: PrivateDbSchema.onCreate,
      onUpgrade: PrivateDbSchema.onUpgrade,
    );
    await seedProfile(db, owner: await ownerId, now: _now());
    _db = db;
    debugPrint('[DesktopPrivateDb] Opened schema v${PrivateDbSchema.version}.');
    return db;
  }

  Future<void> _deletePrivateProfileFiles() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final avatarDir = Directory(p.join(dir.path, _avatarDirName));
      if (await avatarDir.exists()) {
        await avatarDir.delete(recursive: true);
      }
    } catch (error, stack) {
      AppLogger.error('Unable to delete private profile files', error, stack);
    }
  }

  Future<String> _encryptionKey() async {
    const storage = FlutterSecureStorage();
    final existing = await storage.read(key: _keyStorageKey);
    if (existing != null && existing.length >= 32) return existing;
    final key = _generateKey();
    await storage.write(key: _keyStorageKey, value: key);
    return key;
  }

  /// 48 random bytes, base64url-encoded (matches the mobile client).
  static String _generateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(48, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static List<Map<String, dynamic>> _listOf(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  /// Coerces a backup mood/energy score to a valid `daily_moods` value, or null
  /// when it is missing or outside the schema's CHECK bound (0..10) so the row
  /// can be skipped instead of aborting the import.
  static int? _validScore(Object? value) {
    final int? score;
    if (value is int) {
      score = value;
    } else if (value is num) {
      score = value.toInt();
    } else if (value is String) {
      score = int.tryParse(value);
    } else {
      score = null;
    }
    if (score == null || score < 0 || score > 10) return null;
    return score;
  }

  /// Frequency days are stored as a JSON-encoded int list. Accepts either an
  /// already-encoded string or a raw list from a backup.
  static String? _encodeFrequency(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return jsonEncode(value);
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
