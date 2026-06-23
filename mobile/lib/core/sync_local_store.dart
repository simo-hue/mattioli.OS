import 'package:sqflite_sqlcipher/sqflite.dart';

import 'private_db_schema.dart';

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

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

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

  Future<void> markSynced(String recordName, String at) => _db.update(
        PrivateDbSchema.syncStateTable,
        {'dirty': 0, 'last_synced_at': at, 'last_error': null},
        where: 'record_name = ?',
        whereArgs: [recordName],
      );

  Future<void> markError(String recordName, String error) => _db.update(
        PrivateDbSchema.syncStateTable,
        {'last_error': error},
        where: 'record_name = ?',
        whereArgs: [recordName],
      );

  /// Apply a pulled upsert: write the row, then clear dirty in the same txn.
  Future<void> applyUpsert(
    String table,
    String recordName,
    Map<String, Object?> row,
    String at,
  ) async {
    await _db.transaction((txn) async {
      await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.update(
        PrivateDbSchema.syncStateTable,
        {'dirty': 0, 'deleted': 0, 'last_synced_at': at, 'last_error': null},
        where: 'record_name = ?',
        whereArgs: [recordName],
      );
    });
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
  /// existing local data dirty so it uploads on the first sync).
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
  }
}
