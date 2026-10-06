import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/macro_goal.dart';

void main() {
  test('a new weekly goal immediately belongs to its owning quarter', () {
    final goal = MacroGoal(
      id: 'new',
      title: 'Read',
      status: GoalStatus.active,
      type: GoalType.weekly,
      year: 2026,
      month: 12,
      weekNumber: 5,
      createdAt: DateTime(2026, 12, 28),
    );
    expect(goal.quarter, 4);
    expect(computeMacroGoalsStats([goal], '2026')['quarterly_activity'], [
      {'quarter': 4, 'total': 1, 'completed': 0, 'active': 1, 'failed': 0},
    ]);
    expect(computeMacroGoalsStats([goal], 'all')['seasonality'], [
      {'quarter': 4, 'completed': 0, 'active': 1, 'failed': 0},
    ]);
    final moved = goal.copyWith(year: 2027, month: 1, weekNumber: 1);
    expect(moved.quarter, 1);
    expect(computeMacroGoalsStats([moved], '2027')['quarterly_activity'], [
      {'quarter': 1, 'total': 1, 'completed': 0, 'active': 1, 'failed': 0},
    ]);
  });

  for (final alreadyMigrated in [false, true]) {
    for (final storedQuarter in [1, null]) {
      test('private stats use the owning quarter for '
          '${alreadyMigrated ? "v13" : "legacy"} weeks '
          'with stored quarter $storedQuarter', () {
        // Legacy Jan 2027 week one converts to Dec 28–Jan 3, owned by
        // December 2026. A v13 database can retain the former quarter.
        final goal = MacroGoal.fromJson({
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

        final yearStats = computeMacroGoalsStats([goal], '2026');
        expect(yearStats['quarterly_activity'], [
          {'quarter': 4, 'total': 1, 'completed': 1, 'active': 0, 'failed': 0},
        ]);
        final allStats = computeMacroGoalsStats([goal], 'all');
        expect(allStats['seasonality'], [
          {'quarter': 4, 'completed': 1, 'active': 0, 'failed': 0},
        ]);
      });
    }
  }
}
