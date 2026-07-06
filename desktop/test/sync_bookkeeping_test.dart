// Delete-private-data must reset the sync bookkeeping exactly like mobile
// (fixes #6/#7 there): wiping fires tombstone triggers and the reseed
// re-dirties a fresh profile — none of which may leak into a later re-enable —
// while a queued-offline zone wipe (pending_zone_wipe) must survive.
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

  Future<Database> openFreshV3() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          singleInstance: false,
          onConfigure: PrivateDbSchema.onConfigure,
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
        ),
      );

  Future<int> syncStateCount(Database db) async =>
      (await db.query(PrivateDbSchema.syncStateTable)).length;

  test(
      'wipe + reseed + resetSyncBookkeeping leaves no stale tombstones and '
      'clears the delta token', () async {
    final db = await openFreshV3();
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
    await db.update(
      PrivateDbSchema.syncMetaTable,
      {'server_change_token': 'tok', 'last_full_sync_at': now},
      where: 'id = 1',
    );
    expect(await syncStateCount(db), greaterThan(0));

    await db.transaction((txn) async {
      await DesktopPrivateDb.wipeUserData(txn);
      await DesktopPrivateDb.seedProfile(txn, owner: owner, now: now);
      await DesktopPrivateDb.resetSyncBookkeeping(txn);
    });

    // No tombstones for the wiped rows, no dirty reseeded profile — a later
    // re-enable starts from a clean slate (markAllDirty rebuilds what exists).
    expect(await syncStateCount(db), 0);
    final meta =
        (await db.query(PrivateDbSchema.syncMetaTable, where: 'id = 1')).first;
    expect(meta['server_change_token'], isNull);
    expect(meta['last_full_sync_at'], isNull);
    await db.close();
  });

  test('a queued offline zone wipe survives the bookkeeping reset', () async {
    final db = await openFreshV3();
    await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);
    await db.update(
      PrivateDbSchema.syncMetaTable,
      {'pending_zone_wipe': 1},
      where: 'id = 1',
    );

    await db.transaction((txn) async {
      await DesktopPrivateDb.wipeUserData(txn);
      await DesktopPrivateDb.seedProfile(txn, owner: owner, now: now);
      await DesktopPrivateDb.resetSyncBookkeeping(txn);
    });

    final meta =
        (await db.query(PrivateDbSchema.syncMetaTable, where: 'id = 1')).first;
    expect(meta['pending_zone_wipe'], 1,
        reason: 'the cloud wipe must still run on the next sync');
    await db.close();
  });
}
