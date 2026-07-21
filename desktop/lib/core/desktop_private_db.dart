import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/import_merge.dart';
import 'package:evolve_desktop/core/import_merge_stats.dart';
import 'package:evolve_desktop/core/secure_storage_utils.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:evolve_desktop/core/streak_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Thrown when the SQLCipher key needed to open the encrypted private database
/// is unreadable from the Keychain while the database file still exists on
/// disk. This is a *recoverable* lockout, not a crash bug: the existing local
/// data can't be decrypted (its key is gone — typically after a device
/// migration or a change to the app's code-signing identity, which rotates the
/// Keychain access group the key lives under), but the file is intact enough
/// that regenerating the key would silently brick it (SQLCipher error 26). The
/// guard fails closed and throws this instead; callers offer the user an
/// explicit reset via [DesktopPrivateDb.resetLockedDatabase] and continue.
/// Mirrors mobile's `PrivateDatabaseLockedException`.
class PrivateDatabaseLockedException implements Exception {
  const PrivateDatabaseLockedException();

  // Kept byte-identical to the original StateError message so any UI that
  // surfaces `error.toString()` (and mobile parity) is unchanged.
  @override
  String toString() =>
      'Private database key unavailable while the database file exists; '
      'refusing to regenerate it so the data stays recoverable.';
}

/// The slice of the private store the locked-DB recovery flow needs. Extracted
/// so the recovery POLICY ([openOrRecoverPrivate]) is unit-testable with a fake,
/// mirroring mobile's `PrivateDataStore`. [DesktopPrivateDb] is the production
/// implementation.
abstract interface class PrivateRecoveryStore {
  /// Opens the encrypted DB, running the owner self-heal. Throws
  /// [PrivateDatabaseLockedException] when the file exists but its key is gone.
  Future<void> ensureReady();

  /// Hard-deletes the orphaned encrypted file (+ sidecars + avatar folder) so
  /// the next open mints a fresh key. DESTRUCTIVE — only behind an explicit,
  /// user-confirmed action. Never throws.
  Future<void> resetLockedDatabase();

  /// Auto-recovery: renames the locked DB (+ sidecars) ASIDE to a `.bak` set and
  /// clears the key, so a fresh empty DB can be re-pulled from iCloud. Reversible
  /// via [restoreStashedDatabase]. Returns true if a DB file was stashed. Never
  /// throws.
  Future<bool> stashLockedDatabase();

  /// Undo [stashLockedDatabase]: discards the fresh (empty) DB and restores the
  /// stashed copy, leaving it LOCKED again so a later launch retries recovery.
  /// Never throws.
  Future<void> restoreStashedDatabase();

  /// Commit [stashLockedDatabase]: the cloud re-pull succeeded, so delete the
  /// stashed `.bak` set for good. Never throws.
  Future<void> discardStashedDatabase();
}

/// Manages the encrypted local SQLite database used by Private mode.
///
/// The schema is [PrivateDbSchema], ported verbatim from the mobile client so
/// both clients share one source of truth (identical tables/columns/constraints
/// and the iCloud-sync bookkeeping objects). The database is encrypted at rest
/// via SQLCipher; the key and the stable owner UUID live in the macOS Keychain
/// (via [SecureStorageUtils]'s device-local tier) and are device-local — they
/// never leave the device and are never wiped by "delete private data".
///
/// The row-level lifecycle logic (seed / wipe / import) is exposed as static
/// helpers that operate on any [DatabaseExecutor], so it can be exercised
/// against an in-memory `sqflite_common_ffi` database in tests.
class DesktopPrivateDb implements PrivateRecoveryStore {
  DesktopPrivateDb._();

  static DesktopPrivateDb? _instance;
  Database? _db;
  Future<Database>? _opening;

  /// Bumped whenever the DB file is reset/stashed/restored out from under an
  /// in-flight [_open]. An open that started before the bump discards its handle
  /// instead of caching one that points at a since-renamed/deleted (or freshly
  /// re-created empty) file. Mirrors mobile's `_openGeneration`.
  int _openGeneration = 0;

  /// In-memory cache of the owner id so an adopted/reconciled owner sticks for
  /// the session even if the Keychain write fails (mirrors mobile's `_ownerId`).
  String? _cachedOwnerId;

  /// New baseline file name — the pre-alignment mock used `evolve_private.db`.
  static const _dbFileName = 'evolve_private_v2.db';
  static const _keyStorageKey = 'evolve_private_db_key';
  static const _ownerStorageKey = 'evolve_private_owner_id';
  static const _avatarDirName = 'private_profile';

  /// Suffix for the temporary "stashed" copy of a locked DB kept during an
  /// auto-recovery cloud re-pull so it can be restored if the pull didn't run.
  static const _bakSuffix = '.recovery-bak';

