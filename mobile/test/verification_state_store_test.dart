import 'package:evolve_verification/evolve_verification.dart';
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

  // ── v4: the durable Screen Time signal buffer ─────────────────────────────
  //
  // The native drain destroys the App Group buffer as it reads it, so once a
  // signal reaches Dart this table is the only copy in existence.

  ScreenTimeSignal signal(String goalId, DateTime d, ScreenTimeSignalKind k) =>
      ScreenTimeSignal(goalId: goalId, day: d, kind: k);

  test('signals round-trip, filtered by goal and date range', () async {
    await store.recordScreenTimeSignals([
      signal('g', day(5), ScreenTimeSignalKind.stayedUnder),
      signal('g', day(20), ScreenTimeSignalKind.reachedThreshold),
      signal('other', day(5), ScreenTimeSignalKind.stayedUnder),
    ]);

    final res = await store
        .screenTimeSignals(goalIds: ['g'], from: day(1), to: day(10));

    expect(res, hasLength(1));
    expect(res.single.goalId, 'g');
    expect(res.single.day, day(5));
    expect(res.single.kind, ScreenTimeSignalKind.stayedUnder);
  });

  test('reachedThreshold is sticky — a later stayedUnder cannot overwrite it',
      () async {
    await store.recordScreenTimeSignals(
        [signal('g', day(5), ScreenTimeSignalKind.reachedThreshold)]);
    await store.recordScreenTimeSignals(
        [signal('g', day(5), ScreenTimeSignalKind.stayedUnder)]);

    final res = await store
        .screenTimeSignals(goalIds: ['g'], from: day(1), to: day(31));
    expect(res.single.kind, ScreenTimeSignalKind.reachedThreshold,
        reason: 'a duplicate/late interval-end must never forgive a crossing');
  });

  test('a stayedUnder IS upgraded by a later reachedThreshold', () async {
    await store.recordScreenTimeSignals(
        [signal('g', day(5), ScreenTimeSignalKind.stayedUnder)]);
    await store.recordScreenTimeSignals(
        [signal('g', day(5), ScreenTimeSignalKind.reachedThreshold)]);

    final res = await store
        .screenTimeSignals(goalIds: ['g'], from: day(1), to: day(31));
    expect(res.single.kind, ScreenTimeSignalKind.reachedThreshold);
  });

  test('one row per goal-day, however many deliveries arrive', () async {
    await store.recordScreenTimeSignals([
      signal('g', day(5), ScreenTimeSignalKind.stayedUnder),
      signal('g', day(5), ScreenTimeSignalKind.stayedUnder),
      signal('g', day(5), ScreenTimeSignalKind.stayedUnder),
    ]);
    final rows =
        await db.query(SqfliteVerificationStateStore.signalsTable);
    expect(rows, hasLength(1));
  });

  test('pruneScreenTimeSignalsBefore drops aged-out rows for every goal',
      () async {
    await store.recordScreenTimeSignals([
      signal('g', day(1), ScreenTimeSignalKind.stayedUnder),
      signal('other', day(2), ScreenTimeSignalKind.stayedUnder),
      signal('g', day(9), ScreenTimeSignalKind.stayedUnder),
    ]);

    await store.pruneScreenTimeSignalsBefore(day(5));

    final rows = await db.query(SqfliteVerificationStateStore.signalsTable);
    expect(rows, hasLength(1),
        reason: 'a signal whose goal is gone is never named by a later pass, '
            'so the prune has to be global');
    expect(rows.single['goal_id'], 'g');
    expect(rows.single['date'], '2026-07-09');
  });

  test('deleteGoal drops the goal\'s buffered signals as well as its markers',
      () async {
    await store.markManual('g', day(10));
    await store.recordScreenTimeSignals(
        [signal('g', day(10), ScreenTimeSignalKind.stayedUnder)]);

    await store.deleteGoal('g');

    expect(
        await store.screenTimeSignals(
            goalIds: ['g'], from: day(1), to: day(31)),
        isEmpty);
    expect(await store.manualDays(goalIds: ['g'], from: day(1), to: day(31)),
        isEmpty);
  });

  test('an unrecognised stored kind reads as no signal, never as a guess',
      () async {
    await db.execute('DROP TABLE IF EXISTS '
        '${SqfliteVerificationStateStore.signalsTable}');
    // Same shape minus the CHECK, so a future build's kind can be planted.
    await db.execute('''
CREATE TABLE ${SqfliteVerificationStateStore.signalsTable} (
  goal_id TEXT NOT NULL,
  date TEXT NOT NULL,
  kind TEXT NOT NULL,
  recorded_at TEXT NOT NULL,
  PRIMARY KEY (goal_id, date)
)
''');
    await db.insert(SqfliteVerificationStateStore.signalsTable, {
      'goal_id': 'g',
      'date': '2026-07-05',
      'kind': 'someFutureKind',
      'recorded_at': '2026-07-05T00:00:00Z',
    });

    final res = await store
        .screenTimeSignals(goalIds: ['g'], from: day(1), to: day(31));
    expect(res, isEmpty);
  });

  test('a v3 database gains the signal table without touching its freezes',
      () async {
    // A v3 database is one with `verification_state` and NO signals table —
    // exactly what an installed build has before this version.
    await db.execute('DROP TABLE IF EXISTS '
        '${SqfliteVerificationStateStore.signalsTable}');
    await store.markManual('g', day(10), status: 'done');

    // What every open runs, unconditionally.
    await SqfliteVerificationStateStore.createTable(db);

    await store.recordScreenTimeSignals(
        [signal('g', day(10), ScreenTimeSignalKind.stayedUnder)]);
    expect(
        await store.screenTimeSignals(
            goalIds: ['g'], from: day(1), to: day(31)),
        hasLength(1));
    final res =
        await store.manualDays(goalIds: ['g'], from: day(1), to: day(31));
    expect(res['g'], {day(10): 'done'},
        reason: 'the migration is additive — it must not rebuild the table '
            'whose rows are the user\'s own check-ins');
  });
}
