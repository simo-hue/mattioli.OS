// v11 migration: `goals.target_effective_from` — the forward-only anchor for a
// quantitative target, the exact analogue of `verify_effective_from` (v7) for
// the verification rule. Same additive/idempotent properties as v7/v8:
// a plain nullable ADD COLUMN, guarded so a version round-trip can't wedge the
// DB, present identically on a fresh install and an upgraded one, and
// unconstrained so a value from a newer client round-trips.
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

  group('upgrade', () {
    test('adds goals.target_effective_from to a v10-shape goals table',
        () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      // A goals table as it existed at v10 (target present, anchor not).
      await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY, '
          'verify_effective_from TEXT, verify_conditions TEXT, target TEXT)');
      expect(await columnsOf(db, 'goals'),
          isNot(contains('target_effective_from')));

      await PrivateDbSchema.onUpgrade(db, 10, PrivateDbSchema.version);

      expect(await columnsOf(db, 'goals'), contains('target_effective_from'));
      await db.close();
    });

    test('re-running the v11 upgrade is a harmless no-op', () async {
      // A version round-trip (v11 → a downgrade stamps user_version back → v11)
      // must not raise "duplicate column name" and permanently wedge the DB.
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY, target TEXT)');
      await PrivateDbSchema.onUpgrade(db, 10, PrivateDbSchema.version);
      await PrivateDbSchema.onUpgrade(db, 10, PrivateDbSchema.version);

      expect(await columnsOf(db, 'goals'), contains('target_effective_from'));
      await db.close();
    });

    test('a v6 database migrates all the way through to v11', () async {
      // The realistic field case: `main` is at v6, so a device upgrading to this
      // build runs v7..v11 back to back in one open.
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY)');
      await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);

      final cols = await columnsOf(db, 'goals');
      expect(cols, contains('target_effective_from'));
      // The whole v7..v11 column set lands together.
      expect(
        cols,
        containsAll(<String>[
          'verify_effective_from',
          'verify_conditions',
          'target',
          'target_effective_from',
        ]),
      );
      await db.close();
    });
  });

  group('fresh install', () {
    test('onCreate builds goals with target_effective_from', () async {
      final db = await freshDb();
      expect(await columnsOf(db, 'goals'), contains('target_effective_from'));
      await db.close();
    });

    test('the column is unconstrained so a newer-client value round-trips',
        () async {
      final db = await freshDb();
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
        'target': '{"v":1,"dir":"atLeast","amount":80}',
        'target_effective_from': '2026-07-24',
        'created_at': now,
        'updated_at': now,
      });
      final rows =
          await db.query('goals', where: 'id = ?', whereArgs: ['g1']);
      expect(rows.first['target_effective_from'], '2026-07-24');
      await db.close();
    });
  });

  group('wiring', () {
    test('the schema version is 12', () {
      expect(PrivateDbSchema.version, 12);
    });
  });
}
