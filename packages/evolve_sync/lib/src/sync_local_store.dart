import 'package:sqflite_common/sqlite_api.dart';

import 'private_db_schema.dart';
import 'sync_diagnostics.dart';

/// One `sync_state` row.
class SyncStateEntry {
  final String recordName;
  final String tableName;
  final String rowId;
  final String updatedAt; // UTC ISO (the LWW comparator)
  final bool deleted;

  const SyncStateEntry({
    required this.recordName,
    required this.tableName,
    required this.rowId,
    required this.updatedAt,
    required this.deleted,
  });
}

/// A local row that already holds a pulled record's natural key under a
/// different id — the two are the same logical record and only one can survive.
class _NaturalKeyRival {
  final String id;
  final int updatedAtMs;
  const _NaturalKeyRival(this.id, this.updatedAtMs);
}

/// A pulled row THIS build's schema cannot store — a value its constraints
/// reject (the shape of a newer client widening a CHECK and writing a
/// `goal_logs.status` this build has never heard of), or a payload with no id.
///
/// Separate from an ordinary apply failure because it is PERMANENT: the same
/// bytes are rejected identically on every retry, so the change-token hold that
/// exists to retry TRANSIENT failures would instead pin the pull on this record
/// forever. [SyncEngine] quarantines these — see
/// [SyncLocalStore.quarantineRecord].
class UnstorableRowException implements Exception {
  /// Schema-derived and free of row VALUES: it is persisted to
  /// `sync_state.last_error` and shipped to crash reporting.
  final String reason;

  const UnstorableRowException(this.reason);

  @override
  String toString() => 'UnstorableRowException: $reason';
}

/// Reads/writes the local sync bookkeeping (`sync_state` / `sync_meta`) and the
/// raw domain rows over a [Database]. Concrete on purpose: the same class backs
/// the production SQLCipher DB and the in-memory FFI DB used in tests.
///
/// Invariant: the apply* methods are the ONLY place `dirty` is cleared. A row
/// write fires the dirty trigger; clearing `dirty` right after (same txn) is
/// what prevents a pulled row from being re-pushed (pull→push ping-pong).
class SyncLocalStore {
  final Database _db;
  SyncLocalStore(this._db);

  /// The UNIQUE constraints declared in [PrivateDbSchema.createCoreTables] that
  /// are NOT the primary key. Both apps mint a FRESH uuid whenever no LOCAL row
  /// holds a slot, so two devices independently filling the same slot produce
  /// two different ids for one logical record. `record_name` (`<table>:<uuid>`)
  /// therefore cannot arbitrate them — [applyUpsert] resolves on these instead.
  static const Map<String, List<String>> naturalKeys = {
    'goal_logs': ['goal_id', 'date'],
    'daily_moods': ['user_id', 'date'],
    'macro_goal_categories': ['user_id', 'name'],
    // Seeded once per profile by both apps (_ensureProfile), so a second
    // device's enable ALWAYS brings a rival row for this one.
    'goal_category_settings': ['user_id'],
  };

  /// Rows referencing a [naturalKeys] table, as `parent -> {childTable: column}`.
  /// A natural-key merge re-points these onto the surviving row: the schema's
  /// `ON DELETE SET NULL` would instead drop the association outright, and it
  /// cannot fire anyway because the apply runs with FK enforcement off.
  static const Map<String, Map<String, String>> _naturalKeyChildren = {
    'macro_goal_categories': {'long_term_goals': 'category_id'},
  };

  /// `PRAGMA table_info` per table, cached: the schema is fixed once the DB is
  /// open (migrations run at open time).
  final Map<String, Set<String>> _columnCache = {};

  /// The `sync_state.updated_at` a quarantined record is parked at — older than
  /// any real record, so the engine's LWW re-attempts the record the moment it
  /// is delivered again. See [quarantineRecord].
  static const String quarantineStamp = '1970-01-01T00:00:00.000Z';

  /// SQLite PRIMARY result codes meaning "this row does not fit this schema", so
  /// every retry fails identically: `SQLITE_CONSTRAINT` (19) — which covers
  /// CHECK, NOT NULL and UNIQUE — and `SQLITE_MISMATCH` (20), a value of the
  /// wrong storage class. Busy/locked (5/6) and everything else stay
  /// unclassified: those are the transient failures the token-hold is for.
  static const Set<int> _unstorablePrimaryCodes = {19, 20};

