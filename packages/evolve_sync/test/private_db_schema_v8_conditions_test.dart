// v8 migration: goals.verify_conditions — the compound verifiable-habit column.
// Same properties as v7: it lands on an upgrading database and re-running the
// migration is a harmless no-op (not a "duplicate column name" that wedges open).
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Set<String>> goalsColumns(Database db) async => {
        for (final row in await db.rawQuery('PRAGMA table_info(goals)'))
          row['name'] as String,
      };

  test('_upgradeToV8 adds verify_conditions to a v7-shape goals table', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    // A goals table as it existed at v7 — has verify_effective_from, not verify_conditions.
    await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY, '
        'verify_unit TEXT, verify_effective_from TEXT)');
    expect(await goalsColumns(db), isNot(contains('verify_conditions')));

    await PrivateDbSchema.onUpgrade(db, 7, PrivateDbSchema.version);

    expect(await goalsColumns(db), contains('verify_conditions'));
    await db.close();
  });

  test('re-running the v8 upgrade is idempotent', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY, verify_unit TEXT)');
    await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);
    await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);
    expect(await goalsColumns(db), contains('verify_conditions'));
    await db.close();
  });

  test('a fresh install already has verify_conditions', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        onConfigure: PrivateDbSchema.onConfigure,
        onCreate: PrivateDbSchema.onCreate,
      ),
    );
    expect(await goalsColumns(db), contains('verify_conditions'));
    await db.close();
  });
}
