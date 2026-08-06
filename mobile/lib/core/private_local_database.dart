import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:evolve_sync/evolve_sync.dart';
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
import 'macro_goal_calendar.dart';
import 'macro_goal_snapshot.dart';
import 'import_merge.dart';
import 'import_merge_stats.dart';
import 'private_analytics.dart';
import 'private_data_store.dart';
import 'secure_storage_utils.dart';
import 'streak_utils.dart';

/// Thrown when the SQLCipher key needed to open the encrypted private database
/// is unreadable from the Keychain while the database file still exists on
/// disk. This is a *recoverable* lockout, not a crash bug: the existing local
/// data can't be decrypted (its key is gone — typically after a device
/// migration or a change to the app's code-signing identity, which rotates the
/// Keychain access group the key lives under), but the file is intact enough
/// that regenerating the key would silently brick it (SQLCipher error 26). The
/// guard fails closed and throws this instead; callers offer the user an
/// explicit reset via [PrivateLocalDatabase.resetLockedDatabase] and continue.
/// Mirrors desktop's `PrivateDatabaseLockedException`.
class PrivateDatabaseLockedException implements Exception {
  const PrivateDatabaseLockedException();

  // Kept byte-identical to the original StateError message so any UI that
  // surfaces `error.toString()` (and desktop parity) is unchanged.
  @override
  String toString() =>
      'Private database key unavailable while the database file exists; '
      'refusing to regenerate it so the data stays recoverable.';
}

/// Thrown when a key IS present but does not decrypt the database file.
///
/// Deliberately a DIFFERENT exception from [PrivateDatabaseLockedException],
/// because the correct response is the opposite one: *locked* (no key at all)
/// may auto-recover from CloudKit, since a file whose key is gone risks nothing
/// by being stashed — but *undecryptable* must NOT, because the correct key
/// exists somewhere and the recovery path's first act is to rename the file
/// aside and clear the key store. Mirrors desktop.
class PrivateDatabaseUndecryptableException implements Exception {
  const PrivateDatabaseUndecryptableException({
    this.provenanceMismatch = false,
    this.expectedProvenance,
    this.actualProvenance,
  });

  final bool provenanceMismatch;
  final String? expectedProvenance;
  final String? actualProvenance;

  @override
  String toString() => provenanceMismatch
      ? 'Private database was encrypted with a key from "$expectedProvenance" '
          'but this build reads its key from "$actualProvenance"; refusing to '
          'touch the file so the data stays recoverable.'
      : 'Private database exists but the available key does not decrypt it; '
          'refusing to touch the file so the data stays recoverable.';
}

final privateLocalDatabaseProvider = Provider<PrivateDataStore>((ref) {
  return PrivateLocalDatabase();
});

/// Resolves the value written to `goal_logs.streak`.
///
/// [requested] null means "unknown — keep whatever is stored", NOT zero. The
/// write it feeds is `INSERT OR REPLACE`, which rewrites the WHOLE row, so an
/// unknown streak has to be resolved to the existing value rather than left out
/// of the map — omitting it would silently store 0, which is precisely the
/// fabrication the nullable parameter exists to prevent.
///
/// [storedStreak] is the raw column value of the existing row, or null when
/// there is no existing row. A brand-new row has nothing to preserve and takes
/// the column default of 0.
int resolveHabitLogStreak(int? requested, Object? storedStreak) =>
    requested ?? (storedStreak as num?)?.toInt() ?? 0;

/// Reads the existing `goal_logs` row for [goalId]/[date] and resolves what the
/// upcoming `INSERT OR REPLACE` should carry: the row's identity (so it is
/// updated rather than duplicated), its original `created_at`, and the streak
/// per [resolveHabitLogStreak].
///
/// Split out of [PrivateLocalDatabase.setHabitLog] so it can be exercised
/// against the REAL schema. The database is opened through SQLCipher, whose
/// native plugin does not exist in the Flutter test VM (`openDatabase` throws
/// MissingPluginException), so `setHabitLog` as a whole cannot be driven from a
/// test — while the `columns:` list below is load-bearing: drop `'streak'` from
/// it and every preserved streak silently becomes 0, with the entire suite
/// still green. Taking a [DatabaseExecutor] lets a plain sqflite-ffi database
/// stand in, because `sqflite_sqlcipher` and `sqflite_common_ffi` both re-export
/// `package:sqflite_common/sqlite_api.dart` — these are the same types.
Future<({String? id, String? createdAt, int streak})> readExistingHabitLog(
  DatabaseExecutor db, {
  required String goalId,
  required String date,
  required int? requestedStreak,
}) async {
  final rows = await db.query(
    'goal_logs',
    columns: ['id', 'created_at', 'streak'],
    where: 'goal_id = ? AND date = ?',
    whereArgs: [goalId, date],
    limit: 1,
  );
  final row = rows.isEmpty ? null : rows.first;
  return (
    id: row?['id'] as String?,
    createdAt: row?['created_at'] as String?,
    streak: resolveHabitLogStreak(requestedStreak, row?['streak']),
  );
}

class PrivateLocalDatabase implements PrivateDataStore {
  PrivateLocalDatabase._();

  static final PrivateLocalDatabase _instance = PrivateLocalDatabase._();

  factory PrivateLocalDatabase() => _instance;

  static const _dbName = 'private_mode_v1.db';
  static const _dbPasswordKey = 'private_mode_db_password_v1';

  /// Companion Keychain account holding the key for the retained `.locked-*`
  /// aside copy. Preserving the ciphertext without its key would preserve
  /// something nobody can ever read. Mirrors desktop.
  static const _asideKeyStorageKey = 'private_mode_db_password_v1.aside';
  static const _ownerIdKey = 'private_mode_owner_id_v1';

  /// Suffix for the temporary "stashed" copy of a locked DB kept during an
  /// auto-recovery cloud re-pull so it can be restored if the pull didn't run.
  static const _bakSuffix = '.recovery-bak';

  /// Suffix for the non-destructive replacement of the old "delete the
  /// database" recovery. See [resetLockedDatabase].
  static const _lockedAsideSuffix = '.locked-';

