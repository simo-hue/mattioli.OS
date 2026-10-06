import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a new weekly goal appears in its quarter before a database reload', () {
    // Match the draft built by DashboardController.addGoal, which only passes
    // an explicit quarter for quarterly goals.
    const goal = DashboardGoal(
      id: 'new',
      title: 'Read',
      category: '',
      color: Colors.blue,
      progress: 0,
      dueLabel: '',
      type: GoalType.weekly,
      year: 2026,
      month: 12,
      weekNumber: 5,
    );
    expect(goal.quarter, 4);
    final input = _stat(goal);
    expect(computeMacroGoalsStats([input], '2026')['quarterly_activity'], [
      {'quarter': 4, 'total': 1, 'completed': 0, 'active': 1, 'failed': 0},
    ]);
    expect(computeMacroGoalsStats([input], 'all')['seasonality'], [
      {'quarter': 4, 'completed': 0, 'active': 1, 'failed': 0},
    ]);
    final moved = goal.copyWith(year: 2027, month: 1, weekNumber: 1);
    expect(moved.quarter, 1);
    expect(
      computeMacroGoalsStats([_stat(moved)], '2027')['quarterly_activity'],
      [
        {'quarter': 1, 'total': 1, 'completed': 0, 'active': 1, 'failed': 0},
      ],
    );
  });

  for (final alreadyMigrated in [false, true]) {
    for (final storedQuarter in [1, null]) {
      test('private stats use the owning quarter for '
          '${alreadyMigrated ? "v13" : "legacy"} weeks '
          'with stored quarter $storedQuarter', () {
        // The private repository uses this same model boundary; analytics
        // receives the projection made by macroGoalsStatsRpcProvider.
        final goal = DashboardGoal.fromRemoteJson({
          'id': 'g',
          'title': 'Read',
          'type': 'weekly',
          'status': 'completed',
          'year': alreadyMigrated ? 2026 : 2027,
          'month': alreadyMigrated ? 12 : 1,
          'week_number': alreadyMigrated ? 5 : 1,
          if (alreadyMigrated) 'week_start_date': '2026-12-28',
          'quarter': storedQuarter,
          'created_at': '2026-12-29T00:00:00Z',
        });
        expect(goal.weekStartDate, '2026-12-28');
        expect((goal.year, goal.month, goal.weekNumber), (2026, 12, 5));
        final input = _stat(goal);

        final yearStats = computeMacroGoalsStats([input], '2026');
        expect(yearStats['quarterly_activity'], [
          {'quarter': 4, 'total': 1, 'completed': 1, 'active': 0, 'failed': 0},
        ]);
        final allStats = computeMacroGoalsStats([input], 'all');
        expect(allStats['seasonality'], [
          {'quarter': 4, 'completed': 1, 'active': 0, 'failed': 0},
        ]);
      });
    }
  }
}

MacroGoalStat _stat(DashboardGoal goal) => MacroGoalStat(
  status: goal.state.name,
  type: goal.type.name,
  year: goal.year,
  month: goal.month,
  quarter: goal.quarter,
  categoryId: goal.categoryId,
  categoryKey: goal.category.isEmpty ? null : goal.category,
);
