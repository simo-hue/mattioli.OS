// Cumulative numeric macro goals (private schema v10) on desktop: the
// DashboardGoal model's numeric-target plumbing, the period→date-range helper,
// the backup import round-trip (with the linked_goal_id FK guard), and the
// delete-time progress snapshot. Runs the DB pieces headless against an
// in-memory FFI SQLite with the real PrivateDbSchema.
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/core/macro_goal_snapshot.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  DashboardGoal base({
    double? targetAmount,
    String? targetUnit,
    double? progressAmount,
    String? linkedGoalId,
  }) =>
      DashboardGoal(
        id: 'm1',
        title: 'Run 500 km',
        category: 'salute',
        color: const Color(0xFF10B981),
        progress: 0,
        dueLabel: '2026',
        type: GoalType.annual,
        year: 2026,
        targetAmount: targetAmount,
        targetUnit: targetUnit,
        progressAmount: progressAmount,
        linkedGoalId: linkedGoalId,
      );

  group('DashboardGoal model', () {
    test('a numeric target survives fromRemoteJson(toRemoteJson(...))', () {
      final g = base(targetAmount: 500, targetUnit: 'kilometers', linkedGoalId: 'h1');
      final restored = DashboardGoal.fromRemoteJson(g.toRemoteJson());
      expect(restored.targetAmount, 500);
      expect(restored.targetUnit, 'kilometers');
      expect(restored.linkedGoalId, 'h1');
      expect(restored.hasNumericTarget, isTrue);
      expect(restored.isLinked, isTrue);
    });

    test('a plain boolean goal emits NO numeric keys (pre-migration safety)', () {
      final json = base().toRemoteJson();
      expect(json.containsKey('target_amount'), isFalse);
      expect(json.containsKey('target_unit'), isFalse);
      expect(json.containsKey('progress_amount'), isFalse);
      expect(json.containsKey('linked_goal_id'), isFalse);
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
      final g = base(targetAmount: 500, linkedGoalId: 'h1')
          .copyWith(clearLink: true, progressAmount: 320);
      expect(g.linkedGoalId, isNull);
      expect(g.progressAmount, 320);
      expect(g.targetAmount, 500);
    });
  });

  group('macroGoalPeriodRange', () {
    test('annual / quarterly / monthly / weekly / lifetime', () {
      expect(macroGoalPeriodRange(type: 'annual', year: 2026)!.end,
          DateTime.utc(2026, 12, 31));
      expect(macroGoalPeriodRange(type: 'quarterly', year: 2026, quarter: 2)!.start,
          DateTime.utc(2026, 4, 1));
      expect(macroGoalPeriodRange(type: 'monthly', year: 2024, month: 2)!.end,
          DateTime.utc(2024, 2, 29));
      expect(macroGoalPeriodRange(type: 'weekly', year: 2026, month: 7, week: 2)!.start,
          logicalWeekRange(2026, 7, 2).start);
      expect(macroGoalPeriodRange(type: 'lifetime'), isNull);
      expect(macroGoalPeriodRange(type: 'annual'), isNull);
    });
  });

  // ── DB-backed tests ────────────────────────────────────────────────────────
  const owner = 'owner-uuid';
  const now = '2026-07-01T10:00:00.000Z';

  Future<Database> openDb() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: PrivateDbSchema.version,
        singleInstance: false,
        onConfigure: PrivateDbSchema.onConfigure,
        onCreate: PrivateDbSchema.onCreate,
        onUpgrade: PrivateDbSchema.onUpgrade,
      ),
    );
    await DesktopPrivateDb.seedProfile(db, owner: owner, now: now);
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

  group('import round-trip (applyImport)', () {
    test('a numeric macro goal + linked habit survive the merge', () async {
      final db = await openDb();
      final model = {
        'goals': [
          {'id': 'h1', 'title': 'Running', 'color': '#FFFFFF', 'start_date': '2026-01-01'},
        ],
        'long_term_goals': [
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
      await db.transaction((txn) => DesktopPrivateDb.applyImport(
            txn,
            owner: owner,
            backupData: model,
            replaceExisting: false,
            now: now,
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
      final model = {
        'long_term_goals': [
          {
            'id': 'm2',
            'title': 'Ghost link',
            'status': 'active',
            'type': 'annual',
            'year': 2026,
            'target_amount': 100,
            'linked_goal_id': 'ghost',
          },
        ],
      };
      await db.transaction((txn) => DesktopPrivateDb.applyImport(
            txn,
            owner: owner,
            backupData: model,
            replaceExisting: false,
            now: now,
          ));
      final row =
          (await db.query('long_term_goals', where: 'id = ?', whereArgs: ['m2']))
              .first;
      expect(row['target_amount'], 100);
      expect(row['linked_goal_id'], isNull);
      await db.close();
    });
  });

  group('delete snapshot', () {
    test('sums the linked habit over the goal period, then delete preserves it',
        () async {
      final db = await openDb();
      await seedHabit(db, 'h1');
      await seedProgress(db, 'h1', '2026-03-10', 120);
      await seedProgress(db, 'h1', '2026-08-20', 200);
      await seedProgress(db, 'h1', '2025-12-31', 999); // out of the 2026 range
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

      await snapshotLinkedMacroGoals(db, 'h1', now: now);
      await db.delete('goals', where: 'id = ?', whereArgs: ['h1']);

      final row =
          (await db.query('long_term_goals', where: 'id = ?', whereArgs: ['m1']))
              .first;
      expect(row['progress_amount'], 320);
      expect(row['linked_goal_id'], isNull);
      expect(await db.query('goal_progress'), isEmpty);
      await db.close();
    });
  });
}
