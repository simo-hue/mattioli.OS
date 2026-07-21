// SyncEngine core-loop tests (iCloud sync step 3): push, pull+apply, LWW both
// directions, tombstones, no pull->push ping-pong, two-device convergence
// through a shared fake "cloud", account-unavailable no-op, pending zone wipe.
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:evolve_sync/testing.dart';

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

    test('#1 applying a pulled parent (profiles) does not cascade-delete '
        'children', () async {
      final cloud = FakeCloudKitBridge();
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      final a = engine(dbA, cloud);
      final b = engine(dbB, cloud);

      // Both devices end up with goal g1 (a child of profiles), synced + clean.
      await insertGoal(dbA, 'g1', title: 'keepme', at: t(10));
      await a.syncNow(key);
      await b.syncNow(key);
      expect((await readGoal(dbB, 'g1'))!['title'], 'keepme');

      // A edits its profile -> pushes a fresh profiles:owner record.
      await dbA.update('profiles', {'updated_at': t(30)},
          where: 'id = ?', whereArgs: ['owner']);
      await a.syncNow(key);

      // B pulls the profile upsert. With FK ON, INSERT OR REPLACE on profiles
      // would DELETE the old row first and cascade-wipe g1 (and queue a
      // tombstone that pushes the delete back to the cloud). The FK-off apply
      // must keep the child intact and unqueued.
      await b.syncNow(key);

      expect(await readGoal(dbB, 'g1'), isNotNull,
          reason: 'child goal must survive a pulled parent upsert');
      expect((await readGoal(dbB, 'g1'))!['title'], 'keepme');
      final st = (await syncRow(dbB, 'goals:g1'))!;
      expect(st['deleted'], 0, reason: 'no spurious child tombstone');
      expect(st['dirty'], 0, reason: 'child not re-queued for push');
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
      await b.syncNow(key); // pull@30 applied (clears dirty) -> push: nothing

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

    test('#8 avatar_url is stripped on push and the local value is preserved',
        () async {
      final cloud = FakeCloudKitBridge();
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      final a = engine(dbA, cloud);
      final b = engine(dbB, cloud);

      // Each device caches its avatar at a DIFFERENT local path.
      await dbA.update('profiles', {'avatar_url': '/A/avatar.jpg'},
          where: 'id = ?', whereArgs: ['owner']);
      await dbB.update('profiles', {'avatar_url': '/B/avatar.jpg'},
          where: 'id = ?', whereArgs: ['owner']);
      await dbA.update(PrivateDbSchema.syncStateTable, {'dirty': 0});
      await dbB.update(PrivateDbSchema.syncStateTable, {'dirty': 0});

      // A edits a real synced field and pushes.
      await dbA.update('profiles', {'full_name': 'Alice', 'updated_at': t(30)},
          where: 'id = ?', whereArgs: ['owner']);
      await a.syncNow(key);

      // The encrypted wire payload must NOT carry the device-local path.
      final decoded = crypto.decryptJson(cloud.records['profiles:owner']!.payload!, key);
      expect(decoded.containsKey('avatar_url'), isFalse);
      expect(decoded['full_name'], 'Alice');

      // B pulls the edit but keeps its OWN avatar path.
      await b.syncNow(key);
      final bProfile =
          (await dbB.query('profiles', where: 'id = ?', whereArgs: ['owner']))
              .first;
      expect(bProfile['full_name'], 'Alice');
      expect(bProfile['avatar_url'], '/B/avatar.jpg');
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

    test('a record stamped implausibly far in the future pins the change token '
        'on EVERY later sync, forever', () async {
      // The skew guard defers a future-stamped record by rewinding the change
      // token, so the record is re-fetched instead of lost. That is right for a
      // clock a few minutes ahead — `now` catches up and the record applies.
      //
      // It is a trap for a stamp no clock will ever reach. The predicate
      // `rec.updatedAtMs > nowMs + skew` is a pure function of a value frozen
      // in CloudKit, so it is true on every pull forever: the token is rewound
      // on every sync, the whole delta is re-downloaded and re-discarded, and
      // it grows monotonically because the token never moves again. That is
      // the same shape the undecryptable branch already refuses to take, and
      // for the same stated reason ('change token: none', thousands of records
      // re-skipped per sync, indefinitely).
      final cloud = FakeCloudKitBridge();
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      // A pushes a goal dated far beyond any plausible clock error.
      await insertGoal(dbA, 'g1', title: 'future', at: t(10));
      await dbA.update('goals',
          {'updated_at': DateTime.utc(2999).toIso8601String()},
          where: 'id = ?', whereArgs: ['g1']);
      await engine(dbA, cloud).syncNow(key);

      final res = await engine(dbB, cloud).syncNow(key);
      // The guard still does its job: the bogus stamp must not win LWW.
      expect(res.applied, 0);
      expect(await readGoal(dbB, 'g1'), isNull);
      // ...but it must not cost B its place in the zone.
      expect(await SyncLocalStore(dbB).changeToken(), isNotNull,
          reason: 'a stamp no clock will ever reach cannot be deferred: the '
              'token must advance past it');

      // A non-skewed record in the same zone applies, and the token STAYS
      // advanced — B is not condemned to re-fetch the whole zone every sync.
      await insertGoal(dbA, 'g2', title: 'ok', at: t(20));
      await engine(dbA, cloud).syncNow(key);
      final res2 = await engine(dbB, cloud).syncNow(key);
      expect(res2.applied, 1);
      expect((await readGoal(dbB, 'g2'))!['title'], 'ok');
      expect(await SyncLocalStore(dbB).changeToken(), isNotNull,
          reason: 'the poisoned record must not re-pin the token');
      await dbA.close();
      await dbB.close();
    });

    test('a PLAUSIBLY-skewed record is still deferred and still holds the '
        'change token', () async {
      // The other side of the same guard, and the reason the fix above cannot
      // simply be "advance past anything future": a device whose clock is an
      // hour ahead is ordinary, its records are real, and `now` reaches them on
      // its own. Those must still be DEFERRED — held for a later sync — never
      // parked and never applied early.
      final cloud = FakeCloudKitBridge();
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);
      await insertGoal(dbA, 'g1', title: 'skewed', at: t(10));
      await dbA.update(
          'goals',
          {
            'updated_at': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: ['g1']);
      await engine(dbA, cloud).syncNow(key);

      final res = await engine(dbB, cloud).syncNow(key);
      expect(res.applied, 0);
      expect(await readGoal(dbB, 'g1'), isNull);
      expect(await SyncLocalStore(dbB).changeToken(), isNull,
          reason: 'a plausible skew must hold the token so the record is '
              're-fetched once the clock catches up');
      expect(await SyncLocalStore(dbB).stateOf('goals:g1'), isNull,
          reason: 'deferred, NOT parked — nothing was recorded against it');
      await dbA.close();
      await dbB.close();
    });

    test('a record parked as implausibly-future is neither re-fetched every '
        'sync nor lost — it applies once the clock passes its stamp', () async {
      // Letting the token advance is only safe if the record can still come
      // back. This is that half: a peer whose clock ran ten days fast, and a
      // device that has to end up with its data anyway.
      final cloud = FakeCloudKitBridge();
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);

      final bNow = DateTime.utc(2026, 1, 1, 12);
      final stamp = bNow.add(const Duration(days: 10));
      await insertGoal(dbA, 'g1', title: 'from a fast clock', at: t(10));
      await dbA.update('goals', {'updated_at': stamp.toIso8601String()},
          where: 'id = ?', whereArgs: ['g1']);
      await engine(dbA, cloud).syncNow(key);

      // B's clock is the honest one. Driving it explicitly is the only way to
      // test a mechanism whose whole contract is about time passing.
      SyncEngine at(DateTime now) => SyncEngine(
            store: SyncLocalStore(dbB),
            bridge: cloud,
            crypto: crypto,
            clock: () => now,
          );

      var res = await at(bNow).syncNow(key);
      expect(res.applied, 0);
      expect(await readGoal(dbB, 'g1'), isNull);
      expect(await SyncLocalStore(dbB).changeToken(), isNotNull);
      expect((await SyncLocalStore(dbB).diagnostics()).parkedByReason,
          contains(SyncLocalStore.implausibleFutureReason),
          reason: 'the record must be recorded, not silently dropped');

      // A day later the park is not yet due. Nothing is re-fetched: `skipped`
      // counts the records this pull was handed and could not take, so 0 is
      // the direct measurement that the poisoned record was NOT delivered
      // again. Under the old guard this was 1 on this sync and on every sync
      // after it, forever.
      res = await at(bNow.add(const Duration(days: 1))).syncNow(key);
      expect(res.skipped, 0);
      expect(await readGoal(dbB, 'g1'), isNull);
      expect((await SyncLocalStore(dbB).diagnostics()).parkedByReason,
          contains(SyncLocalStore.implausibleFutureReason),
          reason: 'a park that is not yet due must stay parked');

      // The clock passes the stamp: the park expires, one full re-fetch
      // re-delivers the record, and it applies. No user action anywhere.
      res = await at(stamp.add(const Duration(minutes: 1))).syncNow(key);
      expect(res.applied, 1);
      expect((await readGoal(dbB, 'g1'))!['title'], 'from a fast clock');
      final after = await SyncLocalStore(dbB).diagnostics();
      expect(after.parkedByReason, isEmpty);
      expect(after.isFullySynced, isTrue,
          reason: 'the park must not leave the device permanently "not synced"');
      await dbA.close();
      await dbB.close();
    });

    test('a timestamp beyond what DateTime can represent is parked, not thrown '
        'out of the pull, and does not un-park itself', () async {
      // `updatedAtMs` is an arbitrary int on the wire. The park records the
      // record's own stamp as its retry time, which means turning that int
      // into a DateTime — and DateTime rejects anything past ~275760 AD. An
      // unguarded conversion throws out of the middle of `_pull`, trading a
      // pinned change token for a sync that cannot run at all.
      //
      // The second half is the subtler trap: `DateTime.toIso8601String()`
      // renders years past 9999 with a leading '+', which sorts BEFORE every
      // ordinary year. A retry test that compared those strings in SQL would
      // read the most absurd stamp imaginable as already due and un-park it on
      // every sync — the re-download loop, rebuilt inside the recovery path.
      final cloud = FakeCloudKitBridge();
      final db = await openFreshV3();
      await seedOwner(db);
      await cloud.saveRecords([
        CloudRecord(
          recordName: 'goals:absurd',
          tableName: 'goals',
          updatedAtMs: 1 << 62,
          deleted: false,
          payload: crypto.encryptJson({'id': 'absurd', 'title': 'x'}, key),
        ),
      ]);

      final res = await engine(db, cloud).syncNow(key);
      expect(res.skipped, 1);
      expect(await readGoal(db, 'absurd'), isNull);
      expect(await SyncLocalStore(db).changeToken(), isNotNull);
      expect((await SyncLocalStore(db).diagnostics()).parkedByReason,
          contains(SyncLocalStore.implausibleFutureReason));

      // The next sync must not revive it, and must not re-fetch it.
      final res2 = await engine(db, cloud).syncNow(key);
      expect(res2.skipped, 0);
      expect((await SyncLocalStore(db).diagnostics()).parkedByReason,
          contains(SyncLocalStore.implausibleFutureReason));
      await db.close();
    });

    test('a maximally-NEGATIVE timestamp is skipped once, not mistaken for a '
        'future one and re-fetched every sync', () async {
      // The mirror image of the test above, and the reason the skew test is
      // written as `updatedAtMs > nowMs + bound` rather than as a subtraction:
      // `updatedAtMs - nowMs` wraps for an int64 near the floor and reports a
      // huge POSITIVE skew. The record would then be parked with a retry time
      // of "now", come due on the very next sync, drop the change token, be
      // re-fetched, wrap again and be re-parked — the unbounded re-download,
      // rebuilt inside the mechanism added to prevent it.
      final cloud = FakeCloudKitBridge();
      final db = await openFreshV3();
      await seedOwner(db);
      await cloud.saveRecords([
        CloudRecord(
          recordName: 'goals:ancient',
          tableName: 'goals',
          // Dart's int64 floor. Nothing smaller exists, so this is the only
          // value for which `updatedAtMs - nowMs` actually wraps — a merely
          // very negative number does not, and a test using one proves
          // nothing.
          updatedAtMs: 1 << 63,
          deleted: false,
          payload: crypto.encryptJson({'id': 'ancient', 'title': 'x'}, key),
        ),
      ]);

      final res = await engine(db, cloud).syncNow(key);
      expect(await SyncLocalStore(db).changeToken(), isNotNull);
      expect(res.skipped, 1, reason: 'older than anything local: LWW skips it');
      expect((await SyncLocalStore(db).diagnostics()).parkedByReason, isEmpty,
          reason: 'an ancient stamp is not a FUTURE one and must not park');

      // The decisive half: it is gone from the pull, not cycling through it.
      final res2 = await engine(db, cloud).syncNow(key);
      expect(res2.skipped, 0);
      expect(await SyncLocalStore(db).changeToken(), isNotNull);
      await db.close();
    });

    test(
        'a record that FAILS to apply holds the change token (not lost) and is '
        'recovered on a later successful sync', () async {
      final cloud = FakeCloudKitBridge();
      final dbA = await openFreshV3();
      final dbB = await openFreshV3();
      await seedOwner(dbA);
      await seedOwner(dbB);

      await insertGoal(dbA, 'g1', title: 'secret', at: t(10));
      await engine(dbA, cloud).syncNow(key);

      // Device B pulls with the WRONG key: decrypting g1's payload throws.
      //
      // This record is QUARANTINED and the token ADVANCES — deliberately not
      // held. A wrong key is not a transient fault: holding the token would pin
      // B forever, re-downloading and re-discarding the whole zone on every
      // sync (the state a real key split left an iPhone in — `change token:
      // none`, 6238 records skipped per sync, indefinitely).
      final wrongKey = crypto.generateKey();
      final res = await engine(dbB, cloud).syncNow(wrongKey);
      expect(res.applied, 0);
      expect(res.undecryptable, 1);
      expect(await readGoal(dbB, 'g1'), isNull); // nothing applied
      expect(await SyncLocalStore(dbB).changeToken(), isNotNull); // ADVANCED

      // Recovery still works, via a different mechanism: once the correct key
      // is delivered, the changed key fingerprint drops the token and forces one
      // full re-fetch, which re-delivers g1 and applies it. No data lost.
      final res2 = await engine(dbB, cloud).syncNow(key);
      expect(res2.applied, 1);
      expect((await readGoal(dbB, 'g1'))!['title'], 'secret');
      expect(await SyncLocalStore(dbB).changeToken(), isNotNull);
      await dbA.close();
      await dbB.close();
    });

    test('a malformed record name is skipped and lets the token advance',
        () async {
      // A structurally-invalid record (name without the "<table>:" prefix) can
      // never apply; it must be skipped WITHOUT wedging the pull (no RangeError)
      // and WITHOUT holding the token forever.
      final cloud = FakeCloudKitBridge();
      final db = await openFreshV3();
      await seedOwner(db);

      await cloud.saveRecords([
        CloudRecord(
          recordName: 'not-a-valid-name', // no "goals:" prefix
          tableName: 'goals',
          updatedAtMs: ms(t(10)),
          deleted: false,
          payload: crypto.encryptJson({'id': 'x', 'title': 'y'}, key),
        ),
      ]);

      final res = await engine(db, cloud).syncNow(key);
      expect(res.applied, 0);
      // The token advanced past the malformed record (it will not be re-fetched
      // and re-crash the pull every sync).
      expect(await SyncLocalStore(db).changeToken(), isNotNull);
      await db.close();
    });
  });
}