  /// [error] as an [UnstorableRowException], or null if it may be transient.
  ///
  /// Extended result codes carry the primary code in their low byte (275 =
  /// CHECK = 19 | 1<<8), and sqflite reports the extended code on ffi but the
  /// primary one on darwin, so mask before comparing.
  UnstorableRowException? _asUnstorable(DatabaseException error) {
    final code = error.getResultCode();
    if (code != null) {
      return _unstorablePrimaryCodes.contains(code & 0xFF)
          ? UnstorableRowException('row rejected by this schema (sqlite $code)')
          : null;
    }
    // No parseable result code: fall back to SQLite's own wording. Only the
    // CLASSIFICATION reads the raw text — it is never persisted or logged,
    // because a DatabaseException stringifies to include the row's values.
    return error.toString().contains('constraint failed')
        ? const UnstorableRowException(
            'row rejected by this schema (constraint failed)')
        : null;
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  int _ms(String? iso) =>
      iso == null ? -1 : (DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? -1);

  Future<Set<String>> _columnsOf(String table) async {
    final cached = _columnCache[table];
    if (cached != null) return cached;
    final info = await _db.rawQuery('PRAGMA table_info($table)');
    final cols = {for (final c in info) c['name'] as String};
    _columnCache[table] = cols;
    return cols;
  }

  SyncStateEntry _entry(Map<String, Object?> r) => SyncStateEntry(
        recordName: r['record_name'] as String,
        tableName: r['table_name'] as String,
        rowId: r['row_id'] as String,
        updatedAt: r['updated_at'] as String,
        deleted: ((r['deleted'] as int?) ?? 0) == 1,
      );

  Future<List<SyncStateEntry>> dirtyEntries() async {
    final rows = await _db.query(
      PrivateDbSchema.syncStateTable,
      where: 'dirty = 1',
    );
    return rows.map(_entry).toList();
  }

  Future<SyncStateEntry?> stateOf(String recordName) async {
    final rows = await _db.query(
      PrivateDbSchema.syncStateTable,
      where: 'record_name = ?',
      whereArgs: [recordName],
      limit: 1,
    );
    return rows.isEmpty ? null : _entry(rows.first);
  }

  Future<Map<String, Object?>?> readRow(String table, String id) async {
    final rows =
        await _db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Clear `dirty` for a record that was successfully pushed — but ONLY if the
  /// row still carries [pushedUpdatedAt], the `sync_state.updated_at` the push
  /// actually serialized.
  ///
  /// App writes are not serialized against sync: an edit landing during the
  /// upload round-trip re-fires the dirty trigger and moves
  /// `sync_state.updated_at`. An unconditional clear would drop that edit
  /// (never pushed, no dirty flag left to retry from, and the pull can't repair
  /// it because the local stamp is now the newer one). A missed guard leaves
  /// `dirty = 1` so the next push carries the newer value.
  Future<void> markSynced(
    String recordName,
    String at,
    String pushedUpdatedAt,
  ) =>
      _db.update(
        PrivateDbSchema.syncStateTable,
        {'dirty': 0, 'last_synced_at': at, 'last_error': null},
        where: 'record_name = ? AND updated_at = ?',
        whereArgs: [recordName, pushedUpdatedAt],
      );

  Future<void> markError(String recordName, String error) => _db.update(
        PrivateDbSchema.syncStateTable,
        {'last_error': error},
        where: 'record_name = ?',
        whereArgs: [recordName],
      );

  /// Apply a pulled upsert: write the row, then clear dirty in the same txn.
  /// Returns false when the record LOST a natural-key contest (see below) and
  /// was deliberately not written — a benign skip, not a failure.
  ///
  /// The write is an UPDATE of exactly the columns the payload carries, falling
  /// back to INSERT when the id is new. It is deliberately NOT `INSERT OR
  /// REPLACE`:
  ///  * REPLACE resets every column the payload omits to its schema default, so
  ///    a row round-tripping through a client whose schema predates an additive
  ///    migration would wipe the newer columns on the devices that do have them.
  ///  * REPLACE DELETEs any row conflicting on ANY unique index — a different
  ///    row under a [naturalKeys] collision — silently and without firing the
  ///    tombstone trigger (`recursive_triggers` is off), leaving the cloud and
  ///    the other devices unaware the row ever died.
  ///
  /// Columns absent from this build's schema are dropped: a newer client's
  /// additive migration has no storage here. They are not lost, because a
  /// payload written back by THIS build simply omits them and the UPDATE above
  /// leaves them untouched on the clients that do have them.
  ///
  /// A VALUE this build's constraints reject (as opposed to a column it simply
  /// lacks) has nowhere to go at all, and no retry can change that. It raises
  /// [UnstorableRowException] so the engine can tell it apart from a transient
  /// failure and quarantine it rather than pin the change token on it forever.
  ///
  /// FK enforcement is toggled OFF around the write (outside the txn — it's a
  /// no-op once BEGIN runs, same as [reKeyOwner]): the natural-key merge deletes
  /// the losing row, and `macro_goal_categories`' `ON DELETE SET NULL` would
  /// drop exactly the child association [_mergeChildrenOntoWinner] re-points
  /// onto the winner. The pull applies rows in FK-safe parent→child order.
  Future<bool> applyUpsert(
    String table,
    String recordName,
    Map<String, Object?> row,
    int remoteUpdatedAtMs,
    String at,
  ) async {
    final id = row['id'];
    if (id is! String) {
      throw const UnstorableRowException('payload has no string id');
    }
    final known = await _columnsOf(table);
    final data = {
      for (final e in row.entries)
        if (known.contains(e.key)) e.key: e.value,
    };

    var applied = true;
    await _db.execute('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction((txn) async {
        final rival = await _naturalKeyRival(txn, table, row, id);
        if (rival != null) {
          if (!_remoteWinsNaturalKey(remoteUpdatedAtMs, id, rival)) {
            applied = false;
            return;
          }
          await _mergeChildrenOntoWinner(txn, table, rival.id, id, at);
          // Explicit DELETE (unlike REPLACE's implicit one) fires the tombstone
          // trigger, so the loser's death propagates to the other devices.
          await txn.delete(table, where: 'id = ?', whereArgs: [rival.id]);
        }
        final changed =
            await txn.update(table, data, where: 'id = ?', whereArgs: [id]);
        if (changed == 0) {
          await txn.insert(table, data);
        }
        await txn.update(
          PrivateDbSchema.syncStateTable,
          {'dirty': 0, 'deleted': 0, 'last_synced_at': at, 'last_error': null},
          where: 'record_name = ?',
          whereArgs: [recordName],
        );
      });
    } on DatabaseException catch (e) {
      // The throw rolled the transaction back, so a natural-key rival deleted
      // above is still here and the local row is untouched.
      final unstorable = _asUnstorable(e);
      if (unstorable == null) rethrow; // transient — the engine holds the token
      throw unstorable;
    } finally {
      await _db.execute('PRAGMA foreign_keys = ON');
    }
    return applied;
  }

