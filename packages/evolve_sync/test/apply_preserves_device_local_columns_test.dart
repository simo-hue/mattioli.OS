// `localOnlyColumns` was only half-enforced.
//
// PrivateDbSchema documents these columns as "Stripped on push AND preserved on
// apply by [localOnlyColumns]". Only the first half was true: `SyncEngine._push`
// removes them from the payload, but `SyncLocalStore.applyUpsert` filtered the
// pulled payload by `_columnsOf(table)` alone and wrote whatever arrived.
//
// That held only because every CURRENT sender strips. It is not a property of
// this device, which is the wrong place for the guarantee to live — devices in
// the field run older builds, and `deviceLocalProfileColumns` did not always
// exist. A build predating it pushes `is_pro`, `biometric_lock` and
// `sentry_consent` in the payload, and a modern device would have written them.
//
// The list exists for two reasons the schema states outright, and both are
// violated by accepting these on apply:
//   * ENTITLEMENT — `is_pro` must derive from the device's OWN receipt. A synced
//     `is_pro = 1` is an in-app-purchase bypass.
//   * CONSENT and CAPABILITY — consent is given on the device that asked for it,
//     and `biometric_lock` means Face ID on one device and nothing on another.
//
// The existing round-trip test cannot catch this: its device A is always a
// modern, stripping engine, so the payload never carries the columns in the
// first place. This one writes the record the way an OLD build would.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:evolve_sync/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final crypto = SyncCrypto();
  final key = crypto.generateKey();

  String t(int hour) =>
      DateTime.utc(2020, 1, 1).add(Duration(hours: hour)).toIso8601String();

  Future<Database> openFresh() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
        ),
      );

  test(
      'a payload from an OLDER build cannot overwrite this device\'s '
      'entitlement, consent or biometric setting', () async {
    final db = await openFresh();
    // This device: not Pro, consent refused, biometric lock on.
    await db.insert('profiles', {
      'id': 'owner',
      'created_at': t(1),
      'updated_at': t(1),
      'is_pro': 1 - 1,
      'sentry_consent': 1 - 1,
      'biometric_lock': 1,
    });
    await db.update(PrivateDbSchema.syncStateTable, {'dirty': 0});

    final cloud = FakeCloudKitBridge();
    // A record as an OLD build would have written it — device-local columns
    // still in the payload, because that build had no list to strip by.
    await cloud.saveRecords([
      CloudRecord(
        recordName: 'profiles:owner',
        tableName: 'profiles',
        updatedAtMs: DateTime.utc(2024).millisecondsSinceEpoch,
        deleted: false,
        payload: crypto.encryptJson({
          'id': 'owner',
          'full_name': 'From the other device',
          'updated_at': DateTime.utc(2024).toIso8601String(),
          'is_pro': 1,
          'sentry_consent': 1,
          'biometric_lock': 0,
        }, key),
      ),
    ]);

    await SyncEngine(
      store: SyncLocalStore(db),
      bridge: cloud,
      crypto: crypto,
    ).syncNow(key);

    final row = (await db.query('profiles', where: 'id = ?', whereArgs: ['owner']))
        .first;
    expect(row['full_name'], 'From the other device',
        reason: 'the synced columns must still apply');
    expect(row['is_pro'], 0,
        reason: 'a synced is_pro = 1 is an in-app-purchase bypass');
    expect(row['sentry_consent'], 0,
        reason: 'consent belongs to the device that asked for it');
    expect(row['biometric_lock'], 1,
        reason: 'device capability differs; a synced value locks a user out of '
            'a device that cannot satisfy it');
    await db.close();
  });

  test('a device-local column is not resurrected by a tombstone-free re-apply',
      () async {
    // The same guarantee, exercised through the store directly, so it holds for
    // any future caller of applyUpsert and not only through the engine.
    final db = await openFresh();
    await db.insert('profiles', {
      'id': 'owner',
      'created_at': t(1),
      'updated_at': t(1),
      'is_pro': 1,
    });
    final store = SyncLocalStore(db);

    await store.applyUpsert(
      'profiles',
      'profiles:owner',
      {'id': 'owner', 'full_name': 'x', 'is_pro': 0},
      DateTime.utc(2024).millisecondsSinceEpoch,
      t(2),
    );

    final row = (await db.query('profiles', where: 'id = ?', whereArgs: ['owner']))
        .first;
    expect(row['is_pro'], 1, reason: 'this device owns its own entitlement');
    await db.close();
  });

  test('the avatar path column is likewise never overwritten by a peer',
      () async {
    // `profiles.avatar_url` is a LOCAL FILE PATH. Another device's path is
    // meaningless here and would point the UI at a file that does not exist.
    final db = await openFresh();
    await db.insert('profiles', {
      'id': 'owner',
      'created_at': t(1),
      'updated_at': t(1),
      'avatar_url': '/this/device/avatar.png',
    });
    final store = SyncLocalStore(db);

    await store.applyUpsert(
      'profiles',
      'profiles:owner',
      {'id': 'owner', 'avatar_url': '/the/other/device/avatar.png'},
      DateTime.utc(2024).millisecondsSinceEpoch,
      t(2),
    );

    expect(
      (await db.query('profiles', where: 'id = ?', whereArgs: ['owner']))
          .first['avatar_url'],
      '/this/device/avatar.png',
    );
    await db.close();
  });

  test('an empty payload after stripping still updates sync bookkeeping',
      () async {
    // Guards the fix itself: if stripping empties the column map, the write must
    // not throw or silently skip the state row, or the record would be
    // re-delivered and re-applied forever.
    final db = await openFresh();
    await db.insert('profiles',
        {'id': 'owner', 'created_at': t(1), 'updated_at': t(1), 'is_pro': 1});
    final store = SyncLocalStore(db);

    final applied = await store.applyUpsert(
      'profiles',
      'profiles:owner',
      {'id': 'owner', 'is_pro': 0},
      DateTime.utc(2024).millisecondsSinceEpoch,
      t(2),
    );

    expect(applied, isTrue);
    expect((await store.stateOf('profiles:owner'))!.updatedAt, isNotEmpty);
    expect(
      (await db.query('profiles', where: 'id = ?', whereArgs: ['owner']))
          .first['is_pro'],
      1,
    );
    await db.close();
  });
}
