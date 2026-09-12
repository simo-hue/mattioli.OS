// A pulled avatar whose asset cannot be read must not pin the change token
// forever.
//
// The engine holds the change token when a record fails to apply, so the next
// sync re-delivers it — right for a TRANSIENT failure. The pulled avatar's
// bytes, though, arrive as a path to a CKAsset temp file the app does not own:
// once that file is gone, every retry fails identically. Holding the token on
// it therefore never ends — the whole zone delta is re-downloaded and
// re-discarded on every sync, `pullIncomplete` stays true and "last synced"
// never advances again — which is precisely the livelock the undecryptable and
// unknown-table branches already refuse to enter.
import 'dart:typed_data';

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

  Future<Database> seeded() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: PrivateDbSchema.onCreate,
        onUpgrade: PrivateDbSchema.onUpgrade,
      ),
    );
    await db.insert('profiles',
        {'id': 'owner', 'created_at': t(1), 'updated_at': t(1)});
    await db.update(PrivateDbSchema.syncStateTable, {'dirty': 0});
    return db;
  }

  /// The peer's avatar record, pointing at an asset this device cannot read —
  /// the temp file was released before the batch crossed the channel.
  Future<void> putUnreadableAvatar(FakeCloudKitBridge cloud) =>
      cloud.saveRecords([
        CloudRecord(
          recordName: PrivateDbSchema.avatarRecordName('owner'),
          tableName: PrivateDbSchema.avatarRecordTable,
          updatedAtMs: DateTime.utc(2024).millisecondsSinceEpoch,
          deleted: false,
          payload: Uint8List(0),
          assetPath: '/private/var/tmp/gone.bin',
        ),
      ]);

  test('a repeatedly unreadable avatar asset stops pinning the change token',
      () async {
    final db = await seeded();
    final store = SyncLocalStore(db);
    final cloud = FakeCloudKitBridge();
    await putUnreadableAvatar(cloud);
    SyncEngine engine() => SyncEngine(
          store: store,
          bridge: cloud,
          crypto: crypto,
          // Its transport holds nothing, so readStagedDownload throws — the
          // shape of a CKAsset temp file that is no longer there.
          avatarStore: FakeSyncAvatarStore(name: 'mac'),
        );

    final first = await engine().syncNow(key);

    // ONE retry is the whole point of the hold, so it must survive.
    expect(first.pullIncomplete, isTrue);
    expect(await store.changeToken(), isNull,
        reason: 'the first failure is retried — the token is held back');

    final second = await engine().syncNow(key);

    expect(await store.changeToken(), isNotNull,
        reason: 'a failure that has already been retried once is not '
            'transient; the token must move or this device never syncs again');
    expect(second.pullIncomplete, isFalse);
    final diag = await store.diagnostics();
    expect(diag.totalParked, 1,
        reason: 'the avatar that could not be applied stays counted and its '
            'reason stays readable — advancing the token must not hide it');
    expect(diag.toReport(), contains('gone.bin'));
    await db.close();
  });

  test('an avatar that fails once and then reads fine still applies', () async {
    final db = await seeded();
    final store = SyncLocalStore(db);
    final cloud = FakeCloudKitBridge();
    final avatars = FakeSyncAvatarStore(name: 'mac');
    await cloud.saveRecords([
      CloudRecord(
        recordName: PrivateDbSchema.avatarRecordName('owner'),
        tableName: PrivateDbSchema.avatarRecordTable,
        updatedAtMs: DateTime.utc(2024).millisecondsSinceEpoch,
        deleted: false,
        payload: Uint8List(0),
        assetPath: 'staged:peer:1',
      ),
    ]);
    SyncEngine engine() => SyncEngine(
          store: store,
          bridge: cloud,
          crypto: crypto,
          avatarStore: avatars,
        );

    await engine().syncNow(key); // asset not staged yet → held

    // The asset materialises before the retry.
    avatars.assetTransport['staged:peer:1'] =
        crypto.encryptBytes(Uint8List.fromList([9, 9, 9]), key);

    await engine().syncNow(key);

    expect(avatars.avatar, [9, 9, 9]);
    await db.close();
  });
}
