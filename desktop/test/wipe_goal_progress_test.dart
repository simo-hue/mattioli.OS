// A wipe must name `goal_progress` explicitly. SyncLocalStore.applyUpsert turns
// `PRAGMA foreign_keys = OFF` on connection-wide (outside its transaction, where
// the pragma is a no-op) and awaits; sqflite serialises transactions, so a wipe
// acquiring the lock in that window cascades NOTHING. Relying on the goals
// cascade therefore leaves every goal_progress row behind — and the wipe then
// clears sync_state, so nothing flags them.
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner-1';
  final now = DateTime.utc(2026, 1, 1).toIso8601String();

  test('the wipe clears goal_progress even with foreign_keys OFF', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        singleInstance: false,
        onConfigure: PrivateDbSchema.onConfigure,
        onCreate: PrivateDbSchema.onCreate,
        onUpgrade: PrivateDbSchema.onUpgrade,
      ),
    );
    await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);
    await db.insert('goals', {
      'id': 'g1',
      'user_id': owner,
      'title': 'Read',
      'color': '#FFFFFF',
      'start_date': now,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('goal_progress', {
      'id': 'p1',
      'user_id': owner,
      'goal_id': 'g1',
      'date': '2026-01-01',
      'amount': 3.0,
      'source': 'manual',
      'created_at': now,
      'updated_at': now,
    });

    // Exactly what a concurrent applyUpsert leaves on the connection.
    await db.execute('PRAGMA foreign_keys = OFF');

    await db.transaction((txn) async {
      await DesktopPrivateDb.wipeUserData(txn);
    });

    expect((await db.query('goal_progress')), isEmpty,
        reason: 'a wipe that reports success must leave no progress rows');
    await db.close();
  });
}