  /// Sidecar binding the ciphertext to the key that encrypted it. See the
  /// desktop twin: both the lock probe and the fail-closed guard used to accept
  /// ANY string of >= 32 characters as "the key", so a wrong key of the right
  /// length read as healthy.
  static const _keyFingerprintSuffix = '.keyfp';

  /// Whether the encrypted private database file already exists on disk.
  ///
  /// Used at bootstrap to detect a private-mode user whose `active_data_mode`
  /// preference was lost or reset (NSUserDefaults cleared, etc.): without this
  /// the app silently defaults to Supabase mode and never queries the intact
  /// local data, so the user's habits look gone. File presence is a reliable
  /// signal because this file is only ever created when private mode is used.
  static Future<bool> databaseFileExists() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File(p.join(dir.path, _dbName)).exists();
    } catch (_) {
      return false;
    }
  }

  final _uuid = const Uuid();
  static const _platform = MethodChannel('evolve/private_storage');
  Database? _db;
  Future<Database>? _opening;
  String? _ownerId;

  /// Bumped whenever the DB file is reset/stashed/restored out from under an
  /// in-flight [_open] (those paths run outside the sync-service lock). An open
  /// that started before the bump discards its handle instead of caching one
  /// that points at a since-renamed/deleted (or freshly re-created empty) file.
  int _openGeneration = 0;

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

  /// Opens the SQLCipher database and TRANSLATES its failures into the app's own
  /// vocabulary before they can reach a generic catch-all. Mirrors desktop's
  /// `_openEncrypted` — see it for why the obvious "error 26" predicate is
  /// unreachable and what the real shapes are.
  Future<Database> _openEncrypted(
    String dbPath,
    String password, {
    required bool fileExisted,
  }) async {
    try {
      return await _rawOpen(dbPath, password);
    } catch (error, stack) {
      final failure = classifyPrivateDbOpenFailure(
        error,
        fileExistedNonEmpty: fileExisted,
      );
      AppLogger.error(
        '[PrivateDB] open failed — classified as ${failure.name} '
        '(${diagnosticCode(failure)})',
        error,
        stack,
      );
      switch (failure) {
        case PrivateDbOpenFailure.undecryptable:
          throw const PrivateDatabaseUndecryptableException();
        case PrivateDbOpenFailure.schemaTooNew:
        case PrivateDbOpenFailure.corrupt:
        case PrivateDbOpenFailure.movedOrReadonly:
        case PrivateDbOpenFailure.environment:
        case PrivateDbOpenFailure.unknown:
          rethrow;
        case PrivateDbOpenFailure.transient:
          for (final delay in const [
            Duration(milliseconds: 250),
            Duration(milliseconds: 750),
          ]) {
            await Future<void>.delayed(delay);
            try {
              return await _rawOpen(dbPath, password);
            } on Object catch (retryError) {
              if (classifyPrivateDbOpenFailure(
                    retryError,
                    fileExistedNonEmpty: fileExisted,
                  ) !=
                  PrivateDbOpenFailure.transient) {
                rethrow;
              }
            }
          }
          rethrow;
      }
    }
  }

  Future<Database> _rawOpen(String dbPath, String password) {
    return openDatabase(
      dbPath,
      password: password,
      version: PrivateDbSchema.version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        // Positive assertion that the connection is genuinely readable. The
        // plugin's `-query:` never re-checks the error after stepping, so a
        // poisoned connection returns `PRAGMA user_version` as a SUCCESSFUL
        // EMPTY result set — sqflite then reads version 0 and runs the whole
        // migration machinery against a database it cannot read. Empty here
        // means the read FAILED, never "the version is 0".
        final rows = await db.rawQuery('PRAGMA user_version');
        if (rows.isEmpty || rows.first.values.isEmpty) {
          throw const PrivateDatabaseUndecryptableException();
        }
        AppLogger.info(
          '[PrivateDB] open: stored user_version=${rows.first.values.first}, '
          'code PrivateDbSchema.version=${PrivateDbSchema.version}',
        );
      },
      onCreate: PrivateDbSchema.onCreate,
      onUpgrade: PrivateDbSchema.onUpgrade,
      // Fail closed on a downgrade so a version round-trip (iOS/macOS ship
      // independently and share this synced DB) never silently stamps
      // user_version down and re-runs a migration against an already-migrated
      // schema. See PrivateDbSchema.onDowngrade.
      onDowngrade: PrivateDbSchema.onDowngrade,
    );
  }

  Future<Database> _open() async {
    final gen = _openGeneration;
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final dbPath = p.join(dir.path, _dbName);
    final dbFile = File(dbPath);
    final dbFileExists = await dbFile.exists();
    // A zero-length file is NOT a database to protect — SQLCipher initialises it
    // with any key. Treating it as existing turns an interrupted first run into
    // a permanent lockout.
    final dbFileNonEmpty = dbFileExists && await dbFile.length() > 0;
    await _excludeFromBackup(dbFile);

    final password = await _databasePassword(dbFileExists: dbFileNonEmpty);

    // If the sidecar says this file was encrypted with a different key, we know
    // the open cannot succeed BEFORE SQLCipher turns that fact into an opaque
    // failure. Report it as its own state rather than letting it reach the
    // generic error path, whose only remedy used to be deletion.
    if (dbFileNonEmpty) {
      final mismatch = await _keyFingerprintMismatch(dbPath, password);
      if (mismatch != null) {
        AppLogger.error(
          '[PrivateDB] key fingerprint MISMATCH — not touching the file.',
          mismatch,
        );
        throw mismatch;
      }
    }

    final db = await _openEncrypted(
      dbPath,
      password,
      fileExisted: dbFileNonEmpty,
    );
    await _writeKeyFingerprint(dbPath, password);
    // A reset/stash/restore may have run WHILE this open was in flight (those
    // paths mutate the DB file outside the sync-service lock). If so, this
    // handle points at a since-renamed/deleted (or re-created empty) file —
    // discard it rather than caching a stale/empty handle, and surface it as a
    // lock so the caller re-opens cleanly.
    if (gen != _openGeneration) {
      await db.close().catchError((_) {});
      throw const PrivateDatabaseLockedException();
    }
    // Publish the handle only AFTER init succeeds. If _ensureProfile throws, a
    // half-initialized handle must NOT be cached — that would permanently skip
    // the orphaned-owner self-heal below for the rest of the process. Close it
    // and leave _db null so the next _database() retries the full open.
    // (_reconcileOrphanedOwner swallows its own errors, so only _ensureProfile
    // can throw here.)
    try {
      // Reconcile BEFORE seeding, never after.
      //
      // _ensureProfile materialises a profiles + goal_category_settings PAIR
      // keyed on whatever ownerId() currently returns. Running it first means a
      // stale owner id gets a full identity minted for it, and only THEN does
      // the self-heal notice that id owns no data and adopt the one that does —
      // leaving the pair behind forever, with its INSERT trigger replicating it
      // to every other device. That is how a user ended up with 3 profiles on
      // one device and 2 on the other, in lockstep with goal_category_settings
      // (whose user_id is UNIQUE, so its count IS the number of identities ever
      // seeded).
      //
      // Reconciling first lets the self-heal adopt the correct owner while the
      // database is still untouched, so _ensureProfile then finds that owner's
      // profile already present and seeds nothing.
      await _reconcileOrphanedOwner(db);
      await _ensureProfile(db);
    } catch (_) {
      await db.close().catchError((_) {});
      rethrow;
    }
    _db = db;
    return db;
  }

  /// Self-heals orphaned data. If the current owner id matches ZERO data rows
  /// but exactly ONE other `user_id` owns all the data, adopt that id so every
  /// owner-filtered query finds the rows again.
  ///
  /// This rescues two silent-loss situations where the rows are still on disk
  /// but keyed to an id `ownerId()` no longer returns:
  ///  • the device-local owner id was regenerated after a Keychain read
  ///    transiently returned null (the old rows keep the previous id);
  ///  • a second-device iCloud-sync re-key moved every row onto the canonical
  ///    owner but the follow-up `adoptOwner` Keychain write didn't land.
  ///
  /// A genuinely empty database (true first run) and the normal steady state
  /// (current owner already owns rows) are both left untouched. Best-effort and
  /// idempotent — safe to run on every open. Refuses to act when the data is
  /// split across more than one foreign owner (ambiguous — never guess).
  Future<void> _reconcileOrphanedOwner(Database db) async {
    const dataTables = [
      'goals',
      'goal_logs',
      'daily_moods',
      'long_term_goals',
      'macro_goal_categories',
    ];
    try {
      final current = await ownerId();

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
          '[PrivateDB] owner reconcile skipped: data split across '
          '${others.length} owners (ambiguous)',
        );
        return;
      }

      final recovered = others.first;
      // A profiles row for the recovered owner should already exist via FK, but
      // make sure — the queries below and future writes need it.
      final now = _now();
      await db.insert('profiles', {
        'id': recovered,
        'language': 'system',
        'theme_mode': 'dark',
        'accent_color': '#FFFFFF',
        'pref_default_calendar_view': 'settimana',
        'is_pro': 1,
        'created_at': now,
        'updated_at': now,
        'sentry_consent': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      AppLogger.warning(
        '[PrivateDB] recovering orphaned habit data: adopting the owner id '
        'that owns the rows (current owner matched no data)',
      );
      _ownerId = recovered;
      // Persist best-effort; if the Keychain write fails we self-heal again on
      // the next open (the in-memory adoption already fixes this session).
      try {
        await SecureStorageUtils.writeDeviceLocal(
          _ownerIdKey,
          recovered,
          context: '[PrivateDB] owner reconcile',
        );
      } catch (e, stack) {
        AppLogger.error(
          '[PrivateDB] owner reconcile Keychain write failed (retries next open)',
          e,
          stack,
        );
      }
    } catch (e, stack) {
      AppLogger.error('[PrivateDB] owner reconcile failed', e, stack);
    }
  }

  Future<String> _databasePassword({required bool dbFileExists}) async {
    final existing = await SecureStorageUtils.readDeviceLocal(_dbPasswordKey);
    if (existing != null && existing.length >= 32) return existing;

    // Fail closed: the encryption key is absent but an encrypted database file
    // already exists on disk. Minting a NEW key here would make that database
    // permanently undecryptable (and could overwrite a key a later launch can
    // read). Surface a distinct, recoverable error and let a future launch retry
    // rather than silently bricking the user's data. Only a true first run (no
    // db file) is allowed to generate a fresh key.
    if (dbFileExists) {
      throw const PrivateDatabaseLockedException();
    }

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
    await _writeGoal(db, goal, owner, _now());
    _notifyWrite();
  }

  /// Recomputes `goal_logs.streak` for EVERY habit from its full history and
  /// writes back only the rows that were wrong. Returns how many it corrected.
  ///
  /// This is the repair for the empty-goals-window corruption: `applyAutoVerdict`
  /// and `setDerivedStatus` used to recompute the streak from a LIVE
  /// `goalsProvider` read, and when that list was transiently empty the goal
  /// resolved to null, `startDate` fell back to the day being written, and
  /// `computeStreak`'s backward walk broke on its first step — persisting a long
  /// run as ±1 into a table that syncs to every device, which nothing re-derives.
  ///
  /// `streak` is a CACHE of a pure function of data still on disk (the habit's
  /// log history + its start date + its weekly schedule), so every wrong value is
  /// recoverable exactly. Runs in ONE transaction and shares
  /// [recomputeStreaks] with the import path, so the repair and the import can
  /// never disagree about what a row's streak should be.
  ///
  /// Must run only AFTER the writers that corrupt it are fixed, or it re-corrupts.
  ///
  /// Returns null when this owner has NO habits yet — which is NOT the same as
  /// "nothing to fix", and the difference is load-bearing. [ownerId] returns a
  /// device-local uuid until the first sync adopts the canonical owner, so on a
  /// restored or second device the owner-filtered query below legitimately
  /// selects nothing while the user's entire (corrupted) history is still on its
  /// way. Reporting 0 there would let the caller mark the repair permanently
  /// done before the data arrived. Null means "could not scan — ask again".
  @override
  Future<int?> repairAllStreaks() async {
    final db = await _database();
    final owner = await ownerId();
    final goalRows = await db.query(
      'goals',
      columns: ['id'],
      where: 'user_id = ?',
      whereArgs: [owner],
    );
    if (goalRows.isEmpty) return null;
    final ids = {for (final r in goalRows) r['id'] as String};
    final corrected = await db.transaction<int>(
      // A fresh stamp is what lets the correction WIN last-write-wins on every
      // other device; without it the peers discard it. See [recomputeStreaks].
      (txn) => recomputeStreaks(txn, ids, stampUpdatedAt: _now()),
    );
    if (corrected > 0) _notifyWrite();
    return corrected;
  }

  /// Persist multiple goals (used by drag-reorder) in ONE transaction, so a
  /// partial failure can't leave display_order half-applied and so the write is
  /// a single atomic unit rather than N separate ones.
  @override
  Future<void> reorderGoals(List<Goal> goals) async {
    final db = await _database();
    final owner = await ownerId();
    final now = _now();
    await db.transaction((txn) async {
      for (final goal in goals) {
        await _writeGoal(txn, goal, owner, now);
      }
    });
    _notifyWrite();
  }

  /// Writes a single goal row WITHOUT ever deleting the existing one.
  ///
  /// CRITICAL (data-loss guard): `goal_logs.goal_id` is `ON DELETE CASCADE`
  /// (see [PrivateDbSchema]), so writing a goal with `ConflictAlgorithm.replace`
  /// (`INSERT OR REPLACE`) on an EXISTING id first DELETEs the old `goals` row —
  /// which cascades away every one of that habit's `goal_logs`, and (with sync
  /// on) tombstones them to iCloud. A plain rename/reorder would silently wipe
  /// the habit's entire history. So we branch: UPDATE an existing row (no delete,
  /// no cascade), INSERT a brand-new one. `created_at` is preserved on update.
  /// The AFTER UPDATE / AFTER INSERT sync triggers still mark the goal dirty for
  /// push, so sync is unaffected.
  Future<void> _writeGoal(
    DatabaseExecutor db,
    Goal goal,
    String owner,
    String now,
  ) async {
    final existing = await db.query(
      'goals',
      columns: ['created_at'],
      where: 'id = ?',
      whereArgs: [goal.id],
      limit: 1,
    );
    final row = {
      ..._goalToRow(goal),
      'user_id': owner,
      'updated_at': now,
    };
    if (existing.isNotEmpty) {
      row['created_at'] = existing.first['created_at'] as String;
      await db.update(
        'goals',
        row,
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    } else {
      row['created_at'] = now;
      await db.insert('goals', row);
    }
  }

  @override
  Future<void> deleteGoal(String id) async {
    final db = await _database();
    // Before the habit's goal_progress rows cascade away, snapshot the derived
    // total into any macro goal it feeds so a "500 km" goal that reached 320 km
    // keeps showing 320 as a now-manual value. The FK is ON DELETE SET NULL, so
    // the un-link itself is automatic; this preserves the accumulated number,
    // which would otherwise collapse to zero the moment the progress is gone.
    await snapshotLinkedMacroGoals(db, id, now: _now());
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
    int? streak,
    double? value,
  }) async {
    final db = await _database();
    final owner = await ownerId();
    final now = _now();
    final existing = await readExistingHabitLog(
      db,
      goalId: goalId,
      date: date,
      requestedStreak: streak,
    );
    await db.insert('goal_logs', {
      'id': existing.id ?? _uuid.v4(),
      'user_id': owner,
      'goal_id': goalId,
      'date': date,
      'status': status,
      // The measured HealthKit quantity for an auto-verified verdict (null for
      // manual check-ins and Screen Time). REPLACE rewrites the whole row, so we
      // always set it — a manual toggle intentionally clears any prior value.
      'value': value,
      'created_at': existing.createdAt ?? now,
      'updated_at': now,
      'streak': existing.streak,
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
    // ABSENCE IS NOT EVIDENCE. Without the goal there is no start date and no
    // schedule, so the streak cannot be computed — and substituting the written
    // day for the start date collapses it to ±1 (computeStreak's backward walk
    // breaks on its first step). Pass null so the stored value is preserved
    // rather than overwritten with a fabrication.
    final streak = goal == null
        ? null
        : computeStreak(
            habitId: goalId,
            date: parsedDate,
            logs: logs,
            startDate: goal.startDate,
            frequencyDays: goal.frequencyDays,
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
  Future<Map<String, Map<String, double>>> loadHabitProgress() async {
    final db = await _database();
    final owner = await ownerId();
    final rows = await db.query(
      'goal_progress',
      where: 'user_id = ?',
      whereArgs: [owner],
    );
    final result = <String, Map<String, double>>{};
    for (final row in rows) {
      final date = row['date'] as String;
      final goalId = row['goal_id'] as String;
      final amount = (row['amount'] as num).toDouble();
      result.putIfAbsent(date, () => <String, double>{})[goalId] = amount;
    }
    return result;
  }

  @override
  Future<void> setHabitProgress({
    required String goalId,
    required String date,
    required double amount,
    String source = 'manual',
  }) async {
    final db = await _database();
    final owner = await ownerId();
    final now = _now();
    // Deterministic id (goalId:date) — the whole reason two devices can't mint
    // rival rows for one habit-day. Reused on conflict so REPLACE rewrites the
    // SAME primary key (no natural-key merge, no tombstone: the AFTER DELETE
    // trigger does not fire on a REPLACE with recursive triggers off, exactly as
    // setHabitLog relies on).
    final id = PrivateDbSchema.goalProgressId(goalId, date);
    final existing = await db.query(
      'goal_progress',
      columns: ['created_at'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    await db.insert('goal_progress', {
      'id': id,
      'user_id': owner,
      'goal_id': goalId,
      'date': date,
      'amount': amount,
      'source': source,
      'created_at': existing.isNotEmpty
          ? existing.first['created_at'] as String
          : now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyWrite();
  }

  @override
  Future<void> deleteHabitProgress({
    required String goalId,
    required String date,
  }) async {
    final db = await _database();
    await db.delete(
      'goal_progress',
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
  Future<double> linkedHabitProgressSum(
    String habitId,
    MacroGoalDateRange? range,
  ) async {
    final db = await _database();
    // Delegates to the shared, DB-pure summing query so this display read and
    // the delete-time snapshot ([snapshotLinkedMacroGoals]) derive the exact
    // same number from the exact same rows.
    return sumLinkedHabitProgress(db, habitId, range);
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
    final row = {
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
      'updated_at': now,
      // Cumulative numeric macro goals (v10). Written explicitly so an UPDATE
      // can also CLEAR them (e.g. reverting a numeric goal to boolean, or
      // snapshotting progress on unlink). Columns exist after the v10 migration.
      'target_amount': goal.targetAmount,
      'target_unit': goal.targetUnit,
      'progress_amount': goal.progressAmount,
      'linked_goal_id': goal.linkedGoalId,
    };
    // UPDATE-or-INSERT rather than INSERT OR REPLACE. `long_term_goals` has no
    // child rows today, but a REPLACE still needlessly DELETE+re-INSERTs (extra
    // sync tombstone churn) and would become a cascade footgun the day a child
    // table is added. Same safe pattern as [_writeGoal].
    if (existing.isNotEmpty) {
      row['created_at'] = existing.first['created_at'] as String;
      await db.update(
        'long_term_goals',
        row,
        where: 'id = ?',
        whereArgs: [goal.id],
      );
    } else {
      row['created_at'] = goal.createdAt.toIso8601String();
      await db.insert('long_term_goals', row);
    }
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
    // macro_goal_categories is UNIQUE(user_id, name) (case-sensitive: the
    // column has no COLLATE NOCASE) and delete is a SOFT archive that keeps the
    // row in that uniqueness slot forever. A bare insert of a previously-deleted
    // name therefore hits "UNIQUE constraint failed" and the create silently
    // fails. Revive the archived row instead — clear archived_at, apply the
    // newly-picked colour, bump updated_at — mirroring the import path's
    // reconcileCategoriesByName. This resurrects the category's prior macro-goal
    // associations, which the owner accepts. Match the name with the same
    // (binary) collation the UNIQUE constraint enforces, so we revive exactly
    // the row that would have collided. A LIVE same-name row is a genuine
    // duplicate: fall through to the insert so the UNIQUE violation surfaces as
    // an error rather than silently merging onto an existing live category.
    final existing = await db.query(
      'macro_goal_categories',
      columns: ['id', 'archived_at'],
      where: 'user_id = ? AND name = ?',
      whereArgs: [owner, name],
      limit: 1,
    );
    if (existing.isNotEmpty && existing.first['archived_at'] != null) {
      final id = existing.first['id'] as String;
      await db.update(
        'macro_goal_categories',
        {'archived_at': null, 'color': colorHex, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      _notifyWrite();
      return id;
    }
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
  Future<Map<String, String?>> loadSyncedSettings() async {
    final db = await _database();
    final owner = await ownerId();
    // Reading through the shared store (not a hand-rolled query) is the point:
    // it owns the row-beats-legacy-column precedence, and a second copy of that
    // rule on this side is exactly how the two apps would drift apart again.
    return SyncedSettingsStore(db).readAll(owner);
  }

  @override
  Future<void> writeSyncedSettings(Map<String, String?> values) async {
    if (values.isEmpty) return;
    final db = await _database();
    final owner = await ownerId();
    await SyncedSettingsStore(db).writeAll(owner, values);
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
    final progress = await rows('goal_progress');
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
            // Auto-verified habits: round-trip the verification rule so a
            // backup→restore doesn't silently turn a verified goal manual.
            'verify_provider': g['verify_provider'],
            'verify_metric': g['verify_metric'],
            'verify_comparator': g['verify_comparator'],
            'verify_threshold': g['verify_threshold'],
            'verify_unit': g['verify_unit'],
            // The rule's effective-from anchor (D10) rides along so a restore
            // preserves the forward-only edit boundary.
            'verify_effective_from': g['verify_effective_from'],
            // The compound conditions blob (Q4) round-trips too.
            'verify_conditions': g['verify_conditions'],
            // The quantitative target (v9) — without this a backup→restore
            // silently turns a targeted habit back into a plain checkbox.
            'target': g['target'],
            // The target's forward-only anchor (v11) rides along so a restore
            // preserves the edit boundary, exactly like verify_effective_from.
            'target_effective_from': g['target_effective_from'],
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
      // Quantitative-habit daily progress numbers (v9). Round-tripped so a
      // restore keeps each target habit's rings, not just its done/missed
      // verdicts (which live in habitLogs).
      'habitProgress': [
        for (final p in progress)
          {
            'id': p['id'],
            'goal_id': p['goal_id'],
            'date': p['date'],
            'amount': p['amount'],
            'source': p['source'],
            'created_at': p['created_at'],
            'updated_at': p['updated_at'],
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
            // Cumulative numeric macro goals (v10) — round-tripped so a
            // backup→restore keeps a goal's numeric target, stored progress and
            // linked habit, not just its boolean status.
            'target_amount': g['target_amount'],
            'target_unit': g['target_unit'],
            'progress_amount': g['progress_amount'],
            'linked_goal_id': g['linked_goal_id'],
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

  /// Whether the private database is in the recoverable *locked* state: the
  /// encrypted file exists on disk but its SQLCipher key is unreadable from the
  /// Keychain, so [_database] would throw [PrivateDatabaseLockedException].
  /// Lets callers offer an in-app recovery affordance instead of a dead end.
  /// Cheap (one file stat + one Keychain read); safe to call before an import
  /// or from a settings screen.
  @override
  Future<bool> isDatabaseLocked() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final dbPath = p.join(dir.path, _dbName);
      final dbFileExists = await File(dbPath).exists();
      if (!dbFileExists) return false;
      final key = await SecureStorageUtils.readDeviceLocal(_dbPasswordKey);
      if (key == null || key.length < 32) return true;
      // A key of the right LENGTH is not a key that WORKS. Stopping at the
      // length test made a wrong key read as perfectly healthy, so the import
      // pre-flight offered no recovery and the mismatch only surfaced later as
      // an opaque failure from inside SQLCipher. Mirrors desktop.
      return await _keyFingerprintMismatch(dbPath, key) != null;
    } catch (error, stack) {
      // A probe failure must never itself block the user; treat as "not locked"
      // and let the real open surface any genuine problem.
      AppLogger.warning('[PrivateDB] lock probe failed', error, stack);
      return false;
    }
  }

  /// Recovers from a [PrivateDatabaseLockedException] by deleting the orphaned
  /// encrypted database FILE (+ its `-wal`/`-shm` sidecars) and the avatar
  /// folder, and clearing any unreadable key remnant — so the next [_database]
  /// open mints a fresh key over an empty schema. The device-local owner id is
  /// intentionally KEPT so identity stays stable across the reset.
  ///
  /// **Not destructive, despite the name.** The encrypted file is RENAMED ASIDE
  /// to `private_mode_v1.db.locked-<ISO8601>`, never deleted — see the desktop
  /// twin for the full reasoning. In short: the common causes of "can't open"
  /// leave the ciphertext intact and merely separated from its key, so deleting
  /// makes a recoverable situation permanent, and this action sits behind a
  /// button the user reaches simply by launching the app.
  ///
  /// Exactly ONE aside copy is retained, and the recovery stash is cleared so a
  /// reset cannot be silently undone by the orphan sweep at the next launch.
  @override
  Future<void> resetLockedDatabase() async {
    await _quiesceForFileMutation();

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbName);

    await _pruneAsideCopies(dir);

    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    var moved = false;
    for (final suffix in ['', '-wal', '-shm']) {
      final src = File('$dbPath$suffix');
      try {
        if (await src.exists()) {
          await src.rename('$dbPath$suffix$_lockedAsideSuffix$stamp');
          if (suffix.isEmpty) moved = true;
        }
      } catch (error, stack) {
        AppLogger.error(
          '[PrivateDB] locked reset: could not move $dbPath$suffix aside',
          error,
          stack,
        );
      }
    }

    await _deleteIfExists(File('$dbPath$_keyFingerprintSuffix'));
    // A leftover stash would be restored over the fresh database by the orphan
    // sweep on the next launch, silently undoing this reset.
    await discardStashedDatabase();

    try {
      final avatarDir = Directory(p.join(dir.path, 'private_profile'));
      if (await avatarDir.exists()) await avatarDir.delete(recursive: true);
    } catch (error, stack) {
      AppLogger.warning(
        '[PrivateDB] locked reset: avatar folder delete failed',
        error,
        stack,
      );
    }

    // Drop a short/stale key remnant so the next open takes the first-run path
    // and writes a fresh key under the CURRENT Keychain access group. A key
    // that is present-but-unreadable (rotated access group) is invisible to
    // delete too — harmless no-op; the next read misses it and mints fresh.
    // PARK the key beside the aside copy rather than dropping it: moving the
    // ciphertext aside is worthless if the key that opens it is destroyed in
    // the same breath. Mirrors desktop.
    try {
      final current = await SecureStorageUtils.readDeviceLocal(_dbPasswordKey);
      if (current != null && current.isNotEmpty) {
        await SecureStorageUtils.writeDeviceLocal(
          _asideKeyStorageKey,
          current,
          context: '[PrivateDB] park key for the aside copy',
        );
      } else {
        await SecureStorageUtils.deleteDeviceLocal(_asideKeyStorageKey);
      }
      await SecureStorageUtils.deleteDeviceLocal(_dbPasswordKey);
    } catch (error, stack) {
      AppLogger.warning(
        '[PrivateDB] locked reset: could not park/clear the key',
        error,
        stack,
      );
    }

    AppLogger.warning(
      '[PrivateDB] locked database reset: file ${moved ? 'MOVED ASIDE '
          '(recoverable)' : 'was absent'}; key cleared; the next open mints a '
      'fresh key.',
    );
  }

  /// Size of the encrypted database on disk, or null when there is none.
  @override
  Future<int?> databaseSizeBytes() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, _dbName));
      if (!await file.exists()) return null;
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  /// Removes every `.locked-*` aside copy so at most one generation is ever
  /// retained. Best-effort.
  Future<void> _pruneAsideCopies(Directory dir) async {
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith(_dbName) && name.contains(_lockedAsideSuffix)) {
          await _deleteIfExists(entity);
        }
      }
    } catch (error, stack) {
      AppLogger.warning(
        '[PrivateDB] could not prune older aside copies', error, stack);
    }
  }

  /// The retained aside copy from the most recent [resetLockedDatabase], with
  /// its size. NOTE: no Settings screen surfaces this yet — the retained copy
  /// exists for [deleteLockedAsideCopy] and for support/diagnostics, and the
  /// reset dialog is currently the only place the user is told it is kept.
  Future<({String path, int bytes})?> lockedAsideCopy() async {
    try {
      final dir = await getApplicationSupportDirectory();
      if (!await dir.exists()) return null;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (p.basename(entity.path).startsWith('$_dbName$_lockedAsideSuffix')) {
          return (path: entity.path, bytes: await entity.length());
        }
      }
    } catch (error, stack) {
      AppLogger.warning(
        '[PrivateDB] could not inspect the aside copy', error, stack);
    }
    return null;
  }

  /// Permanently deletes the retained aside copy — the ONLY place in the app
  /// allowed to destroy private ciphertext, and only from an explicit,
  /// separately-confirmed action.
  @override
  Future<void> deleteLockedAsideCopy() async {
    await _pruneAsideCopies(await getApplicationSupportDirectory());
    try {
      await SecureStorageUtils.deleteDeviceLocal(_asideKeyStorageKey);
    } catch (error, stack) {
      AppLogger.warning(
        '[PrivateDB] could not remove the parked aside key', error, stack);
    }
    AppLogger.warning(
      '[PrivateDB] aside copy deleted permanently at the user\'s explicit '
      'request',
    );
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (error, stack) {
      AppLogger.warning(
        '[PrivateDB] could not delete ${file.path}', error, stack);
    }
  }

  Future<void> _moveIfExists(File src, String destination) async {
    try {
      if (await src.exists()) await src.rename(destination);
    } catch (error, stack) {
      AppLogger.warning('[PrivateDB] could not move ${src.path}', error, stack);
    }
  }

  /// Eight bytes of `SHA-256(key)`, hex — see the desktop twin. Non-secret by
  /// construction, and readable precisely when the database is not.
  static String _fingerprint(String key) =>
      sha256.convert(utf8.encode(key)).toString().substring(0, 16);

  Future<void> _writeKeyFingerprint(String dbPath, String key) async {
    try {
      await File('$dbPath$_keyFingerprintSuffix').writeAsString(
        jsonEncode({
          'fp': _fingerprint(key),
          'store': 'keychain',
          'writtenAt': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
    } catch (error, stack) {
      AppLogger.warning(
        '[PrivateDB] could not write the key fingerprint', error, stack);
    }
  }

  /// Compares the key about to be used against the sidecar written when the
  /// file was created. Null when there is nothing to compare — a missing
  /// sidecar is not evidence of a mismatch.
  Future<PrivateDatabaseUndecryptableException?> _keyFingerprintMismatch(
    String dbPath,
    String key,
  ) async {
    try {
      final file = File('$dbPath$_keyFingerprintSuffix');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final recorded = decoded['fp'];
      if (recorded is! String || recorded.isEmpty) return null;
      if (recorded == _fingerprint(key)) return null;
      final store = decoded['store'];
      return PrivateDatabaseUndecryptableException(
        provenanceMismatch: store is String && store != 'keychain',
        expectedProvenance: store is String ? store : null,
        actualProvenance: 'keychain',
      );
    } catch (error, stack) {
      AppLogger.warning(
        '[PrivateDB] could not read the key fingerprint', error, stack);
      return null;
    }
  }

  /// Bump the open generation, wait out any in-flight [_open] (so it can't
  /// re-create a file we're about to move/delete), and drop the cached handle.
  /// Shared by [resetLockedDatabase]/[stashLockedDatabase]/[restoreStashedDatabase],
  /// which all mutate the DB file directly and run outside the sync lock.
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

  /// Renames the locked database aside so a fresh one can be re-pulled from
  /// CloudKit. **The key is cleared BEFORE the file moves, and a failure to
  /// clear it aborts the whole operation** — see the desktop twin. The old order
  /// (rename first, clear the key last, swallow any failure as a warning) is
  /// exactly what leaves an old-key file beside a new-key store, which every
  /// later launch reports as an unclassifiable open failure.
  ///
  /// A pre-existing stash is never clobbered: it is the only copy of an earlier
  /// attempt's data.
  @override
  Future<bool> stashLockedDatabase() async {
    await _quiesceForFileMutation();
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbName);

    if (await File('$dbPath$_bakSuffix').exists()) {
      AppLogger.warning(
        '[PrivateDB] stash ABORTED: a .recovery-bak already exists, so a '
        'previous recovery is still in flight or was interrupted. Refusing to '
        'overwrite the only copy of its data.',
      );
      return false;
    }

    try {
      await SecureStorageUtils.deleteDeviceLocal(_dbPasswordKey);
    } catch (error, stack) {
      AppLogger.error(
        '[PrivateDB] stash ABORTED: could not clear the device-local key, so '
        'moving the database would strand it beside a stale key.',
        error,
        stack,
      );
      return false;
    }

    var stashed = false;
    for (final suffix in ['', '-wal', '-shm']) {
      final src = File('$dbPath$suffix');
      try {
        if (await src.exists()) {
          await src.rename('$dbPath$suffix$_bakSuffix');
          if (suffix.isEmpty) stashed = true;
        }
      } catch (error, stack) {
        AppLogger.error('[PrivateDB] stash failed for $suffix', error, stack);
      }
    }
    await _moveIfExists(
      File('$dbPath$_keyFingerprintSuffix'),
      '$dbPath$_keyFingerprintSuffix$_bakSuffix',
    );
    return stashed;
  }

  /// Undoes [stashLockedDatabase]. **Only ever touches the live database when a
  /// stash actually exists to put back** — it used to delete the live file
  /// unconditionally and only then look for a `.recovery-bak` to rename over it,
  /// so calling it with no stash (which the recovery's catch-all does, blind, on
  /// any failure) destroyed a healthy database and restored nothing.
  @override
  Future<void> restoreStashedDatabase() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbName);

    if (!await File('$dbPath$_bakSuffix').exists()) {
      AppLogger.info(
        '[PrivateDB] restore skipped: no .recovery-bak present, so the live '
        'database is left untouched.',
      );
      return;
    }

    await _quiesceForFileMutation();

    // Clear the key BEFORE the files move: the restored file belongs to the OLD
    // key, so a fresh key left in the store would make it read as undecryptable
    // instead of as the recoverable lock state.
    try {
      await SecureStorageUtils.deleteDeviceLocal(_dbPasswordKey);
    } catch (error, stack) {
      AppLogger.error(
        '[PrivateDB] restore ABORTED: could not clear the freshly-minted key, '
        'so restoring would leave the old-key database beside it.',
        error,
        stack,
      );
      return;
    }

    for (final suffix in ['', '-wal', '-shm']) {
      final fresh = File('$dbPath$suffix');
      final bak = File('$dbPath$suffix$_bakSuffix');
      try {
        if (!await bak.exists()) continue;
        await _deleteIfExists(fresh);
        await bak.rename(fresh.path);
      } catch (error, stack) {
        AppLogger.error('[PrivateDB] restore failed for $suffix', error, stack);
      }
    }
    await _moveIfExists(
      File('$dbPath$_keyFingerprintSuffix$_bakSuffix'),
      '$dbPath$_keyFingerprintSuffix',
    );
  }


  @override
  Future<bool> hasStashedDatabase() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${p.join(dir.path, _dbName)}$_bakSuffix').exists();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> discardStashedDatabase() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _dbName);
    for (final suffix in ['', '-wal', '-shm']) {
      await _deleteIfExists(File('$dbPath$suffix$_bakSuffix'));
    }
    await _deleteIfExists(File('$dbPath$_keyFingerprintSuffix$_bakSuffix'));
  }

  @override
  Future<void> deleteAllPrivateData() async {
    final db = await _database();
    final profileRow = await loadProfileRow();
    await db.transaction((txn) async {
      await txn.delete('goal_logs');
      // Explicit, beside goal_logs, rather than leaning on the goals/profiles
      // cascade: this method wipes every child table by name in FK-safe order,
      // and an unlisted table is how a wipe silently leaves rows behind.
      await txn.delete('goal_progress');
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

    // "Delete all private data" must mean ALL of it. The recovery artefacts —
    // the retained `.locked-*` aside copy, its parked key and any
    // `.recovery-bak` stash — are full encrypted copies of exactly the data the
    // user just asked to be rid of, and leaving them behind while reporting
    // success is a privacy defect, not a safety net.
    await deleteLockedAsideCopy();
    await discardStashedDatabase();
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
    return (await resolveAvatarFile())?.readAsBytes();
  }

  /// Whether an avatar is CONFIGURED — `profiles.avatar_url` is set — whether or
  /// not its file can currently be read.
  ///
  /// The engine needs this to tell "the user removed their avatar" (a tombstone
  /// that must propagate) apart from "we lost the file" (which must never be
  /// replicated as a deletion). See [SyncAvatarStore.hasAvatarConfigured].
  Future<bool> hasAvatarConfigured() async {
    final path = (await loadProfileRow())['avatar_url'] as String?;
    return path != null && path.isNotEmpty;
  }

  /// The avatar file as it exists on THIS device right now, or null if it
  /// cannot be found.
  ///
  /// Resolves by BASENAME against the current container before trusting the
  /// stored string, because that string is a legacy absolute path and iOS
  /// regenerates the container UUID in it across reinstalls. The image itself
  /// never moves — only the prefix of the path we wrote down does — so looking
  /// the file up by name repairs an install that would otherwise show the
  /// default avatar and, worse, push a tombstone that deleted the picture on
  /// every other device.
  ///
  /// Self-healing rather than a migration: it costs one extra stat, needs no
  /// schema change, is idempotent, and fixes databases already carrying a stale
  /// path without anything having to run first.
  Future<File?> resolveAvatarFile() async {
    final stored = (await loadProfileRow())['avatar_url'] as String?;
    if (stored == null || stored.isEmpty) return null;
    final dir = await getApplicationSupportDirectory();
    for (final candidate in avatarPathCandidates(
      stored: stored,
      supportDir: dir.path,
    )) {
      final file = File(candidate);
      if (await file.exists()) return file;
    }
    return null;
  }

  /// [resolveAvatarFile] as a path, for the UI (which needs a String and cannot
  /// await inside `build`).
  @override
  Future<String?> resolveAvatarPath() async =>
      (await resolveAvatarFile())?.path;

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
          if (g.status == GoalStatus.active) {
            seasonalityStats[g.quarter!]!['active'] =
                seasonalityStats[g.quarter!]!['active']! + 1;
          }
          if (g.status == GoalStatus.failed) {
            seasonalityStats[g.quarter!]!['failed'] =
                seasonalityStats[g.quarter!]!['failed']! + 1;
          }
          if (g.status == GoalStatus.completed) {
            seasonalityStats[g.quarter!]!['completed'] =
                seasonalityStats[g.quarter!]!['completed']! + 1;
          }
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
          if (g.status == GoalStatus.completed) {
            monthStats[g.month!]!['completed'] =
                monthStats[g.month!]!['completed']! + 1;
          }
          if (g.status == GoalStatus.active) {
            monthStats[g.month!]!['active'] =
                monthStats[g.month!]!['active']! + 1;
          }
          if (g.status == GoalStatus.failed) {
            monthStats[g.month!]!['failed'] =
                monthStats[g.month!]!['failed']! + 1;
          }
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
        if (g.status == GoalStatus.completed) {
          typeStats[g.type.name]!['completed'] =
              typeStats[g.type.name]!['completed']! + 1;
        }
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
          if (g.status == GoalStatus.completed) {
            quarterlyStats[g.quarter!]!['completed'] =
                quarterlyStats[g.quarter!]!['completed']! + 1;
          }
          if (g.status == GoalStatus.active) {
            quarterlyStats[g.quarter!]!['active'] =
                quarterlyStats[g.quarter!]!['active']! + 1;
          }
          if (g.status == GoalStatus.failed) {
            quarterlyStats[g.quarter!]!['failed'] =
                quarterlyStats[g.quarter!]!['failed']! + 1;
          }
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
      'verify_effective_from': row['verify_effective_from'],
      'verify_conditions': row['verify_conditions'],
      'target': row['target'],
      'target_effective_from': row['target_effective_from'],
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
      // Always write ALL verification columns (null when absent): upsertGoal uses
      // ConflictAlgorithm.replace, so an omitted column would be wiped to NULL on
      // every edit. Single rule → flat verify_*, compound → verify_conditions
      // with the flat columns nulled (Q4); an undecodable newer-client compound
      // is written back verbatim (verifyColumnValues) so replace can't strip it.
      // Columns exist after the evolve_sync v4/v8 migrations (run on open).
      ...goal.verifyColumnValues,
      // Same reasoning: written explicitly (date-only) so replace can't wipe it.
      // The anchor rides with a live rule OR a preserved compound blob (so a
      // preserved compound keeps its D10 freeze), else null. Matches the cloud
      // path, which retains it via omission + the preservesCompound guard.
      'verify_effective_from': goal.verifyEffectiveFromColumnValue,
      // Written explicitly (like the verify_* columns) so ConflictAlgorithm
      // .replace can't wipe it on an unrelated edit. Live target encoded, an
      // unreadable newer-client blob preserved verbatim, else null. Column
      // exists after the evolve_sync v9 migration (run automatically on open).
      'target': goal.targetColumnValue,
      // Same reasoning: written explicitly (date-only) so replace can't wipe it.
      // The forward-only target anchor rides with a written target (readable or
      // preserved blob); null otherwise. Column exists after the v11 migration.
      'target_effective_from':
          goal.targetColumnValue != null && goal.targetEffectiveFrom != null
              ? goal.targetEffectiveFrom!.toIso8601String().substring(0, 10)
              : null,
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
      // Cumulative numeric macro goals (v10). Columns exist after the evolve_sync
      // v10 migration (run automatically on open).
      'target_amount': row['target_amount'],
      'target_unit': row['target_unit'],
      'progress_amount': row['progress_amount'],
      'linked_goal_id': row['linked_goal_id'],
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