  /// Park a pulled record this build cannot apply: record WHY, without pinning
  /// the change token on it forever (see [SyncEngine]).
  ///
  /// NONE of the record's data is written or destroyed — it stays intact in the
  /// cloud and on the client that authored it, and this row is only bookkeeping.
  /// Two properties make that parking safe, and both are load-bearing:
  ///
  ///  * `dirty = 0`. A dirty state row whose table row does not exist makes the
  ///    push send a TOMBSTONE for it (the "row vanished under us" path), which
  ///    would delete the very record being preserved — from the cloud and from
  ///    the client that authored it. Nothing marks this row dirty: the triggers
  ///    fire on row writes only (there is no row), [markAllDirty] walks the
  ///    tables (ditto), and [reKeyOwner] drops `sync_state` wholesale.
  ///    [quarantineStamp] is the backstop if that ever stops holding — an
  ///    epoch-stamped tombstone loses LWW on every device that has the record.
  ///  * [quarantineStamp] on INSERT, and `updated_at` left ALONE on conflict
  ///    (the record is already tracked at the local row's real version).
  ///    Stamping the REMOTE version here is the move that would lose data: LWW
  ///    would then read the record as one this device already holds and skip it
  ///    forever — even on a full re-fetch, and even after an app update taught
  ///    this build to store it.
  Future<void> quarantineRecord(
    String recordName,
    String tableName,
    String rowId,
    String reason,
  ) =>
      _db.rawInsert(
        'INSERT INTO ${PrivateDbSchema.syncStateTable} '
        '(record_name, table_name, row_id, updated_at, dirty, deleted, '
        'last_error) VALUES (?, ?, ?, ?, 0, 0, ?) '
        'ON CONFLICT(record_name) DO UPDATE SET last_error = excluded.last_error',
        [recordName, tableName, rowId, quarantineStamp, reason],
      );

