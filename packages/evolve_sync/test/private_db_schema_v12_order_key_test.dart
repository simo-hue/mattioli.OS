// v12: fractional habit ordering.
//
// `display_order` was a dense 0..n-1 sequence — a property of the whole
// COLLECTION — merged by the sync engine PER ROW. One pulled goal row therefore
// overwrote one habit's slot in isolation, leaving duplicate and missing
// positions that `ORDER BY display_order, created_at` then resolved into an
// order nobody chose.
//
// `order_key` is a property of the ROW: a value strictly between its
// neighbours. Per-row last-write-wins is then correct by construction.
// `order_key_updated_at` carries FIELD-level LWW for that one column, so an
// unrelated edit (a rename on another device) cannot drag a habit back to a
// position the user already moved it out of.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner-1';
  const now = '2026-06-01T00:00:00.000Z';

  Future<Database> openV12() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        onConfigure: PrivateDbSchema.onConfigure,
        onCreate: PrivateDbSchema.onCreate,
        onUpgrade: PrivateDbSchema.onUpgrade,
      ),
    );
    // goals.user_id REFERENCES profiles(id), and onConfigure turns FKs on.
    // ignore, not the default: sqflite CACHES in-memory databases by path, so a
    // later openV12() in the same file can hand back a database that already
    // has this row.
    await db.insert(
      'profiles',
      {'id': owner, 'created_at': now, 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.delete('goals');
    return db;
  }

  Future<void> seedGoal(
    Database db,
    String id, {
    int? displayOrder,
    String createdAt = now,
  }) async {
    await db.insert('goals', {
      'id': id,
      'user_id': owner,
      'title': id,
      'color': '#3B82F6',
      'start_date': now,
      'display_order': displayOrder,
      'created_at': createdAt,
      'updated_at': now,
    });
  }

  Future<List<String>> idsByOrderKey(Database db) async {
    final rows = await db.query('goals', orderBy: 'order_key ASC');
    return [for (final r in rows) r['id'] as String];
  }

  group('the v12 columns exist and are usable', () {
    test('a fresh database is born with order_key and its index', () async {
      final db = await openV12();
      final cols = {
        for (final r in await db.rawQuery('PRAGMA table_info(goals)'))
          r['name'] as String,
      };
      expect(cols, containsAll(['order_key', 'order_key_updated_at']));

      final indexes = {
        for (final r in await db.rawQuery('PRAGMA index_list(goals)'))
          r['name'] as String,
      };
      expect(indexes, contains('idx_goals_user_order_key'));
      await db.close();
    });

    test('the schema version is 12', () {
      expect(PrivateDbSchema.version, 12);
    });
  });

  group('backfillOrderKeys', () {
    test('THE MIGRATION: preserves the order display_order already had',
        () async {
      // A single-device user's hand-picked order must survive exactly.
      final db = await openV12();
      await seedGoal(db, 'c', displayOrder: 2);
      await seedGoal(db, 'a', displayOrder: 0);
      await seedGoal(db, 'b', displayOrder: 1);
      await db.update('goals', {'order_key': null, 'order_key_updated_at': null});

      await PrivateDbSchema.backfillOrderKeys(db);

      expect(await idsByOrderKey(db), ['a', 'b', 'c']);
      await db.close();
    });

    test('is DETERMINISTIC: ties break by created_at then id', () async {
      // Two devices running this independently must agree wherever their inputs
      // already agree — otherwise the migration itself scrambles the order.
      final db = await openV12();
      await seedGoal(db, 'z', displayOrder: 0, createdAt: '2026-01-01T00:00:00Z');
      await seedGoal(db, 'y', displayOrder: 0, createdAt: '2026-01-01T00:00:00Z');
      await seedGoal(db, 'x', displayOrder: 0, createdAt: '2025-01-01T00:00:00Z');
      await db.update('goals', {'order_key': null, 'order_key_updated_at': null});

      await PrivateDbSchema.backfillOrderKeys(db);

      expect(await idsByOrderKey(db), ['x', 'y', 'z'],
          reason: 'older created_at first, then id ascending');
      await db.close();
    });

    test('a NULL display_order sorts last rather than first', () async {
      // SQLite puts NULL FIRST in an ASC sort, which is how a habit created
      // after a reorder used to jump to the top. The backfill must not carry
      // that over.
      final db = await openV12();
      await seedGoal(db, 'positioned', displayOrder: 0);
      await seedGoal(db, 'unpositioned');
      await db.update('goals', {'order_key': null, 'order_key_updated_at': null});

      await PrivateDbSchema.backfillOrderKeys(db);

      expect(await idsByOrderKey(db), ['positioned', 'unpositioned']);
      await db.close();
    });

    test('THE REGRESSION: leaves order_key_updated_at NULL', () async {
      // The stamp is the FIELD-level LWW clock, not a propagation stamp. If the
      // migration claimed `now`, the SECOND device to migrate — days later,
      // since iOS and macOS ship independently — would outrank every drag made
      // on the first and snap the order back to its own stale display_order.
      final db = await openV12();
      await seedGoal(db, 'a', displayOrder: 0);
      await db.update('goals', {'order_key': null, 'order_key_updated_at': null});

      await PrivateDbSchema.backfillOrderKeys(db);

      final row = (await db.query('goals', where: "id = 'a'")).single;
      expect(row['order_key'], isNotNull);
      expect(row['order_key_updated_at'], isNull,
          reason: 'a migration has not POSITIONED anything — a null local stamp '
              'yields to a peer key (so devices converge) while a null remote '
              'stamp cannot outrank a real drag');
      await db.close();
    });

    test('a real drag DEFENDS its position against a peer backfill', () async {
      final db = await openV12();
      await seedGoal(db, 'a', displayOrder: 0);
      // This device dragged the habit; the peer only migrated.
      await db.update('goals', {
        'order_key': 5.0,
        'order_key_updated_at': '2026-08-06T12:00:00.000Z',
      });
      final store = SyncLocalStore(db);

      await store.applyUpsert(
        'goals',
        'goals:a',
        {
          'id': 'a',
          'user_id': owner,
          'title': 'renamed on the peer',
          'color': '#3B82F6',
          'start_date': now,
          'order_key': 1024.0,
          'order_key_updated_at': null, // a backfilled peer row
          'created_at': now,
          'updated_at': '2030-01-01T00:00:00.000Z',
        },
        DateTime.parse('2030-01-01T00:00:00.000Z').millisecondsSinceEpoch,
        now,
      );

      final row = (await db.query('goals', where: "id = 'a'")).single;
      expect(row['order_key'], 5.0, reason: 'the drag wins over a migration');
      expect(row['title'], 'renamed on the peer');
      await db.close();
    });

    test('stamps updated_at so the backfill PROPAGATES to peers', () async {
      // The AFTER UPDATE trigger records sync_state.updated_at from the row's
      // own value and peers apply on strict greater-than, so an unbumped row
      // would be pushed and then discarded everywhere.
      final db = await openV12();
      await seedGoal(db, 'a', displayOrder: 0);
      await db.update('goals', {'order_key': null, 'order_key_updated_at': null});
      await db.update('goals', {'updated_at': now});

      await PrivateDbSchema.backfillOrderKeys(db);

      final row = (await db.query('goals', where: "id = 'a'")).single;
      expect(row['updated_at'], isNot(now),
          reason: 'the PROPAGATION stamp is bumped so peers accept the row');
      expect(row['order_key_updated_at'], isNull,
          reason: 'the LWW clock is not — see the test above');
      await db.close();
    });

    test('leaves rows that already have a key alone', () async {
      final db = await openV12();
      await seedGoal(db, 'a', displayOrder: 0);
      await db.update('goals', {'order_key': 555.0});

      await PrivateDbSchema.backfillOrderKeys(db);

      final row = (await db.query('goals', where: "id = 'a'")).single;
      expect(row['order_key'], 555.0, reason: 'idempotent — no churn');
      await db.close();
    });
  });

  group('field-level LWW for order_key (SyncLocalStore.applyUpsert)', () {
    Future<SyncLocalStore> storeOn(Database db) async => SyncLocalStore(db);

    Map<String, Object?> goalPayload({
      required String id,
      required double orderKey,
      required String orderKeyStamp,
      String title = 'from-peer',
    }) =>
        {
          'id': id,
          'user_id': owner,
          'title': title,
          'color': '#3B82F6',
          'start_date': now,
          'order_key': orderKey,
          'order_key_updated_at': orderKeyStamp,
          'created_at': now,
          'updated_at': '2030-01-01T00:00:00.000Z',
        };

    test(
        'THE RULE: a peer row carrying an OLDER position does not move the habit',
        () async {
      // Rename a habit on the Mac and its stale order_key rides along inside a
      // newer row. Whole-row LWW would apply it and drag the habit back to where
      // the Mac still thinks it belongs. It must not be possible to move a habit
      // by renaming it.
      final db = await openV12();
      await seedGoal(db, 'a', displayOrder: 0);
      await db.update('goals', {
        'order_key': 9999.0,
        'order_key_updated_at': '2026-08-06T12:00:00.000Z', // moved HERE, later
      });
      final store = await storeOn(db);

      await store.applyUpsert(
        'goals',
        'goals:a',
        goalPayload(
          id: 'a',
          orderKey: 1.0,
          orderKeyStamp: '2026-08-06T09:00:00.000Z', // the Mac's older position
        ),
        DateTime.parse('2030-01-01T00:00:00.000Z').millisecondsSinceEpoch,
        now,
      );

      final row = (await db.query('goals', where: "id = 'a'")).single;
      expect(row['order_key'], 9999.0,
          reason: 'the local position is newer and must survive');
      expect(row['title'], 'from-peer',
          reason: 'every OTHER column still applies — this is one field, not a '
              'veto on the whole row');
      await db.close();
    });

    test('a peer row carrying a NEWER position DOES move the habit', () async {
      final db = await openV12();
      await seedGoal(db, 'a', displayOrder: 0);
      await db.update('goals', {
        'order_key': 9999.0,
        'order_key_updated_at': '2026-08-06T09:00:00.000Z',
      });
      final store = await storeOn(db);

      await store.applyUpsert(
        'goals',
        'goals:a',
        goalPayload(
          id: 'a',
          orderKey: 1.0,
          orderKeyStamp: '2026-08-06T12:00:00.000Z', // genuinely newer
        ),
        DateTime.parse('2030-01-01T00:00:00.000Z').millisecondsSinceEpoch,
        now,
      );

      expect((await db.query('goals', where: "id = 'a'")).single['order_key'],
          1.0);
      await db.close();
    });

    test('a remote row with NO stamp cannot claim to be newer', () async {
      // An older build that does not know about order_key_updated_at.
      final db = await openV12();
      await seedGoal(db, 'a', displayOrder: 0);
      await db.update('goals', {
        'order_key': 9999.0,
        'order_key_updated_at': '2026-08-06T12:00:00.000Z',
      });
      final store = await storeOn(db);

      await store.applyUpsert(
        'goals',
        'goals:a',
        {
          ...goalPayload(id: 'a', orderKey: 1.0, orderKeyStamp: ''),
          'order_key_updated_at': null,
        },
        DateTime.parse('2030-01-01T00:00:00.000Z').millisecondsSinceEpoch,
        now,
      );

      expect((await db.query('goals', where: "id = 'a'")).single['order_key'],
          9999.0);
      await db.close();
    });

    test('a LOCAL row never positioned here takes the remote position',
        () async {
      // A pre-v12 row: this device has no claim to defend.
      final db = await openV12();
      await seedGoal(db, 'a', displayOrder: 0);
      await db.update(
          'goals', {'order_key': 9999.0, 'order_key_updated_at': null});
      final store = await storeOn(db);

      await store.applyUpsert(
        'goals',
        'goals:a',
        goalPayload(
          id: 'a',
          orderKey: 1.0,
          orderKeyStamp: '2026-08-06T09:00:00.000Z',
        ),
        DateTime.parse('2030-01-01T00:00:00.000Z').millisecondsSinceEpoch,
        now,
      );

      expect((await db.query('goals', where: "id = 'a'")).single['order_key'],
          1.0);
      await db.close();
    });

    test('THE DIVERGENCE FIX: a preserved position is re-dirtied for push',
        () async {
      // Whole-row LWW made the peer's record the winner, so the peer will never
      // look at our order_key again on its own. If the merged row were left
      // clean the two devices would show different orders forever.
      final db = await openV12();
      await seedGoal(db, 'a', displayOrder: 0);
      await db.update('goals', {
        'order_key': 9999.0,
        'order_key_updated_at': '2026-08-06T12:00:00.000Z',
      });
      final store = SyncLocalStore(db);

      await store.applyUpsert(
        'goals',
        'goals:a',
        goalPayload(
          id: 'a',
          orderKey: 1.0,
          orderKeyStamp: '2026-08-06T09:00:00.000Z',
        ),
        DateTime.parse('2030-01-01T00:00:00.000Z').millisecondsSinceEpoch,
        '2031-01-01T00:00:00.000Z',
      );

      final sync = (await db.query(PrivateDbSchema.syncStateTable,
              where: "record_name = 'goals:a'"))
          .single;
      expect(sync['dirty'], 1,
          reason: 'the merge must be pushed back, or the peer never learns it');
      final row = (await db.query('goals', where: "id = 'a'")).single;
      expect(row['updated_at'], '2031-01-01T00:00:00.000Z',
          reason: 'and it must be stamped LATER than the record it merged, or '
              'the peer rejects it on strict greater-than');
      await db.close();
    });

    test('an ordinary apply (nothing preserved) stays clean', () async {
      final db = await openV12();
      await seedGoal(db, 'a', displayOrder: 0);
      await db.update(
          'goals', {'order_key': 1.0, 'order_key_updated_at': null});
      final store = SyncLocalStore(db);

      await store.applyUpsert(
        'goals',
        'goals:a',
        goalPayload(
          id: 'a',
          orderKey: 7.0,
          orderKeyStamp: '2026-08-06T09:00:00.000Z',
        ),
        DateTime.parse('2030-01-01T00:00:00.000Z').millisecondsSinceEpoch,
        now,
      );

      final sync = (await db.query(PrivateDbSchema.syncStateTable,
              where: "record_name = 'goals:a'"))
          .single;
      expect(sync['dirty'], 0, reason: 'no merge happened — nothing to push');
      await db.close();
    });

    test('a brand-new habit from a peer keeps its position', () async {
      final db = await openV12();
      final store = await storeOn(db);

      await store.applyUpsert(
        'goals',
        'goals:new',
        goalPayload(
          id: 'new',
          orderKey: 42.0,
          orderKeyStamp: '2026-08-06T09:00:00.000Z',
        ),
        DateTime.parse('2030-01-01T00:00:00.000Z').millisecondsSinceEpoch,
        now,
      );

      expect((await db.query('goals', where: "id = 'new'")).single['order_key'],
          42.0);
      await db.close();
    });
  });
}
