import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/verification_state_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late SqfliteVerificationStateStore store;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await SqfliteVerificationStateStore.createTable(db);
    store = SqfliteVerificationStateStore(db);
  });

  tearDown(() => db.close());

  DateTime day(int n) => DateTime(2026, 7, n);

  test('markManual records a frozen day, queryable within range', () async {
    await store.markManual('g', day(10));
    final res =
        await store.manualDays(goalIds: ['g'], from: day(1), to: day(31));
    expect(res['g'], contains(day(10)));
  });

  test('manualDays honours the goal filter and date range', () async {
    await store.markManual('g', day(5));
    await store.markManual('g', day(20));
    await store.markManual('other', day(5));
    final res =
        await store.manualDays(goalIds: ['g'], from: day(1), to: day(10));
    expect(res['g'], {day(5): null}); // day(20) out of range, 'other' excluded
  });

  test('markManual clears any couldn\'t-verify marker for the day', () async {
    await store.recordCouldNotVerify('g', day(10));
    expect(await store.couldNotVerifyDays('g'), contains(day(10)));
    await store.markManual('g', day(10));
    expect(await store.couldNotVerifyDays('g'), isEmpty);
  });

  test('recordCouldNotVerify is a no-op on a manually-frozen day', () async {
    await store.markManual('g', day(10));
    await store.recordCouldNotVerify('g', day(10));
    expect(await store.couldNotVerifyDays('g'), isEmpty);
  });

  test('recordCouldNotVerify is idempotent', () async {
    await store.recordCouldNotVerify('g', day(10));
    await store.recordCouldNotVerify('g', day(10));
    expect(await store.couldNotVerifyDays('g'), {day(10)});
  });

  test('resolveCouldNotVerify clears the marker', () async {
    await store.recordCouldNotVerify('g', day(10));
    await store.resolveCouldNotVerify('g', day(10));
    expect(await store.couldNotVerifyDays('g'), isEmpty);
  });

  test('clearManual removes the freeze', () async {
    await store.markManual('g', day(10));
    await store.clearManual('g', day(10));
    final res =
        await store.manualDays(goalIds: ['g'], from: day(1), to: day(31));
    expect(res, isEmpty);
  });

  test('deleteGoal wipes only that goal\'s bookkeeping', () async {
    await store.markManual('g', day(5));
    await store.recordCouldNotVerify('g', day(6));
    await store.markManual('other', day(5));
    await store.deleteGoal('g');
    expect(
      await store
          .manualDays(goalIds: ['g', 'other'], from: day(1), to: day(31)),
      {
        'other': {day(5): null}
      },
    );
    expect(await store.couldNotVerifyDays('g'), isEmpty);
  });

  test('manualDays with no goal ids returns empty', () async {
    expect(
      await store.manualDays(goalIds: const [], from: day(1), to: day(31)),
      isEmpty,
    );
  });

  test('works against a transaction executor', () async {
    await db.transaction((txn) async {
      await SqfliteVerificationStateStore(txn).markManual('g', day(9));
    });
    final res =
        await store.manualDays(goalIds: ['g'], from: day(1), to: day(31));
    expect(res['g'], contains(day(9)));
  });

  group('nudged marker (couldn\'t-verify de-dup)', () {
    test('markNudged records only for a live couldn\'t-verify day', () async {
      // No couldn't-verify row yet → the UPDATE is a no-op.
      await store.markNudged('g', day(10));
      expect(await store.nudgedDays('g'), isEmpty);

      await store.recordCouldNotVerify('g', day(10));
      expect(await store.nudgedDays('g'), isEmpty); // recorded, not yet nudged
      await store.markNudged('g', day(10));
      expect(await store.nudgedDays('g'), {day(10)});
    });

    test('resolving a couldn\'t-verify day drops its nudged mark', () async {
      await store.recordCouldNotVerify('g', day(10));
      await store.markNudged('g', day(10));
      await store.resolveCouldNotVerify('g', day(10));
      expect(await store.nudgedDays('g'), isEmpty);
    });

    test('a manual freeze drops the nudged mark', () async {
      await store.recordCouldNotVerify('g', day(10));
      await store.markNudged('g', day(10));
      await store.markManual('g', day(10));
      expect(await store.nudgedDays('g'), isEmpty);
    });

    test('nudged marks are per goal + day', () async {
      await store.recordCouldNotVerify('g', day(10));
      await store.recordCouldNotVerify('g', day(11));
      await store.recordCouldNotVerify('other', day(10));
      await store.markNudged('g', day(10));
      expect(await store.nudgedDays('g'), {day(10)}); // day(11) not nudged
      expect(await store.nudgedDays('other'), isEmpty);
    });
  });

  test('pruneCouldNotVerifyBefore deletes markers strictly before the cutoff',
      () async {
    await store.recordCouldNotVerify('g', day(5));
    await store.recordCouldNotVerify('g', day(9));
    await store.recordCouldNotVerify('g', day(10));
    await store.markNudged('g', day(5));
    await store.pruneCouldNotVerifyBefore('g', day(10));
    expect(await store.couldNotVerifyDays('g'), {day(10)}); // 5 + 9 pruned
    expect(await store.nudgedDays('g'), isEmpty); // day(5)'s nudged mark gone
  });

  test('migrateToV2 adds nudged_at to a pre-existing v1 table', () async {
    // Rebuild the table with the original v1 schema (no nudged_at column).
    await db.execute('DROP TABLE IF EXISTS verification_state');
    await db.execute('''
CREATE TABLE verification_state (
  goal_id TEXT NOT NULL,
  date TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('manual', 'could_not_verify')),
  recorded_at TEXT NOT NULL,
  PRIMARY KEY (goal_id, date, kind)
)
''');
    // Migration is idempotent — running twice must not throw.
    await SqfliteVerificationStateStore.migrateToV2(db);
    await SqfliteVerificationStateStore.migrateToV2(db);

    await store.recordCouldNotVerify('g', day(10));
    await store.markNudged('g', day(10));
    expect(await store.nudgedDays('g'), {day(10)});
  });

  test('migrateToV2 is a no-op (no throw) when the table is absent', () async {
    // Simulates a v1 DB whose table doesn't exist yet: PRAGMA returns no rows,
    // so an ALTER would throw "no such table" and fail openDatabase. The guard
    // must skip it and leave table creation to createTable.
    await db.execute('DROP TABLE IF EXISTS verification_state');
    await SqfliteVerificationStateStore.migrateToV2(db); // must not throw
    // createTable (as the provider calls post-open) then builds it with nudged_at.
    await SqfliteVerificationStateStore.createTable(db);
    await store.recordCouldNotVerify('g', day(1));
    await store.markNudged('g', day(1));
    expect(await store.nudgedDays('g'), {day(1)});
  });

  // The status is what lets reconcile RESTORE a freeze whose `goal_logs` row is
  // not visible, instead of judging the day by the sensor and overwriting the
  // user's own check-in. A freeze that carries no status is left alone.
  test('markManual round-trips the status the user chose', () async {
    await store.markManual('g', day(10), status: 'done');
    await store.markManual('g', day(11), status: 'missed');
    await store.markManual('g', day(12)); // legacy shape: no status
    final res =
        await store.manualDays(goalIds: ['g'], from: day(1), to: day(31));
    expect(res['g'], {day(10): 'done', day(11): 'missed', day(12): null});
  });

  test('re-freezing a day overwrites the status with the newer choice', () async {
    await store.markManual('g', day(10), status: 'done');
    await store.markManual('g', day(10), status: 'missed');
    final res =
        await store.manualDays(goalIds: ['g'], from: day(1), to: day(31));
    expect(res['g'], {day(10): 'missed'},
        reason: 'the most recent choice is the one to restore');
  });

  test('a v2 database migrates to v3 keeping its freezes, with a null status',
      () async {
    // Rebuild the table in exactly the v2 shape. `inMemoryDatabasePath` is
    // cached by path, so this is the same handle `setUp` opened — drop first or
    // the CREATE collides with the v3 table already there.
    await db.execute('DROP TABLE IF EXISTS ${SqfliteVerificationStateStore.table}');
    await db.execute('''
CREATE TABLE ${SqfliteVerificationStateStore.table} (
  goal_id TEXT NOT NULL,
  date TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('manual', 'could_not_verify')),
  recorded_at TEXT NOT NULL,
  nudged_at TEXT,
  PRIMARY KEY (goal_id, date, kind)
)
''');
    await db.insert(SqfliteVerificationStateStore.table, {
      'goal_id': 'g',
      'date': '2026-07-10',
      'kind': 'manual',
      'recorded_at': '2026-07-10T00:00:00Z',
    });

    await SqfliteVerificationStateStore.migrateToV3(db);

    final res =
        await store.manualDays(goalIds: ['g'], from: day(1), to: day(31));
    expect(res['g'], {DateTime(2026, 7, 10): null},
        reason: 'the freeze must survive the migration; its status is unknown, '
            'which is the honest value and the one that makes reconcile leave '
            'the day alone');
  });

  test('migrateToV3 is idempotent', () async {
    await SqfliteVerificationStateStore.migrateToV3(db);
    await SqfliteVerificationStateStore.migrateToV3(db);
    await store.markManual('g', day(10), status: 'done');
    final res =
        await store.manualDays(goalIds: ['g'], from: day(1), to: day(31));
    expect(res['g'], {day(10): 'done'});
  });
}
