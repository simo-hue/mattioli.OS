// v10 migration: the four cumulative-numeric-macro-goal columns on
// `long_term_goals` — target_amount, target_unit, progress_amount and
// linked_goal_id (FK to goals, ON DELETE SET NULL).
//
// Same additive/idempotent properties as v7/v8, plus the FK-behaviour assertion
// that is the whole point of the feature: deleting the linked habit must SET
// NULL (un-link) the macro goal rather than CASCADE it away, and that SET NULL
// must mark the macro-goal row dirty so the un-link syncs.
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

  Future<Database> freshDb() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: PrivateDbSchema.version,
          onConfigure: PrivateDbSchema.onConfigure,
          onCreate: PrivateDbSchema.onCreate,
          singleInstance: false,
        ),
      );

  const macroCols = <String>[
    'target_amount',
    'target_unit',
    'progress_amount',
    'linked_goal_id',
  ];

  Future<void> seed(Database db) async {
    const now = '2026-07-24T10:00:00.000Z';
    await db.insert('profiles', {
      'id': 'u1',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('goals', {
      'id': 'h1',
      'user_id': 'u1',
      'title': 'Running (km)',
      'color': '#FFFFFF',
      'start_date': '2026-01-01',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('long_term_goals', {
      'id': 'm1',
      'user_id': 'u1',
      'title': 'Run 500 km this year',
      'status': 'active',
      'type': 'annual',
      'year': 2026,
      'target_amount': 500.0,
      'target_unit': 'kilometers',
      'linked_goal_id': 'h1',
      'created_at': now,
      'updated_at': now,
    });
  }

  group('upgrade', () {
    test('adds the four columns to a v9-shape long_term_goals table', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      // goals must exist first — linked_goal_id references it.
      await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY)');
      await db.execute('CREATE TABLE long_term_goals (id TEXT PRIMARY KEY, '
          'title TEXT, status TEXT, type TEXT, category_id TEXT)');
      for (final c in macroCols) {
        expect(await columnsOf(db, 'long_term_goals'), isNot(contains(c)));
      }

      await PrivateDbSchema.onUpgrade(db, 9, PrivateDbSchema.version);

      expect(await columnsOf(db, 'long_term_goals'), containsAll(macroCols));
      await db.close();
    });

    test('re-running the v10 upgrade is a harmless no-op', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY)');
      await db.execute('CREATE TABLE long_term_goals (id TEXT PRIMARY KEY, '
          'title TEXT, status TEXT, type TEXT)');
      await PrivateDbSchema.onUpgrade(db, 9, PrivateDbSchema.version);
      await PrivateDbSchema.onUpgrade(db, 9, PrivateDbSchema.version);

      expect(await columnsOf(db, 'long_term_goals'), containsAll(macroCols));
      await db.close();
    });

    test('a v6 database migrates all the way through to v10', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY)');
      await db.execute('CREATE TABLE long_term_goals (id TEXT PRIMARY KEY, '
          'title TEXT, status TEXT, type TEXT)');
      await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);

      expect(await columnsOf(db, 'long_term_goals'), containsAll(macroCols));
      await db.close();
    });
  });

  group('fresh install', () {
    test('already has the four macro-target columns', () async {
      final db = await freshDb();
      expect(await columnsOf(db, 'long_term_goals'), containsAll(macroCols));
      await db.close();
    });

    test('a fresh install and a migrated database agree on the shape', () async {
      final fresh = await freshDb();
      final freshCols = await columnsOf(fresh, 'long_term_goals');
      await fresh.close();

      final migrated = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await PrivateDbSchema.createCoreTables(migrated);
      // Drop only the three non-FK columns and let the migration re-add them:
      // SQLite refuses to DROP a column named in a foreign key, and
      // linked_goal_id references goals(id). Its parity is covered by the fresh
      // install + FK-behaviour tests instead.
      for (final c in const ['target_amount', 'target_unit', 'progress_amount']) {
        await migrated.execute('ALTER TABLE long_term_goals DROP COLUMN $c');
      }
      await PrivateDbSchema.onUpgrade(migrated, 9, PrivateDbSchema.version);

      expect(await columnsOf(migrated, 'long_term_goals'), freshCols);
      await migrated.close();
    });
  });

  group('linked_goal_id FK', () {
    test('deleting the linked habit SET-NULLs the macro goal, not deletes it',
        () async {
      final db = await freshDb();
      await seed(db);

      await db.delete('goals', where: 'id = ?', whereArgs: ['h1']);

      final macro =
          await db.query('long_term_goals', where: 'id = ?', whereArgs: ['m1']);
      // The goal survives — un-linked, not cascaded away.
      expect(macro, hasLength(1));
      expect(macro.first['linked_goal_id'], isNull);
      // Its numeric target is untouched by the un-link.
      expect(macro.first['target_amount'], 500.0);
      await db.close();
    });

    test('the SET NULL un-link marks the macro goal dirty for sync', () async {
      final db = await freshDb();
      await seed(db);
      // Simulate an already-synced state.
      await db.update(PrivateDbSchema.syncStateTable, {'dirty': 0},
          where: 'table_name = ?', whereArgs: ['long_term_goals']);

      await db.delete('goals', where: 'id = ?', whereArgs: ['h1']);

      final state = await db.query(
        PrivateDbSchema.syncStateTable,
        where: 'table_name = ? AND row_id = ?',
        whereArgs: ['long_term_goals', 'm1'],
      );
      // Without a dirty mark the un-link would never push and the two devices
      // would disagree about whether the goal is still linked.
      expect(state.first['dirty'], 1);
      expect(state.first['deleted'], 0);
      await db.close();
    });

    test('target_unit is unconstrained so a newer client value round-trips',
        () async {
      final db = await freshDb();
      await db.insert('profiles', {
        'id': 'u1',
        'created_at': '2026-07-24T10:00:00.000Z',
        'updated_at': '2026-07-24T10:00:00.000Z',
      });
      await db.insert('long_term_goals', {
        'id': 'm2',
        'user_id': 'u1',
        'title': 'Future unit goal',
        'status': 'active',
        'type': 'annual',
        'target_amount': 10.0,
        'target_unit': 'some_future_unit',
        'created_at': '2026-07-24T10:00:00.000Z',
        'updated_at': '2026-07-24T10:00:00.000Z',
      });
      final rows =
          await db.query('long_term_goals', where: 'id = ?', whereArgs: ['m2']);
      expect(rows.first['target_unit'], 'some_future_unit');
      await db.close();
    });
  });

  group('wiring', () {
    test('the schema version includes v10', () {
      // Pinned as a floor (like the v9 test) rather than an exact match so a
      // later additive version bump doesn't force-edit an unrelated test.
      expect(PrivateDbSchema.version, greaterThanOrEqualTo(10));
    });
  });
}
