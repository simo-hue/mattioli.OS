// Regression guard for the #1 data-loss bug: writing a habit (goals row) must
// never delete that habit's goal_logs.
//
// `goal_logs.goal_id` is `ON DELETE CASCADE`, so persisting a goal with
// `ConflictAlgorithm.replace` (INSERT OR REPLACE) on an EXISTING id first
// DELETEs the old goals row — cascading away every log and, with sync on,
// tombstoning them to iCloud. `PrivateLocalDatabase.upsertGoal` / `reorderGoals`
// therefore branch to UPDATE-for-existing (see `_writeGoal`). This test pins the
// invariant against the REAL schema + sync triggers so a revert to REPLACE, or a
// schema change to the cascade, fails loudly.
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner-1';
  const goalId = 'goal-A';
  const now = '2026-06-01T00:00:00.000Z';

  Future<Database> openDb() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: PrivateDbSchema.onCreate,
        onUpgrade: PrivateDbSchema.onUpgrade,
      ),
    );
    await db.insert('profiles', {'id': owner, 'created_at': now, 'updated_at': now});
    await db.insert('goals', {
      'id': goalId,
      'user_id': owner,
      'title': 'Meditate',
      'color': '#3B82F6',
      'start_date': '2026-01-01',
      'created_at': now,
      'updated_at': now,
    });
    for (final d in ['2026-05-10', '2026-05-11', '2026-05-12']) {
      await db.insert('goal_logs', {
        'id': 'log-$d',
        'user_id': owner,
        'goal_id': goalId,
        'date': d,
        'status': 'done',
        'created_at': now,
        'updated_at': now,
      });
    }
    // Clear the sync_state churn from the seed inserts so tombstone assertions
    // below reflect only the goal write under test.
    await db.delete(PrivateDbSchema.syncStateTable);
    return db;
  }

  Future<int> logCount(Database db) async =>
      (await db.rawQuery('SELECT COUNT(*) AS c FROM goal_logs')).first['c']
          as int;

  Future<int> logTombstones(Database db) async =>
      (await db.rawQuery(
        "SELECT COUNT(*) AS c FROM ${PrivateDbSchema.syncStateTable} "
        "WHERE table_name = 'goal_logs' AND deleted = 1",
      ))
          .first['c'] as int;

  Map<String, Object?> goalRow(String title) => {
        'id': goalId,
        'user_id': owner,
        'title': title,
        'color': '#3B82F6',
        'start_date': '2026-01-01',
        'created_at': now,
        'updated_at': '2026-06-02T00:00:00.000Z',
      };

  test('INSERT OR REPLACE on goals WIPES logs and queues tombstones (the bug)',
      () async {
    final db = await openDb();
    expect(await logCount(db), 3);

    // The pre-fix behavior — kept as an executable description of the hazard.
    await db.insert('goals', goalRow('Meditate (renamed)'),
        conflictAlgorithm: ConflictAlgorithm.replace);

    expect(await logCount(db), 0, reason: 'REPLACE cascade-deletes goal_logs');
    expect(await logTombstones(db), 3,
        reason: 'cascade fires the goal_logs delete trigger → pushes deletes to iCloud');
    await db.close();
  });

  test('UPDATE on goals PRESERVES logs and queues no log tombstones (the fix)',
      () async {
    final db = await openDb();
    expect(await logCount(db), 3);

    // The post-fix behavior of upsertGoal/_writeGoal for an existing id.
    await db.update('goals', goalRow('Meditate (renamed)'),
        where: 'id = ?', whereArgs: [goalId]);

    expect(await logCount(db), 3, reason: 'editing a habit must keep its history');
    expect(await logTombstones(db), 0,
        reason: 'no spurious goal_logs deletions propagate to iCloud');
    await db.close();
  });
}
