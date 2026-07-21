// Regression tests for the four cross-device data-integrity defects in the
// engine: natural-key collisions (#19), a local edit racing a push (#20),
// unbounded push batches (#21), and forward-compatibility with a newer client's
// schema (#23).
import 'package:evolve_sync/evolve_sync.dart';
import 'package:evolve_sync/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Wraps a real fake cloud and rejects any operation over [cap] the way
/// CloudKit rejects an oversized CKModifyRecordsOperation: a REQUEST-level
/// `CKError.limitExceeded`, so no per-record block runs and nothing uploads.
class _CappedCloud implements CloudKitBridge {
  _CappedCloud(this.inner, {required this.cap});

  final FakeCloudKitBridge inner;
  final int cap;
  final List<int> batchSizes = [];

  /// Reject the Nth saveRecords call outright (simulates a mid-push failure).
  int? failCallIndex;

  @override
  Future<SaveOutcome> saveRecords(List<CloudRecord> records) async {
    batchSizes.add(records.length);
    if (records.length > cap) {
      throw StateError('limitExceeded: ${records.length} records in one op');
    }
    if (failCallIndex == batchSizes.length - 1) {
      throw StateError('networkFailure');
    }
    return inner.saveRecords(records);
  }

  @override
  Future<CloudAccountStatus> accountStatus() => inner.accountStatus();
  @override
  Future<void> ensureZone() => inner.ensureZone();
  @override
  Future<FetchOutcome> fetchChanges(String? token) => inner.fetchChanges(token);
  @override
  Future<void> deleteRecords(List<String> names) => inner.deleteRecords(names);
  @override
  Future<void> deleteZone() => inner.deleteZone();
  // Delegates: the probe is orthogonal to what these wrappers simulate.
  @override
  Future<bool> zoneHasRecords() => inner.zoneHasRecords();

  @override
  Future<void> ensureSubscription() => inner.ensureSubscription();
}

/// Runs [onSave] the first time a push reaches the network, standing in for an
/// app write that lands while the upload is in flight.
class _EditDuringPushCloud implements CloudKitBridge {
  _EditDuringPushCloud(this.inner, this.onSave);

  final FakeCloudKitBridge inner;
  final Future<void> Function() onSave;
  bool _fired = false;

  @override
  Future<SaveOutcome> saveRecords(List<CloudRecord> records) async {
    if (!_fired) {
      _fired = true;
      await onSave();
    }
    return inner.saveRecords(records);
  }

  @override
  Future<CloudAccountStatus> accountStatus() => inner.accountStatus();
  @override
  Future<void> ensureZone() => inner.ensureZone();
  @override
  Future<FetchOutcome> fetchChanges(String? token) => inner.fetchChanges(token);
  @override
  Future<void> deleteRecords(List<String> names) => inner.deleteRecords(names);
  @override
  Future<void> deleteZone() => inner.deleteZone();

  // Delegates: the probe is orthogonal to what this wrapper simulates.
  @override
  Future<bool> zoneHasRecords() => inner.zoneHasRecords();

