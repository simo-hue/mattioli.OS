// v9 migration: `goals.target` (the quantitative-target JSON envelope) and the
// new `goal_progress` table holding one accumulated number per habit-day.
//
// Same additive/idempotent properties as v7 and v8, plus the two that are new
// here because v9 introduces a synced TABLE rather than just a column: the
// dirty/tombstone triggers must exist for it (or its rows would never push),
// and its id must be deterministic (or two devices mint rival rows for one
// habit-day and the natural-key merge deletes one of them).
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Set<String>> columnsOf(Database db, String table) async => {
        for (final row in await db.rawQuery('PRAGMA table_info($table)'))
          row['name'] as String,
      };

  Future<Set<String>> objectsOf(Database db, String type) async => {
        for (final row in await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type = '$type'"))
          row['name'] as String,
      };

  Future<Database> freshDb() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          onConfigure: PrivateDbSchema.onConfigure,
          onCreate: PrivateDbSchema.onCreate,
          singleInstance: false,
        ),
      );

  Future<void> seedGoal(Database db) async {
    const now = '2026-07-24T10:00:00.000Z';
    await db.insert('profiles', {
      'id': 'u1',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('goals', {
      'id': 'g1',
      'user_id': 'u1',
      'title': 'Push-ups',
      'color': '#FFFFFF',
      'start_date': '2026-07-01',
      'created_at': now,
      'updated_at': now,
    });
  }

  group('upgrade', () {
    test('adds goals.target to a v8-shape goals table', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      // A goals table as it existed at v8.
      await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY, '
          'verify_unit TEXT, verify_effective_from TEXT, verify_conditions TEXT)');
      expect(await columnsOf(db, 'goals'), isNot(contains('target')));

      await PrivateDbSchema.onUpgrade(db, 8, PrivateDbSchema.version);

      expect(await columnsOf(db, 'goals'), contains('target'));
      await db.close();
    });

    test('creates goal_progress with its index and sync triggers', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY)');
      expect(await objectsOf(db, 'table'), isNot(contains('goal_progress')));

      await PrivateDbSchema.onUpgrade(db, 8, PrivateDbSchema.version);

      expect(await objectsOf(db, 'table'), contains('goal_progress'));
      expect(await objectsOf(db, 'index'),
          contains('idx_goal_progress_user_date'));
      // Without these the table would exist but never sync — rows would be
      // written locally and silently never pushed.
      expect(
        await objectsOf(db, 'trigger'),
        containsAll(<String>[
          'goal_progress_sync_ai',
          'goal_progress_sync_au',
          'goal_progress_sync_ad',
        ]),
      );
      await db.close();
    });

    test('re-running the v9 upgrade is a harmless no-op', () async {
      // A version round-trip (v9 → a downgrade stamps user_version back → v9)
      // must not raise "duplicate column name" / "table already exists" and
      // permanently wedge every future open.
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY)');
      await PrivateDbSchema.onUpgrade(db, 8, PrivateDbSchema.version);
      await PrivateDbSchema.onUpgrade(db, 8, PrivateDbSchema.version);

      expect(await columnsOf(db, 'goals'), contains('target'));
      expect(await objectsOf(db, 'table'), contains('goal_progress'));
      await db.close();
    });

    test('a v6 database migrates all the way through to v9', () async {
      // The realistic field case: `main` is at v6, so a device upgrading to this
      // build runs v7, v8 and v9 back to back in one open.
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY)');
      await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);

      expect(
        await columnsOf(db, 'goals'),
        containsAll(<String>[
          'verify_effective_from',
          'verify_conditions',
          'target',
        ]),
      );
      expect(await objectsOf(db, 'table'), contains('goal_progress'));
      await db.close();
    });
  });

  group('fresh install', () {
    test('already has goals.target and goal_progress', () async {
      final db = await freshDb();
      expect(await columnsOf(db, 'goals'), contains('target'));
      expect(
        await columnsOf(db, 'goal_progress'),
        containsAll(<String>[
          'id',
          'user_id',
          'goal_id',
          'date',
          'amount',
          'source',
          'created_at',
          'updated_at',
        ]),
      );
      await db.close();
    });

    test('a fresh install and a migrated database agree on the shape', () async {
      final fresh = await freshDb();
      final freshCols = await columnsOf(fresh, 'goal_progress');
      final freshGoals = await columnsOf(fresh, 'goals');
      await fresh.close();

      final migrated = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await PrivateDbSchema.createCoreTables(migrated);
      await migrated.execute('DROP TABLE goal_progress');
      await migrated.execute('ALTER TABLE goals DROP COLUMN target');
      await PrivateDbSchema.onUpgrade(migrated, 8, PrivateDbSchema.version);

      expect(await columnsOf(migrated, 'goal_progress'), freshCols);
      expect(await columnsOf(migrated, 'goals'), freshGoals);
      await migrated.close();
    });
  });

  group('goal_progress rows', () {
    test('a write marks the row dirty for push', () async {
      final db = await freshDb();
      await seedGoal(db);

      await db.insert('goal_progress', {
        'id': PrivateDbSchema.goalProgressId('g1', '2026-07-24'),
        'user_id': 'u1',
        'goal_id': 'g1',
        'date': '2026-07-24',
        'amount': 40.0,
        'source': 'manual',
        'created_at': '2026-07-24T10:00:00.000Z',
        'updated_at': '2026-07-24T10:00:00.000Z',
      });

      final state = await db.query(
        PrivateDbSchema.syncStateTable,
        where: 'table_name = ?',
        whereArgs: ['goal_progress'],
      );
      expect(state, hasLength(1));
      expect(state.first['record_name'], 'goal_progress:g1:2026-07-24');
      expect(state.first['dirty'], 1);
      expect(state.first['deleted'], 0);
      await db.close();
    });

    test('a delete leaves a tombstone', () async {
      final db = await freshDb();
      await seedGoal(db);
      final id = PrivateDbSchema.goalProgressId('g1', '2026-07-24');
      await db.insert('goal_progress', {
        'id': id,
        'user_id': 'u1',
        'goal_id': 'g1',
        'date': '2026-07-24',
        'amount': 40.0,
        'source': 'manual',
        'created_at': '2026-07-24T10:00:00.000Z',
        'updated_at': '2026-07-24T10:00:00.000Z',
      });
      await db.delete('goal_progress', where: 'id = ?', whereArgs: [id]);

      final state = await db.query(
        PrivateDbSchema.syncStateTable,
        where: 'table_name = ?',
        whereArgs: ['goal_progress'],
      );
      expect(state.first['deleted'], 1);
      expect(state.first['dirty'], 1);
      await db.close();
    });

    test('one row per habit-day is enforced', () async {
      final db = await freshDb();
      await seedGoal(db);
      Map<String, Object?> row(String id) => {
            'id': id,
            'user_id': 'u1',
            'goal_id': 'g1',
            'date': '2026-07-24',
            'amount': 40.0,
            'source': 'manual',
            'created_at': '2026-07-24T10:00:00.000Z',
            'updated_at': '2026-07-24T10:00:00.000Z',
          };
      await db.insert('goal_progress', row('a'));
      await expectLater(
        db.insert('goal_progress', row('b')),
        throwsA(isA<DatabaseException>()),
      );
      await db.close();
    });

    test('deleting the habit cascades its progress away', () async {
      final db = await freshDb();
      await seedGoal(db);
      await db.insert('goal_progress', {
        'id': PrivateDbSchema.goalProgressId('g1', '2026-07-24'),
        'user_id': 'u1',
        'goal_id': 'g1',
        'date': '2026-07-24',
        'amount': 40.0,
        'source': 'manual',
        'created_at': '2026-07-24T10:00:00.000Z',
        'updated_at': '2026-07-24T10:00:00.000Z',
      });

      await db.delete('goals', where: 'id = ?', whereArgs: ['g1']);

      expect(await db.query('goal_progress'), isEmpty);
      // The cascade must emit its own tombstone, or the peer keeps the row.
      final state = await db.query(
        PrivateDbSchema.syncStateTable,
        where: 'table_name = ? AND deleted = 1',
        whereArgs: ['goal_progress'],
      );
      expect(state, hasLength(1));
      await db.close();
    });

    test('source is unconstrained so a newer client value round-trips', () async {
      // Deliberate policy, matching verify_provider: a rejected row would be
      // quarantined and the user's number would vanish until they upgrade.
      final db = await freshDb();
      await seedGoal(db);
      await db.insert('goal_progress', {
        'id': PrivateDbSchema.goalProgressId('g1', '2026-07-25'),
        'user_id': 'u1',
        'goal_id': 'g1',
        'date': '2026-07-25',
        'amount': 12.0,
        'source': 'some_future_wearable',
        'created_at': '2026-07-25T10:00:00.000Z',
        'updated_at': '2026-07-25T10:00:00.000Z',
      });
      final rows = await db.query('goal_progress', where: 'date = ?', whereArgs: ['2026-07-25']);
      expect(rows.first['source'], 'some_future_wearable');
      await db.close();
    });
  });

  group('wiring', () {
    test('goal_progress is a synced table', () async {
      expect(PrivateDbSchema.syncedTables, contains('goal_progress'));
    });

    test('the id is deterministic, so two devices cannot mint rival rows', () {
      expect(PrivateDbSchema.goalProgressId('g1', '2026-07-24'),
          'g1:2026-07-24');
      expect(PrivateDbSchema.goalProgressId('g1', '2026-07-24'),
          PrivateDbSchema.goalProgressId('g1', '2026-07-24'));
      expect(PrivateDbSchema.goalProgressId('g2', '2026-07-24'),
          isNot(PrivateDbSchema.goalProgressId('g1', '2026-07-24')));
    });

    test('the schema version is at least 9', () {
      // Pinned deliberately: the version drives the sync engine's re-fetch of
      // records it previously quarantined, so bumping the schema without
      // bumping this constant silently strands every peer's goal_progress rows.
      // (v10 added the cumulative-macro-goal columns; goal_progress arrived at
      // v9, so any version >= 9 satisfies this table's re-fetch requirement.)
      expect(PrivateDbSchema.version, greaterThanOrEqualTo(9));
    });
  });
}
