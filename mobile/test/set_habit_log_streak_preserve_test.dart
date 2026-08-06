// The DATABASE half of the absent-goal streak fix.
//
// `setHabitLog` writes with `ConflictAlgorithm.replace` (INSERT OR REPLACE),
// which rewrites the WHOLE row. So "leave the streak alone" cannot be done by
// omitting the column — the stored value has to be READ BACK and re-written.
// That makes the `columns: [... 'streak']` list load-bearing, and it is
// invisible everywhere else: dropping 'streak' from it leaves the entire suite
// green while silently zeroing every preserved streak.
//
// `PrivateLocalDatabase` opens through SQLCipher, whose native plugin does not
// exist in the Flutter test VM (`openDatabase` throws MissingPluginException),
// so the method itself cannot be driven from a test. `readExistingHabitLog` is
// therefore split out to take a `DatabaseExecutor`, and these tests run it
// against the REAL schema on a plain sqflite-ffi database —
// `sqflite_sqlcipher` and `sqflite_common_ffi` both re-export
// `package:sqflite_common/sqlite_api.dart`, so the types are identical.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner-1';
  const goalId = 'goal-A';
  const now = '2026-06-01T00:00:00.000Z';

  Future<Database> openDb() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: PrivateDbSchema.onCreate,
        onUpgrade: PrivateDbSchema.onUpgrade,
      ),
    );
    await db.insert('profiles',
        {'id': owner, 'created_at': now, 'updated_at': now});
    await db.insert('goals', {
      'id': goalId,
      'user_id': owner,
      'title': 'Meditate',
      'color': '#3B82F6',
      'start_date': '2026-06-01T00:00:00.000Z',
      'created_at': now,
      'updated_at': now,
    });
    return db;
  }

  Future<void> seedLog(Database db,
      {required String date, required String status, required int? streak}) {
    return db.insert('goal_logs', {
      'id': 'log-$date',
      'user_id': owner,
      'goal_id': goalId,
      'date': date,
      'status': status,
      'streak': streak,
      'created_at': now,
      'updated_at': now,
    });
  }

  test('an unknown streak resolves to the value already stored', () async {
    final db = await openDb();
    await seedLog(db, date: '2026-06-10', status: 'done', streak: 40);

    final resolved = await readExistingHabitLog(
      db,
      goalId: goalId,
      date: '2026-06-10',
      requestedStreak: null,
    );

    expect(resolved.streak, 40,
        reason: 'null means "unknown — keep what is stored", never zero');
    expect(resolved.id, 'log-2026-06-10',
        reason: 'the existing row is UPDATED, not duplicated');
    expect(resolved.createdAt, now, reason: 'the row keeps its original age');
    await db.close();
  });

  test('an unknown streak on a row that does not exist resolves to 0',
      () async {
    final db = await openDb();

    final resolved = await readExistingHabitLog(
      db,
      goalId: goalId,
      date: '2026-06-11',
      requestedStreak: null,
    );

    expect(resolved.streak, 0, reason: 'nothing to preserve');
    expect(resolved.id, isNull, reason: 'the caller must mint a fresh id');
    expect(resolved.createdAt, isNull);
    await db.close();
  });

  test('a NULL streak column resolves to 0 rather than throwing', () async {
    // The column is nullable in the real schema; a row written by an older
    // build — or by a peer over sync — can hold NULL.
    final db = await openDb();
    await seedLog(db, date: '2026-06-12', status: 'done', streak: null);

    final resolved = await readExistingHabitLog(
      db,
      goalId: goalId,
      date: '2026-06-12',
      requestedStreak: null,
    );

    expect(resolved.streak, 0);
    await db.close();
  });

  test('a known streak overrides whatever is stored, including a sign flip',
      () async {
    final db = await openDb();
    await seedLog(db, date: '2026-06-13', status: 'done', streak: 40);

    final resolved = await readExistingHabitLog(
      db,
      goalId: goalId,
      date: '2026-06-13',
      requestedStreak: -1,
    );

    expect(resolved.streak, -1,
        reason: 'a computed streak always wins over the stored one');
    await db.close();
  });

  test('an explicit 0 is honoured, not mistaken for unknown', () async {
    final db = await openDb();
    await seedLog(db, date: '2026-06-14', status: 'done', streak: 9);

    final resolved = await readExistingHabitLog(
      db,
      goalId: goalId,
      date: '2026-06-14',
      requestedStreak: 0,
    );

    expect(resolved.streak, 0);
    await db.close();
  });

  test('another habit-day\'s streak is never picked up', () async {
    final db = await openDb();
    await seedLog(db, date: '2026-06-15', status: 'done', streak: 99);
    await seedLog(db, date: '2026-06-16', status: 'done', streak: 3);

    final resolved = await readExistingHabitLog(
      db,
      goalId: goalId,
      date: '2026-06-16',
      requestedStreak: null,
    );

    expect(resolved.streak, 3, reason: 'the WHERE clause must match the date');
    await db.close();
  });
}