  @override
  Future<void> ensureSubscription() => inner.ensureSubscription();
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
  int ms(String iso) => DateTime.parse(iso).millisecondsSinceEpoch;

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
    await db.insert('profiles',
        {'id': 'owner', 'created_at': t(1), 'updated_at': t(1)});
    await db.update(PrivateDbSchema.syncStateTable, {'dirty': 0});
  }

  Future<void> insertGoal(Database db, String id, {required String at}) =>
      db.insert('goals', {
        'id': id,
        'user_id': 'owner',
        'title': 'goal $id',
        'color': '#FFFFFF',
        'start_date': at,
        'created_at': at,
        'updated_at': at,
      });

  Map<String, Object?> logRow(String id,
          {required String status, required String at}) =>
      {
        'id': id,
        'user_id': 'owner',
        'goal_id': 'g1',
        'date': '2020-01-05',
        'status': status,
        'created_at': at,
        'updated_at': at,
        'streak': 1,
      };

  Future<void> insertCategory(Database db, String id,
          {required String name, required String at}) =>
      db.insert('macro_goal_categories', {
        'id': id,
        'user_id': 'owner',
        'name': name,
        'color': '#FF0000',
        'created_at': at,
        'updated_at': at,
      });

  Future<void> insertMacroGoal(Database db, String id,
          {required String categoryId, required String at}) =>
      db.insert('long_term_goals', {
        'id': id,
        'user_id': 'owner',
        'title': 'macro $id',
        'status': 'active',
        'type': 'annual',
        'year': 2020,
        'category_id': categoryId,
        'created_at': at,
        'updated_at': at,
      });

  Future<Map<String, Object?>?> syncRow(Database db, String recordName) async {
    final r = await db.query(PrivateDbSchema.syncStateTable,
        where: 'record_name = ?', whereArgs: [recordName], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  SyncEngine engine(Database db, CloudKitBridge bridge) =>
      SyncEngine(store: SyncLocalStore(db), bridge: bridge, crypto: crypto);

  group('#19 natural-key collisions', () {
    test('naturalKeys matches every UNIQUE constraint in the live schema',
        () async {
      // SyncLocalStore.naturalKeys restates constraints declared in
      // PrivateDbSchema. A UNIQUE constraint added there but not here silently
      // re-opens this whole class of bug, so read the real schema and compare.
      final db = await openFresh();
      final found = <String, List<String>>{};
      for (final table in PrivateDbSchema.syncedTables) {
        for (final idx in await db.rawQuery('PRAGMA index_list($table)')) {
          // origin 'u' = an index backing a UNIQUE constraint ('pk' is the
          // primary key, 'c' a plain CREATE INDEX).
          if (idx['unique'] != 1 || idx['origin'] != 'u') continue;
          final cols = await db.rawQuery("PRAGMA index_info('${idx['name']}')");
          found[table] = [for (final c in cols) c['name'] as String]..sort();
        }
      }
      final declared = {
        for (final e in SyncLocalStore.naturalKeys.entries)
          e.key: [...e.value]..sort(),
      };
      expect(declared, found);
      await db.close();
    });

    test(
        'an OLDER remote log does not destroy the NEWER local log for the same '
        '(goal_id, date), and both devices converge on the same row', () async {
      final cloud = FakeCloudKitBridge();
      final dbA = await openFresh();
      final dbB = await openFresh();
      await seedOwner(dbA);
      await seedOwner(dbB);
      await insertGoal(dbA, 'g1', at: t(5));
      await insertGoal(dbB, 'g1', at: t(5));
      await dbA.update(PrivateDbSchema.syncStateTable, {'dirty': 0});
      await dbB.update(PrivateDbSchema.syncStateTable, {'dirty': 0});

      // Each device marks the SAME habit on the SAME day while the other is
      // offline. Both mint a fresh uuid, so one logical slot has two ids.
      // A's edit is the NEWER one.
      await dbA.insert('goal_logs', logRow('lA', status: 'done', at: t(30)));
      await dbB.insert('goal_logs', logRow('lB', status: 'skipped', at: t(20)));

      // B pushed first (A was offline).
      await cloud.saveRecords([
        CloudRecord(
          recordName: 'goal_logs:lB',
          tableName: 'goal_logs',
          updatedAtMs: ms(t(20)),
          deleted: false,
          payload:
              crypto.encryptJson(logRow('lB', status: 'skipped', at: t(20)), key),
        ),
      ]);

      // A pulls B's older log. It must NOT replace A's newer one.
      await engine(dbA, cloud).syncNow(key);
      final aLogs = await dbA.query('goal_logs');
      expect(aLogs, hasLength(1));
      expect(aLogs.single['id'], 'lA');
      expect(aLogs.single['status'], 'done',
          reason: "A's newer 'done' must survive B's older 'skipped'");

      // B pulls A's newer log: its own row loses and must be really deleted —
      // with a tombstone, so the death propagates instead of silently vanishing.
      await engine(dbB, cloud).syncNow(key);
      final bLogs = await dbB.query('goal_logs');
      expect(bLogs, hasLength(1));
      expect(bLogs.single['id'], 'lA');
      expect(bLogs.single['status'], 'done');
      expect((await syncRow(dbB, 'goal_logs:lB'))!['deleted'], 1,
          reason: 'the losing row must leave a real tombstone');
      expect(cloud.records['goal_logs:lB']!.deleted, isTrue,
          reason: "the loser's tombstone must reach the cloud");

      // Both devices agree, and stay agreeing after another round.
      await engine(dbA, cloud).syncNow(key);
      expect(await dbA.query('goal_logs'), hasLength(1));
      expect((await dbA.query('goal_logs')).single['status'], 'done');
      expect(await SyncLocalStore(dbA).foreignKeyCheck(), isEmpty);
      expect(await SyncLocalStore(dbB).foreignKeyCheck(), isEmpty);

      await dbA.close();
      await dbB.close();
    });

    test('a same-name category merge re-points macro goals and leaves no '
        'dangling category_id on either device', () async {
      final cloud = FakeCloudKitBridge();
      final dbA = await openFresh();
      final dbB = await openFresh();
      await seedOwner(dbA);
      await seedOwner(dbB);

      // Each device independently has a 'Sport' category with its own macro
      // goal. A's category is the newer one.
      await insertCategory(dbA, 'cA', name: 'Sport', at: t(30));
      await insertMacroGoal(dbA, 'mA', categoryId: 'cA', at: t(31));
      await insertCategory(dbB, 'cB', name: 'Sport', at: t(20));
      await insertMacroGoal(dbB, 'mB', categoryId: 'cB', at: t(21));

      // B syncs first: its category+macro goal reach the cloud before A's.
      await engine(dbB, cloud).syncNow(key);
      // A pulls B's losing category, then B's macro goal pointing at it.
      await engine(dbA, cloud).syncNow(key);
      // B pulls A's winning category: cB loses, mB must follow onto cA.
      await engine(dbB, cloud).syncNow(key);

      final bCats = await dbB.query('macro_goal_categories');
      expect(bCats, hasLength(1));
      expect(bCats.single['id'], 'cA');
      final bMb = (await dbB
              .query('long_term_goals', where: 'id = ?', whereArgs: ['mB']))
          .single;
      expect(bMb['category_id'], 'cA',
          reason: "the loser's macro goal must move to the surviving category, "
              'not lose its category');
      expect(await SyncLocalStore(dbB).foreignKeyCheck(), isEmpty);

      // A pulls the re-pointed macro goal + the loser's tombstone and converges.
      await engine(dbA, cloud).syncNow(key);
      final aCats = await dbA.query('macro_goal_categories');
      expect(aCats, hasLength(1));
      expect(aCats.single['id'], 'cA');
      final aMacros = await dbA.query('long_term_goals', orderBy: 'id');
      expect(aMacros.map((m) => m['id']), ['mA', 'mB']);
      expect(aMacros.every((m) => m['category_id'] == 'cA'), isTrue);
      expect(await SyncLocalStore(dbA).foreignKeyCheck(), isEmpty,
          reason: 'a macro goal must never be left pointing at a deleted '
              'category');

      await dbA.close();
      await dbB.close();
    });

    test('an exact-timestamp tie resolves to the SAME winner on both devices',
        () async {
      final cloud = FakeCloudKitBridge();
      final dbA = await openFresh();
      final dbB = await openFresh();
      await seedOwner(dbA);
      await seedOwner(dbB);
      await insertGoal(dbA, 'g1', at: t(5));
      await insertGoal(dbB, 'g1', at: t(5));
      await dbA.update(PrivateDbSchema.syncStateTable, {'dirty': 0});
      await dbB.update(PrivateDbSchema.syncStateTable, {'dirty': 0});

      // Same slot, same millisecond: LWW alone cannot pick, so the tiebreak has
      // to be a total order both devices compute identically.
      await dbA.insert('goal_logs', logRow('lA', status: 'done', at: t(30)));
      await dbB.insert('goal_logs', logRow('lB', status: 'skipped', at: t(30)));

      await engine(dbA, cloud).syncNow(key);
      await engine(dbB, cloud).syncNow(key);
      await engine(dbA, cloud).syncNow(key);
      await engine(dbB, cloud).syncNow(key);

      final aLogs = await dbA.query('goal_logs');
      final bLogs = await dbB.query('goal_logs');
      expect(aLogs, hasLength(1));
      expect(bLogs, hasLength(1));
      expect(aLogs.single['id'], bLogs.single['id'],
          reason: 'both devices must survive on the same row');
      expect(aLogs.single['status'], bLogs.single['status']);

      await dbA.close();
      await dbB.close();
    });
  });

  group('#20 a local edit racing a push', () {
    test('an edit landing during the upload stays dirty and reaches the other '
        'device on the next sync', () async {
      final fake = FakeCloudKitBridge();
      final dbA = await openFresh();
      final dbB = await openFresh();
      await seedOwner(dbA);
      await seedOwner(dbB);
      await insertGoal(dbA, 'g1', at: t(10));

      // The user re-titles g1 while the push of the t(10) version is in flight.
      final cloud = _EditDuringPushCloud(fake, () async {
        await dbA.update('goals', {'title': 'edited mid-push', 'updated_at': t(20)},
            where: 'id = ?', whereArgs: ['g1']);
      });

      await engine(dbA, cloud).syncNow(key);

      // The push only carried the t(10) payload, so the row must still be
      // queued — clearing dirty here is what silently drops the edit.
      expect((await syncRow(dbA, 'goals:g1'))!['dirty'], 1,
          reason: 'a row edited during the push must stay dirty');

      // The next sync uploads it, and the edit reaches the other device.
      await engine(dbA, fake).syncNow(key);
      expect((await syncRow(dbA, 'goals:g1'))!['dirty'], 0);
      await engine(dbB, fake).syncNow(key);
      final bGoal =
          (await dbB.query('goals', where: 'id = ?', whereArgs: ['g1'])).single;
      expect(bGoal['title'], 'edited mid-push');

      await dbA.close();
      await dbB.close();
    });

    test('a normal push still clears dirty', () async {
      final cloud = FakeCloudKitBridge();
      final db = await openFresh();
      await seedOwner(db);
      await insertGoal(db, 'g1', at: t(10));

      await engine(db, cloud).syncNow(key);

      expect((await syncRow(db, 'goals:g1'))!['dirty'], 0);
      // A second sync must not re-push it (the guard must not strand rows dirty).
      expect((await engine(db, cloud).syncNow(key)).pushed, 0);
      await db.close();
    });

    test('a legacy row with a null updated_at is not left permanently dirty',
        () async {
      // macro_goal_categories.updated_at is the one nullable case: the trigger
      // COALESCEs it to "now" in sync_state while the pushed record falls back
      // to that same stamp. The guard must still match.
      final cloud = FakeCloudKitBridge();
      final db = await openFresh();
      await seedOwner(db);
      await db.insert('macro_goal_categories', {
        'id': 'c1',
        'user_id': 'owner',
        'name': 'Sport',
        'color': '#FF0000',
        'created_at': t(10),
        'updated_at': null,
      });

      expect((await engine(db, cloud).syncNow(key)).pushed, 1);
      expect((await syncRow(db, 'macro_goal_categories:c1'))!['dirty'], 0);
      expect((await engine(db, cloud).syncNow(key)).pushed, 0,
          reason: 'a null updated_at must not ping-pong forever');
      await db.close();
    });
  });

  group('#21 push batching', () {
    test('a first-enable push of a large history is split into operations '
        'CloudKit accepts', () async {
      final db = await openFresh();
      await seedOwner(db);
      for (var i = 0; i < 900; i++) {
        await insertGoal(db, 'g$i', at: t(10));
      }
      final cloud = _CappedCloud(FakeCloudKitBridge(), cap: 400);

      final res = await engine(db, cloud).syncNow(key);

      expect(cloud.batchSizes.every((n) => n <= 400), isTrue,
          reason: 'no single operation may exceed the limit: '
              '${cloud.batchSizes}');
      expect(cloud.batchSizes.length, greaterThan(1));
      expect(res.pushed, 900);
      final stillDirty = await db.query(PrivateDbSchema.syncStateTable,
          where: 'dirty = 1');
      expect(stillDirty, isEmpty, reason: 'everything must actually upload');
      await db.close();
    });

    test('a failed batch keeps the batches already saved and leaves the rest '
        'dirty for the next sync', () async {
      final db = await openFresh();
      await seedOwner(db);
      for (var i = 0; i < 900; i++) {
        await insertGoal(db, 'g$i', at: t(10));
      }
      final inner = FakeCloudKitBridge();
      final cloud = _CappedCloud(inner, cap: 400)..failCallIndex = 1;

      await expectLater(engine(db, cloud).syncNow(key), throwsStateError);

      // The first batch's rows are saved and clean; the rest are still queued.
      expect(inner.records, hasLength(400), reason: 'progress must be durable');
      expect(
          await db.query(PrivateDbSchema.syncStateTable, where: 'dirty = 1'),
          hasLength(500));

      // The next sync resumes and finishes the job.
      cloud.failCallIndex = null;
      await engine(db, cloud).syncNow(key);
      expect(
          await db.query(PrivateDbSchema.syncStateTable, where: 'dirty = 1'),
          isEmpty);
      expect(inner.records, hasLength(900));
      await db.close();
    });
  });

  group('#23 forward compatibility with a newer client', () {
    /// Stands in for the next additive migration: a column a NEWER build has and
    /// this one does not (exactly the shape of v4's goals.verify_* against v3).
    Future<Database> openNewerSchema() async {
      final db = await openFresh();
      await db.execute('ALTER TABLE goals ADD COLUMN verify_window TEXT');
      return db;
    }

    /// A build whose `goal_logs.status` CHECK has been WIDENED — the newer
    /// client that legitimately authors `status = 'partial'`. SQLite cannot
    /// ALTER a CHECK, so the table is rebuilt (as the real v2 migration does)
    /// before the sync triggers are created over it.
    Future<Database> openWiderStatusCheck() => databaseFactory.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: PrivateDbSchema.version,
            singleInstance: false,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
            onCreate: (db, _) async {
              await PrivateDbSchema.createCoreTables(db);
              await db.execute('DROP TABLE goal_logs');
              await db.execute('''
CREATE TABLE goal_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  status TEXT NOT NULL
    CHECK (status IN ('done', 'missed', 'skipped', 'partial')),
  value REAL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  streak INTEGER DEFAULT 0,
  UNIQUE(goal_id, date)
)
''');
              await db.execute('CREATE INDEX idx_goal_logs_user_date '
                  'ON goal_logs (user_id, date DESC)');
              await PrivateDbSchema.createSyncObjects(db);
            },
            onUpgrade: PrivateDbSchema.onUpgrade,
          ),
        );

    /// The poison pill: a log a newer client wrote with a status THIS build's
    /// CHECK rejects. Pushed straight into the cloud so the test does not depend
    /// on the newer client's own push path.
    Future<void> cloudLogWithNewerStatus(FakeCloudKitBridge cloud) =>
        cloud.saveRecords([
          CloudRecord(
            recordName: 'goal_logs:l1',
            tableName: 'goal_logs',
            updatedAtMs: ms(t(10)),
            deleted: false,
            payload: crypto.encryptJson(
              logRow('l1', status: 'partial', at: t(10)),
              key,
            ),
          ),
        ]);

    test('a row carrying an unknown column applies on the older client instead '
        'of wedging the pull', () async {
      final cloud = FakeCloudKitBridge();
      final dbNew = await openNewerSchema();
      final dbOld = await openFresh();
      await seedOwner(dbNew);
      await seedOwner(dbOld);

      await insertGoal(dbNew, 'g1', at: t(10));
      await dbNew.update('goals', {'verify_window': 'morning'},
          where: 'id = ?', whereArgs: ['g1']);
      await engine(dbNew, cloud).syncNow(key);

      final res = await engine(dbOld, cloud).syncNow(key);

      expect(res.applied, greaterThan(0));
      final oldGoal = await dbOld.query('goals', where: 'id = ?', whereArgs: ['g1']);
      expect(oldGoal, hasLength(1),
          reason: 'an unknown column must not stop the row from applying');
      expect(oldGoal.single['title'], 'goal g1');
      expect(await SyncLocalStore(dbOld).changeToken(), isNotNull,
          reason: 'a permanently-unapplyable record would pin the token and '
              're-download the whole delta on every sync');

      await dbNew.close();
      await dbOld.close();
    });

    test('a row round-tripping through the older client keeps the column the '
        'older client cannot store', () async {
      final cloud = FakeCloudKitBridge();
      final dbNew = await openNewerSchema();
      final dbOld = await openFresh();
      await seedOwner(dbNew);
      await seedOwner(dbOld);

      await insertGoal(dbNew, 'g1', at: t(10));
      await dbNew.update('goals', {'verify_window': 'morning'},
          where: 'id = ?', whereArgs: ['g1']);
      await engine(dbNew, cloud).syncNow(key);
      await engine(dbOld, cloud).syncNow(key);

      // The user edits the goal on the OLD device, which knows nothing about
      // verify_window and pushes a payload without it.
      await dbOld.update('goals', {'title': 'renamed', 'updated_at': t(20)},
          where: 'id = ?', whereArgs: ['g1']);
      await engine(dbOld, cloud).syncNow(key);
      await engine(dbNew, cloud).syncNow(key);

      final newGoal =
          (await dbNew.query('goals', where: 'id = ?', whereArgs: ['g1'])).single;
      expect(newGoal['title'], 'renamed', reason: "the old client's edit applies");
      expect(newGoal['verify_window'], 'morning',
          reason: 'a column the sender simply does not have must not be wiped '
              'on the devices that do have it');

      await dbNew.close();
      await dbOld.close();
    });

    test('a VALUE this build cannot store is quarantined instead of pinning the '
        'change token forever', () async {
      final cloud = FakeCloudKitBridge();
      final dbOld = await openFresh();
      await seedOwner(dbOld);

      // One delta: the poison pill, plus an ordinary record behind it.
      await cloudLogWithNewerStatus(cloud);
      await cloud.saveRecords([
        CloudRecord(
          recordName: 'goals:g1',
          tableName: 'goals',
          updatedAtMs: ms(t(11)),
          deleted: false,
          payload: crypto.encryptJson({
            'id': 'g1',
            'user_id': 'owner',
            'title': 'goal g1',
            'color': '#FFFFFF',
            'start_date': t(11),
            'created_at': t(11),
            'updated_at': t(11),
          }, key),
        ),
      ]);

      final res = await engine(dbOld, cloud).syncNow(key);

      expect(await SyncLocalStore(dbOld).changeToken(), isNotNull,
          reason: 'a row that can NEVER apply must not pin the token — that '
              're-downloads the whole delta on every sync, forever');
      expect(res.applied, 1, reason: 'the rest of the delta still applies');
      expect(
          await dbOld.query('goal_logs', where: 'id = ?', whereArgs: ['l1']),
          isEmpty);

      // Recorded and queryable ON DEVICE: markError alone silently no-ops for a
      // never-before-seen record (its sync_state row does not exist yet), which
      // left the failure with no local trace at all.
      final parked = (await syncRow(dbOld, 'goal_logs:l1'))!;
      expect(parked['last_error'], isNotNull);
      expect(parked['dirty'], 0,
          reason: 'a dirty state row with no table row pushes a TOMBSTONE, '
              'which would delete the record this quarantine preserves');
      expect(parked['updated_at'], SyncLocalStore.quarantineStamp,
          reason: 'parking at the REMOTE stamp would make LWW treat the record '
              'as one we already hold and skip it forever');
      await dbOld.close();
    });

    test('a quarantined record is neither destroyed nor pushed back mangled, '
        'and still applies on a client that understands it', () async {
      final cloud = FakeCloudKitBridge();
      final dbOld = await openFresh();
      await seedOwner(dbOld);
      await cloudLogWithNewerStatus(cloud);
      final original = cloud.records['goal_logs:l1']!.payload;

      // Sync repeatedly: the pill must not wedge, and must not push anything.
      await engine(dbOld, cloud).syncNow(key);
      final tokenAfterFirst = await SyncLocalStore(dbOld).changeToken();
      final res = await engine(dbOld, cloud).syncNow(key);

      expect(res.pushed, 0, reason: 'the old client must not write it back');
      expect(await SyncLocalStore(dbOld).changeToken(), tokenAfterFirst);
      expect(cloud.records['goal_logs:l1']!.deleted, isFalse,
          reason: 'the old client must never tombstone the record it skipped');
      expect(cloud.records['goal_logs:l1']!.payload, original,
          reason: 'the cloud copy must survive byte-for-byte');

      // The record is intact for any client whose schema accepts the value.
      final dbNew = await openWiderStatusCheck();
      await seedOwner(dbNew);
      await insertGoal(dbNew, 'g1', at: t(9));
      await engine(dbNew, cloud).syncNow(key);
      final log =
          (await dbNew.query('goal_logs', where: 'id = ?', whereArgs: ['l1']))
              .single;
      expect(log['status'], 'partial');
      expect(log['streak'], 1, reason: 'no column lost on the round trip');
      await dbOld.close();
      await dbNew.close();
    });

    test('a quarantined record is re-attempted when it is delivered again, not '
        'mistaken for one already held', () async {
      // The recovery path: a quarantine is PARKED, not marked applied, so the
      // full re-fetch that follows an app update re-applies it rather than
      // having LWW skip it as already-present.
      final cloud = FakeCloudKitBridge();
      final dbOld = await openFresh();
      await seedOwner(dbOld);
      await cloudLogWithNewerStatus(cloud);
      await engine(dbOld, cloud).syncNow(key);

      // Clear the trace, then re-deliver the record from scratch.
      await dbOld.update(
        PrivateDbSchema.syncStateTable,
        {'last_error': null},
        where: 'record_name = ?',
        whereArgs: ['goal_logs:l1'],
      );
      await SyncLocalStore(dbOld).setChangeToken(null);
      await engine(dbOld, cloud).syncNow(key);

      expect((await syncRow(dbOld, 'goal_logs:l1'))!['last_error'], isNotNull,
          reason: 'the record must be re-attempted on re-delivery; a build that '
              'has since learned the value would apply it here');
      await dbOld.close();
    });

    test('a record for a table this build has no schema for is skipped and lets '
        'the token advance', () async {
      final cloud = FakeCloudKitBridge();
      final db = await openFresh();
      await seedOwner(db);

      await cloud.saveRecords([
        CloudRecord(
          recordName: 'future_table:x1',
          tableName: 'future_table',
          updatedAtMs: ms(t(10)),
          deleted: false,
          payload: crypto.encryptJson({'id': 'x1', 'foo': 'bar'}, key),
        ),
      ]);

      final res = await engine(db, cloud).syncNow(key);

      expect(res.applied, 0);
      expect(await SyncLocalStore(db).changeToken(), isNotNull);
      await db.close();
    });
  });
}
