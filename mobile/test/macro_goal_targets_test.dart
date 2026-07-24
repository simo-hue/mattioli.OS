// Cumulative numeric macro goals (private schema v10): the MacroGoal model's
// numeric-target plumbing, the period→date-range helper, the backup import
// round-trip (including the linked_goal_id FK guard), and the delete-time
// progress snapshot. Runs the DB pieces against an in-memory FFI SQLite seeded
// with the real PrivateDbSchema — encryption is orthogonal.
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:mattioli_os/core/import_merge.dart';
import 'package:mattioli_os/core/macro_goal_calendar.dart';
import 'package:mattioli_os/core/macro_goal_snapshot.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  MacroGoal base({
    double? targetAmount,
    String? targetUnit,
    double? progressAmount,
    String? linkedGoalId,
  }) =>
      MacroGoal(
        id: 'm1',
        title: 'Run 500 km',
        status: GoalStatus.active,
        type: GoalType.annual,
        year: 2026,
        createdAt: DateTime.utc(2026, 1, 1),
        targetAmount: targetAmount,
        targetUnit: targetUnit,
        progressAmount: progressAmount,
        linkedGoalId: linkedGoalId,
      );

  group('MacroGoal model', () {
    test('a numeric target survives fromJson(toJson(...))', () {
      final g = base(
        targetAmount: 500,
        targetUnit: 'kilometers',
        linkedGoalId: 'h1',
      );
      final restored = MacroGoal.fromJson(g.toJson());
      expect(restored.targetAmount, 500);
      expect(restored.targetUnit, 'kilometers');
      expect(restored.linkedGoalId, 'h1');
      expect(restored.hasNumericTarget, isTrue);
      expect(restored.isLinked, isTrue);
    });

    test('a manual numeric goal round-trips its stored progress', () {
      final g = base(targetAmount: 24, targetUnit: 'count', progressAmount: 6);
      final restored = MacroGoal.fromJson(g.toJson());
      expect(restored.progressAmount, 6);
      expect(restored.isLinked, isFalse);
    });

    test('a plain boolean goal emits NO numeric keys (pre-migration safety)',
        () {
      final json = base().toJson();
      expect(json.containsKey('target_amount'), isFalse);
      expect(json.containsKey('target_unit'), isFalse);
      expect(json.containsKey('progress_amount'), isFalse);
      expect(json.containsKey('linked_goal_id'), isFalse);
    });

    test('a numeric goal DOES emit its set keys', () {
      final json = base(targetAmount: 500, targetUnit: 'kilometers').toJson();
      expect(json['target_amount'], 500);
      expect(json['target_unit'], 'kilometers');
    });

    test('clearTarget reverts to a boolean goal (nulls all four)', () {
      final g = base(
        targetAmount: 500,
        targetUnit: 'kilometers',
        progressAmount: 100,
        linkedGoalId: 'h1',
      ).copyWith(clearTarget: true);
      expect(g.targetAmount, isNull);
      expect(g.targetUnit, isNull);
      expect(g.progressAmount, isNull);
      expect(g.linkedGoalId, isNull);
    });

    test('clearLink + progressAmount snapshots without touching the target', () {
      final g = base(targetAmount: 500, targetUnit: 'kilometers', linkedGoalId: 'h1')
          .copyWith(clearLink: true, progressAmount: 320);
      expect(g.linkedGoalId, isNull);
      expect(g.progressAmount, 320);
      expect(g.targetAmount, 500); // untouched
    });
  });

  group('macroGoalPeriodRange', () {
    test('annual spans Jan 1 .. Dec 31', () {
      final r = macroGoalPeriodRange(type: 'annual', year: 2026)!;
      expect(r.start, DateTime.utc(2026, 1, 1));
      expect(r.end, DateTime.utc(2026, 12, 31));
    });

    test('quarterly spans the quarter (Q2 = Apr..Jun)', () {
      final r = macroGoalPeriodRange(type: 'quarterly', year: 2026, quarter: 2)!;
      expect(r.start, DateTime.utc(2026, 4, 1));
      expect(r.end, DateTime.utc(2026, 6, 30));
    });

    test('monthly spans the month (Feb 2024 = leap, 29 days)', () {
      final r = macroGoalPeriodRange(type: 'monthly', year: 2024, month: 2)!;
      expect(r.start, DateTime.utc(2024, 2, 1));
      expect(r.end, DateTime.utc(2024, 2, 29));
    });

    test('weekly reuses the logical week-of-month range', () {
      final r = macroGoalPeriodRange(
          type: 'weekly', year: 2026, month: 7, week: 2)!;
      final w = logicalWeekRange(2026, 7, 2);
      expect(r.start, w.start);
      expect(r.end, w.end);
    });

    test('lifetime ⇒ null (all history, no bound)', () {
      expect(macroGoalPeriodRange(type: 'lifetime'), isNull);
    });

    test('a period missing its fields ⇒ null (safe sum-everything fallback)', () {
      expect(macroGoalPeriodRange(type: 'annual'), isNull);
      expect(macroGoalPeriodRange(type: 'quarterly', year: 2026), isNull);
    });
  });

  // ── DB-backed tests ────────────────────────────────────────────────────────
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
        singleInstance: false,
      ),
    );
    await db.insert('profiles', {
      'id': owner,
      'created_at': now,
      'updated_at': now,
    });
    return db;
  }

  Future<void> seedHabit(Database db, String id) => db.insert('goals', {
        'id': id,
        'user_id': owner,
        'title': 'Running',
        'color': '#FFFFFF',
        'start_date': '2026-01-01',
        'created_at': now,
        'updated_at': now,
      });

  Future<void> seedProgress(Database db, String habitId, String date, double amt) =>
      db.insert('goal_progress', {
        'id': PrivateDbSchema.goalProgressId(habitId, date),
        'user_id': owner,
        'goal_id': habitId,
        'date': date,
        'amount': amt,
        'source': 'manual',
        'created_at': now,
        'updated_at': now,
      });

  group('import round-trip', () {
    var idc = 0;
    String newId() => 'gen-${idc++}';

    test('a native numeric macro goal survives normalize→validate→merge', () async {
      final db = await openDb();
      await seedHabit(db, 'h1');
      final raw = {
        'mode': 'private',
        'habits': [
          {'id': 'h1', 'title': 'Running', 'color': '#FFFFFF', 'start_date': '2026-01-01'},
        ],
        'macroGoals': [
          {
            'id': 'm1',
            'title': 'Run 500 km',
            'status': 'active',
            'type': 'annual',
            'year': 2026,
            'target_amount': 500,
            'target_unit': 'kilometers',
            'linked_goal_id': 'h1',
          },
        ],
      };
      final validated = validateCanonical(normalizeBackup(raw));
      await db.transaction((txn) => applyPrivateImportMerge(
            txn: txn,
            owner: owner,
            canonical: validated.canonical,
            replaceExisting: false,
            now: now,
            newId: newId,
          ));
      final row =
          (await db.query('long_term_goals', where: 'id = ?', whereArgs: ['m1']))
              .first;
      expect(row['target_amount'], 500);
      expect(row['target_unit'], 'kilometers');
      expect(row['linked_goal_id'], 'h1');
      await db.close();
    });

    test('a linked_goal_id whose habit is absent is nulled (no FK abort)', () async {
      final db = await openDb();
      // NOTE: no habit 'ghost' seeded and none in the backup.
      final raw = {
        'mode': 'private',
        'macroGoals': [
          {
            'id': 'm2',
            'title': 'Ghost link',
            'status': 'active',
            'type': 'annual',
            'year': 2026,
            'target_amount': 100,
            'target_unit': 'count',
            'linked_goal_id': 'ghost',
          },
        ],
      };
      final validated = validateCanonical(normalizeBackup(raw));
      await db.transaction((txn) => applyPrivateImportMerge(
            txn: txn,
            owner: owner,
            canonical: validated.canonical,
            replaceExisting: false,
            now: now,
            newId: newId,
          ));
      final row =
          (await db.query('long_term_goals', where: 'id = ?', whereArgs: ['m2']))
              .first;
      // The goal imports, but with a nulled (safe) link rather than aborting.
      expect(row['target_amount'], 100);
      expect(row['linked_goal_id'], isNull);
      await db.close();
    });
  });

  group('delete snapshot', () {
    test('sums the linked habit over the goal period and unlinks it', () async {
      final db = await openDb();
      await seedHabit(db, 'h1');
      // 2026 progress that should count (annual goal for 2026)…
      await seedProgress(db, 'h1', '2026-03-10', 120);
      await seedProgress(db, 'h1', '2026-08-20', 200);
      // …and a 2025 row that must NOT count.
      await seedProgress(db, 'h1', '2025-12-31', 999);
      await db.insert('long_term_goals', {
        'id': 'm1',
        'user_id': owner,
        'title': 'Run 500 km',
        'status': 'active',
        'type': 'annual',
        'year': 2026,
        'target_amount': 500.0,
        'target_unit': 'kilometers',
        'linked_goal_id': 'h1',
        'created_at': now,
        'updated_at': now,
      });

      await snapshotLinkedMacroGoals(db, 'h1', now: now);

      final row =
          (await db.query('long_term_goals', where: 'id = ?', whereArgs: ['m1']))
              .first;
      // 120 + 200, the 2025 row excluded by the annual range.
      expect(row['progress_amount'], 320);
      expect(row['linked_goal_id'], isNull);
      await db.close();
    });

    test('a lifetime goal sums ALL history', () async {
      final db = await openDb();
      await seedHabit(db, 'h1');
      await seedProgress(db, 'h1', '2024-01-01', 10);
      await seedProgress(db, 'h1', '2026-01-01', 5);
      await db.insert('long_term_goals', {
        'id': 'm3',
        'user_id': owner,
        'title': 'Lifetime',
        'status': 'active',
        'type': 'lifetime',
        'target_amount': 100.0,
        'linked_goal_id': 'h1',
        'created_at': now,
        'updated_at': now,
      });

      await snapshotLinkedMacroGoals(db, 'h1', now: now);

      final row =
          (await db.query('long_term_goals', where: 'id = ?', whereArgs: ['m3']))
              .first;
      expect(row['progress_amount'], 15);
      await db.close();
    });

    test('the real deleteGoal-style flow: snapshot THEN cascade preserves it',
        () async {
      final db = await openDb();
      await seedHabit(db, 'h1');
      await seedProgress(db, 'h1', '2026-03-10', 320);
      await db.insert('long_term_goals', {
        'id': 'm1',
        'user_id': owner,
        'title': 'Run 500 km',
        'status': 'active',
        'type': 'annual',
        'year': 2026,
        'target_amount': 500.0,
        'linked_goal_id': 'h1',
        'created_at': now,
        'updated_at': now,
      });

      // Mirror PrivateLocalDatabase.deleteGoal: snapshot, then delete the habit.
      await snapshotLinkedMacroGoals(db, 'h1', now: now);
      await db.delete('goals', where: 'id = ?', whereArgs: ['h1']);

      final row =
          (await db.query('long_term_goals', where: 'id = ?', whereArgs: ['m1']))
              .first;
      // Goal survives with its snapshot; progress rows are gone with the habit.
      expect(row['progress_amount'], 320);
      expect(row['linked_goal_id'], isNull);
      expect(await db.query('goal_progress'), isEmpty);
      await db.close();
    });
  });
}
