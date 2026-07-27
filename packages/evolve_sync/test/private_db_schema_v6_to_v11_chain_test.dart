// The FULL v6 → v11 upgrade chain, in ONE open, with real rows present.
//
// Why this exists: every other migration test here exercises a SINGLE leg
// against a stub table ("a goals table as it existed at v8" = four columns and
// no data). That proves each ALTER runs; it does not prove the five legs
// compose, and it cannot catch the failure that actually costs a user their
// history — a leg that rebuilds a table (SQLite cannot ALTER a CHECK
// constraint, so rebuild is the only option) and silently drops rows, or drops
// the dirty/tombstone triggers so the table exists but never syncs again.
//
// This is the exact jump the field will take: shipped devices are on v6 and the
// next release is v11, so all five legs run back-to-back inside one
// `openDatabase`. Until it ships, this test is the only thing standing in for
// that. It is NOT a substitute for running it on a real SQLCipher file —
// encryption is orthogonal to schema logic and only a device proves that half.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const t0 = '2026-07-01T09:00:00.000Z';

  Future<Set<String>> columnsOf(Database db, String table) async => {
        for (final row in await db.rawQuery('PRAGMA table_info($table)'))
          row['name'] as String,
      };

  Future<Set<String>> objectsOf(Database db, String type) async => {
        for (final row in await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type = '$type'"))
          row['name'] as String,
      };

  /// A v6-shaped database: the pre-v7 core tables, i.e. everything EXCEPT
  /// `verify_effective_from` (v7), `verify_conditions` (v8), `target` +
  /// `goal_progress` (v9), the macro-goal numeric columns (v10) and
  /// `target_effective_from` (v11).
  Future<Database> openV6WithData() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
CREATE TABLE profiles (
  id TEXT PRIMARY KEY,
  full_name TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''');
    await db.execute('''
CREATE TABLE goals (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  color TEXT NOT NULL,
  icon TEXT,
  frequency_days TEXT,
  start_date TEXT NOT NULL,
  end_date TEXT,
  display_order INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  reminder_time TEXT,
  verify_provider TEXT,
  verify_metric TEXT,
  verify_comparator TEXT,
  verify_threshold REAL,
  verify_unit TEXT
)''');
    await db.execute('''
CREATE TABLE goal_logs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  status TEXT NOT NULL,
  streak INTEGER DEFAULT 0,
  notes TEXT,
  value REAL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (goal_id, date)
)''');
    await db.execute('''
CREATE TABLE long_term_goals (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  status TEXT NOT NULL,
  type TEXT NOT NULL,
  year INTEGER,
  month INTEGER,
  week_number INTEGER,
  quarter INTEGER,
  color TEXT,
  category_key TEXT,
  category_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''');
    await db.execute('''
CREATE TABLE daily_moods (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  mood_score INTEGER NOT NULL,
  energy_score INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE (user_id, date)
)''');

    // Real history, the thing a migration must never lose.
    await db.insert('profiles',
        {'id': 'u1', 'full_name': 'Simo', 'created_at': t0, 'updated_at': t0});
    await db.insert('goals', {
      'id': 'g1',
      'user_id': 'u1',
      'title': 'Push-ups',
      'color': '#FFFFFF',
      'start_date': '2026-06-01',
      'created_at': t0,
      'updated_at': t0,
      'reminder_time': '07:30',
      // A v6 auto-verified habit: the flat rule columns, pre-compound.
      'verify_provider': 'healthKit',
      'verify_metric': 'steps',
      'verify_comparator': 'atLeast',
      'verify_threshold': 10000.0,
      'verify_unit': 'count',
    });
    for (var d = 1; d <= 40; d++) {
      final day = '2026-06-${d.toString().padLeft(2, '0')}';
      await db.insert('goal_logs', {
        'id': 'l$d',
        'user_id': 'u1',
        'goal_id': 'g1',
        'date': day,
        'status': d.isEven ? 'done' : 'missed',
        'streak': d,
        'value': d * 100.0,
        'created_at': t0,
        'updated_at': t0,
      });
    }
    await db.insert('long_term_goals', {
      'id': 'm1',
      'user_id': 'u1',
      'title': 'Read 24 books',
      'status': 'active',
      'type': 'annual',
      'year': 2026,
      'created_at': t0,
      'updated_at': t0,
    });
    await db.insert('daily_moods', {
      'id': 'd1',
      'user_id': 'u1',
      'date': '2026-06-01',
      'mood_score': 4,
      'energy_score': 3,
      'created_at': t0,
      'updated_at': t0,
    });
    // A real v6 database also carries the sync bookkeeping and the
    // dirty/tombstone triggers, installed back at v3. Without these the fixture
    // is not a v6 database, and the trigger assertion below would be vacuous.
    // createSyncTriggers skips tables that do not exist yet, so goal_progress
    // (v9) is correctly absent here.
    await PrivateDbSchema.createSyncObjects(db);
    return db;
  }

  test('all five legs run in one open and the v6 data survives intact',
      () async {
    final db = await openV6WithData();

    await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);

    // Every column the five legs add is present.
    final goalCols = await columnsOf(db, 'goals');
    expect(
      goalCols,
      containsAll(<String>[
        'verify_effective_from', // v7
        'verify_conditions', // v8
        'target', // v9
        'target_effective_from', // v11
      ]),
    );
    expect(await objectsOf(db, 'table'), contains('goal_progress')); // v9
    expect(
      await columnsOf(db, 'long_term_goals'),
      containsAll(<String>[
        'target_amount', // v10
        'target_unit',
        'progress_amount',
        'linked_goal_id',
      ]),
    );

    // …and nothing was lost on the way. This is the assertion that matters.
    expect(
      (await db.query('goal_logs')).length,
      40,
      reason: 'a rebuild leg dropped logged history',
    );
    final goal = (await db.query('goals', where: 'id = ?', whereArgs: ['g1']))
        .single;
    expect(goal['title'], 'Push-ups');
    expect(goal['reminder_time'], '07:30');
    expect(goal['verify_provider'], 'healthKit',
        reason: 'a v6 verification rule must survive to v11');
    expect(goal['verify_threshold'], 10000.0);
    // New columns default to NULL — the whole forward-only-freeze design rests
    // on this (NULL ⇒ fall back to start_date, so no past day is rewritten).
    expect(goal['target'], isNull);
    expect(goal['target_effective_from'], isNull);
    expect(goal['verify_effective_from'], isNull);

    final log = (await db.query('goal_logs', where: 'id = ?', whereArgs: ['l40']))
        .single;
    expect(log['status'], 'done');
    expect(log['streak'], 40);
    expect(log['value'], 4000.0);

    expect((await db.query('long_term_goals')).single['title'], 'Read 24 books');
    expect((await db.query('daily_moods')).single['mood_score'], 4);

    await db.close();
  });

  test('every synced table still has its dirty/tombstone triggers afterwards',
      () async {
    // A rebuild leg that forgets to reinstall triggers leaves a table that reads
    // and writes fine LOCALLY and silently never pushes again — the worst
    // possible failure, because nothing surfaces it until data is missing on the
    // other device.
    final db = await openV6WithData();
    await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);

    final triggers = await objectsOf(db, 'trigger');
    final missing = <String>[];
    var checked = 0;
    for (final table in PrivateDbSchema.syncedTables) {
      // Only tables that actually exist in this DB can be expected to carry
      // triggers (user_settings/goal_category_settings/macro_goal_categories
      // are created by legs older than v6 or by onCreate).
      final exists = (await objectsOf(db, 'table')).contains(table);
      if (!exists) continue;
      for (final suffix in ['ai', 'au', 'ad']) {
        final name = '${table}_sync_$suffix';
        checked++;
        if (!triggers.contains(name)) missing.add(name);
      }
    }
    expect(missing, isEmpty,
        reason: 'these tables would never sync again: $missing');
    // Non-vacuity: if the fixture ever stops installing triggers, or the table
    // list shrinks, the loop above would pass by checking nothing at all.
    expect(checked, greaterThanOrEqualTo(18),
        reason: 'only $checked triggers were asserted — the test has gone '
            'vacuous, which is worse than failing');

    await db.close();
  });

  test('re-running the whole chain is a harmless no-op', () async {
    // The downgrade guard throws, but a version round-trip can still stamp
    // user_version back on an older build that lacks it. Re-running must not
    // raise "duplicate column name" / "table already exists" and permanently
    // wedge every future open.
    final db = await openV6WithData();
    await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);
    await PrivateDbSchema.onUpgrade(db, 6, PrivateDbSchema.version);

    expect((await db.query('goal_logs')).length, 40);
    expect(await columnsOf(db, 'goals'), contains('target_effective_from'));
    await db.close();
  });

  test('the chain is driven by oldVersion alone, not by newVersion', () async {
    // Documenting real behaviour, not asserting a wish: onUpgrade runs every leg
    // whose guard is `oldVersion < N`, with no upper bound against newVersion.
    // Harmless in production — sqflite always passes the code's own version as
    // newVersion — but worth pinning, because a caller that passed a LOWER
    // newVersion expecting a partial upgrade would silently get the full chain.
    //
    // It also means a crash mid-migration is safe by a different route:
    // user_version is only stamped after onUpgrade returns, so an interrupted
    // upgrade leaves the DB at v6 and the next open simply re-runs the whole
    // chain — which the idempotency test above covers.
    final db = await openV6WithData();

    await PrivateDbSchema.onUpgrade(db, 6, 9);

    expect(
      await columnsOf(db, 'goals'),
      contains('target_effective_from'),
      reason: 'newVersion: 9 does not stop the v10/v11 legs from running',
    );
    expect((await db.query('goal_logs')).length, 40);
    await db.close();
  });
}
