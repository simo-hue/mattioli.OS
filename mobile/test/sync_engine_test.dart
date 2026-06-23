// SyncEngine core-loop tests (iCloud sync step 3): push, pull+apply, LWW both
// directions, tombstones, no pull->push ping-pong, two-device convergence
// through a shared fake "cloud", account-unavailable no-op, pending zone wipe.
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/cloudkit_bridge.dart';
import 'package:mattioli_os/core/private_db_schema.dart';
import 'package:mattioli_os/core/sync_crypto.dart';
import 'package:mattioli_os/core/sync_engine.dart';
import 'package:mattioli_os/core/sync_local_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_cloudkit_bridge.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final crypto = SyncCrypto();
  final key = crypto.generateKey();

  // Ordered ISO timestamps in the past (well before "now") so the engine's
  // future-skew guard never trips on legitimate test data: t(10) < t(20) < ...
  String t(int hour) =>
      DateTime.utc(2020, 1, 1).add(Duration(hours: hour)).toIso8601String();
  int ms(String iso) => DateTime.parse(iso).millisecondsSinceEpoch;

  // singleInstance:false so each call is an INDEPENDENT in-memory DB — two
  // devices (dbA, dbB) must not alias the same cached ':memory:' instance.
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

  // Seed a profile (FK target) and clear the seed's dirty flags so tests only
  // push the rows they touch. Both devices share the same canonical owner here
  // (the re-key that establishes that is step 3b).
  Future<void> seedOwner(Database db) async {
    await db.insert('profiles',
        {'id': 'owner', 'created_at': t(1), 'updated_at': t(1)});
    await db.update(PrivateDbSchema.syncStateTable, {'dirty': 0});
  }

  Future<void> insertGoal(Database db, String id,
          {required String title, required String at}) =>
      db.insert('goals', {
        'id': id,
        'user_id': 'owner',
        'title': title,
        'color': '#FFFFFF',
        'start_date': at,
        'created_at': at,
        'updated_at': at,
      });

  Future<void> updateGoal(Database db, String id,
          {required String title, required String at}) =>
      db.update('goals', {'title': title, 'updated_at': at},
          where: 'id = ?', whereArgs: [id]);

  Future<Map<String, Object?>?> readGoal(Database db, String id) async {
    final r = await db.query('goals', where: 'id = ?', whereArgs: [id], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, Object?>?> syncRow(Database db, String recordName) async {
    final r = await db.query(PrivateDbSchema.syncStateTable,
        where: 'record_name = ?', whereArgs: [recordName], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  SyncEngine engine(Database db, CloudKitBridge bridge) =>
      SyncEngine(store: SyncLocalStore(db), bridge: bridge, crypto: crypto);

  group('single device push/pull', () {
    test('push uploads a dirty row and clears dirty', () async {
      final db = await openFreshV3();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge();
      await insertGoal(db, 'g1', title: 'Read', at: t(10));

      final res = await engine(db, cloud).syncNow(key);

      expect(res.pushed, 1);
      expect(cloud.records.containsKey('goals:g1'), isTrue);
      expect(cloud.records['goals:g1']!.deleted, isFalse);
      expect((await syncRow(db, 'goals:g1'))!['dirty'], 0);
      await db.close();
    });

    test('payload on the wire is encrypted (no plaintext title)', () async {
      final db = await openFreshV3();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge();
      await insertGoal(db, 'g1', title: 'TopSecretHabit', at: t(10));
      await engine(db, cloud).syncNow(key);

      final payload = cloud.records['goals:g1']!.payload!;
      final asText = String.fromCharCodes(payload);
      expect(asText.contains('TopSecretHabit'), isFalse);
      // ...and it decrypts back.
      expect(crypto.decryptJson(payload, key)['title'], 'TopSecretHabit');
      await db.close();
    });
  });

  group('two devices through a shared cloud', () {
    test('a row created on A appears on B', () async {
      final cloud = FakeCloudKitBridge();
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);

      await insertGoal(dbA, 'g1', title: 'v1', at: t(10));
      await engine(dbA, cloud).syncNow(key);
      final res = await engine(dbB, cloud).syncNow(key);

      expect(res.applied, 1);
      expect((await readGoal(dbB, 'g1'))!['title'], 'v1');
      // Applied row must NOT be left dirty (no ping-pong back to the cloud).
      expect((await syncRow(dbB, 'goals:g1'))!['dirty'], 0);

      // A second sync on B pushes nothing.
      final res2 = await engine(dbB, cloud).syncNow(key);
      expect(res2.pushed, 0);
      await dbA.close();
      await dbB.close();
    });

    test('LWW: a newer remote edit overwrites an older local edit', () async {
      final cloud = FakeCloudKitBridge();
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      final a = engine(dbA, cloud);
      final b = engine(dbB, cloud);

      await insertGoal(dbA, 'g1', title: 'v1', at: t(10));
      await a.syncNow(key);
      await b.syncNow(key); // B now has g1@10

      await updateGoal(dbA, 'g1', title: 'vA', at: t(30));
      await a.syncNow(key); // cloud g1@30

      await updateGoal(dbB, 'g1', title: 'vB', at: t(20)); // older
      await b.syncNow(key); // push@20 -> conflict; pull@30 -> applied

      expect((await readGoal(dbB, 'g1'))!['title'], 'vA');
      expect((await syncRow(dbB, 'goals:g1'))!['dirty'], 0);
      await dbA.close();
      await dbB.close();
    });

    test('LWW: a newer local edit wins and is pushed', () async {
      final cloud = FakeCloudKitBridge();
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      final a = engine(dbA, cloud);
      final b = engine(dbB, cloud);

      await insertGoal(dbA, 'g1', title: 'v1', at: t(10));
      await a.syncNow(key);
      await b.syncNow(key);

      await updateGoal(dbB, 'g1', title: 'vBnew', at: t(40));
      await b.syncNow(key); // push@40 saved (cloud was @10)

      expect(cloud.records['goals:g1']!.updatedAtMs, ms(t(40)));
      await a.syncNow(key); // A pulls the newer @40
      expect((await readGoal(dbA, 'g1'))!['title'], 'vBnew');
      await dbA.close();
      await dbB.close();
    });

    test('a delete on A tombstones and removes the row on B', () async {
      final cloud = FakeCloudKitBridge();
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      final a = engine(dbA, cloud);
      final b = engine(dbB, cloud);

      await insertGoal(dbA, 'g1', title: 'v1', at: t(10));
      await a.syncNow(key);
      await b.syncNow(key);

      await dbA.delete('goals', where: 'id = ?', whereArgs: ['g1']);
      await a.syncNow(key);
      expect(cloud.records['goals:g1']!.deleted, isTrue);

      await b.syncNow(key);
      expect(await readGoal(dbB, 'g1'), isNull);
      expect((await syncRow(dbB, 'goals:g1'))!['deleted'], 1);
      await dbA.close();
      await dbB.close();
    });
  });

  group('guards', () {
    test('iCloud unavailable: no push/pull, local untouched', () async {
      final db = await openFreshV3();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge()..status = CloudAccountStatus.noAccount;
      await insertGoal(db, 'g1', title: 'Read', at: t(10));

      final res = await engine(db, cloud).syncNow(key);
      expect(res.ran, isFalse);
      expect(res.blockedBy, CloudAccountStatus.noAccount);
      expect(cloud.saveCalls, 0);
      expect((await syncRow(db, 'goals:g1'))!['dirty'], 1); // still pending
      await db.close();
    });

    test('pending zone wipe deletes the zone and resets the token', () async {
      final db = await openFreshV3();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge();
      final store = SyncLocalStore(db);
      await store.setPendingZoneWipe(true);

      final res = await engine(db, cloud).syncNow(key);
      expect(res.wiped, isTrue);
      expect(cloud.zoneDeleted, isTrue);
      expect(await store.pendingZoneWipe(), isFalse);
      expect(await store.changeToken(), isNull);
      await db.close();
    });

    test('future-skew guard ignores implausibly-future remote records',
        () async {
      final cloud = FakeCloudKitBridge();
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      // A pushes a goal dated far in the future.
      await insertGoal(dbA, 'g1', title: 'future', at: t(10));
      await dbA.update('goals',
          {'updated_at': DateTime.utc(2999).toIso8601String()},
          where: 'id = ?', whereArgs: ['g1']);
      await engine(dbA, cloud).syncNow(key);

      final res = await engine(dbB, cloud).syncNow(key);
      expect(res.applied, 0); // skipped as bogus-future
      expect(await readGoal(dbB, 'g1'), isNull);
      await dbA.close();
      await dbB.close();
    });
  });
}
