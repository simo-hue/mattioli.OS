import 'package:evolve_verification/evolve_verification.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// On-device, **unsynced**, data-mode-independent implementation of
/// [VerificationStateStore] (D4/D8). Backs the local verification bookkeeping —
/// manual freezes + couldn't-verify markers — in a small `verification_state`
/// table, separate from the synced `goal_logs`/`goals` data.
///
/// Typed against `DatabaseExecutor` (which `sqflite_sqlcipher` and the in-memory
/// `sqflite_common_ffi` test factory both implement) so it runs against the app
/// database on device and an in-memory database in tests, and inside
/// transactions.
class SqfliteVerificationStateStore implements VerificationStateStore {
  SqfliteVerificationStateStore(this._db);

  final DatabaseExecutor _db;

  static const String table = 'verification_state';

  static const String _manual = 'manual';
  static const String _cnv = 'could_not_verify';

  /// The on-disk filename for the dedicated verification-state database.
  static const String dbFileName = 'verification_state.db';

  /// Opens (creating / migrating as needed) the dedicated `verification_state.db`
  /// and returns a store over it.
  ///
  /// This database is **unencrypted** and exists in BOTH data modes (D8): it
  /// holds only local verification bookkeeping (manual freezes + couldn't-verify
  /// markers), never synced or private user data, so it needs no cipher key —
  /// which is exactly what lets it be reopened from a cold background
  /// notification isolate, where the encrypted app DB's key is unavailable.
  /// `sqflite` caches by path (single-instance), so a second call in the same
  /// isolate returns the already-open connection rather than a competing handle.
  static Future<SqfliteVerificationStateStore> open() async {
    final path = p.join(await getDatabasesPath(), dbFileName);
    final db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, _) => createTable(db),
      onUpgrade: (db, oldVersion, _) async {
        // v1 → v2 added the `nudged_at` column (couldn't-verify nudge de-dup).
        if (oldVersion < 2) await migrateToV2(db);
        // v2 → v3 added `status` — the verdict a manual freeze protects.
        if (oldVersion < 3) await migrateToV3(db);
      },
    );
    // Idempotent — also creates the table for a DB opened at an existing version.
    await createTable(db);
    return SqfliteVerificationStateStore(db);
  }

  /// Creates the table + index. Idempotent, so it is safe to call on every open.
  static Future<void> createTable(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS $table (
  goal_id TEXT NOT NULL,
  date TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('$_manual', '$_cnv')),
  recorded_at TEXT NOT NULL,
  nudged_at TEXT,
  status TEXT,
  PRIMARY KEY (goal_id, date, kind)
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_vstate_goal_kind ON $table (goal_id, kind)',
    );
  }

  /// v1 → v2 migration: add the nullable `nudged_at` column that records when a
  /// couldn't-verify day last fired a nudge (so it isn't re-nudged every
  /// foreground). Guarded by a column probe so it is idempotent (safe to run
  /// more than once, and on a table that already has the column).
  ///
  /// If the table does not exist yet (`PRAGMA table_info` returns no rows), this
  /// is a no-op: the post-open [createTable] call already creates the table with
  /// `nudged_at` present, so `ALTER TABLE` on a missing table (which would throw
  /// and fail `openDatabase`) is deliberately avoided.
  static Future<void> migrateToV2(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.isEmpty) return; // no table → createTable will build it fresh
    final hasNudgedAt = columns.any((c) => c['name'] == 'nudged_at');
    if (!hasNudgedAt) {
      await db.execute('ALTER TABLE $table ADD COLUMN nudged_at TEXT');
    }
  }

  /// v2 → v3 migration: add the nullable `status` column — the verdict a manual
  /// freeze protects (`done`/`missed`).
  ///
  /// Additive and null-filling, so existing freezes survive with `status IS
  /// NULL`. That is the honest value for them: they were recorded before the
  /// status was stored, so nothing is known about what the user chose, and
  /// reconcile leaves such a day alone rather than restoring a guess. They heal
  /// on the next check-in, which rewrites the row with a status.
  ///
  /// Guarded by a column probe, like [migrateToV2], so it is idempotent and safe
  /// on a table that already has the column.
  static Future<void> migrateToV3(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.isEmpty) return; // no table → createTable will build it fresh
    final hasStatus = columns.any((c) => c['name'] == 'status');
    if (!hasStatus) {
      await db.execute('ALTER TABLE $table ADD COLUMN status TEXT');
    }
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _parse(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  @override
  Future<Map<String, Map<DateTime, String?>>> manualDays({
    required Iterable<String> goalIds,
    required DateTime from,
    required DateTime to,
  }) async {
    final ids = goalIds.toList();
    if (ids.isEmpty) return {};
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await _db.query(
      table,
      columns: ['goal_id', 'date', 'status'],
      where: "kind = '$_manual' AND goal_id IN ($placeholders) "
          'AND date BETWEEN ? AND ?',
      whereArgs: [...ids, _key(from), _key(to)],
    );
    final out = <String, Map<DateTime, String?>>{};
    for (final r in rows) {
      (out[r['goal_id'] as String] ??= {})[_parse(r['date'] as String)] =
          r['status'] as String?;
    }
    return out;
  }

  @override
  Future<Set<DateTime>> couldNotVerifyDays(String goalId) async {
    final rows = await _db.query(
      table,
      columns: ['date'],
      where: "goal_id = ? AND kind = '$_cnv'",
      whereArgs: [goalId],
    );
    return rows.map((r) => _parse(r['date'] as String)).toSet();
  }

  @override
  Future<void> markManual(String goalId, DateTime day, {String? status}) async {
    final key = _key(day);
    await _db.insert(
      table,
      {
        'goal_id': goalId,
        'date': key,
        'kind': _manual,
        'recorded_at': _now(),
        // The verdict this freeze protects. `ConflictAlgorithm.replace` means a
        // re-freeze overwrites it, which is what should happen — the user's most
        // recent choice is the one to restore.
        'status': status,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Manual resolution supersedes any couldn't-verify marker for the day.
    await _db.delete(
      table,
      where: 'goal_id = ? AND date = ? AND kind = ?',
      whereArgs: [goalId, key, _cnv],
    );
  }

  @override
  Future<void> clearManual(String goalId, DateTime day) async {
    await _db.delete(
      table,
      where: 'goal_id = ? AND date = ? AND kind = ?',
      whereArgs: [goalId, _key(day), _manual],
    );
  }

  @override
  Future<void> recordCouldNotVerify(String goalId, DateTime day) async {
    final key = _key(day);
    final frozen = await _db.query(
      table,
      where: 'goal_id = ? AND date = ? AND kind = ?',
      whereArgs: [goalId, key, _manual],
      limit: 1,
    );
    if (frozen.isNotEmpty) return; // manual wins — never re-nudge a frozen day
    await _db.insert(
      table,
      {'goal_id': goalId, 'date': key, 'kind': _cnv, 'recorded_at': _now()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<void> resolveCouldNotVerify(String goalId, DateTime day) async {
    await _db.delete(
      table,
      where: 'goal_id = ? AND date = ? AND kind = ?',
      whereArgs: [goalId, _key(day), _cnv],
    );
  }

  @override
  Future<void> pruneCouldNotVerifyBefore(String goalId, DateTime day) async {
    // `date` is stored as zero-padded `yyyy-MM-dd`, so lexicographic `<` matches
    // chronological order.
    await _db.delete(
      table,
      where: "goal_id = ? AND kind = '$_cnv' AND date < ?",
      whereArgs: [goalId, _key(day)],
    );
  }

  @override
  Future<Set<DateTime>> nudgedDays(String goalId) async {
    final rows = await _db.query(
      table,
      columns: ['date'],
      where: "goal_id = ? AND kind = '$_cnv' AND nudged_at IS NOT NULL",
      whereArgs: [goalId],
    );
    return rows.map((r) => _parse(r['date'] as String)).toSet();
  }

  @override
  Future<void> markNudged(String goalId, DateTime day) async {
    // UPDATE targets only the live couldn't-verify row, so it is a no-op once
    // the day has resolved or been frozen manual (the row is gone).
    await _db.update(
      table,
      {'nudged_at': _now()},
      where: 'goal_id = ? AND date = ? AND kind = ?',
      whereArgs: [goalId, _key(day), _cnv],
    );
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    await _db.delete(table, where: 'goal_id = ?', whereArgs: [goalId]);
  }
}