  /// Native bridge that flags the private-data directory as backup-excluded.
  /// Same channel contract as the iOS bridge (`evolve/private_storage`).
  static const _privateStorageChannel = MethodChannel('evolve/private_storage');

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
    _cachedOwnerId = canonical;
    await SecureStorageUtils.writeDeviceLocal(_ownerStorageKey, canonical);
  }

  /// Returns the open database, initializing it on first call. The open is
  /// serialized so concurrent callers share a single connection.
  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  /// Opens the DB (running the owner self-heal) without exposing the handle —
  /// the recovery flow only needs "did it open, or is it locked?". Throws
  /// [PrivateDatabaseLockedException] when the file exists but its key is gone.
  /// Mirrors mobile's `PrivateDataStore.ensureReady`.
  @override
  Future<void> ensureReady() async {
    await database;
  }

  /// The stable local owner UUID (created once, reused forever). Kept in the
  /// Keychain so it survives a data wipe and stays stable across restarts.
  Future<String> get ownerId async {
    final cached = _cachedOwnerId;
    if (cached != null && cached.isNotEmpty) return cached;
    var id = await SecureStorageUtils.readDeviceLocal(_ownerStorageKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await SecureStorageUtils.writeDeviceLocal(_ownerStorageKey, id);
    }
    _cachedOwnerId = id;
    return id;
  }

  /// Closes the database (e.g. before app shutdown).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Whether the encrypted private database file exists on disk. Used at startup
  /// to recover a Private-mode user whose data-mode preference was lost (mirrors
  /// mobile's `PrivateLocalDatabase.databaseFileExists`).
  static Future<bool> databaseFileExists() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _dbFileName)).exists();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle: delete / export / import
  // ---------------------------------------------------------------------------

  /// Whether the private database is in the recoverable *locked* state: the
  /// encrypted file exists on disk but its SQLCipher key is unreadable from the
  /// Keychain, so [database] would throw [PrivateDatabaseLockedException].
  /// Lets callers offer an in-app recovery affordance instead of a dead end.
  /// Cheap (one file stat + one Keychain read); safe to call before an import
  /// or from a settings screen.
  Future<bool> isDatabaseLocked() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final dbFileExists = await File(p.join(dir.path, _dbFileName)).exists();
      if (!dbFileExists) return false;
      final key = await SecureStorageUtils.readDeviceLocal(_keyStorageKey);
      return key == null || key.length < 32;
    } catch (error, stack) {
      // A probe failure must never itself block the user; treat as "not locked"
      // and let the real open surface any genuine problem.
      AppLogger.warning('[DesktopPrivateDb] lock probe failed', error, stack);
      return false;
    }
  }

  /// Recovers from a [PrivateDatabaseLockedException] by deleting the orphaned
  /// encrypted database FILE (+ its `-wal`/`-shm` sidecars) and the avatar
  /// folder, and clearing any unreadable key remnant — so the next [database]
  /// open mints a fresh key over an empty schema. The device-local owner id is
  /// intentionally KEPT so identity stays stable across the reset.
  ///
  /// DESTRUCTIVE and irreversible: the existing local private data cannot be
  /// decrypted (its key is gone), so this must ONLY run behind an explicit,
  /// user-confirmed recovery action — never automatically (a merely transient
  /// Keychain miss would otherwise nuke recoverable data). Best-effort per
  /// file; a missing sidecar is not an error.
  @override
  Future<void> resetLockedDatabase() async {
    await _quiesceForFileMutation();

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbFileName);
    for (final path in [dbPath, '$dbPath-wal', '$dbPath-shm']) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (error, stack) {
        AppLogger.error(
          '[DesktopPrivateDb] locked reset: could not delete $path',
          error,
          stack,
        );
      }
    }

    await _deletePrivateProfileFiles();

    // Drop a short/stale key remnant so the next open takes the first-run path
    // and writes a fresh key under the CURRENT Keychain access group. A key
    // that is present-but-unreadable (rotated access group) is invisible to
    // delete too — harmless no-op; the next read misses it and mints fresh.
    try {
      await SecureStorageUtils.deleteDeviceLocal(_keyStorageKey);
    } catch (error, stack) {
      AppLogger.warning(
        '[DesktopPrivateDb] locked reset: key remnant delete failed',
        error,
        stack,
      );
    }

    AppLogger.warning(
      '[DesktopPrivateDb] locked database reset: orphaned file + key cleared; '
      'the next open mints a fresh key.',
    );
  }

  /// Bump the open generation, wait out any in-flight [_open] (so it can't
  /// re-create a file we're about to move/delete), and drop the cached handle.
  /// Shared by [resetLockedDatabase]/[stashLockedDatabase]/[restoreStashedDatabase],
  /// which all mutate the DB file directly. Mirrors mobile's
  /// `_quiesceForFileMutation`.
  Future<void> _quiesceForFileMutation() async {
    _openGeneration++;
    final pending = _opening;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // The in-flight open observes the generation bump and throws; ignore.
      }
    }
    try {
      await _db?.close();
    } catch (_) {
      // Best-effort: a locked DB was never opened / the handle is already dead.
    }
    _db = null;
    _opening = null;
  }

  @override
  Future<bool> stashLockedDatabase() async {
    await _quiesceForFileMutation();
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbFileName);
    var stashed = false;
    for (final suffix in ['', '-wal', '-shm']) {
      final src = File('$dbPath$suffix');
      final dst = File('$dbPath$suffix$_bakSuffix');
      try {
        if (await dst.exists()) await dst.delete();
        if (await src.exists()) {
          await src.rename(dst.path);
          if (suffix.isEmpty) stashed = true;
        }
      } catch (error, stack) {
        AppLogger.error('[DesktopPrivateDb] stash failed for $suffix', error, stack);
      }
    }
    // Drop the unreadable key remnant so the next open mints a fresh key for the
    // empty DB the cloud re-pull will populate. The stashed .bak still holds the
    // real (old-key-encrypted) data until we discard or restore it.
    try {
      await SecureStorageUtils.deleteDeviceLocal(_keyStorageKey);
    } catch (error, stack) {
      AppLogger.warning(
        '[DesktopPrivateDb] stash: key remnant delete failed', error, stack);
    }
    return stashed;
  }

  @override
  Future<void> restoreStashedDatabase() async {
    await _quiesceForFileMutation();
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbFileName);
    for (final suffix in ['', '-wal', '-shm']) {
      final fresh = File('$dbPath$suffix');
      final bak = File('$dbPath$suffix$_bakSuffix');
      try {
        if (await fresh.exists()) await fresh.delete();
        if (await bak.exists()) await bak.rename(fresh.path);
      } catch (error, stack) {
        AppLogger.error(
          '[DesktopPrivateDb] restore failed for $suffix', error, stack);
      }
    }
    // The restored DB is encrypted with the OLD (now-lost) key; drop the fresh
    // key minted for the discarded empty DB so isDatabaseLocked() reads true
    // again and a later launch re-enters the recovery flow.
    try {
      await SecureStorageUtils.deleteDeviceLocal(_keyStorageKey);
    } catch (error, stack) {
      AppLogger.warning(
        '[DesktopPrivateDb] restore: key remnant delete failed', error, stack);
    }
  }

  @override
  Future<void> discardStashedDatabase() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbFileName);
    for (final suffix in ['', '-wal', '-shm']) {
      final bak = File('$dbPath$suffix$_bakSuffix');
      try {
        if (await bak.exists()) await bak.delete();
      } catch (error, stack) {
        AppLogger.warning(
          '[DesktopPrivateDb] discard stash failed for $suffix', error, stack);
      }
    }
  }

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
    await txn.update(PrivateDbSchema.syncMetaTable, {
      'server_change_token': null,
      'last_full_sync_at': null,
    }, where: 'id = 1');
  }

  /// Exports the entire private data space as a JSON-serializable map.
  Future<Map<String, dynamic>> exportData() async {
    final db = await database;
    final owner = await ownerId;
    return exportSnapshot(db, owner: owner);
  }

  /// Builds the export payload from [db]. Static so the FFI round-trip tests
  /// can exercise it against an in-memory database.
  ///
  /// The shape mirrors the MOBILE private export
  /// (`mobile/lib/core/private_local_database.dart` `exportData`) key-for-key —
  /// `schemaVersion` + `settings` + camelCase container keys with snake_case
  /// DB-row elements — because mobile's import normalization only reads the
  /// camelCase containers for a `mode: 'private'` file. Emitting the same
  /// canonical shape from every client keeps a backup round-trippable across
  /// desktop, mobile, and back. `frequency_days` is stored JSON-encoded;
  /// decode it back to a list so re-imports are representation-stable.
  static Future<Map<String, dynamic>> exportSnapshot(
    DatabaseExecutor db, {
    required String owner,
  }) async {
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

    final profileRows = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [owner],
      limit: 1,
    );
    final profile = profileRows.isNotEmpty ? profileRows.first : null;

    // Full rows (ids + timestamps) so this export round-trips losslessly and an
    // import can reconcile by identity + last-write-wins.
    return {
      'schemaVersion': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'mode': 'private',
      'profile': profile,
      // On both clients the settings ARE profile columns; mobile exports the
      // same row under both keys (`loadSettingsRow() => loadProfileRow()`).
      'settings': profile,
      'habits': [
        for (final g in goals)
          {
            'id': g['id'],
            'title': g['title'],
            'description': g['description'],
            'icon': g['icon'],
            'color': g['color'],
            'frequency_days': decodeFrequencyDays(g['frequency_days']),
            'start_date': g['start_date'],
            'end_date': g['end_date'],
            'display_order': g['display_order'],
            'created_at': g['created_at'],
            'updated_at': g['updated_at'],
            'reminder_time': g['reminder_time'],
            // Round-trip the auto-verification rule so backup/restore keeps it.
            'verify_provider': g['verify_provider'],
            'verify_metric': g['verify_metric'],
            'verify_comparator': g['verify_comparator'],
            'verify_threshold': g['verify_threshold'],
            'verify_unit': g['verify_unit'],
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

  /// Decodes a stored `frequency_days` value (JSON-encoded TEXT in the private
  /// DB, a real list from Supabase) to a plain list for the portable export
  /// file. An unparseable value is passed through unchanged rather than lost.
  static Object? decodeFrequencyDays(Object? stored) {
    if (stored == null || stored is List) return stored;
    if (stored is String) {
      try {
        final decoded = jsonDecode(stored);
        if (decoded is List) return decoded;
      } catch (_) {
        // fall through: keep the original representation
      }
    }
    return stored;
  }

  /// Decodes a stored `frequency_days` value to canonical ISO weekdays for the
  /// streak/scheduling helpers: a `List<int>` (1-7), or null for "every day". An
  /// empty or entirely-unusable value becomes null — never an empty list, which
  /// would mean "no day" and spin the streak's scheduled-day search.
  static List<int>? frequencyDaysList(Object? stored) {
    final decoded = decodeFrequencyDays(stored);
    if (decoded is! List) return null;
    final days = decoded
        .map((e) => e is int ? e : (e is num ? e.toInt() : int.tryParse('$e')))
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toList();
    return days.isEmpty ? null : days;
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
  Future<Uint8List?> readAvatarBytes() async =>
      (await resolveAvatarFile())?.readAsBytes();

  /// Whether an avatar is CONFIGURED — `profiles.avatar_url` is set — whether or
  /// not its file can currently be read.
  ///
  /// The engine needs this to tell "the user removed their avatar" (a tombstone
  /// that must propagate) apart from "we lost the file" (which must never be
  /// replicated as a deletion, or one device losing its own copy destroys the
  /// image everywhere). See [SyncAvatarStore.hasAvatarConfigured].
  Future<bool> hasAvatarConfigured() async {
    final db = await database;
    final owner = await ownerId;
    final rows = await db.query('profiles',
        columns: ['avatar_url'], where: 'id = ?', whereArgs: [owner], limit: 1);
    final path = rows.isEmpty ? null : rows.first['avatar_url'] as String?;
    return path != null && path.isNotEmpty;
  }

  /// The avatar file as it exists on THIS device right now, or null if it
  /// cannot be found.
  ///
  /// Resolves by BASENAME against the current container before trusting the
  /// stored string. `profiles.avatar_url` holds an absolute path, and a
  /// container path is not a stable identifier — iOS regenerates it across
  /// reinstalls, and a Mac can have one change when the app is re-signed or
  /// migrated. Kept identical to mobile deliberately: divergence between the two
  /// apps in exactly this kind of helper is how the accent-colour and
  /// settings-readback bugs happened.
  ///
  /// Self-healing rather than a migration — one extra stat, no schema change,
  /// idempotent, and it repairs a database already carrying a stale path.
  Future<File?> resolveAvatarFile() async {
    final db = await database;
    final owner = await ownerId;
    final rows = await db.query('profiles',
        columns: ['avatar_url'], where: 'id = ?', whereArgs: [owner], limit: 1);
    final stored = rows.isEmpty ? null : rows.first['avatar_url'] as String?;
    if (stored == null || stored.isEmpty) return null;
    final dir = await getApplicationSupportDirectory();
    for (final candidate in avatarPathCandidates(
      stored: stored,
      supportDir: dir.path,
      avatarDirName: _avatarDirName,
    )) {
      final file = File(candidate);
      if (await file.exists()) return file;
    }
    return null;
  }

  /// [resolveAvatarFile] as a path, for the UI.
  Future<String?> resolveAvatarPath() async =>
      (await resolveAvatarFile())?.path;

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

    await SyncLocalStore(
      db,
    ).setLocalOnlyColumn('profiles', owner, 'avatar_url', path);

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
    await SyncLocalStore(
      db,
    ).setLocalOnlyColumn('profiles', owner, 'avatar_url', null);
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
    // `biometric_lock` is deliberately ABSENT. It is a
    // PrivateDbSchema.deviceLocalProfileColumn — device capability differs, so
    // a value another device decided must never be adopted here. The sync
    // engine already strips it on push; leaving it in this allow-list let a
    // BACKUP FILE do through the import restore exactly what the engine
    // forbids over the wire. Nothing on desktop writes it through
    // sanitizeSettings either: the biometric controller owns it in
    // SecureStorage/SharedPreferences.
    'morning_brief_time',
    'evening_review_time',
    'date_of_birth',
  };

  /// Pure: filters [values] to known settings columns and coerces bools to 0/1.
  /// Empty when no known keys are present.
  ///
  /// It deliberately does NOT stamp `is_pro: 1` / `sentry_consent: 0` any more.
  /// Both are [PrivateDbSchema.deviceLocalProfileColumns] now, so appending them
  /// to every settings write meant toggling any unrelated preference on the Mac
  /// re-published an entitlement and a consent decision the Mac had no business
  /// asserting — on the iPhone that silently reset crash-reporting consent. The
  /// Private-mode invariants are seeded once by [seedProfile] and owned by the
  /// device from then on.
  ///
  /// The [PrivateDbSchema.deviceLocalProfileColumns] subtraction is structural
  /// rather than a hand-maintained coincidence: the rule "no device-local
  /// column is decidable by another device, or by a file" now derives from the
  /// single shared declaration, so a future addition to that list is honoured
  /// here for free instead of quietly reopening the hole `biometric_lock` sat
  /// in. It only READS an existing const — nothing in the shared package is
  /// widened.
  static Map<String, Object?> sanitizeSettings(Map<String, dynamic> values) {
    return <String, Object?>{
      for (final e in values.entries)
        if (_settingsColumns.contains(e.key) &&
            !PrivateDbSchema.deviceLocalProfileColumns.contains(e.key))
          e.key: e.value is bool ? (e.value == true ? 1 : 0) : e.value,
    };
  }

  // There is deliberately NO `updateSettings(Map)` here any more.
  //
  // It had zero callers and was a trap: it wrote ONLY the legacy `profiles`
  // columns, and [SyncedSettingsStore.readAll] lets a `user_settings` row beat
  // a column by design. So the obvious-looking "settings writer" would have
  // returned normally, fired notifyWrite(), and then been silently shadowed on
  // the next read — the setting appears to save, reverts, and never reaches the
  // user's iPhone. Use [writeSyncedSettings] for anything in
  // [PrivateDbSchema.syncedSettingKeys] and [updateProfileFields] for
  // name / date of birth.

  /// Every synced setting for this device's owner, row-first with the legacy
  /// `profiles`-column fallback. Keys absent from BOTH stores are omitted, so a
  /// caller can tell "never set" from "set to null" and keep its own default.
  ///
  /// The read counterpart of [writeSyncedSettings], and the private-mode
  /// equivalent of the Supabase `profiles` select the settings page used to be
  /// able to do only when signed in. Mirrors mobile's `loadSettingsRow`.
  Future<Map<String, String?>> loadSettingsRow() async {
    final db = await database;
    final owner = await ownerId;
    return SyncedSettingsStore(db).readAll(owner);
  }

  /// Writes settings through the shared [SyncedSettingsStore], which dual-writes
  /// the per-key `user_settings` row AND the legacy `profiles` column so a
  /// not-yet-updated device keeps seeing the change.
  ///
  /// Keys must be in [PrivateDbSchema.syncedSettingKeys]; the store throws
  /// otherwise rather than silently dropping a setting that would then refuse to
  /// travel between devices.
  Future<void> writeSyncedSettings(Map<String, String?> values) async {
    if (values.isEmpty) return;
    final db = await database;
    final owner = await ownerId;
    await SyncedSettingsStore(db).writeAll(owner, values);
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

    // Resolve the habit's start_date (so the run can't walk before it) and its
    // weekly schedule (so off-days are transparent to the streak).
    final goalRows = await db.query(
      'goals',
      columns: ['start_date', 'frequency_days'],
      where: 'id = ?',
      whereArgs: [goalId],
      limit: 1,
    );
    final startDate = goalRows.isEmpty
        ? DateTime(day.year, day.month, day.day)
        : DateTime.tryParse(goalRows.first['start_date'] as String? ?? '') ??
              DateTime(day.year, day.month, day.day);
    final frequencyDays = goalRows.isEmpty
        ? null
        : frequencyDaysList(goalRows.first['frequency_days']);

    final streak = computeStreak(
      habitId: goalId,
      date: day,
      logs: logs,
      startDate: startDate,
      frequencyDays: frequencyDays,
    );

    // Upsert by (goal_id, date) with an explicit update-or-insert rather than
    // INSERT OR REPLACE: on a UNIQUE conflict OR REPLACE does DELETE+INSERT,
    // which fires the AFTER-DELETE sync-tombstone trigger and pushes a fresh id
    // to iCloud (churn). Reusing the stable row id keeps only the AFTER-UPDATE
    // (dirty) trigger — matching the foreground toggle in
    // PrivateDashboardRepository.setHabitStatus.
    final existing = await db.query(
      'goal_logs',
      columns: ['id'],
      where: 'goal_id = ? AND date = ?',
      whereArgs: [goalId, dayKey],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        'goal_logs',
        {'status': status, 'streak': streak, 'updated_at': now},
        where: 'goal_id = ? AND date = ?',
        whereArgs: [goalId, dayKey],
      );
    } else {
      await db.insert('goal_logs', {
        'id': const Uuid().v4(),
        'user_id': owner,
        'goal_id': goalId,
        'date': dayKey,
        'status': status,
        'streak': streak,
        'created_at': now,
        'updated_at': now,
      });
    }
    notifyWrite();
  }

  /// Imports [backupData] (canonical shape) into the private DB and returns
  /// the per-entity merge outcome. The whole import is one transaction; the
  /// dirty/tombstone triggers record every row it touches, and [notifyWrite]
  /// schedules the iCloud push after the commit.
  Future<ImportMergeStats> importData({
    required Map<String, dynamic> backupData,
    required bool replaceExisting,
  }) async {
    final db = await database;
    final owner = await ownerId;
    final stats = await db.transaction(
      (txn) => applyImport(
        txn,
        owner: owner,
        backupData: backupData,
        replaceExisting: replaceExisting,
        now: _now(),
      ),
    );
    notifyWrite();
    return stats;
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
      // Seed the same preference columns mobile's _ensureProfile writes so a
      // freshly-seeded (and CloudKit-synced) profile row is byte-identical
      // across platforms. Critically `language: 'system'` — the schema DEFAULT
      // is 'it', which would otherwise propagate via last-write-wins and flip a
      // synced device's language to Italian. Only applied on first creation
      // (ConflictAlgorithm.ignore), never overwriting an existing choice.
      'language': 'system',
      'theme_mode': 'dark',
      'accent_color': '#FFFFFF',
      'pref_default_calendar_view': 'settimana',
      'is_pro': 1,
      'sentry_consent': 0,
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

  /// Applies backup data under [owner], coalescing every NOT-NULL column so
  /// the aligned schema is satisfied. Parents are written before children.
  ///
  /// When [replaceExisting] is true, wipes the five user-data tables first and
  /// inserts everything fresh (profile/settings are left untouched by the
  /// wipe). When false, performs a **true merge** mirroring mobile's
  /// `applyPrivateImportMerge`: records are matched by identity and reconciled
  /// with last-write-wins —
  ///   - goals & macro goals by `id`;
  ///   - goal logs by their natural key `(goal_id, date)`;
  ///   - daily moods by their natural key `(user_id, date)`;
  ///   - categories by `id`, else by case-insensitive name (existing wins on a
  ///     match; only a missing `archived_at` is filled from the import) — see
  ///     [reconcileCategoriesByName], shared with the cloud plan.
  ///
  /// Streaks are recomputed from the merged log history for every goal whose
  /// logs changed, so the denormalized `goal_logs.streak` is never trusted
  /// from the file.
  ///
  /// Import stays resilient: a malformed row is skipped rather than aborting
  /// the whole transaction (which would roll back an otherwise-valid import).
  /// Callers going through [DesktopBackupImportService] get invalid rows
  /// dropped AND counted upfront by `validateCanonical`; the inline guards
  /// here are the last line of defense for direct callers.
  static Future<ImportMergeStats> applyImport(
    DatabaseExecutor txn, {
    required String owner,
    required Map<String, dynamic> backupData,
    required bool replaceExisting,
    required String now,
  }) async {
    final stats = ImportMergeStats(replaced: replaceExisting);

    if (replaceExisting) {
      // Wipe existing user data (profiles/settings are preserved). The delete
      // triggers queue a tombstone per row — deliberate: replace-mode deletions
      // must propagate to the other devices on the next sync.
      await txn.delete('goal_logs');
      await txn.delete('daily_moods');
      await txn.delete('long_term_goals');
      await txn.delete('macro_goal_categories');
      await txn.delete('goals');
    }

    // ── Categories: id, else case-insensitive name (shared brain with the
    // cloud plan). macro_goal_categories has UNIQUE(user_id, name), so a
    // same-name insert would collide; matching by name and remapping the
    // referencing macro goals is mandatory. ──
    final existingCats = replaceExisting
        ? const <Map<String, Object?>>[]
        : await txn.query(
            'macro_goal_categories',
            columns: ['id', 'name', 'archived_at'],
            where: 'user_id = ?',
            whereArgs: [owner],
          );
    final rec = reconcileCategoriesByName(
      categories: _listOf(backupData['macro_goal_categories']),
      existing: existingCats,
      newId: () => const Uuid().v4(),
    );
    final catRemap = <String, String>{...rec.remap};
    final validCatIds = <String>{...rec.validIds};

    for (final fill in rec.archiveFills) {
      await txn.update(
        'macro_goal_categories',
        {'archived_at': fill.archivedAt, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [fill.id],
      );
      stats.categories.updated++;
    }
    stats.categories.unchanged += rec.unchanged;

    for (final cat in rec.toInsert) {
      final importedId = cat['id'] as String;
      final name = cat['name'] ?? 'Categoria';
      final rid = await txn.insert('macro_goal_categories', {
        'id': importedId,
        'user_id': owner,
        'name': name,
        'color': cat['color'] ?? '#6B7280',
        'created_at': cat['created_at'] ?? now,
        'updated_at': cat['updated_at'] ?? cat['created_at'] ?? now,
        'archived_at': cat['archived_at'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (rid != 0) {
        stats.categories.added++;
      } else {
        // Insert was ignored — a colliding row exists that the preloaded set
        // missed (e.g. an exact-name duplicate raced in). Remap onto it so
        // referencing macro goals never dangle.
        final row = await txn.query(
          'macro_goal_categories',
          columns: ['id'],
          where: 'user_id = ? AND name = ?',
          whereArgs: [owner, name],
          limit: 1,
        );
        if (row.isNotEmpty) {
          final fid = row.first['id'] as String;
          catRemap[importedId] = fid;
          validCatIds.add(fid);
        }
        stats.categories.unchanged++;
      }
    }

    // ── Goals: identity by id, last-write-wins by updated_at. ──
    final existingGoals = replaceExisting
        ? const <String, Map<String, Object?>>{}
        : {
            for (final r in await txn.query(
              'goals',
              columns: ['id', 'created_at', 'updated_at'],
              where: 'user_id = ?',
              whereArgs: [owner],
            ))
              r['id'] as String: r,
          };
    // Logs may attach to goals that already exist locally (merge mode) as well
    // as to goals introduced by this import; anything else is orphan-skipped
    // (the FK would otherwise abort the whole import).
    final knownGoalIds = <String>{...existingGoals.keys};

    for (final g in _listOf(backupData['goals'])) {
      final id = (g['id'] as String?) ?? const Uuid().v4();
      final existing = existingGoals[id];
      if (existing == null) {
        // Only register the goal as "known" and count it if the row actually
        // landed (rid == 0 means INSERT OR IGNORE dropped it). This keeps a
        // non-inserted goal out of knownGoalIds so its logs are correctly
        // orphan-skipped instead of FK-aborting the whole transaction.
        final rid = await txn.insert(
          'goals',
          _goalRow(g, id, owner, (g['created_at'] as String?) ?? now, now),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (rid != 0) {
          knownGoalIds.add(id);
          stats.habits.added++;
        }
      } else if (incomingWins(
        incoming: g['updated_at'] as String?,
        existing: existing['updated_at'] as String?,
      )) {
        final n = await txn.update(
          'goals',
          _goalRow(g, id, owner, existing['created_at'] as String? ?? now, now),
          where: 'id = ?',
          whereArgs: [id],
        );
        if (n > 0) {
          stats.habits.updated++;
        } else {
          stats.habits.unchanged++;
        }
      } else {
        stats.habits.unchanged++;
      }
    }

    // ── Macro goals: identity by id, LWW; category_id remapped onto the merged
    // category, nulled if it would dangle (the insert would otherwise violate
    // the FK and abort). ──
    final existingMacros = replaceExisting
        ? const <String, Map<String, Object?>>{}
        : {
            for (final r in await txn.query(
              'long_term_goals',
              columns: ['id', 'created_at', 'updated_at'],
              where: 'user_id = ?',
              whereArgs: [owner],
            ))
              r['id'] as String: r,
          };

    for (final g in _listOf(backupData['long_term_goals'])) {
      final id = (g['id'] as String?) ?? const Uuid().v4();
      final importedCatId = g['category_id'] as String?;
      final remapped = importedCatId == null
          ? null
          : (catRemap[importedCatId] ?? importedCatId);
      final categoryId = (remapped != null && validCatIds.contains(remapped))
          ? remapped
          : null;
      final existing = existingMacros[id];
      if (existing == null) {
        final rid = await txn.insert(
          'long_term_goals',
          _macroRow(
            g,
            id,
            owner,
            categoryId,
            (g['created_at'] as String?) ?? now,
            now,
          ),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (rid != 0) {
          stats.macroGoals.added++;
        }
      } else if (incomingWins(
        incoming: g['updated_at'] as String?,
        existing: existing['updated_at'] as String?,
      )) {
        final n = await txn.update(
          'long_term_goals',
          _macroRow(
            g,
            id,
            owner,
            categoryId,
            existing['created_at'] as String? ?? now,
            now,
          ),
          where: 'id = ?',
          whereArgs: [id],
        );
        if (n > 0) {
          stats.macroGoals.updated++;
        } else {
          stats.macroGoals.unchanged++;
        }
      } else {
        stats.macroGoals.unchanged++;
      }
    }

    // ── Goal logs: identity by (goal_id, date), LWW. Orphan logs (no goal) are
    // skipped to respect the FK. ──
    final existingLogs = replaceExisting
        ? const <String, Map<String, Object?>>{}
        : {
            for (final r in await txn.query(
              'goal_logs',
              columns: ['id', 'goal_id', 'date', 'updated_at'],
              where: 'user_id = ?',
              whereArgs: [owner],
            ))
              '${r['goal_id']}|${r['date']}': r,
          };
    final affectedGoals = <String>{};

    for (final l in _listOf(backupData['goal_logs'])) {
      final goalId = l['goal_id'] as String?;
      final date = l['date'] as String?;
      if (goalId == null || date == null || !knownGoalIds.contains(goalId)) {
        continue;
      }
      final key = '$goalId|$date';
      final existing = existingLogs[key];
      if (existing == null) {
        final rid = await txn.insert('goal_logs', {
          'id': (l['id'] as String?) ?? const Uuid().v4(),
          'user_id': owner,
          'goal_id': goalId,
          'date': date,
          'status': l['status'] ?? 'done',
          'value': l['value'],
          'streak': l['streak'] ?? 0,
          'created_at': l['created_at'] ?? now,
          'updated_at': l['updated_at'] ?? now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (rid != 0) {
          affectedGoals.add(goalId);
          stats.logs.added++;
        }
      } else if (incomingWins(
        incoming: l['updated_at'] as String?,
        existing: existing['updated_at'] as String?,
      )) {
        final n = await txn.update(
          'goal_logs',
          {
            'status': l['status'] ?? 'done',
            'value': l['value'],
            'updated_at': l['updated_at'] ?? now,
          },
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
        if (n > 0) {
          affectedGoals.add(goalId);
          stats.logs.updated++;
        } else {
          stats.logs.unchanged++;
        }
      } else {
        stats.logs.unchanged++;
      }
    }

    // ── Daily moods: identity by (user_id, date), LWW. ──
    final existingMoods = replaceExisting
        ? const <String, Map<String, Object?>>{}
        : {
            for (final r in await txn.query(
              'daily_moods',
              columns: ['id', 'date', 'updated_at'],
              where: 'user_id = ?',
              whereArgs: [owner],
            ))
              r['date'] as String: r,
          };

    for (final m in _listOf(backupData['daily_moods'])) {
      final date = m['date'] as String?;
      final moodScore = _validScore(m['mood_score']);
      final energyScore = _validScore(m['energy_score']);
      // date/scores are NOT NULL with a CHECK (0..10); skip the row if any is
      // missing or out of range instead of aborting the transaction.
      if (date == null || moodScore == null || energyScore == null) continue;
      final existing = existingMoods[date];
      if (existing == null) {
        final rid = await txn.insert('daily_moods', {
          'id': (m['id'] as String?) ?? const Uuid().v4(),
          'user_id': owner,
          'date': date,
          'mood_score': moodScore,
          'energy_score': energyScore,
          'created_at': m['created_at'] ?? now,
          'updated_at': m['updated_at'] ?? now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        if (rid != 0) {
          stats.moods.added++;
        }
      } else if (incomingWins(
        incoming: m['updated_at'] as String?,
        existing: existing['updated_at'] as String?,
      )) {
        final n = await txn.update(
          'daily_moods',
          {
            'mood_score': moodScore,
            'energy_score': energyScore,
            'updated_at': m['updated_at'] ?? now,
          },
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
        if (n > 0) {
          stats.moods.updated++;
        } else {
          stats.moods.unchanged++;
        }
      } else {
        stats.moods.unchanged++;
      }
    }

    // ── Recompute streaks over the merged history for every touched goal, so
    // the stored signed streak reflects local + imported logs combined. ──
    await recomputeStreaksForGoals(txn, affectedGoals);

    // Restore the profile (name / date of birth / settings) onto the owner row.
    // sanitizeSettings filters to known columns, coerces bools, and drops the
    // local-path avatar_url — so an import can never smuggle in a foreign id,
    // entitlement, or broken avatar path. The rule it enforces is general: no
    // PrivateDbSchema.deviceLocalProfileColumn is restorable from a file, so
    // `biometric_lock`/`is_pro`/`sentry_consent` keep the DEVICE's own values
    // rather than adopting whatever the backup claimed.
    //
    // Wrapped so a single out-of-domain value from a foreign/older client (e.g.
    // an unknown theme_mode failing the CHECK) can't roll back the whole import,
    // honoring the same row-level resilience as the data inserts above.
    //
    // Applied ONLY on a REPLACE import (a deliberate full restore). A MERGE
    // import must NOT silently flip the active user's theme/language/name to the
    // backup's values — the file is being brought in ALONGSIDE the live profile,
    // not restored over it (mobile parity: mobile never re-applies the profile
    // block on import).
    final profile = backupData['profile'];
    if (replaceExisting && profile is Map) {
      final sanitized = sanitizeSettings(Map<String, dynamic>.from(profile));
      if (sanitized.isNotEmpty) {
        try {
          await txn.update(
            'profiles',
            {...sanitized, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [owner],
          );
          await _restoreSyncedSettingRows(
            txn,
            owner: owner,
            sanitized: sanitized,
            now: now,
          );
        } catch (error, stack) {
          AppLogger.error('Skipped invalid profile on import', error, stack);
        }
      }
    }

    return stats;
  }

  /// The other half of the profile restore: the per-key `user_settings` rows.
  ///
  /// Without this a REPLACE import reported success and changed nothing the
  /// user could see. The restore wrote only the legacy `profiles` columns,
  /// while the REPLACE wipe above clears five data tables and deliberately
  /// leaves `user_settings` alone — and [SyncedSettingsStore.readAll] lets a
  /// row beat a column, on purpose ("the setting I turned off came back" is the
  /// worse failure). So every setting the user had ever touched on this Mac
  /// outranked the restored one, for good, silently.
  ///
  /// Raw SQL rather than [SyncedSettingsStore.writeAll] because that opens its
  /// OWN transaction and this runs inside the import's `txn`; the statement is
  /// kept byte-identical to the store's so both devices mint the same record
  /// id via [SyncedSettingsStore.rowId] and ordinary last-write-wins resolves
  /// them. Filtered to [PrivateDbSchema.syncedSettingKeys] — a non-synced or
  /// device-local column has no business becoming a synced row.
  ///
  /// Consequence, deliberate and worth stating: these rows are dirty, so a
  /// REPLACE restore now propagates to the user's other devices on the next
  /// push. That is what "replace" means, and the profiles columns already
  /// travelled that way.
  static Future<void> _restoreSyncedSettingRows(
    DatabaseExecutor txn, {
    required String owner,
    required Map<String, Object?> sanitized,
    required String now,
  }) async {
    for (final e in sanitized.entries) {
      if (!PrivateDbSchema.syncedSettingKeys.contains(e.key)) continue;
      await txn.rawInsert(
        'INSERT INTO user_settings '
        '(id, user_id, key, value, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(user_id, key) DO UPDATE SET '
        'value = excluded.value, updated_at = excluded.updated_at',
        [
          SyncedSettingsStore.rowId(owner, e.key),
          owner,
          e.key,
          e.value == null ? null : '${e.value}',
          now,
          now,
        ],
      );
    }
  }

  /// Full `goals` row from a canonical backup record. [createdAt] is decided
  /// by the caller (the file's value on insert, the existing row's on an LWW
  /// update) so a winning update never rewrites the local created_at.
  static Map<String, Object?> _goalRow(
    Map<String, dynamic> g,
    String id,
    String owner,
    String createdAt,
    String updatedAt,
  ) {
    return {
      'id': id,
      'user_id': owner,
      'title': g['title'] ?? '',
      'description': g['description'],
      'icon': g['icon'],
      'color': g['color'] ?? '#3B82F6',
      'frequency_days': _encodeFrequency(g['frequency_days']),
      'start_date': g['start_date'] ?? g['created_at'] ?? updatedAt,
      'end_date': g['end_date'],
      'display_order': g['display_order'],
      'reminder_time': g['reminder_time'],
      'verify_provider': g['verify_provider'],
      'verify_metric': g['verify_metric'],
      'verify_comparator': g['verify_comparator'],
      'verify_threshold': g['verify_threshold'],
      'verify_unit': g['verify_unit'],
      'created_at': createdAt,
      'updated_at': g['updated_at'] ?? updatedAt,
    };
  }

  /// Full `long_term_goals` row from a canonical backup record; [categoryId]
  /// is the already-remapped (and FK-safe) category reference.
  static Map<String, Object?> _macroRow(
    Map<String, dynamic> g,
    String id,
    String owner,
    String? categoryId,
    String createdAt,
    String updatedAt,
  ) {
    return {
      'id': id,
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
      'created_at': createdAt,
      'updated_at': g['updated_at'] ?? updatedAt,
    };
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<Database> _open() async {
    final gen = _openGeneration;
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbFileName);
    final dbFileExists = await File(dbPath).exists();
    await _excludeFromBackup(dir);
    final key = await _encryptionKey(dbFileExists: dbFileExists);

    final db = await openDatabase(
      dbPath,
      version: PrivateDbSchema.version,
      password: key,
      onConfigure: (db) async {
        await PrivateDbSchema.onConfigure(db);
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: PrivateDbSchema.onCreate,
      onUpgrade: PrivateDbSchema.onUpgrade,
      // Fail closed on a downgrade — mobile has always done this, desktop had
      // not. With NO onDowngrade, sqflite neither throws nor wipes: it silently
      // stamps `user_version` DOWN while leaving the NEWER physical schema in
      // place, so a later migration re-runs against tables/columns that already
      // exist and the database permanently fails to open.
      //
      // Not hypothetical on this platform: macOS ships independently of iOS and
      // users keep old `.app` bundles, so running an older build after a newer
      // one is routine. Throwing leaves `user_version` at the newer value, so
      // the newer build still opens cleanly and the older build simply refuses
      // a schema it does not understand.
      onDowngrade: PrivateDbSchema.onDowngrade,
    );
    // A reset/stash/restore may have run WHILE this open was in flight (those
    // paths mutate the DB file outside any lock). If so, this handle points at a
    // since-renamed/deleted (or re-created empty) file — discard it rather than
    // caching a stale/empty handle, and surface it as a lock so the caller
    // re-opens cleanly. Mirrors mobile's `_openGeneration` guard.
    if (gen != _openGeneration) {
      await db.close().catchError((_) {});
      throw const PrivateDatabaseLockedException();
    }
    // Publish the handle only AFTER init succeeds. If seedProfile throws, a
    // half-initialized handle must NOT be cached — that would permanently skip
    // the orphaned-owner self-heal below. (_reconcileOrphanedOwner swallows its
    // own errors, so only seedProfile can throw here.)
    try {
      // Reconcile BEFORE seeding, never after — see the matching comment in the
      // mobile client. seedProfile materialises a profiles +
      // goal_category_settings PAIR for whatever `ownerId` currently returns, so
      // seeding first mints a full identity for a stale id and the self-heal
      // then adopts a different one, stranding the pair permanently and
      // replicating it to every other device.
      await _reconcileOrphanedOwner(db);
      await seedProfile(db, owner: await ownerId, now: _now());
    } catch (_) {
      await db.close().catchError((_) {});
      rethrow;
    }
    _db = db;
    debugPrint('[DesktopPrivateDb] Opened schema v${PrivateDbSchema.version}.');
    return db;
  }

  /// Self-heals an "orphaned owner": if this device's current owner id owns no
  /// rows but exactly one OTHER user_id owns all the data, adopt that id so
  /// owner-filtered queries find the data again. Guards two silent-loss
  /// preconditions — a transient Keychain miss that minted a fresh owner UUID,
  /// or a second-device iCloud re-key whose best-effort [adoptOwner] write
  /// failed. Ambiguous splits (data across >1 owner) are left untouched.
  /// Mirrors mobile's `PrivateLocalDatabase._reconcileOrphanedOwner`.
  Future<void> _reconcileOrphanedOwner(Database db) async {
    const dataTables = [
      'goals',
      'goal_logs',
      'daily_moods',
      'long_term_goals',
      'macro_goal_categories',
    ];
    try {
      final current = await ownerId;

      // If the current owner already owns any data, we're in steady state.
      for (final t in dataTables) {
        final mine = await db.query(
          t,
          columns: ['user_id'],
          where: 'user_id = ?',
          whereArgs: [current],
          limit: 1,
        );
        if (mine.isNotEmpty) return;
      }

      // Collect the distinct OTHER owners that actually hold data.
      final others = <String>{};
      for (final t in dataTables) {
        final rows = await db.rawQuery(
          'SELECT DISTINCT user_id FROM $t WHERE user_id != ?',
          [current],
        );
        for (final r in rows) {
          final id = r['user_id'] as String?;
          if (id != null && id.isNotEmpty) others.add(id);
        }
      }

      if (others.isEmpty) return; // genuinely empty / first run
      if (others.length > 1) {
        AppLogger.warning(
          '[DesktopPrivateDb] owner reconcile skipped: data split across '
          '${others.length} owners (ambiguous)',
        );
        return;
      }

      final recovered = others.first;
      // Ensure the recovered owner has its FK parent rows before adopting.
      await seedProfile(db, owner: recovered, now: _now());

      AppLogger.warning(
        '[DesktopPrivateDb] recovering orphaned habit data: adopting the owner '
        'id that owns the rows (current owner matched no data)',
      );
      _cachedOwnerId = recovered;
      // Persist best-effort; if the Keychain write fails we self-heal again on
      // the next open (the in-memory adoption already fixes this session).
      try {
        await SecureStorageUtils.writeDeviceLocal(
          _ownerStorageKey,
          recovered,
          context: '[DesktopPrivateDb] owner reconcile',
        );
      } catch (e, stack) {
        AppLogger.error(
          '[DesktopPrivateDb] owner reconcile Keychain write failed '
          '(retries next open)',
          e,
          stack,
        );
      }
    } catch (e, stack) {
      AppLogger.error('[DesktopPrivateDb] owner reconcile failed', e, stack);
    }
  }

  /// Flags the private-data directory as excluded from device backups (Time
  /// Machine / iCloud) via the native `evolve/private_storage` channel. The
  /// whole Application Support directory is excluded rather than the single
  /// `.db` file so it also covers SQLite's `-wal`/`-shm` sidecars (which may not
  /// exist yet) and the `private_profile` avatar folder — exactly the
  /// device-local Private data that must never ride a backup onto another
  /// device where the SQLCipher key (device-local, see [SecureStorageUtils])
  /// doesn't exist. Best-effort: failures are logged, not fatal. Mirrors
  /// mobile's `PrivateLocalDatabase._excludeFromBackup`.
  Future<void> _excludeFromBackup(Directory dir) async {
    if (!Platform.isMacOS) return;
    try {
      await dir.create(recursive: true);
      await _privateStorageChannel.invokeMethod<void>('excludeFromBackup', {
        'path': dir.path,
      });
      final marker = File(p.join(dir.path, '.private_mode_local_only'));
      if (!await marker.exists()) {
        await marker.writeAsString(
          'Private mode database. Exclude this directory from device backups.',
        );
      }
    } catch (error, stack) {
      AppLogger.warning(
        '[DesktopPrivateDb] backup exclusion failed',
        error,
        stack,
      );
    }
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

  Future<String> _encryptionKey({required bool dbFileExists}) async {
    final existing = await SecureStorageUtils.readDeviceLocal(_keyStorageKey);
    if (existing != null && existing.length >= 32) return existing;

    // Fail closed: the encryption key is absent but an encrypted database file
    // already exists on disk. Minting a NEW key here would make that database
    // permanently undecryptable — SQLCipher reports error 26 "file is not a
    // database" — and would overwrite a key a later launch might still read.
    // Surface a distinct, recoverable error and let a future launch retry
    // instead of silently bricking the user's data. Only a true first run (no
    // db file) may generate a fresh key. Mirrors mobile's PrivateLocalDatabase
    // `_databasePassword` guard.
    if (dbFileExists) {
      throw const PrivateDatabaseLockedException();
    }

    final key = _generateKey();
    await SecureStorageUtils.writeDeviceLocal(_keyStorageKey, key);
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
