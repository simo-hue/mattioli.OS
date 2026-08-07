// The habit row actually reaches SQLite with its position.
//
// This closes the coverage gap that let the whole reorder feature be silently
// broken: EVERY reorder test asserts against `FakePrivateDataStore`, so they see
// the ids handed to `reorderGoals` and nothing else. Deleting `order_key` from
// the row builder left all 904 mobile tests green — while on a device every drag
// was discarded the moment the app relaunched, and the field-level LWW stamp
// that defends a drag against a peer was never written either.
//
// `PrivateLocalDatabase` opens through SQLCipher, whose native plugin does not
// exist in the test VM, so the row builder is a pure top-level function and is
// exercised here against the REAL schema on sqflite-ffi.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner-1';
  const now = '2026-06-01T00:00:00.000Z';

  Future<Database> openDb() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        onConfigure: PrivateDbSchema.onConfigure,
        onCreate: PrivateDbSchema.onCreate,
        onUpgrade: PrivateDbSchema.onUpgrade,
      ),
    );
    await db.insert(
      'profiles',
      {'id': owner, 'created_at': now, 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.delete('goals');
    return db;
  }

  Goal habit({double? orderKey, String? stamp}) => Goal(
        id: 'g1',
        title: 'Meditate',
        color: const Color(0xFF3B82F6),
        startDate: DateTime(2026, 6, 1),
        orderKey: orderKey,
        orderKeyUpdatedAt: stamp,
      );

  /// Writes the row the production path builds, through the real schema.
  Future<Map<String, Object?>> writeAndRead(Goal goal, Database db) async {
    final row = goalToRow(goal, 'fresh-id');
    await db.insert(
      'goals',
      {...row, 'user_id': owner, 'created_at': now, 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return (await db.query('goals', where: "id = 'g1'")).single;
  }

  test('THE GAP: order_key and its stamp actually reach the goals table',
      () async {
    final db = await openDb();

    final stored = await writeAndRead(
      habit(orderKey: 1536.0, stamp: '2026-08-06T12:00:00.000Z'),
      db,
    );

    expect(stored['order_key'], 1536.0,
        reason: 'without this column the drag is discarded on relaunch');
    expect(stored['order_key_updated_at'], '2026-08-06T12:00:00.000Z',
        reason: 'without the stamp a peer edit walks the habit back');
    await db.close();
  });

  test('a keyless habit round-trips as NULL, not as 0', () async {
    // 0 is a legal position that would sort the habit to the very top; NULL
    // means "unpositioned" and sorts it last via the fallback.
    final db = await openDb();

    final stored = await writeAndRead(habit(), db);

    expect(stored['order_key'], isNull);
    expect(stored['order_key_updated_at'], isNull);
    await db.close();
  });

  test('a NEGATIVE key survives — dropping at the top produces them', () async {
    final db = await openDb();

    final stored = await writeAndRead(
      habit(orderKey: -1024.0, stamp: now),
      db,
    );

    expect(stored['order_key'], -1024.0);
    await db.close();
  });

  test('the fractional value is not rounded to an integer', () async {
    // The column is REAL; storing it as INTEGER would collapse every midpoint
    // and reintroduce duplicate positions.
    final db = await openDb();

    final stored = await writeAndRead(habit(orderKey: 1536.5, stamp: now), db);

    expect(stored['order_key'], 1536.5);
    await db.close();
  });

  test('the row keeps its id rather than taking the fresh one', () async {
    final db = await openDb();
    final row = goalToRow(habit(orderKey: 1024.0), 'fresh-id');
    expect(row['id'], 'g1');
    await db.close();
  });
}