  /// A local row holding [table]'s natural key under a DIFFERENT id, if any.
  /// Compares on `sync_state.updated_at` — the same stamp the engine's LWW uses,
  /// and the one that covers `macro_goal_categories`' nullable `updated_at`.
  Future<_NaturalKeyRival?> _naturalKeyRival(
    DatabaseExecutor txn,
    String table,
    Map<String, Object?> row,
    String id,
  ) async {
    final key = naturalKeys[table];
    // A sender predating one of the key's columns can't be compared on it.
    if (key == null || !key.every(row.containsKey)) return null;
    final rows = await txn.rawQuery(
      'SELECT t.id AS id, COALESCE(s.updated_at, t.updated_at) AS updated_at '
      'FROM $table t LEFT JOIN ${PrivateDbSchema.syncStateTable} s '
      "ON s.record_name = '$table:' || t.id "
      'WHERE ${[for (final c in key) 't.$c = ?'].join(' AND ')} '
      'AND t.id <> ? LIMIT 1',
      [for (final c in key) row[c], id],
    );
    if (rows.isEmpty) return null;
    return _NaturalKeyRival(
      rows.first['id'] as String,
      _ms(rows.first['updated_at'] as String?),
    );
  }

  bool _remoteWinsNaturalKey(
    int remoteMs,
    String remoteId,
    _NaturalKeyRival local,
  ) {
    if (remoteMs != local.updatedAtMs) return remoteMs > local.updatedAtMs;
    // An exact tie must resolve identically on BOTH devices or each keeps the
    // other's row and they never reconverge, so fall back to a total order on
    // the id (arbitrary, but the same everywhere).
    return remoteId.compareTo(local.id) < 0;
  }

  /// Re-point the loser's children onto the surviving row: two rows sharing a
  /// natural key ARE the same logical record, so its children belong to the
  /// winner. `updated_at` is bumped because an unbumped row loses the engine's
  /// LWW comparison on the other devices and the re-point would never
  /// propagate, stranding them on a reference to the deleted row.
  Future<void> _mergeChildrenOntoWinner(
    DatabaseExecutor txn,
    String table,
    String loserId,
    String winnerId,
    String at,
  ) async {
    for (final child in (_naturalKeyChildren[table] ?? const {}).entries) {
      await txn.update(
        child.key,
        {child.value: winnerId, 'updated_at': at},
        where: '${child.value} = ?',
        whereArgs: [loserId],
      );
    }
  }

  /// Apply a pulled tombstone: delete the row, then stamp the tombstone with the
  /// server's time and clear dirty (overriding the delete trigger's "now").
  Future<void> applyDelete(
    String table,
    String id,
    String recordName,
    String updatedAtIso,
    String at,
  ) async {
    await _db.transaction((txn) async {
      await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      await txn.update(
        PrivateDbSchema.syncStateTable,
        {
          'dirty': 0,
          'deleted': 1,
          'updated_at': updatedAtIso,
          'last_synced_at': at,
          'last_error': null,
        },
        where: 'record_name = ?',
        whereArgs: [recordName],
      );
    });
  }

  Future<String?> changeToken() async {
    final r = await _db.query(
      PrivateDbSchema.syncMetaTable,
      columns: ['server_change_token'],
      where: 'id = 1',
      limit: 1,
    );
    return r.isEmpty ? null : r.first['server_change_token'] as String?;
  }

