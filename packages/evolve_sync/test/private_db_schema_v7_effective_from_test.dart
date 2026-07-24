// v7 migration: goals.verify_effective_from — the forward-only rule-edit anchor
// (D10). These pin the two properties the schema comments promise: the column
// lands on an upgrading database, and re-running the migration (a version
// round-trip: v7 → downgrade stamps user_version to 6 → v7) is a harmless no-op
// rather than a "duplicate column name" that would wedge every future open.
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

  test('_upgradeToV7 adds verify_effective_from to a v6-shape goals table',
      () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    // A goals table as it existed at v6 — no verify_effective_from column.
    await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY, verify_unit TEXT)');
    expect(await goalsColumns(db), isNot(contains('verify_effective_from')));

    await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);

    expect(await goalsColumns(db), contains('verify_effective_from'));
    await db.close();
  });

  test('re-running the v7 upgrade is idempotent (no duplicate-column throw)',
      () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute('CREATE TABLE goals (id TEXT PRIMARY KEY, verify_unit TEXT)');

    await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);
    // A version round-trip re-enters the same migration against a table that
    // already has the column — must not throw.
    await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);

    expect(await goalsColumns(db), contains('verify_effective_from'));
    await db.close();
  });

  test('a fresh install already has verify_effective_from', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        onConfigure: PrivateDbSchema.onConfigure,
        onCreate: PrivateDbSchema.onCreate,
      ),
    );
    expect(await goalsColumns(db), contains('verify_effective_from'));
    await db.close();
  });
}
