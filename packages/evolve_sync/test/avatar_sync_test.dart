// Avatar CKAsset sync (P2 of desktop/ICLOUD_SYNC_PLAN.md): the one non-row
// record. Round-trip through the fake cloud, encrypted-on-the-wire, LWW both
// directions, tombstone removal, no pull→push ping-pong, markAllDirty pickup,
// and the setLocalOnlyColumn no-re-dirty contract the app-side stores rely on.
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

  Uint8List img(String seed) =>
      Uint8List.fromList(List.generate(64, (i) => (seed.codeUnitAt(0) + i) & 0xff));

  Future<Database> openFreshV3() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
        ),
      );

  Future<void> seedOwner(Database db, {String? avatarUrl}) async {
    await db.insert('profiles', {
      'id': 'owner',
      'avatar_url': avatarUrl,
      'created_at': t(1),
      'updated_at': t(1),
    });
    await db.update(PrivateDbSchema.syncStateTable, {'dirty': 0});
  }

  Future<Map<String, Object?>?> syncRow(Database db, String recordName) async {
    final r = await db.query(PrivateDbSchema.syncStateTable,
        where: 'record_name = ?', whereArgs: [recordName], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  SyncEngine engine(Database db, CloudKitBridge bridge,
          {SyncAvatarStore? avatars}) =>
      SyncEngine(
        store: SyncLocalStore(db),
        bridge: bridge,
        crypto: crypto,
        avatarStore: avatars,
      );

  group('avatar round-trip', () {
    test('avatar set on A appears on B, encrypted in transit', () async {
      final cloud = FakeCloudKitBridge();
      final transport = <String, Uint8List>{};
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      final avatarsA =
          FakeSyncAvatarStore(name: 'A', assetTransport: transport);
      final avatarsB =
          FakeSyncAvatarStore(name: 'B', assetTransport: transport);

      avatarsA.avatar = img('X');
      await SyncLocalStore(dbA).markAvatarDirty('owner');
      await engine(dbA, cloud, avatars: avatarsA).syncNow(key);

      // On the wire: an asset-only record, ciphertext staged (not plaintext).
      final rec = cloud.records['avatar:owner']!;
      expect(rec.tableName, PrivateDbSchema.avatarRecordTable);
      expect(rec.deleted, isFalse);
      expect(rec.assetPath, isNotNull);
      expect(transport[rec.assetPath], isNot(equals(img('X'))));

      final res = await engine(dbB, cloud, avatars: avatarsB).syncNow(key);
      expect(res.applied, greaterThanOrEqualTo(1));
      expect(avatarsB.avatar, img('X'));
      expect((await syncRow(dbB, 'avatar:owner'))!['dirty'], 0);

      // No ping-pong: B has nothing to push afterwards.
      expect(await SyncLocalStore(dbB).dirtyEntries(), isEmpty);
      await dbA.close();
      await dbB.close();
    });

    test('newer avatar wins (LWW) — older push does not clobber it', () async {
      final cloud = FakeCloudKitBridge();
      final transport = <String, Uint8List>{};
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      final avatarsA =
          FakeSyncAvatarStore(name: 'A', assetTransport: transport);
      final avatarsB =
          FakeSyncAvatarStore(name: 'B', assetTransport: transport);

      // A publishes v1, B pulls it.
      avatarsA.avatar = img('1');
      await SyncLocalStore(dbA).markAvatarDirty('owner');
      await engine(dbA, cloud, avatars: avatarsA).syncNow(key);
      await engine(dbB, cloud, avatars: avatarsB).syncNow(key);
      expect(avatarsB.avatar, img('1'));

      // B updates the avatar later (markAvatarDirty stamps "now", which is
      // strictly newer than A's stamp) and publishes v2.
      avatarsB.avatar = img('2');
      await SyncLocalStore(dbB).markAvatarDirty('owner');
      await engine(dbB, cloud, avatars: avatarsB).syncNow(key);

      // A pulls: the newer v2 replaces its local v1.
      await engine(dbA, cloud, avatars: avatarsA).syncNow(key);
      expect(avatarsA.avatar, img('2'));

      // An A push now would be a no-op (nothing dirty) — no clobbering.
      expect(await SyncLocalStore(dbA).dirtyEntries(), isEmpty);
      await dbA.close();
      await dbB.close();
    });

    test('avatar removal propagates as a tombstone', () async {
      final cloud = FakeCloudKitBridge();
      final transport = <String, Uint8List>{};
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      final avatarsA =
          FakeSyncAvatarStore(name: 'A', assetTransport: transport);
      final avatarsB =
          FakeSyncAvatarStore(name: 'B', assetTransport: transport);

      avatarsA.avatar = img('X');
      await SyncLocalStore(dbA).markAvatarDirty('owner');
      await engine(dbA, cloud, avatars: avatarsA).syncNow(key);
      await engine(dbB, cloud, avatars: avatarsB).syncNow(key);
      expect(avatarsB.avatar, isNotNull);

      // Remove on A → tombstone → B applies the removal.
      avatarsA.avatar = null;
      await SyncLocalStore(dbA).markAvatarDirty('owner', deleted: true);
      await engine(dbA, cloud, avatars: avatarsA).syncNow(key);
      expect(cloud.records['avatar:owner']!.deleted, isTrue);

      await engine(dbB, cloud, avatars: avatarsB).syncNow(key);
      expect(avatarsB.avatar, isNull);
      expect(avatarsB.removeCalls, 1);
      expect((await syncRow(dbB, 'avatar:owner'))!['deleted'], 1);
      await dbA.close();
      await dbB.close();
    });

    test('missing local avatar file degrades to a tombstone push', () async {
      final cloud = FakeCloudKitBridge();
      final db = await openFreshV3();
      await seedOwner(db);
      final avatars = FakeSyncAvatarStore(name: 'A');

      // Dirty avatar record but no bytes to read (file vanished).
      await SyncLocalStore(db).markAvatarDirty('owner');
      await engine(db, cloud, avatars: avatars).syncNow(key);

      expect(cloud.records['avatar:owner']!.deleted, isTrue);
      await db.close();
    });

    test('engine without an avatar store skips avatar records', () async {
      final cloud = FakeCloudKitBridge();
      final transport = <String, Uint8List>{};
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      final avatarsA =
          FakeSyncAvatarStore(name: 'A', assetTransport: transport);

      avatarsA.avatar = img('X');
      await SyncLocalStore(dbA).markAvatarDirty('owner');
      await engine(dbA, cloud, avatars: avatarsA).syncNow(key);

      // B has no avatar store wired: the record is skipped, nothing crashes.
      final res = await engine(dbB, cloud).syncNow(key);
      expect(res.skipped, greaterThanOrEqualTo(1));
      await dbA.close();
      await dbB.close();
    });
  });

  group('bookkeeping', () {
    test('markAllDirty queues the avatar when profiles.avatar_url is set',
        () async {
      final db = await openFreshV3();
      await seedOwner(db, avatarUrl: '/local/path/avatar.png');
      final store = SyncLocalStore(db);

      await store.markAllDirty();

      final entries = await store.dirtyEntries();
      final names = entries.map((e) => e.recordName).toSet();
      expect(names, contains('avatar:owner'));
      expect(
        entries
            .firstWhere((e) => e.recordName == 'avatar:owner')
            .tableName,
        PrivateDbSchema.avatarRecordTable,
      );
      await db.close();
    });

    test('markAllDirty skips the avatar when no avatar is set', () async {
      final db = await openFreshV3();
      await seedOwner(db);
      final store = SyncLocalStore(db);

      await store.markAllDirty();

      final names = (await store.dirtyEntries()).map((e) => e.recordName);
      expect(names, isNot(contains('avatar:owner')));
      await db.close();
    });

    test('setLocalOnlyColumn keeps a clean row clean (no push queued)',
        () async {
      final db = await openFreshV3();
      await seedOwner(db); // seed clears dirty
      final store = SyncLocalStore(db);
      final before = await syncRow(db, 'profiles:owner');

      await store.setLocalOnlyColumn(
          'profiles', 'owner', 'avatar_url', '/new/path.png');

      final after = await syncRow(db, 'profiles:owner');
      expect(after!['dirty'], 0);
      expect(after['updated_at'], before!['updated_at']);
      final row =
          (await db.query('profiles', where: "id = 'owner'", limit: 1)).first;
      expect(row['avatar_url'], '/new/path.png');
      await db.close();
    });

    test('setLocalOnlyColumn keeps a dirty row dirty (pending edit survives)',
        () async {
      final db = await openFreshV3();
      await seedOwner(db);
      await db.update('profiles', {'full_name': 'Simo', 'updated_at': t(5)},
          where: "id = 'owner'"); // real edit → dirty
      final store = SyncLocalStore(db);

      await store.setLocalOnlyColumn(
          'profiles', 'owner', 'avatar_url', '/p.png');

      final state = await syncRow(db, 'profiles:owner');
      expect(state!['dirty'], 1, reason: 'the pending profile edit still pushes');
      expect(state['updated_at'], t(5));
      await db.close();
    });

    test('setLocalOnlyColumn leaves no sync_state behind for untracked rows',
        () async {
      final db = await openFreshV3();
      await seedOwner(db);
      await db.delete(PrivateDbSchema.syncStateTable); // row untracked
      final store = SyncLocalStore(db);

      await store.setLocalOnlyColumn(
          'profiles', 'owner', 'avatar_url', '/p.png');

      expect(await syncRow(db, 'profiles:owner'), isNull);
      await db.close();
    });
  });

  group('malformed avatar record', () {
    // A record CLAIMING tableName "avatar" whose NAME lacks the "avatar:"
    // prefix is structurally invalid, exactly like the row case the engine's
    // malformed-name guard already covers — and the avatar path is the one that
    // cannot survive it: both the state write and its own catch block chop a
    // fixed "avatar:".length off the name, so a shorter name raises a
    // RangeError from inside the catch, where nothing catches it. It escapes
    // `syncNow`, the change token is never stored, and every later sync
    // re-fetches the same record and dies again — a permanently wedged pull.
    test('a malformed avatar record name is skipped and lets the token advance',
        () async {
      final cloud = FakeCloudKitBridge();
      final transport = <String, Uint8List>{};
      final db = await openFreshV3();
      await seedOwner(db);
      final avatars = FakeSyncAvatarStore(name: 'B', assetTransport: transport);
      avatars.avatar = img('L'); // this device's own avatar

      await cloud.saveRecords([
        CloudRecord(
          recordName: 'x', // no "avatar:" prefix, shorter than one
          tableName: PrivateDbSchema.avatarRecordTable,
          updatedAtMs: DateTime.parse(t(10)).millisecondsSinceEpoch,
          deleted: false,
          payload: Uint8List(0),
          assetPath: await avatars
              .stageEncryptedUpload(crypto.encryptBytes(img('R'), key)),
        ),
      ]);

      final res = await engine(db, cloud, avatars: avatars).syncNow(key);

      expect(res.applied, 0);
      expect(avatars.avatar, img('L'), reason: 'local avatar left alone');
      // The token advanced past the malformed record: it will not be re-fetched
      // and re-crash the pull on every sync from here on.
      expect(await SyncLocalStore(db).changeToken(), isNotNull);
      await db.close();
    });
  });
}
