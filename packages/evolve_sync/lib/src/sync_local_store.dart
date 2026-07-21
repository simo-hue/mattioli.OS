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
    // Both apps mint a row id independently the first time a setting is
    // written, so the SAME setting can exist under two ids. Without this the
    // two rows would never merge and the setting would flip between values
    // depending on which record was applied last — the exact failure per-key
    // settings records exist to prevent.
    'user_settings': ['user_id', 'key'],
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

  /// What an `updated_at` that cannot be ORDERED compares as: absent, or a
  /// string `DateTime.tryParse` rejects.
  ///
  /// [SyncEngine] shares this constant, and the two MUST agree. The engine
  /// derives `CloudRecord.updatedAtMs` (what goes on the wire) with its own
  /// copy of the same parse; this class derives the local natural-key rival's
  /// stamp; and [_remoteWinsNaturalKey] compares one directly against the
  /// other. While they disagreed — the engine answering 0, this class -1 — two
  /// equally unorderable stamps compared UNEQUAL, so the deterministic id
  /// tiebreak below never ran. Both devices then concluded "the remote row
  /// wins", each deleted its own copy and adopted the peer's, and the two
  /// tombstones crossed on the next pass and removed the row from both. The
  /// row was not lost by the tiebreak being wrong; it was lost by the two
  /// halves of one comparison using different arithmetic.
  ///
  /// Unparseable stamps are not hypothetical and are not produced here: the
  /// backup-import path in both apps coerces the file's `updated_at` as a plain
  /// string (unlike `start_date`/`end_date`, which it validates as dates) and
  /// writes whatever the file carried straight into the row, whence the dirty
  /// trigger copies it verbatim into `sync_state`.
  ///
  /// 0 and not -1, even though 0 sits inside the legal value domain, because
  /// this value travels on the wire and every build already in the field
  /// interprets it. [SyncEngine] uses -1 for "this device holds no record at
  /// all", so at 0 an unreadable stamp still beats an empty slot and the record
  /// lands on a device that has never seen it. Lowering the wire value to -1
  /// would tie with that sentinel and silently strand the record on every older
  /// device instead — the same data loss, moved.
  ///
  /// It does alias onto a genuine epoch stamp ([quarantineStamp] parses to
  /// exactly 0). That is harmless here: both mean "this copy loses to anything
  /// carrying a readable, later stamp", which is the only question either
  /// comparison asks.
  static const int unorderableMs = 0;

  int _ms(String? iso) => iso == null
      ? unorderableMs
      : (DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? unorderableMs);

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

  /// Record why a PUSH failed. A bare UPDATE is correct here and only here:
  /// every record the push names came out of [dirtyEntries], so the row
  /// provably exists and stays `dirty = 1` for the next attempt.
  ///
  /// Do NOT reuse this for a pulled record — see [markPullError].
  Future<void> markError(String recordName, String error) => _db.update(
        PrivateDbSchema.syncStateTable,
        {'last_error': error},
        where: 'record_name = ?',
        whereArgs: [recordName],
      );

  /// Marks the reason a PULLED record could not be applied.
  ///
  /// Split from [markError] because that method's bare UPDATE silently
  /// evaporates here. A record arriving from another device that this build has
  /// never seen has no `sync_state` row at all — the engine's own
  /// `stateOf()` returned null moments earlier — so the UPDATE matched zero
  /// rows and wrote nothing. The engine meanwhile held the change token for
  /// that record, so the device re-downloaded the entire delta on every sync,
  /// forever, while diagnostics reported a perfectly clean database and both
  /// apps' status row read "Everything uploaded". A permanently non-converging
  /// device that says it is fine is the worst output this layer can produce.
  ///
  /// Upserts, mirroring [quarantineRecord], and for the same two load-bearing
  /// reasons: `dirty = 0` (a dirty state row with no table row makes the push
  /// send a TOMBSTONE for the very record being preserved), and `updated_at`
  /// left ALONE on conflict — stamping the remote version would make LWW read
  /// the record as one this device already holds and skip it forever.
  ///
  /// The reason is stored under [pullFailurePrefix] so [diagnostics] can tell
  /// these apart from a quarantine: the change token is HELD for these, so the
  /// next sync re-delivers and re-attempts them on its own. A quarantined
  /// record's token has already advanced and only a full re-fetch revives it.
  /// The two need opposite advice, so they must not share a count.
  Future<void> markPullError(
    String recordName,
    String tableName,
    String rowId,
    String error,
  ) =>
      _db.rawInsert(
        'INSERT INTO ${PrivateDbSchema.syncStateTable} '
        '(record_name, table_name, row_id, updated_at, dirty, deleted, '
        'last_error) VALUES (?, ?, ?, ?, 0, 0, ?) '
        'ON CONFLICT(record_name) DO UPDATE SET last_error = excluded.last_error',
        [
          recordName,
          tableName,
          rowId,
          quarantineStamp,
          '$pullFailurePrefix$error',
        ],
      );

  /// Marks a `last_error` as a pull-apply failure whose change token is HELD,
  /// so [diagnostics] can separate "being retried" from "parked forever".
  /// Matched with SQL `LIKE`, so it must not contain `%` or `_`.
  ///
  /// Nothing needs to clear this explicitly: all three apply paths
  /// ([applyUpsert], [applyDelete], [applyAvatarState]) already write
  /// `last_error = null` for the record they land, so a transient failure stops
  /// being reported the moment the retry succeeds.
  static const String pullFailurePrefix = 'pull-failed: ';

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
    // Device-local columns are dropped on the way IN as well as on the way out.
    //
    // `PrivateDbSchema` documents them as "stripped on push AND preserved on
    // apply", but only the push half was implemented — this filtered by
    // `_columnsOf` alone and wrote whatever arrived. That held solely because
    // every CURRENT sender strips, which makes the guarantee a property of the
    // fleet rather than of this device. Devices in the field run older builds,
    // and `deviceLocalProfileColumns` did not always exist: a build predating it
    // still pushes `is_pro`, `sentry_consent` and `biometric_lock` inside the
    // payload.
    //
    // The consequences are the reasons the list exists. A pulled `is_pro = 1` is
    // an in-app-purchase bypass; a pulled `sentry_consent` grants consent on a
    // device that was never asked; a pulled `biometric_lock` either locks a user
    // out of a device that cannot satisfy it or silently does nothing; and a
    // pulled `avatar_url` points this device's UI at a file path that exists
    // only on another machine.
    //
    // This is a NARROWING — it enforces the existing list, and does not add to
    // it. Nothing here changes what goes on the wire, so older builds are
    // unaffected and no coordinated release is needed.
    final deviceLocal = PrivateDbSchema.localOnlyColumns[table] ?? const [];
    final data = {
      for (final e in row.entries)
        if (known.contains(e.key) && !deviceLocal.contains(e.key))
          e.key: e.value,
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
  ///
  /// Runs with FK enforcement OFF, exactly like [applyUpsert] — and for a far
  /// more serious reason. `profiles` is the `ON DELETE CASCADE` parent of EVERY
  /// synced table, so with foreign keys live a single pulled `profiles`
  /// tombstone deletes the user's entire database: goals, logs, moods,
  /// categories, everything. Worse, each cascaded row fires its own delete
  /// trigger, so the wipe is marked dirty and PROPAGATES to every other device.
  /// One stale tombstone would take out every copy the user has.
  ///
  /// `long_term_goals.category_id` is `ON DELETE SET NULL`, so a pulled
  /// `macro_goal_categories` tombstone would silently strip the category from
  /// the user's macro goals for the same reason.
  ///
  /// A pulled tombstone means "this ONE record is gone", never "and everything
  /// that referenced it". Cascades are a local-write concept; sync replicates
  /// each row's deletion explicitly, and the sender emits a tombstone per
  /// affected row. Letting SQLite infer extra deletions here duplicates that
  /// work and gets it wrong.
  ///
  /// FK must be toggled OUTSIDE the transaction — `PRAGMA foreign_keys` is a
  /// no-op once BEGIN has run (see [applyUpsert] and [reKeyOwner]).
  Future<void> applyDelete(
    String table,
    String id,
    String recordName,
    String updatedAtIso,
    String at,
  ) async {
    await _db.execute('PRAGMA foreign_keys = OFF');
    try {
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
    } finally {
      await _db.execute('PRAGMA foreign_keys = ON');
    }
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

  // ── Orphan identity reap ──────────────────────────────────────────────────

  /// Tables holding real user data. `profiles` and `goal_category_settings` are
  /// excluded because they ARE the identity scaffolding — both are minted as a
  /// pair by `_ensureProfile`/`seedProfile` and `goal_category_settings` is
  /// never read or written by the app (see the note on its DDL). Counting them
  /// as data would make every orphan look occupied and the reap a no-op.
  static const List<String> _identityDataTables = [
    'goals',
    'goal_logs',
    'daily_moods',
    'long_term_goals',
    'macro_goal_categories',
  ];

  /// Delete abandoned identities: `profiles` rows that are neither [canonical]
  /// nor own a single row of user data, together with their
  /// `goal_category_settings` shell. Returns the ids actually reaped.
  ///
  /// LOCAL ONLY — nothing propagates. The `sync_state` rows for the deleted
  /// records are restored exactly as they were, which does two things: the
  /// tombstones the delete triggers just wrote are erased, so no deletion
  /// crosses the wire; and the preserved `updated_at` makes the engine's LWW
  /// treat the cloud copy as not-newer, so a later full re-fetch cannot
  /// resurrect the row.
  ///
  /// Local-only is a deliberate choice over propagating tombstones. A device
  /// can transiently hold an OLD id as its active owner (the re-key writes the
  /// database before the Keychain), so letting one device's identity verdict
  /// delete rows on another risks a device deleting its own live profile and
  /// then re-seeding it in a loop. Each device instead reaches the same verdict
  /// independently from shared facts, and converges without coordinating. The
  /// cost is that the orphan record lingers in CloudKit as a few hundred
  /// harmless bytes.
  ///
  /// THE PRECONDITION IS LOAD-BEARING. Refusing to touch an identity that owns
  /// any data is what makes this safe, and it guards two distinct hazards:
  /// a genuine orphan-with-data needs a MIGRATION rather than a delete, and a
  /// device whose active owner is transiently stale would otherwise reap the
  /// real canonical identity — which owns everything, so it is always skipped.
  Future<List<String>> reapOrphanIdentities(String canonical) async {
    final reaped = <String>[];
    final profiles = await _db.query('profiles', columns: ['id']);

    for (final p in profiles) {
      final id = p['id'] as String;
      if (id == canonical) continue;

      var owned = 0;
      for (final t in _identityDataTables) {
        final r = await _db.rawQuery(
          'SELECT COUNT(*) AS n FROM $t WHERE user_id = ?',
          [id],
        );
        owned += (r.first['n'] as int?) ?? 0;
      }
      // Owns real data: NOT an orphan shell. Leave it entirely alone — this
      // needs data migration and a human decision, not a silent delete.
      if (owned > 0) continue;

      final settings = await _db.query(
        'goal_category_settings',
        columns: ['id'],
        where: 'user_id = ?',
        whereArgs: [id],
      );
      final names = <String>[
        'profiles:$id',
        for (final s in settings) 'goal_category_settings:${s['id']}',
      ];

      // Snapshot the bookkeeping BEFORE the delete triggers overwrite it.
      final snapshot = <String, Map<String, Object?>>{};
      for (final n in names) {
        final rows = await _db.query(
          PrivateDbSchema.syncStateTable,
          where: 'record_name = ?',
          whereArgs: [n],
          limit: 1,
        );
        if (rows.isNotEmpty) snapshot[n] = Map<String, Object?>.of(rows.first);
      }

      // FK OFF: delete the child explicitly rather than letting CASCADE infer
      // it, so exactly the rows intended are removed and nothing else can be
      // dragged along by a constraint added later.
      await _db.execute('PRAGMA foreign_keys = OFF');
      try {
        await _db.transaction((txn) async {
          await txn.delete(
            'goal_category_settings',
            where: 'user_id = ?',
            whereArgs: [id],
          );
          await txn.delete('profiles', where: 'id = ?', whereArgs: [id]);
          for (final n in names) {
            final prior = snapshot[n];
            if (prior == null) {
              // No bookkeeping before ⇒ remove the tombstone the trigger just
              // invented, so this deletion stays local.
              await txn.delete(
                PrivateDbSchema.syncStateTable,
                where: 'record_name = ?',
                whereArgs: [n],
              );
            } else {
              await txn.insert(
                PrivateDbSchema.syncStateTable,
                prior,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        });
      } finally {
        await _db.execute('PRAGMA foreign_keys = ON');
      }
      reaped.add(id);
    }
    return reaped;
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

  /// The schema version recorded at the last sync, or null before v6.
  Future<int?> syncedSchemaVersion() async {
    final rows = await _db.query(
      PrivateDbSchema.syncMetaTable,
      columns: ['schema_version'],
      where: 'id = 1',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['schema_version'] as int?;
  }

  Future<void> setSyncedSchemaVersion(int version) => _db.update(
        PrivateDbSchema.syncMetaTable,
        {'schema_version': version},
        where: 'id = 1',
      );

  /// The exact `last_error` written for a record whose table this build did not
  /// know. A constant because [clearUnknownTableParks] matches on it.
  static const String unknownTableReason =
      'no schema for this table in this build';

  /// Un-park records skipped because this build had no table for them, so a
  /// full re-fetch re-applies them now that it does.
  ///
  /// Without this an additive table migration silently loses every record the
  /// other device pushed while this one was behind: they were quarantined, the
  /// change token advanced past them, and CloudKit never replays a record it has
  /// already delivered. The device would simply never see those rows again.
  /// Kept symmetric with [clearUndecryptableParks] — including the `dirty`
  /// guard on the rewind. An unknown-table park normally takes
  /// [quarantineRecord]'s INSERT branch (this build has no such table, so it has
  /// no trigger and no local row, and the row cannot be dirty), but a future
  /// additive migration that lands the table between a park and an un-park
  /// would make it reachable. Diverging the two helpers is how that would
  /// become a bug again.
  Future<int> clearUnknownTableParks() => _db.rawUpdate(
        'UPDATE ${PrivateDbSchema.syncStateTable} SET last_error = NULL, '
        'updated_at = CASE WHEN dirty = 1 THEN updated_at ELSE ? END '
        'WHERE last_error = ?',
        [quarantineStamp, unknownTableReason],
      );

  /// Un-park every record parked as undecryptable, so a full re-fetch re-applies
  /// them under the new key.
  ///
  /// Clears `last_error` and drops the parked stamp back to [quarantineStamp]
  /// so the engine's LWW treats a re-delivered copy as newer than anything held
  /// locally. Deliberately narrow — it matches ONLY the undecryptable reason, so
  /// records parked because this build's schema cannot store them stay parked
  /// (a new key does not teach an old build a new CHECK).
  ///
  /// The rewind SKIPS a row with a pending local write, and that guard is
  /// load-bearing. [quarantineRecord]'s ON CONFLICT branch deliberately
  /// preserves `dirty`, so a record parked during a key split and then edited by
  /// the user is both parked and queued for push. Epoch-stamping that row
  /// destroys the edit twice over: on the pull, every remote copy — even one
  /// OLDER than the edit — beats `localMs = 0` and overwrites it while clearing
  /// dirty; on the push, a pending delete goes out as a tombstone stamped 1970
  /// and loses LWW on every other device, so the deletion silently never
  /// propagates while the sync reports success.
  ///
  /// Nothing is lost by skipping them: the rewind exists so a re-delivered
  /// record beats a parked PLACEHOLDER, and a placeholder (the INSERT branch)
  /// already sits at [quarantineStamp]. The only rows whose value the rewind
  /// changes are the dirty ones.
  ///
  /// The row count is still every matched row, dirty or not, because the engine
  /// keys the full re-fetch off it — a dirty parked record needs its newer
  /// remote copy re-delivered just as much as a clean one.
  Future<int> clearUndecryptableParks() => _db.rawUpdate(
        'UPDATE ${PrivateDbSchema.syncStateTable} SET last_error = NULL, '
        'updated_at = CASE WHEN dirty = 1 THEN updated_at ELSE ? END '
        'WHERE last_error = ?',
        [quarantineStamp, undecryptableReason],
      );

  /// The exact `last_error` written for a record sealed under another key. A
  /// constant because [clearUndecryptableParks] matches on it.
  static const String undecryptableReason =
      'undecryptable: sealed with a different sync key';

  /// The exact `last_error` written for a record stamped so far in the future
  /// that no clock error explains it. A constant because
  /// [clearImplausibleFutureParks] matches on it.
  ///
  /// It names its own retry rule because [SyncDiagnostics.toReport] files every
  /// park under "will NOT retry", which is true of the other two kinds and
  /// false of this one: this park expires by itself once the local clock passes
  /// the record's stamp. Saying so in the reason is what keeps the line honest
  /// without giving the header a special case.
  static const String implausibleFutureReason =
      'implausible future timestamp: the authoring clock is wrong '
      '(retried once ours passes it)';

  /// Park a record whose stamp is implausibly far in the future, recording WHEN
  /// it becomes worth retrying so the park can expire on its own.
  ///
  /// Everything [quarantineRecord] documents applies verbatim — `dirty = 0` so
  /// no tombstone is ever pushed for the parked row, [quarantineStamp] on
  /// INSERT and `updated_at` left ALONE on conflict so a re-delivered copy
  /// still wins LWW — with one addition, and it is the difference between a
  /// bounded park and a permanent one.
  ///
  /// [retryAfterIso] is the record's OWN stamp, stored in `last_synced_at`.
  /// That column is bookkeeping with no reader anywhere in this package or
  /// either app (grep it), and for a parked record its usual meaning — "when
  /// this record last moved" — is vacuous, so it carries "when this record is
  /// worth moving again" instead. [clearImplausibleFutureParks] reads it back
  /// and un-parks only the records whose moment has come, which is what lets a
  /// device that received a week-fast peer's rows heal a week later with no
  /// user action. If you ever give `last_synced_at` a real reader, this needs
  /// its own column first.
  ///
  /// Written on BOTH branches, unlike [quarantineRecord]'s conflict branch. A
  /// record parked after having synced normally already carries a real, PAST
  /// `last_synced_at`; leaving it would make the park read as due immediately
  /// and un-park on the very next sync, which is the re-fetch-every-sync loop
  /// this whole mechanism exists to break.
  Future<void> parkFutureSkew(
    String recordName,
    String tableName,
    String rowId,
    String retryAfterIso,
  ) =>
      _db.rawInsert(
        'INSERT INTO ${PrivateDbSchema.syncStateTable} '
        '(record_name, table_name, row_id, updated_at, dirty, deleted, '
        'last_error, last_synced_at) VALUES (?, ?, ?, ?, 0, 0, ?, ?) '
        'ON CONFLICT(record_name) DO UPDATE SET '
        'last_error = excluded.last_error, '
        'last_synced_at = excluded.last_synced_at',
        [
          recordName,
          tableName,
          rowId,
          quarantineStamp,
          implausibleFutureReason,
          retryAfterIso,
        ],
      );

  /// Un-park every future-skew park whose retry moment has passed, so the full
  /// re-fetch the engine drives off the returned count re-delivers them.
  ///
  /// Deliberately NOT a blanket clear, unlike its two siblings. A key rotation
  /// or a schema upgrade is an event: it happens once and un-parking everything
  /// is right. Clock skew has no event — the condition simply expires — so an
  /// unconditional clear here would un-park, re-fetch, re-park and re-fetch on
  /// every single sync, rebuilding the unbounded re-download that parking
  /// exists to stop. The `<= now` test is what makes it fire at most once per
  /// park.
  ///
  /// The comparison runs in Dart rather than SQL on purpose: `last_synced_at`
  /// is TEXT, so SQL would order it lexicographically, and
  /// `DateTime.toIso8601String()` emits a `+YYYYYY-` prefix for years past
  /// 9999 — which sorts BEFORE every ordinary year and would make the most
  /// absurd stamps look due immediately, i.e. the loop again, reachable by
  /// exactly the corrupt data this guard is for. An unreadable or absent
  /// retry stamp is treated as NOT due: failing closed leaves the record
  /// parked and visible in [diagnostics], never silently revived.
  ///
  /// Keeps [clearUndecryptableParks]' `dirty` guard on the rewind, for the same
  /// load-bearing reason: epoch-stamping a row with a pending local write
  /// destroys that write on both the pull and the push.
  Future<int> clearImplausibleFutureParks(DateTime now) async {
    final parked = await _db.query(
      PrivateDbSchema.syncStateTable,
      columns: ['record_name', 'last_synced_at'],
      where: 'last_error = ?',
      whereArgs: [implausibleFutureReason],
    );
    final due = <String>[
      for (final r in parked)
        if (_isDue(r['last_synced_at'] as String?, now))
          r['record_name'] as String,
    ];
    if (due.isEmpty) return 0;
    final placeholders = List.filled(due.length, '?').join(', ');
    return _db.rawUpdate(
      'UPDATE ${PrivateDbSchema.syncStateTable} SET last_error = NULL, '
      'last_synced_at = NULL, '
      'updated_at = CASE WHEN dirty = 1 THEN updated_at ELSE ? END '
      'WHERE record_name IN ($placeholders)',
      [quarantineStamp, ...due],
    );
  }

  bool _isDue(String? retryAfterIso, DateTime now) {
    if (retryAfterIso == null) return false;
    final at = DateTime.tryParse(retryAfterIso);
    return at != null && !at.isAfter(now);
  }

  // ── Diagnostics (read-only) ───────────────────────────────────────────────

  /// A snapshot of what has and has not moved — see [SyncDiagnostics].
  ///
  /// Strictly read-only: it must be safe to call from a status screen at any
  /// time, including mid-sync, so it takes no transaction and holds no lock. A
  /// count read while a push is committing may be a moment stale, which is
  /// immaterial for a diagnostic and far preferable to serialising against the
  /// engine.
  Future<SyncDiagnostics> diagnostics({String? owner}) async {
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
    final ownedRows = <String, int>{};
    // The identity column differs: `profiles` IS the identity (its `id`),
    // everything else points at it via `user_id`.
    String ownerColumnOf(String table) => table == 'profiles' ? 'id' : 'user_id';
    final owners = <String>{};
    for (final t in PrivateDbSchema.syncedTables) {
      final r = await _db.rawQuery('SELECT COUNT(*) AS n FROM $t');
      localRows[t] = (r.first['n'] as int?) ?? 0;

      final col = ownerColumnOf(t);
      for (final row in await _db
          .rawQuery('SELECT DISTINCT $col AS o FROM $t WHERE $col IS NOT NULL')) {
        owners.add(row['o'] as String);
      }
      if (owner != null) {
        final o = await _db.rawQuery(
          'SELECT COUNT(*) AS n FROM $t WHERE $col = ?',
          [owner],
        );
        ownedRows[t] = (o.first['n'] as int?) ?? 0;
      }
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
        'AND last_error NOT LIKE ? '
        'GROUP BY last_error ORDER BY n DESC',
        [dirty, '$pullFailurePrefix%'],
      );
      return {
        for (final r in rows) r['last_error'] as String: (r['n'] as int?) ?? 0,
      };
    }

    // Records the PULL could not apply. Counted separately from the parked ones
    // above because the change token is HELD for these: the next sync
    // re-delivers and re-attempts them without the user doing anything, whereas
    // a quarantined record's token has already advanced past it. Telling a user
    // "this will never retry" about a record that is being retried every 60
    // seconds is its own small lie.
    Future<Map<String, int>> heldErrors() async {
      final rows = await _db.rawQuery(
        'SELECT last_error, COUNT(*) AS n FROM '
        '${PrivateDbSchema.syncStateTable} '
        'WHERE last_error LIKE ? GROUP BY last_error ORDER BY n DESC',
        ['$pullFailurePrefix%'],
      );
      return {
        for (final r in rows)
          (r['last_error'] as String).substring(pullFailurePrefix.length):
              (r['n'] as int?) ?? 0,
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
      ownedRowsByTable: ownedRows,
      distinctOwnerCount: owners.length,
      pendingByTable: await countBy('dirty = 1 AND deleted = 0'),
      pendingDeletesByTable: await countBy('dirty = 1 AND deleted = 1'),
      errorsByReason: await errorsWhere(1),
      parkedByReason: await errorsWhere(0),
      heldByReason: await heldErrors(),
      hasChangeToken: metaRow['server_change_token'] != null,
      lastFullSyncAt:
          DateTime.tryParse((metaRow['last_full_sync_at'] as String?) ?? ''),
    );
  }
}
