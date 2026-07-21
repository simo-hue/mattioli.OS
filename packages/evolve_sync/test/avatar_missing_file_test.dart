// A missing LOCAL avatar file must never delete the avatar on other devices.
//
// `readAvatarBytes()` returned null for two completely different situations:
//   * the user removed their avatar — a tombstone is CORRECT, and
//   * the file we were pointing at could not be read — where a tombstone is
//     catastrophic.
//
// `_encodeAvatar` replicated both as a DELETION. So one device losing track of
// its own file destroyed the image on every device, permanently, while the sync
// reported success. The same report-success-while-failing family as everything
// else in this layer, with the sharpest teeth: nothing was retryable afterwards,
// because the bytes were gone from the zone too.
//
// It is not hypothetical. `profiles.avatar_url` holds an ABSOLUTE path rooted at
// the app's container, and iOS regenerates that container's UUID across
// reinstalls — so the path goes stale while the DB (and `markAllDirty`, which
// only checks that `avatar_url` is non-empty) still believes an avatar exists.
// That is the reported bug: the picture vanished on the phone, and would have
// taken the Mac's copy with it.
import 'dart:typed_data';

import 'package:evolve_sync/evolve_sync.dart';
import 'package:evolve_sync/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// An avatar the app still has on paper — `avatar_url` is set — whose file
/// cannot be read. Exactly the shape of a moved iOS container.
class _LostFileAvatarStore extends FakeSyncAvatarStore {
  _LostFileAvatarStore({required super.name});

  @override
  Future<Uint8List?> readAvatarBytes() async => null;

  @override
  Future<bool> hasAvatarConfigured() async => true;
}

/// The user genuinely removed their avatar: nothing configured, nothing on disk.
class _NoAvatarStore extends FakeSyncAvatarStore {
  _NoAvatarStore({required super.name});

  @override
  Future<Uint8List?> readAvatarBytes() async => null;

  @override
  Future<bool> hasAvatarConfigured() async => false;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final crypto = SyncCrypto();
  final key = crypto.generateKey();

  String t(int hour) =>
      DateTime.utc(2020, 1, 1).add(Duration(hours: hour)).toIso8601String();

  /// A device that already has an avatar recorded, with a stale absolute path.
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
    await db.insert('profiles', {
      'id': 'owner',
      'created_at': t(1),
      'updated_at': t(1),
      'avatar_url': '/var/mobile/Containers/Data/Application/'
          'OLD-CONTAINER-UUID/private_profile/avatar.png',
    });
    return db;
  }

  /// The other device's perfectly good avatar, already in the zone.
  Future<void> putGoodAvatar(FakeCloudKitBridge cloud) => cloud.saveRecords([
        CloudRecord(
          recordName: PrivateDbSchema.avatarRecordName('owner'),
          tableName: PrivateDbSchema.avatarRecordTable,
          updatedAtMs: DateTime.utc(2024).millisecondsSinceEpoch,
          deleted: false,
          payload: Uint8List(0),
          assetPath: 'the-good-avatar',
        ),
      ]);

  test('a lost local file does NOT tombstone the avatar in the zone', () async {
    final db = await seeded();
    final store = SyncLocalStore(db);
    final cloud = FakeCloudKitBridge();
    await putGoodAvatar(cloud);
    // Re-enable / re-key marks the avatar dirty purely because `avatar_url` is
    // non-empty — it never checks the file is there.
    await store.markAllDirty();

    await SyncEngine(
      store: store,
      bridge: cloud,
      crypto: crypto,
      avatarStore: _LostFileAvatarStore(name: 'phone'),
    ).syncNow(key);

    final record = cloud.records[PrivateDbSchema.avatarRecordName('owner')]!;
    expect(record.deleted, isFalse,
        reason: 'losing track of our OWN copy is never a reason to tell every '
            'other device to destroy theirs');
    expect(record.assetPath, 'the-good-avatar',
        reason: 'the other device\'s avatar must be untouched');
    await db.close();
  });

  test('a lost local file is reported, not silently swallowed', () async {
    final db = await seeded();
    final store = SyncLocalStore(db);
    final cloud = FakeCloudKitBridge();
    await putGoodAvatar(cloud);
    await store.markAllDirty();

    final res = await SyncEngine(
      store: store,
      bridge: cloud,
      crypto: crypto,
      avatarStore: _LostFileAvatarStore(name: 'phone'),
    ).syncNow(key);

    expect(res.fullySynced, isFalse,
        reason: 'something the user can see did not reach the cloud');
    expect(await store.lastFullSync(), isNull,
        reason: '"Last synced" must not advance over it');
    final d = await store.diagnostics();
    expect(d.isFullySynced, isFalse);
    expect(d.toReport(), contains('avatar'),
        reason: 'the report is the only thing a user can paste into a bug '
            'report — it has to name what is stuck');
    await db.close();
  });

  test('a genuinely REMOVED avatar still tombstones', () async {
    // The other half of the contract, and the reason this cannot simply be
    // "never tombstone an avatar": deleting your profile picture has to
    // propagate, or it comes back on the next sync from the other device.
    final db = await seeded();
    await db.update('profiles', {'avatar_url': null},
        where: 'id = ?', whereArgs: ['owner']);
    final store = SyncLocalStore(db);
    final cloud = FakeCloudKitBridge();
    await putGoodAvatar(cloud);
    await store.markAvatarDirty('owner');

    await SyncEngine(
      store: store,
      bridge: cloud,
      crypto: crypto,
      avatarStore: _NoAvatarStore(name: 'phone'),
    ).syncNow(key);

    expect(cloud.records[PrivateDbSchema.avatarRecordName('owner')]!.deleted,
        isTrue,
        reason: 'the user removed it deliberately — that must travel');
    await db.close();
  });

  test('a healthy avatar still uploads normally', () async {
    final db = await seeded();
    final store = SyncLocalStore(db);
    final cloud = FakeCloudKitBridge();
    final avatars = FakeSyncAvatarStore(name: 'phone')
      ..avatar = Uint8List.fromList([1, 2, 3]);
    await store.markAllDirty();

    final res = await SyncEngine(
      store: store,
      bridge: cloud,
      crypto: crypto,
      avatarStore: avatars,
    ).syncNow(key);

    final record = cloud.records[PrivateDbSchema.avatarRecordName('owner')]!;
    expect(record.deleted, isFalse);
    expect(record.assetPath, isNotNull);
    expect(res.fullySynced, isTrue,
        reason: 'the fix must not make every healthy sync look broken');
    await db.close();
  });
}
