import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/dashboard/domain/macro_goal_progress.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardGoal _goal({
  String id = 'g1',
  GoalType type = GoalType.annual,
  int? year = 2026,
  int? quarter,
  int? month,
  int? weekNumber,
  double? targetAmount,
  String? targetUnit,
  double? progressAmount,
  String? linkedGoalId,
}) {
  return DashboardGoal(
    id: id,
    title: 'Run',
    category: 'salute',
    color: const Color(0xFF10B981),
    progress: 0,
    dueLabel: '2026',
    type: type,
    year: year,
    quarter: quarter,
    month: month,
    weekNumber: weekNumber,
    targetAmount: targetAmount,
    targetUnit: targetUnit,
    progressAmount: progressAmount,
    linkedGoalId: linkedGoalId,
  );
}

void main() {
  group('sumHabitProgressInRange', () {
    final progress = <String, Map<String, double>>{
      '2025-12-31': {'h1': 5},
      '2026-01-01': {'h1': 10, 'h2': 1},
      '2026-06-15': {'h1': 20},
      '2026-12-31': {'h1': 4},
      '2027-01-01': {'h1': 100},
    };

    test('null range sums all history for the habit', () {
      expect(sumHabitProgressInRange(progress, 'h1', null), 139);
    });

    test('bounded range includes both endpoints and excludes outside', () {
      final range = MacroGoalDateRange(
        start: DateTime.utc(2026, 1, 1),
        end: DateTime.utc(2026, 12, 31),
      );
      // 10 + 20 + 4 — excludes 2025-12-31 and 2027-01-01.
      expect(sumHabitProgressInRange(progress, 'h1', range), 34);
    });

    test('ignores other habits', () {
      final range = MacroGoalDateRange(
        start: DateTime.utc(2026, 1, 1),
        end: DateTime.utc(2026, 12, 31),
      );
      expect(sumHabitProgressInRange(progress, 'h2', range), 1);
    });

    test('unknown habit sums to 0', () {
      expect(sumHabitProgressInRange(progress, 'nope', null), 0);
    });
  });

  group('resolveMacroGoalProgressAmount', () {
    test('manual goal reads its stored amount', () {
      final goal = _goal(targetAmount: 500, progressAmount: 320);
      expect(resolveMacroGoalProgressAmount(goal, const {}), 320);
    });

    test('manual goal with no stored value reads as 0', () {
      final goal = _goal(targetAmount: 500);
      expect(resolveMacroGoalProgressAmount(goal, const {}), 0);
    });

    test('linked goal sums the habit over its annual period', () {
      final goal = _goal(
        targetAmount: 500,
        linkedGoalId: 'h1',
        progressAmount: 999, // ignored while linked
      );
      final progress = <String, Map<String, double>>{
        '2026-03-01': {'h1': 120},
        '2026-08-01': {'h1': 200},
        '2027-01-01': {'h1': 50}, // out of the 2026 range
      };
      expect(resolveMacroGoalProgressAmount(goal, progress), 320);
    });
  });

  group('linkedMacroGoalSnapshots (delete-time freeze)', () {
    final progress = <String, Map<String, double>>{
      '2026-03-01': {'h1': 120, 'h2': 9},
      '2026-08-01': {'h1': 200},
      '2027-01-01': {'h1': 50}, // outside the 2026 goal's range
    };
    final goals = [
      _goal(id: 'annual', linkedGoalId: 'h1', targetAmount: 500), // 2026
      _goal(
        id: 'lifetime',
        type: GoalType.lifetime,
        year: null,
        linkedGoalId: 'h1',
        targetAmount: 1000,
      ),
      _goal(id: 'other', linkedGoalId: 'h9', targetAmount: 5), // not h1
      _goal(id: 'manual', targetAmount: 5, progressAmount: 3), // not linked
    ];

    test('freezes only goals linked to the deleted habit, over their range', () {
      final snaps = linkedMacroGoalSnapshots(
        goals: goals,
        habitProgress: progress,
        habitId: 'h1',
      );
      expect(snaps.map((s) => s.goalId).toList(), ['annual', 'lifetime']);
      final byId = {for (final s in snaps) s.goalId: s.total};
      // annual 2026 excludes the 2027 row: 120 + 200 = 320.
      expect(byId['annual'], 320);
      // lifetime sums all of h1's history: 120 + 200 + 50 = 370.
      expect(byId['lifetime'], 370);
    });

    test('returns nothing when no goal is linked to the habit', () {
      final snaps = linkedMacroGoalSnapshots(
        goals: goals,
        habitProgress: progress,
        habitId: 'nobody',
      );
      expect(snaps, isEmpty);
    });
  });

  group('macroGoalProgressFor', () {
    test('boolean goal (no target) returns null', () {
      expect(macroGoalProgressFor(_goal(), const {}), isNull);
    });

    test('linked goal yields the clamped fraction + carried unit', () {
      final goal = _goal(
        targetAmount: 500,
        targetUnit: 'kilometers',
        linkedGoalId: 'h1',
      );
      final progress = <String, Map<String, double>>{
        '2026-03-01': {'h1': 250},
      };
      final result = macroGoalProgressFor(goal, progress)!;
      expect(result.amount, 250);
      expect(result.target, 500);
      expect(result.unit, TargetUnit.kilometers);
      expect(result.fraction, closeTo(0.5, 1e-9));
      expect(result.isComplete, isFalse);
    });

    test('manual goal at/over target is complete', () {
      final goal = _goal(targetAmount: 24, progressAmount: 24);
      final result = macroGoalProgressFor(goal, const {})!;
      expect(result.isComplete, isTrue);
      expect(result.fraction, 1.0);
    });
  });
}
