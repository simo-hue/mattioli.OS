// The one-time repair of the streaks the empty-goals window corrupted.
//
// `applyAutoVerdict` / `setDerivedStatus` used to recompute the streak from a
// LIVE goalsProvider read. When that list was transiently empty the goal
// resolved to null, `startDate` fell back to the day being written, and
// computeStreak's backward walk broke on its first step — persisting a long run
// as ±1 into a SYNCED table that nothing re-derives.
//
// `streak` is a CACHE of a pure function of data still on disk, so every wrong
// value is recoverable exactly. Two halves are tested here: the recompute itself
// against the REAL schema, and the once-per-install gate around it.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/import_merge.dart';
import 'package:mattioli_os/core/private_data_store.dart';
import 'package:mattioli_os/core/streak_repair.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_private_data_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner-1';
  const goalId = 'goal-A';
  const now = '2026-06-01T00:00:00.000Z';

  Future<Database> openDb({List<int>? frequencyDays}) async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: PrivateDbSchema.onCreate,
        onUpgrade: PrivateDbSchema.onUpgrade,
      ),
    );
    await db.insert(
        'profiles', {'id': owner, 'created_at': now, 'updated_at': now});
    await db.insert('goals', {
      'id': goalId,
      'user_id': owner,
      'title': 'Meditate',
      'color': '#3B82F6',
      'start_date': '2026-06-01T00:00:00.000Z',
      if (frequencyDays != null) 'frequency_days': '$frequencyDays',
      'created_at': now,
      'updated_at': now,
    });
    return db;
  }

  /// [n] consecutive 'done' days from 2026-06-01, each storing [streakFor].
  Future<void> seedRun(Database db, int n,
      {required int Function(int index) streakFor}) async {
    for (var i = 0; i < n; i++) {
      final d = DateTime(2026, 6, 1 + i);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      await db.insert('goal_logs', {
        'id': 'log-$key',
        'user_id': owner,
        'goal_id': goalId,
        'date': key,
        'status': 'done',
        'streak': streakFor(i),
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<List<int>> storedStreaks(Database db) async {
    final rows = await db.query('goal_logs', orderBy: 'date ASC');
    return [for (final r in rows) (r['streak'] as num?)?.toInt() ?? 0];
  }

  group('recomputeStreaks (the repair core, real schema)', () {
    test('THE REPAIR: a run collapsed to 1s is restored to 1..n', () async {
      final db = await openDb();
      // Exactly what the corruption looks like: every day stamped ±1.
      await seedRun(db, 10, streakFor: (_) => 1);

      final corrected = await db.transaction<int>(
        (txn) => recomputeStreaks(txn, {goalId}),
      );

      expect(await storedStreaks(db), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(corrected, 9, reason: 'day 1 was already correct at 1');
      await db.close();
    });

    test('an already-correct history is left alone and reports 0', () async {
      final db = await openDb();
      await seedRun(db, 5, streakFor: (i) => i + 1);

      final corrected = await db.transaction<int>(
        (txn) => recomputeStreaks(txn, {goalId}),
      );

      expect(corrected, 0, reason: 'no write means no sync churn');
      expect(await storedStreaks(db), [1, 2, 3, 4, 5]);
      await db.close();
    });

    test('honours the weekly schedule', () async {
      // Mon/Wed/Fri. 2026-06-01 is a Monday; 03 Wed, 05 Fri are the next two
      // scheduled days, and the off-days between them are transparent.
      final db = await openDb(frequencyDays: [1, 3, 5]);
      for (final (i, day) in [1, 3, 5].indexed) {
        await db.insert('goal_logs', {
          'id': 'log-$day',
          'user_id': owner,
          'goal_id': goalId,
          'date': '2026-06-0$day',
          'status': 'done',
          'streak': 1, // corrupted
          'created_at': now,
          'updated_at': now,
        });
        expect(i, isNotNull);
      }

      await db.transaction<int>((txn) => recomputeStreaks(txn, {goalId}));

      expect(await storedStreaks(db), [1, 2, 3],
          reason: 'off-days must not break the run');
      await db.close();
    });

    test('a NULL streak column is repaired rather than skipped', () async {
      final db = await openDb();
      await db.insert('goal_logs', {
        'id': 'log-x',
        'user_id': owner,
        'goal_id': goalId,
        'date': '2026-06-01',
        'status': 'done',
        'streak': null,
        'created_at': now,
        'updated_at': now,
      });

      await db.transaction<int>((txn) => recomputeStreaks(txn, {goalId}));

      expect(await storedStreaks(db), [1]);
      await db.close();
    });

    test('a missed run is restored with its NEGATIVE sign', () async {
      final db = await openDb();
      for (var i = 0; i < 3; i++) {
        await db.insert('goal_logs', {
          'id': 'log-$i',
          'user_id': owner,
          'goal_id': goalId,
          'date': '2026-06-0${i + 1}',
          'status': 'missed',
          'streak': -1, // collapsed
          'created_at': now,
          'updated_at': now,
        });
      }

      await db.transaction<int>((txn) => recomputeStreaks(txn, {goalId}));

      expect(await storedStreaks(db), [-1, -2, -3],
          reason: 'the sign carries the run TYPE, not just its length');
      await db.close();
    });
  });

  group('the repair must PROPAGATE, not just correct locally', () {
    test('THE REGRESSION: a corrected row is stamped so peers accept it',
        () async {
      // The AFTER UPDATE trigger stamps sync_state from the ROW's own
      // updated_at, and peers apply on STRICT greater-than. A row corrected
      // without a fresh stamp is pushed carrying its ORIGINAL timestamp, every
      // peer sees `rec.updatedAtMs == localMs`, skips it, and stays corrupted
      // forever — with no repair pass of its own to save it.
      final db = await openDb();
      await seedRun(db, 3, streakFor: (_) => 1);

      await db.transaction<int>((txn) => recomputeStreaks(
            txn,
            {goalId},
            stampUpdatedAt: '2026-08-06T12:00:00.000Z',
          ));

      final rows = await db.query('goal_logs', orderBy: 'date ASC');
      final stamps = [for (final r in rows) r['updated_at'] as String];
      expect(stamps.where((s) => s == '2026-08-06T12:00:00.000Z'), hasLength(2),
          reason: 'the two CORRECTED rows carry the new stamp');
      expect(stamps.where((s) => s == now), hasLength(1),
          reason: 'the already-correct row is not touched, so no sync churn');

      // Every row is already dirty from its INSERT; what matters is the stamp
      // sync_state carries, because that is what the peer compares.
      final sync = await db.query('sync_state',
          where: "table_name = 'goal_logs'", orderBy: 'row_id ASC');
      final byRow = {
        for (final r in sync) r['row_id'] as String: r['updated_at'] as String?
      };
      expect(byRow['log-2026-06-02'], '2026-08-06T12:00:00.000Z',
          reason: 'sync_state must carry the NEW stamp, or the peer skips it');
      expect(byRow['log-2026-06-03'], '2026-08-06T12:00:00.000Z');
      expect(byRow['log-2026-06-01'], now,
          reason: 'the already-correct row is untouched');
      await db.close();
    });

    test('the import path is unchanged: no stamp, no churn', () async {
      // applyPrivateImportMerge is already inside an LWW merge managing its own
      // timestamps; recomputeStreaks must not start rewriting them.
      final db = await openDb();
      await seedRun(db, 3, streakFor: (_) => 1);

      await db.transaction<int>((txn) => recomputeStreaks(txn, {goalId}));

      final rows = await db.query('goal_logs', orderBy: 'date ASC');
      expect([for (final r in rows) r['updated_at']], everyElement(now));
      await db.close();
    });
  });

  group('runStreakRepairOnce (the gate)', () {
    test('runs once, then never again', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _CountingStore(corrected: 7);

      expect(await runStreakRepairOnce(store: store, prefs: prefs), 7);
      expect(store.runs, 1);

      expect(await runStreakRepairOnce(store: store, prefs: prefs), isNull);
      expect(store.runs, 1, reason: 'the flag must gate the second call');
      expect(prefs.getBool(kStreakRepairPrefKey), isTrue);
    });

    test('a FAILURE is retried on the next launch', () async {
      // Nothing else will ever fix these rows, so a locked database or a disk
      // error must not silently mark the repair done.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _ThrowingStore();

      expect(await runStreakRepairOnce(store: store, prefs: prefs), isNull);

      expect(prefs.getBool(kStreakRepairPrefKey), isNot(isTrue),
          reason: 'a failed repair must NOT be recorded as done');
      expect(await runStreakRepairOnce(store: store, prefs: prefs), isNull);
      expect(store.runs, 2, reason: 'it tried again');
    });

    test('an install with nothing to fix still records itself as done',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _CountingStore(corrected: 0);

      expect(await runStreakRepairOnce(store: store, prefs: prefs), 0);
      expect(prefs.getBool(kStreakRepairPrefKey), isTrue,
          reason: 'a clean install must not re-scan on every launch');
    });

    test('THE REGRESSION: NO HABITS YET does not close the gate', () async {
      // `ownerId()` returns a device-local uuid until the first sync adopts the
      // canonical owner, so on a restored or second device this fires while the
      // user's entire corrupted history is still arriving. Reporting 0 there —
      // indistinguishable from a clean install — would mark the repair done on
      // the one device that most needs it, permanently.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _CountingStore(corrected: null);

      expect(await runStreakRepairOnce(store: store, prefs: prefs), isNull);
      expect(prefs.getBool(kStreakRepairPrefKey), isNot(isTrue),
          reason: 'the data has not arrived — ask again next launch');

      // Next launch: the owner has been adopted and the habits are here.
      store.corrected = 12;
      expect(await runStreakRepairOnce(store: store, prefs: prefs), 12);
      expect(prefs.getBool(kStreakRepairPrefKey), isTrue);
    });

    test('a device that already ran it does not run it again', () async {
      SharedPreferences.setMockInitialValues({kStreakRepairPrefKey: true});
      final prefs = await SharedPreferences.getInstance();
      final store = _CountingStore(corrected: 99);

      expect(await runStreakRepairOnce(store: store, prefs: prefs), isNull);
      expect(store.runs, 0);
    });
  });
}

class _CountingStore extends FakePrivateDataStore {
  _CountingStore({required this.corrected});
  int? corrected;
  int runs = 0;

  @override
  Future<int?> repairAllStreaks() async {
    runs++;
    return corrected;
  }
}

class _ThrowingStore extends FakePrivateDataStore implements PrivateDataStore {
  int runs = 0;

  @override
  Future<int?> repairAllStreaks() async {
    runs++;
    throw StateError('database locked');
  }
}
