// `profiles` is the ON DELETE CASCADE parent of every synced table, so a pulled
// `profiles` tombstone applied with foreign keys live deletes the user's ENTIRE
// database — and each cascaded row fires its own delete trigger, marking the
// wipe dirty so it PROPAGATES to every other device. One stale tombstone would
// take out every copy the user has.
//
// These tests pin the guard at the scale it actually matters: a real user's
// 3,487 macro goals.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:evolve_sync/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const now = '2026-07-20T00:00:00.000Z';
  const owner = 'owner-1';

  Future<Database> openDb() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          // onConfigure turns foreign_keys ON for the whole connection — the
          // production setting, and the thing that made this dangerous.
          onConfigure: PrivateDbSchema.onConfigure,
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
          singleInstance: false,
        ),
      );

  Future<void> seed(Database db, {int goals = 20, int macros = 50}) async {
    await db.insert(
      'profiles',
      {'id': owner, 'created_at': now, 'updated_at': now},
    );
    await db.insert('macro_goal_categories', {
      'id': 'cat-1',
      'user_id': owner,
      'name': 'Health',
      'color': '#FFFFFF',
      'created_at': now,
      'updated_at': now,
    });
    for (var i = 0; i < goals; i++) {
      await db.insert('goals', {
        'id': 'h$i',
        'user_id': owner,
        'title': 'habit $i',
        'color': '#FFFFFF',
        'start_date': '2026-01-01',
        'created_at': now,
        'updated_at': now,
      });
    }
    for (var i = 0; i < macros; i++) {
      await db.insert('long_term_goals', {
        'id': 'g$i',
        'user_id': owner,
        'title': 'goal $i',
        'status': 'active',
        'type': 'annual',
        'year': 2026,
        'category_id': 'cat-1',
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  test('a pulled profiles tombstone does NOT cascade-delete the database',
      () async {
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seed(db, macros: 3487);

    // The catastrophic case: a stale/erroneous profiles tombstone arrives.
    await store.applyDelete('profiles', owner, 'profiles:$owner', now, now);

    // The profile row itself is gone — that IS what the tombstone said.
    expect((await db.query('profiles')).length, 0);
    // ...and NOTHING else was touched. Before the FK guard this was 0/0/0.
    expect((await db.query('long_term_goals')).length, 3487,
        reason: "a tombstone means 'this record is gone', never 'and every "
            "row that referenced it'");
    expect((await db.query('goals')).length, 20);
    expect((await db.query('macro_goal_categories')).length, 1);
    await db.close();
  });

  test('the non-cascade is not silently re-marked dirty for propagation',
      () async {
    // The second half of the danger: cascaded deletes fire their own triggers,
    // so the wipe would be queued for upload and destroy the peers too.
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seed(db, macros: 100);
    // Everything starts clean, as it would after a successful sync.
    for (final t in PrivateDbSchema.syncedTables) {
      for (final r in await db.query(t, columns: ['id'])) {
        await store.markSynced('$t:${r['id']}', now, now);
      }
    }

    await store.applyDelete('profiles', owner, 'profiles:$owner', now, now);

    final d = await store.diagnostics();
    expect(d.pendingDeletesByTable['long_term_goals'], isNull,
        reason: 'no cascaded tombstones may be queued for upload');
    expect(d.pendingDeletesByTable['goals'], isNull);
    await db.close();
  });

  test('a category tombstone does not strip category_id from macro goals',
      () async {
    // long_term_goals.category_id is ON DELETE SET NULL — the quieter version
    // of the same bug.
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seed(db, macros: 10);

    await store.applyDelete(
        'macro_goal_categories', 'cat-1', 'macro_goal_categories:cat-1', now, now);

    final rows = await db.query('long_term_goals');
    expect(rows.length, 10);
    expect(rows.every((r) => r['category_id'] == 'cat-1'), isTrue,
        reason: 'the association survives; only the category row was deleted');
    await db.close();
  });

  test('foreign keys are restored after the delete', () async {
    // The guard toggles a CONNECTION-wide pragma; leaving it off would silently
    // disable integrity for every subsequent local write.
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seed(db, macros: 1);

    await store.applyDelete('long_term_goals', 'g0', 'long_term_goals:g0', now, now);

    final pragma = await db.rawQuery('PRAGMA foreign_keys');
    expect(pragma.first.values.first, 1);
    await db.close();
  });

  test('a batch carrying a parent tombstone AND child upserts keeps the '
      'children', () async {
    // Sorting by table alone put a `profiles` tombstone at priority 0 — ahead of
    // the child upserts in the same batch. Deletions now sort last, so the
    // children land while their parent still exists.
    //
    // Both this ordering and the FK guard independently save the children here;
    // that redundancy is the point. The ordering makes the apply correct on its
    // own terms rather than leaving `PRAGMA foreign_keys = OFF` as the single
    // thing standing between a routine tombstone and a wiped database.
    final cloud = FakeCloudKitBridge();
    final crypto = SyncCrypto();
    final key = crypto.generateKey();

    // Zone holds: goals owned by `owner`, plus a tombstone for `owner`'s
    // profile — the shape an identity reconcile produces.
    await cloud.saveRecords([
      CloudRecord(
        recordName: 'profiles:$owner',
        tableName: 'profiles',
        updatedAtMs: DateTime.parse(now).millisecondsSinceEpoch + 1000,
        deleted: true,
      ),
      for (var i = 0; i < 5; i++)
        CloudRecord(
          recordName: 'long_term_goals:g$i',
          tableName: 'long_term_goals',
          updatedAtMs: DateTime.parse(now).millisecondsSinceEpoch,
          deleted: false,
          payload: crypto.encryptJson({
            'id': 'g$i',
            'user_id': owner,
            'title': 'goal $i',
            'status': 'active',
            'type': 'annual',
            'year': 2026,
            'created_at': now,
            'updated_at': now,
          }, key),
        ),
    ]);

    final db = await openDb();
    // The receiving device already holds the profile, so the tombstone has
    // something to delete and the children have a parent to attach to.
    await db.insert(
      'profiles',
      {'id': owner, 'created_at': now, 'updated_at': now},
    );
    final store = SyncLocalStore(db);
    await SyncEngine(store: store, bridge: cloud, crypto: crypto).syncNow(key);

    expect((await db.query('long_term_goals')).length, 5,
        reason: 'the child upserts must survive the parent tombstone');
    expect((await db.query('profiles')).length, 0,
        reason: 'the tombstone still did its own job');
    await db.close();
  });
}
