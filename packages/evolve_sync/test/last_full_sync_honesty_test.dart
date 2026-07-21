// A1 — "success is still reported on failure".
//
// `SyncEngine.syncNow` stamped `last_full_sync_at` unconditionally, immediately
// after the push, regardless of how many records the push had failed to upload.
// Every UI in both apps renders that stamp as "Last synced: <time>", so a user
// whose entire dataset was stranded in the local database was told, truthfully
// formatted and completely falsely, that their data had just synced. That is
// the exact behaviour that hid the original reported bug for weeks.
//
// These tests assert the OBSERVABLE contract, not the code path:
//   * a sync that did not move everything must not advance the timestamp a UI
//     renders as "last synced";
//   * a sync that DID move everything must still advance it (the fix must not
//     be a blanket refusal to ever report success);
//   * `SyncResult` must carry a failure count, so the UI can say something
//     other than nothing.
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

  Future<void> seedOwner(Database db) async {
    await db.insert(
        'profiles', {'id': 'owner', 'created_at': t(1), 'updated_at': t(1)});
    await db.update(PrivateDbSchema.syncStateTable, {'dirty': 0});
  }

  Future<void> insertGoal(Database db, String id, {required String at}) =>
      db.insert('goals', {
        'id': id,
        'user_id': 'owner',
        'title': id,
        'color': '#FFFFFF',
        'start_date': at,
        'created_at': at,
        'updated_at': at,
      });

  SyncEngine engine(Database db, CloudKitBridge bridge) =>
      SyncEngine(store: SyncLocalStore(db), bridge: bridge, crypto: crypto);

  group('last_full_sync_at must not be stamped by a sync that failed', () {
    test('a push in which EVERY record failed leaves "last synced" unset',
        () async {
      final db = await openFresh();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge();
      await insertGoal(db, 'g1', at: t(10));
      await insertGoal(db, 'g2', at: t(11));
      cloud.failSaveFor.addAll({'goals:g1', 'goals:g2'});

      final res = await engine(db, cloud).syncNow(key);

      expect(res.pushed, 0, reason: 'nothing reached the cloud');
      expect(await SyncLocalStore(db).lastFullSync(), isNull,
          reason:
              'the UI renders this as "Last synced: <time>". Nothing synced, '
              'so there is no time to render.');
      await db.close();
    });

    test('a push in which SOME records failed leaves "last synced" unset',
        () async {
      final db = await openFresh();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge();
      await insertGoal(db, 'g1', at: t(10));
      await insertGoal(db, 'g2', at: t(11));
      cloud.failSaveFor.add('goals:g2');

      final res = await engine(db, cloud).syncNow(key);

      expect(res.pushed, 1);
      expect(await SyncLocalStore(db).lastFullSync(), isNull,
          reason: 'a partial push is not a full sync');
      await db.close();
    });

    test('SyncResult reports how many records the push failed to upload',
        () async {
      final db = await openFresh();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge();
      await insertGoal(db, 'g1', at: t(10));
      await insertGoal(db, 'g2', at: t(11));
      await insertGoal(db, 'g3', at: t(12));
      cloud.failSaveFor.addAll({'goals:g1', 'goals:g3'});

      final res = await engine(db, cloud).syncNow(key);

      expect(res.pushFailed, 2);
      expect(res.fullySynced, isFalse);
      await db.close();
    });

    test(
        'a pull that held the change token leaves "last synced" unset '
        '(records were deferred, so the device is not up to date)', () async {
      final db = await openFresh();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge();
      // A record from a device whose clock is a couple of hours ahead: a
      // PLAUSIBLE skew, so the guard defers it and holds the change token, and
      // this pull did NOT take the zone. The stamp has to stay inside the
      // deferrable band — a stamp days out is no longer deferred at all, it is
      // parked and the token advances (see the skew tests in
      // sync_engine_test.dart), which is a completed sync and would say
      // nothing about the invariant under test here.
      await cloud.saveRecords([
        CloudRecord(
          recordName: 'goals:future',
          tableName: 'goals',
          updatedAtMs: DateTime.now()
              .toUtc()
              .add(const Duration(hours: 2))
              .millisecondsSinceEpoch,
          deleted: false,
          payload: crypto.encryptJson({'id': 'future'}, key),
        ),
      ]);

      final res = await engine(db, cloud).syncNow(key);

      expect(res.pullIncomplete, isTrue);
      expect(res.fullySynced, isFalse);
      expect(await SyncLocalStore(db).lastFullSync(), isNull);
      await db.close();
    });

    test('a PARKED implausible record stamps "last synced" but still reports '
        'the device as not fully synced', () async {
      // The two answers differ on purpose and both have to stay true.
      // `SyncResult.fullySynced` describes THIS sync, which completed: it took
      // everything the zone offered that it could take, and held nothing back.
      // `SyncDiagnostics.isFullySynced` describes the DEVICE, which is still
      // missing a record. Collapsing them either way is a lie in one direction
      // or the other — "last synced: never" on a device that is syncing fine,
      // or "up to date" over a record that never arrived.
      final db = await openFresh();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge();
      await cloud.saveRecords([
        CloudRecord(
          recordName: 'goals:bogus',
          tableName: 'goals',
          updatedAtMs: DateTime.utc(2999).millisecondsSinceEpoch,
          deleted: false,
          payload: crypto.encryptJson({'id': 'bogus'}, key),
        ),
      ]);

      final res = await engine(db, cloud).syncNow(key);

      expect(res.pullIncomplete, isFalse);
      expect(res.fullySynced, isTrue);
      expect(await SyncLocalStore(db).lastFullSync(), isNotNull);

      final diagnostics = await SyncLocalStore(db).diagnostics();
      expect(diagnostics.isFullySynced, isFalse,
          reason: 'a parked record must keep the DEVICE out of "up to date"');
      expect(diagnostics.parkedByReason,
          contains(SyncLocalStore.implausibleFutureReason),
          reason: 'the park must name its cause, not vanish into a count');
      await db.close();
    });
  });

  group('a sync that genuinely succeeded must still say so', () {
    test('a clean push stamps "last synced"', () async {
      final db = await openFresh();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge();
      await insertGoal(db, 'g1', at: t(10));

      final res = await engine(db, cloud).syncNow(key);

      expect(res.pushed, 1);
      expect(res.pushFailed, 0);
      expect(res.fullySynced, isTrue);
      expect(await SyncLocalStore(db).lastFullSync(), isNotNull);
      await db.close();
    });

    test('a sync with nothing to do stamps "last synced"', () async {
      final db = await openFresh();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge();

      final res = await engine(db, cloud).syncNow(key);

      expect(res.fullySynced, isTrue);
      expect(await SyncLocalStore(db).lastFullSync(), isNotNull,
          reason: 'an idle device IS up to date — this is not a failure');
      await db.close();
    });

    test(
        'a retry that succeeds after a failed push finally stamps "last synced"',
        () async {
      final db = await openFresh();
      await seedOwner(db);
      final cloud = FakeCloudKitBridge();
      await insertGoal(db, 'g1', at: t(10));
      cloud.failSaveFor.add('goals:g1');

      await engine(db, cloud).syncNow(key);
      expect(await SyncLocalStore(db).lastFullSync(), isNull);

      // The record stayed dirty, so the next sync re-pushes it.
      cloud.failSaveFor.clear();
      final res = await engine(db, cloud).syncNow(key);

      expect(res.pushed, 1, reason: 'the failed record was retried, not lost');
      expect(await SyncLocalStore(db).lastFullSync(), isNotNull);
      await db.close();
    });
  });
}
