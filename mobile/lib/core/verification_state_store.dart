import 'package:evolve_verification/evolve_verification.dart';
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

  /// Creates the table + index. Idempotent, so it is safe to call on every open.
  static Future<void> createTable(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS $table (
  goal_id TEXT NOT NULL,
  date TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('$_manual', '$_cnv')),
  recorded_at TEXT NOT NULL,
  PRIMARY KEY (goal_id, date, kind)
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_vstate_goal_kind ON $table (goal_id, kind)',
    );
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
  Future<Map<String, Set<DateTime>>> manualDays({
    required Iterable<String> goalIds,
    required DateTime from,
    required DateTime to,
  }) async {
    final ids = goalIds.toList();
    if (ids.isEmpty) return {};
    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await _db.query(
      table,
      columns: ['goal_id', 'date'],
      where: "kind = '$_manual' AND goal_id IN ($placeholders) "
          'AND date BETWEEN ? AND ?',
      whereArgs: [...ids, _key(from), _key(to)],
    );
    final out = <String, Set<DateTime>>{};
    for (final r in rows) {
      (out[r['goal_id'] as String] ??= {}).add(_parse(r['date'] as String));
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
  Future<void> markManual(String goalId, DateTime day) async {
    final key = _key(day);
    await _db.insert(
      table,
      {'goal_id': goalId, 'date': key, 'kind': _manual, 'recorded_at': _now()},
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
  Future<void> deleteGoal(String goalId) async {
    await _db.delete(table, where: 'goal_id = ?', whereArgs: [goalId]);
  }
}
