// Diagnostics are the surface a user reads when sync has silently stalled, so
// these tests pin the two properties that make it trustworthy: the per-table
// counts must reflect what is ACTUALLY pending (not an aggregate that can be
// stamped optimistically), and a quarantined record must never be reported as a
// transient error — the two demand completely different user action.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const now = '2026-07-20T00:00:00.000Z';
  const owner = 'owner-1';

  // singleInstance: false — the default shares ONE `:memory:` handle across
  // every openDatabase in the process, so tests leak rows into each other.
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

  Future<void> seedProfile(Database db) => db.insert(
        'profiles',
        {'id': owner, 'created_at': now, 'updated_at': now},
      );

  Future<void> addMacroGoal(Database db, String id) => db.insert(
        'long_term_goals',
        {
          'id': id,
          'user_id': owner,
          'title': 'goal $id',
          'status': 'active',
          'type': 'annual',
          'year': 2026,
          'created_at': now,
          'updated_at': now,
        },
      );

  Future<void> addHabit(Database db, String id) => db.insert(
        'goals',
        {
          'id': id,
          'user_id': owner,
          'title': 'habit $id',
          'color': '#FFFFFF',
          'start_date': '2026-01-01',
          'created_at': now,
          'updated_at': now,
        },
      );

  test('counts local rows and pending pushes per table', () async {
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedProfile(db);
    await addHabit(db, 'h1');
    for (var i = 0; i < 5; i++) {
      await addMacroGoal(db, 'g$i');
    }

    final d = await store.diagnostics();

    expect(d.localRowsByTable['long_term_goals'], 5);
    expect(d.localRowsByTable['goals'], 1);
    // The write triggers marked every inserted row dirty.
    expect(d.pendingByTable['long_term_goals'], 5);
    expect(d.pendingByTable['goals'], 1);
    expect(d.pendingByTable['profiles'], 1);
    expect(d.isFullySynced, isFalse);
    await db.close();
  });

  test('a partial push leaves exactly the unsent tables pending — the '
      'signal that distinguishes a stalled push from a healthy one', () async {
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedProfile(db);
    await addHabit(db, 'h1');
    for (var i = 0; i < 3; i++) {
      await addMacroGoal(db, 'g$i');
    }

    // Simulate the reported bug: the early batch (profile + habits) is
    // acknowledged by CloudKit, then the push dies before reaching macro goals.
    await store.markSynced('profiles:$owner', now, now);
    await store.markSynced('goals:h1', now, now);

    final d = await store.diagnostics();

    expect(d.pendingByTable['goals'], isNull, reason: 'habits went through');
    expect(d.pendingByTable['profiles'], isNull);
    expect(d.pendingByTable['long_term_goals'], 3,
        reason: 'macro goals never left the device');
    expect(d.totalPending, 3);
    expect(d.isFullySynced, isFalse);
    await db.close();
  });

  test('tombstones are counted apart from upserts', () async {
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedProfile(db);
    await addMacroGoal(db, 'g1');
    await store.markSynced('long_term_goals:g1', now, now);
    await db.delete('long_term_goals', where: 'id = ?', whereArgs: ['g1']);

    final d = await store.diagnostics();

    expect(d.pendingDeletesByTable['long_term_goals'], 1);
    expect(d.pendingByTable['long_term_goals'], isNull);
    expect(d.localRowsByTable['long_term_goals'], 0);
    await db.close();
  });

  test('a record that will retry is reported apart from one that will not',
      () async {
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedProfile(db);
    await addMacroGoal(db, 'g1');

    // g1: push failed but the row is still dirty ⇒ the next sync retries it.
    await store.markError('long_term_goals:g1', 'CKError 7 rate limited');
    // g2: a PULLED record this build cannot store — no local row, so
    // quarantineRecord takes its INSERT branch (dirty = 0) and nothing will
    // retry it on its own.
    await store.quarantineRecord(
      'long_term_goals:g2',
      'long_term_goals',
      'g2',
      'row rejected by this schema (sqlite 19)',
    );

    final d = await store.diagnostics();

    expect(d.errorsByReason, {'CKError 7 rate limited': 1});
    expect(d.parkedByReason, {'row rejected by this schema (sqlite 19)': 1});
    expect(d.totalErrors, 1);
    expect(d.totalParked, 1);
    expect(d.isFullySynced, isFalse);
    await db.close();
  });

  test('identical errors are grouped so one rate-limit burst reads as a '
      'count, not a wall of rows', () async {
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedProfile(db);
    for (var i = 0; i < 4; i++) {
      await addMacroGoal(db, 'g$i');
      await store.markError('long_term_goals:g$i', 'CKError 7 rate limited');
    }

    final d = await store.diagnostics();

    expect(d.errorsByReason.length, 1);
    expect(d.errorsByReason['CKError 7 rate limited'], 4);
    await db.close();
  });

  test('isFullySynced only once nothing is pending, errored or parked',
      () async {
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedProfile(db);
    await addMacroGoal(db, 'g1');
    await store.markSynced('profiles:$owner', now, now);
    await store.markSynced('long_term_goals:g1', now, now);

    final d = await store.diagnostics();

    expect(d.totalPending, 0);
    expect(d.totalErrors, 0);
    expect(d.totalParked, 0);
    expect(d.isFullySynced, isTrue);
    expect(d.localRowsByTable['long_term_goals'], 1);
    await db.close();
  });

  test('toReport renders every synced table, including empty ones', () async {
    final db = await openDb();
    final store = SyncLocalStore(db);
    await seedProfile(db);
    await addMacroGoal(db, 'g1');

    final report = (await store.diagnostics()).toReport();

    for (final t in PrivateDbSchema.syncedTables) {
      expect(report, contains(t),
          reason: 'a table missing from the report reads as "no problem there"');
    }
    expect(report, contains('change token: none'));
    await db.close();
  });
}