  Future<void> setChangeToken(String? token) => _db.update(
        PrivateDbSchema.syncMetaTable,
        {'server_change_token': token},
        where: 'id = 1',
      );

  Future<void> setLastFullSync(String at) => _db.update(
        PrivateDbSchema.syncMetaTable,
        {'last_full_sync_at': at},
        where: 'id = 1',
      );

  Future<DateTime?> lastFullSync() async {
    final r = await _db.query(
      PrivateDbSchema.syncMetaTable,
      columns: ['last_full_sync_at'],
      where: 'id = 1',
      limit: 1,
    );
    final s = r.isEmpty ? null : r.first['last_full_sync_at'] as String?;
    return s == null ? null : DateTime.tryParse(s);
  }

  Future<bool> pendingZoneWipe() async {
    final r = await _db.query(
      PrivateDbSchema.syncMetaTable,
      columns: ['pending_zone_wipe'],
      where: 'id = 1',
      limit: 1,
    );
    return r.isNotEmpty && ((r.first['pending_zone_wipe'] as int?) ?? 0) == 1;
  }

  Future<void> setPendingZoneWipe(bool value) => _db.update(
        PrivateDbSchema.syncMetaTable,
        {'pending_zone_wipe': value ? 1 : 0},
        where: 'id = 1',
      );

