// A second device must be able to re-key onto the canonical owner even when a
// BARE identity shell has already been minted for that id.
//
// `goal_category_settings.user_id` is UNIQUE, so the re-key's
// `UPDATE ... SET user_id = canonical` collides with any row that id already
// owns — SQLITE_CONSTRAINT, the whole transaction rolls back, and
// `SyncEngine.enable` throws. It throws again on every later attempt, because
// nothing removes the shell: iCloud sync is then wedged on that device forever.
//
// The shell is exactly what a read path that seeds (`_ensureProfile` behind
// `loadProfileRow`) mints for an owner id that owns no rows — the state a
// half-finished enable leaves behind.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const local = 'local-owner';
  const canonical = 'canonical-owner';
  const t0 = '2026-01-01T00:00:00.000Z';

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

  Future<void> seedIdentity(
    Database db,
    String id, {
    String? fullName,
    bool withGoal = false,
  }) async {
    await db.insert('profiles', {
      'id': id,
      'full_name': fullName,
      'created_at': t0,
      'updated_at': t0,
    });
    await db.insert('goal_category_settings', {
      'id': 'gcs-$id',
      'user_id': id,
      'mappings': '{}',
      'created_at': t0,
      'updated_at': t0,
    });
    if (withGoal) {
      await db.insert('goals', {
        'id': 'goal-$id',
        'user_id': id,
        'title': 'Read',
        'color': '#FFFFFF',
        'start_date': t0,
        'created_at': t0,
        'updated_at': t0,
      });
    }
  }

  test('re-key survives a bare identity shell already minted for the canonical '
      'owner', () async {
    final db = await openFresh();
    // The real user's data, under this device's own id.
    await seedIdentity(db, local, fullName: 'Simone', withGoal: true);
    // The shell: a profile + settings pair for the canonical id that owns no
    // data at all.
    await seedIdentity(db, canonical);

    await SyncLocalStore(db).reKeyOwner(local, canonical);

    // Everything unions under the canonical id...
    final goals = await db.query('goals');
    expect(goals.single['user_id'], canonical);
    // ...with exactly one settings row (the UNIQUE column that used to collide).
    final settings = await db.query('goal_category_settings');
    expect(settings, hasLength(1));
    expect(settings.single['user_id'], canonical);
    // ...and the user's REAL profile survives, not the shell's defaults.
    final profiles = await db.query('profiles');
    expect(profiles, hasLength(1));
    expect(profiles.single['id'], canonical);
    expect(profiles.single['full_name'], 'Simone');
    expect(await SyncLocalStore(db).foreignKeyCheck(), isEmpty);
    await db.close();
  });

  test('a canonical identity that owns real data is left alone', () async {
    // The reap must be limited to SHELLS. An id that owns rows is a real
    // identity (the canonical profile pulled from the peer, with data already
    // applied under it), and deleting its profile would take that data's FK
    // parent with it.
    final db = await openFresh();
    await seedIdentity(db, local, fullName: 'Simone', withGoal: true);
    await seedIdentity(db, canonical, fullName: 'Canonical', withGoal: true);

    await expectLater(
      SyncLocalStore(db).reKeyOwner(local, canonical),
      throwsA(anything),
      reason: 'two populated identities need a real merge, not a silent delete',
    );

    expect((await db.query('profiles')).length, 2,
        reason: 'the failed re-key rolls back, changing nothing');
    await db.close();
  });
}
