// Abandoned identity shells accumulate because `_open()` used to seed a
// profiles + goal_category_settings PAIR for the CURRENT owner id before the
// self-heal decided that id was wrong. A real user reached 3 identities on one
// device and 2 on the other, in lockstep with goal_category_settings (whose
// user_id is UNIQUE, so its count IS the number of identities ever seeded).
//
// The reap removes those shells. Its precondition — never touch an identity
// that owns data — is what makes it safe, and these tests exist mostly to pin
// that precondition rather than the happy path.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const now = '2026-07-20T00:00:00.000Z';
  const canonical = 'owner-canonical';

  Future<Database> openDb() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          onConfigure: PrivateDbSchema.onConfigure,
          onCreate: PrivateDbSchema.onCreate,
          onUpgrade: PrivateDbSchema.onUpgrade,
          singleInstance: false,
        ),
      );

  /// Seeds an identity the way `_ensureProfile` / `seedProfile` does: a
  /// profiles + goal_category_settings PAIR.
  Future<void> seedIdentity(Database db, String id) async {
    await db.insert('profiles', {
      'id': id,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('goal_category_settings', {
      'id': 'gcs-$id',
      'user_id': id,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> addGoals(Database db, String owner, int n) async {
    for (var i = 0; i < n; i++) {
      await db.insert('long_term_goals', {
        'id': '$owner-g$i',
        'user_id': owner,
        'title': 'goal $i',
        'status': 'active',
        'type': 'annual',
        'year': 2026,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  test('reaps empty shells and leaves the canonical identity alone', () async {
    // The exact production shape: 3 identities, all data under one of them.
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedIdentity(db, canonical);
    await seedIdentity(db, 'orphan-1');
    await seedIdentity(db, 'orphan-2');
    await addGoals(db, canonical, 3487);

    final reaped = await store.reapOrphanIdentities(canonical);

    expect(reaped.toSet(), {'orphan-1', 'orphan-2'});
    expect((await db.query('profiles')).length, 1);
    expect((await db.query('goal_category_settings')).length, 1,
        reason: 'the shell settings row goes with its profile');
    expect((await db.query('long_term_goals')).length, 3487,
        reason: 'user data is never touched by a reap');
    await db.close();
  });

  test('REFUSES to reap an identity that owns data', () async {
    // The load-bearing precondition. An orphan holding rows needs a migration
    // and a human decision, never a silent delete.
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedIdentity(db, canonical);
    await seedIdentity(db, 'has-data');
    await addGoals(db, 'has-data', 12);

    final reaped = await store.reapOrphanIdentities(canonical);

    expect(reaped, isEmpty);
    expect((await db.query('profiles')).length, 2);
    expect((await db.query('long_term_goals')).length, 12);
    await db.close();
  });

  test('a device whose ACTIVE owner is transiently stale cannot reap the real '
      'identity', () async {
    // The re-key writes the database before the Keychain, so a device can
    // briefly consider an old id active. Passing that stale id as `canonical`
    // must NOT delete the identity that owns everything — the precondition is
    // the second thing standing in the way.
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedIdentity(db, 'stale-active');
    await seedIdentity(db, canonical);
    await addGoals(db, canonical, 500);

    final reaped = await store.reapOrphanIdentities('stale-active');

    expect(reaped, isEmpty, reason: 'the data-owning identity is protected');
    expect((await db.query('profiles')).length, 2);
    expect((await db.query('long_term_goals')).length, 500);
    await db.close();
  });

  test('the reap does NOT propagate — no tombstone is queued', () async {
    // Local-only by design: one device's identity verdict must never delete
    // rows on another, because a device can transiently disagree about which
    // id is active.
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedIdentity(db, canonical);
    await seedIdentity(db, 'orphan-1');
    await addGoals(db, canonical, 5);
    // Everything already acknowledged, as after a healthy sync.
    for (final t in PrivateDbSchema.syncedTables) {
      for (final r in await db.query(t, columns: ['id'])) {
        await store.markSynced('$t:${r['id']}', now, now);
      }
    }

    await store.reapOrphanIdentities(canonical);

    final d = await store.diagnostics();
    expect(d.totalPending, 0,
        reason: 'a reap must queue nothing for upload — not an upsert and '
            'certainly not a tombstone');
    expect(d.pendingDeletesByTable, isEmpty);
    await db.close();
  });

  test('the preserved sync_state stops the cloud copy resurrecting the row',
      () async {
    // The reap keeps each deleted record's bookkeeping at its original stamp so
    // the engine's LWW treats a re-delivered cloud copy as not-newer. Without
    // this a full re-fetch would simply put the orphan back.
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedIdentity(db, canonical);
    await seedIdentity(db, 'orphan-1');
    await store.markSynced('profiles:orphan-1', now, now);

    await store.reapOrphanIdentities(canonical);

    final state = await store.stateOf('profiles:orphan-1');
    expect(state, isNotNull,
        reason: 'the bookkeeping must survive the row it described');
    expect(state!.deleted, isFalse,
        reason: 'a tombstone here would propagate the deletion');
    expect(state.updatedAt, now,
        reason: 'the original stamp is what makes the cloud copy lose LWW');
    await db.close();
  });

  test('is idempotent — a second run finds nothing left to do', () async {
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedIdentity(db, canonical);
    await seedIdentity(db, 'orphan-1');
    await addGoals(db, canonical, 2);

    expect((await store.reapOrphanIdentities(canonical)).length, 1);
    expect(await store.reapOrphanIdentities(canonical), isEmpty);
    expect((await db.query('profiles')).length, 1);
    await db.close();
  });

  test('diagnostics report a clean single identity afterwards', () async {
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedIdentity(db, canonical);
    await seedIdentity(db, 'orphan-1');
    await seedIdentity(db, 'orphan-2');
    await addGoals(db, canonical, 10);

    final before = await store.diagnostics(owner: canonical);
    expect(before.distinctOwnerCount, 3);
    expect(before.orphanedRows, 4); // 2 profiles + 2 settings shells

    await store.reapOrphanIdentities(canonical);

    final after = await store.diagnostics(owner: canonical);
    expect(after.distinctOwnerCount, 1);
    expect(after.orphanedRows, 0);
    expect(after.localRowsByTable['long_term_goals'], 10);
    await db.close();
  });
}