  /// Unify this device's owner id onto the canonical sync-owner (shared via the
  /// iCloud Keychain) when a second device enables sync. Re-points every row's
  /// `user_id` and the single `profiles` row to [canonicalOwner] so the per-row
  /// data unions and the singletons converge under one identity.
  ///
  /// Enable-time only: it clears + rebuilds `sync_state` (everything dirty for
  /// the first upload), so it must not run while real tombstones are pending.
  Future<void> reKeyOwner(String localOwner, String canonicalOwner) async {
    if (localOwner == canonicalOwner) return;

    // FK must be toggled OUTSIDE a transaction (it's a no-op once BEGIN runs).
    // Re-keying a referenced primary key (profiles.id) needs it off.
    await _db.execute('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction((txn) async {
        final canonicalExists = (await txn.query(
          'profiles',
          where: 'id = ?',
          whereArgs: [canonicalOwner],
          limit: 1,
        ))
            .isNotEmpty;
        if (canonicalExists) {
          // The canonical profile already arrived (pulled) — drop the local one.
          await txn.delete('profiles', where: 'id = ?', whereArgs: [localOwner]);
        } else {
          await txn.update('profiles', {'id': canonicalOwner},
              where: 'id = ?', whereArgs: [localOwner]);
        }
        for (final t in PrivateDbSchema.syncedTables) {
          if (t == 'profiles') continue;
          await txn.update(t, {'user_id': canonicalOwner},
              where: 'user_id = ?', whereArgs: [localOwner]);
        }
      });
    } finally {
      await _db.execute('PRAGMA foreign_keys = ON');
    }

    // Owner-keyed record_names (profiles:<owner>) changed; the simplest correct
    // rebuild is to drop sync_state and re-mark everything dirty for upload.
    await _db.delete(PrivateDbSchema.syncStateTable);
    await markAllDirty();
  }

  /// Returns the FK violations reported by `PRAGMA foreign_key_check` (empty ⇒
  /// integrity intact). Used to assert the re-key migration is clean.
  Future<List<Map<String, Object?>>> foreignKeyCheck() =>
      _db.rawQuery('PRAGMA foreign_key_check');

  /// Backfill `sync_state` for rows that pre-date sync (first enable marks all
  /// existing local data dirty so it uploads on the first sync). Includes the
  /// avatar pseudo-record when a local avatar exists, since no trigger covers
  /// it.
  Future<void> markAllDirty() async {
    for (final t in PrivateDbSchema.syncedTables) {
      final rows = await _db.query(t, columns: ['id', 'updated_at']);
      for (final row in rows) {
        await _db.insert(
          PrivateDbSchema.syncStateTable,
          {
            'record_name': '$t:${row['id']}',
            'table_name': t,
            'row_id': row['id'],
            'updated_at': row['updated_at'] ?? _nowIso(),
            'dirty': 1,
            'deleted': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    final profiles = await _db.query(
      'profiles',
      columns: ['id', 'avatar_url', 'updated_at'],
    );
    for (final p in profiles) {
      final avatar = p['avatar_url'] as String?;
      if (avatar != null && avatar.isNotEmpty) {
        await markAvatarDirty(p['id'] as String);
      }
    }
  }

  // ── Avatar pseudo-record (`avatar:<owner>`, no backing table) ─────────────

  /// Mark the avatar record dirty for push — called explicitly by the app's
  /// avatar write path (no trigger exists for it). [deleted] pushes a tombstone
  /// (avatar removed).
  Future<void> markAvatarDirty(String owner, {bool deleted = false}) =>
      _db.insert(
        PrivateDbSchema.syncStateTable,
        {
          'record_name': PrivateDbSchema.avatarRecordName(owner),
          'table_name': PrivateDbSchema.avatarRecordTable,
          'row_id': owner,
          'updated_at': _nowIso(),
          'dirty': 1,
          'deleted': deleted ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// Record a pulled avatar (or avatar tombstone) as applied: stamp the
  /// server's edit time and clear dirty — mirroring [applyUpsert]/[applyDelete]
  /// for the record that has no DB row of its own.
  Future<void> applyAvatarState(
    String recordName,
    String updatedAtIso,
    String at, {
    required bool deleted,
  }) =>
      _db.insert(
        PrivateDbSchema.syncStateTable,
        {
          'record_name': recordName,
          'table_name': PrivateDbSchema.avatarRecordTable,
          'row_id': recordName
              .substring(PrivateDbSchema.avatarRecordTable.length + 1),
          'updated_at': updatedAtIso,
          'last_synced_at': at,
          'dirty': 0,
          'deleted': deleted ? 1 : 0,
          'last_error': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// Update a device-local column (e.g. `profiles.avatar_url`) WITHOUT leaving
  /// the row marked for push: the write fires the table's dirty trigger like
  /// any other, so the row's prior sync state is captured first and restored
  /// after, all in one transaction. Local-only columns are stripped from
  /// payloads anyway — re-pushing the row over them would be pure ping-pong.
  Future<void> setLocalOnlyColumn(
    String table,
    String id,
    String column,
    Object? value,
  ) async {
    await _db.transaction((txn) async {
      final prior = await txn.query(
        PrivateDbSchema.syncStateTable,
        where: 'record_name = ?',
        whereArgs: ['$table:$id'],
        limit: 1,
      );
      await txn.update(
        table,
        {column: value},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (prior.isEmpty) {
        // The row had no sync state before this write — drop what the trigger
        // just created so a local-only touch never queues a push by itself.
        await txn.delete(
          PrivateDbSchema.syncStateTable,
          where: 'record_name = ?',
          whereArgs: ['$table:$id'],
        );
      } else {
        await txn.update(
          PrivateDbSchema.syncStateTable,
          {
            'dirty': prior.first['dirty'],
            'deleted': prior.first['deleted'],
            'updated_at': prior.first['updated_at'],
          },
          where: 'record_name = ?',
          whereArgs: ['$table:$id'],
        );
      }
    });
  }

  /// Drop ALL sync bookkeeping: every `sync_state` row, the change token and
  /// the key fingerprint. Local user data is untouched.
  ///
  /// For the recovery reset, where the cloud zone has been wiped and this
  /// device is about to re-upload from scratch. Everything the old bookkeeping
  /// described — records synced, records parked as undecryptable, the token's
  /// position — refers to a zone that no longer exists, so keeping any of it
  /// would suppress the very re-upload the reset exists to perform.
  Future<void> resetSyncState() async {
    await _db.delete(PrivateDbSchema.syncStateTable);
    await _db.update(
      PrivateDbSchema.syncMetaTable,
      {
        'server_change_token': null,
        'key_fingerprint': null,
        'last_full_sync_at': null,
      },
      where: 'id = 1',
    );
  }

  // ── E2E key fingerprint (v5) ──────────────────────────────────────────────

  /// The key fingerprint recorded at the last sync, or null before v5 / the
  /// first sync on this device.
  Future<String?> keyFingerprint() async {
    final rows = await _db.query(
      PrivateDbSchema.syncMetaTable,
      columns: ['key_fingerprint'],
      where: 'id = 1',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['key_fingerprint'] as String?;
  }

  Future<void> setKeyFingerprint(String fingerprint) => _db.update(
        PrivateDbSchema.syncMetaTable,
        {'key_fingerprint': fingerprint},
        where: 'id = 1',
      );

  /// Un-park every record parked as undecryptable, so a full re-fetch re-applies
  /// them under the new key.
  ///
  /// Clears `last_error` and drops the parked stamp back to [quarantineStamp]
  /// so the engine's LWW treats a re-delivered copy as newer than anything held
  /// locally. Deliberately narrow — it matches ONLY the undecryptable reason, so
  /// records parked because this build's schema cannot store them stay parked
  /// (a new key does not teach an old build a new CHECK).
  Future<int> clearUndecryptableParks() => _db.update(
        PrivateDbSchema.syncStateTable,
        {'last_error': null, 'updated_at': quarantineStamp},
        where: 'last_error = ?',
        whereArgs: [undecryptableReason],
      );

  /// The exact `last_error` written for a record sealed under another key. A
  /// constant because [clearUndecryptableParks] matches on it.
  static const String undecryptableReason =
      'undecryptable: sealed with a different sync key';

  // ── Diagnostics (read-only) ───────────────────────────────────────────────

  /// A snapshot of what has and has not moved — see [SyncDiagnostics].
  ///
  /// Strictly read-only: it must be safe to call from a status screen at any
  /// time, including mid-sync, so it takes no transaction and holds no lock. A
  /// count read while a push is committing may be a moment stale, which is
  /// immaterial for a diagnostic and far preferable to serialising against the
  /// engine.
  Future<SyncDiagnostics> diagnostics() async {
    Future<Map<String, int>> countBy(String where) async {
      final rows = await _db.rawQuery(
        'SELECT table_name, COUNT(*) AS n FROM '
        '${PrivateDbSchema.syncStateTable} WHERE $where GROUP BY table_name',
      );
      return {
        for (final r in rows)
          r['table_name'] as String: (r['n'] as int?) ?? 0,
      };
    }

    final localRows = <String, int>{};
    for (final t in PrivateDbSchema.syncedTables) {
      final r = await _db.rawQuery('SELECT COUNT(*) AS n FROM $t');
      localRows[t] = (r.first['n'] as int?) ?? 0;
    }

    // Split errored records on `dirty`, NOT on [quarantineStamp]: a record is
    // retried iff it is dirty, and `quarantineRecord`'s ON CONFLICT branch
    // updates only `last_error`, so a parked record that already had a
    // `sync_state` row keeps its original stamp and a stamp test misclassifies
    // it. `dirty` is what actually decides whether anything happens next.
    Future<Map<String, int>> errorsWhere(int dirty) async {
      final rows = await _db.rawQuery(
        'SELECT last_error, COUNT(*) AS n FROM '
        '${PrivateDbSchema.syncStateTable} '
        'WHERE last_error IS NOT NULL AND dirty = ? '
        'GROUP BY last_error ORDER BY n DESC',
        [dirty],
      );
      return {
        for (final r in rows) r['last_error'] as String: (r['n'] as int?) ?? 0,
      };
    }

    final meta = await _db.query(
      PrivateDbSchema.syncMetaTable,
      where: 'id = 1',
      limit: 1,
    );
    final metaRow = meta.isEmpty ? const <String, Object?>{} : meta.first;

    return SyncDiagnostics(
      localRowsByTable: localRows,
      pendingByTable: await countBy('dirty = 1 AND deleted = 0'),
      pendingDeletesByTable: await countBy('dirty = 1 AND deleted = 1'),
      errorsByReason: await errorsWhere(1),
      parkedByReason: await errorsWhere(0),
      hasChangeToken: metaRow['server_change_token'] != null,
      lastFullSyncAt:
          DateTime.tryParse((metaRow['last_full_sync_at'] as String?) ?? ''),
    );
  }
}
