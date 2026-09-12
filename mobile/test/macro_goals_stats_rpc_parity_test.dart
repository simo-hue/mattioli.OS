// F54 — Private-mode macro-goal stats diverged from the cloud
// `get_macro_goals_stats` RPC the same screen renders in Account mode.
//
// (a) "Most productive year" ranked years by COMPLETED goals while the RPC's
//     most_prod_year_stat orders by `total DESC` and returns that total — so the
//     card named the wrong year AND labelled it with a count that was not the
//     "total goals" the subtitle claims. The sibling best_year computation two
//     lines up already mirrors the RPC's rate-then-total tie-break.
// (b) The loop seeds (-1) escaped as real values when a bucket was empty: the
//     RPC's LIMIT-1 CTEs return SQL NULL for that state, and the view's
//     `as int? ?? 0` cannot fire on a valid -1 — so a user with only Lifetime
//     goals (or none) read "-1%" on screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/macro_goal.dart';

MacroGoal goal({
  required GoalStatus status,
  int? year,
  int? month,
  int? quarter,
  String? categoryId,
  GoalType type = GoalType.annual,
}) =>
    MacroGoal(
      id: 'g-$year-${status.name}-${month ?? 0}-${quarter ?? 0}-$categoryId',
      title: 'Goal',
      status: status,
      type: type,
      year: year,
      month: month,
      quarter: quarter,
      categoryId: categoryId,
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  test('most productive year is the year with the most TOTAL goals', () {
    final goals = <MacroGoal>[
      // 2025: 10 goals, 3 completed.
      for (var i = 0; i < 3; i++)
        goal(status: GoalStatus.completed, year: 2025, month: i + 1),
      for (var i = 0; i < 7; i++)
        goal(status: GoalStatus.active, year: 2025, month: i + 1),
      // 2024: 5 goals, 4 completed.
      for (var i = 0; i < 4; i++)
        goal(status: GoalStatus.completed, year: 2024, month: i + 1),
      goal(status: GoalStatus.active, year: 2024, month: 5),
    ];

    final stats = computeMacroGoalsStats(goals, 'all');

    expect(stats['most_productive_year'], 2025,
        reason: 'the RPC orders year_stats by total DESC');
    expect(stats['most_productive_count'], 10,
        reason: 'the subtitle says "total goals", and the RPC returns total');
    // The sibling best_year (rate, then total) is unchanged: 2024 is 80%.
    expect(stats['best_year'], 2024);
    expect(stats['best_year_rate'], 80);
  });

  test('empty buckets are null, not the -1 loop seeds ("all" view)', () {
    final stats = computeMacroGoalsStats(const [], 'all');

    expect(stats['best_year'], isNull);
    expect(stats['best_year_rate'], isNull,
        reason: '-1 survives the view\'s `as int? ?? 0` and prints as "-1%"');
    expect(stats['most_productive_year'], isNull);
    expect(stats['most_productive_count'], isNull);
  });

  test('empty buckets are null, not the -1 loop seeds (single-year view)', () {
    // A year whose goals are all Lifetime: no category, no month, no type
    // bucket can win, exactly like the RPC returning NULL from its LIMIT-1 CTEs.
    final stats = computeMacroGoalsStats(const [], '2026');

    expect(stats['best_category'], isNull);
    expect(stats['best_category_rate'], isNull);
    expect(stats['best_month'], isNull);
    expect(stats['best_month_rate'], isNull);
    expect(stats['best_type'], isNull);
    expect(stats['best_type_rate'], isNull);
  });

  test('a populated single year still reports its best buckets', () {
    final goals = <MacroGoal>[
      goal(
          status: GoalStatus.completed,
          year: 2026,
          month: 3,
          quarter: 1,
          categoryId: 'cat-a'),
      goal(
          status: GoalStatus.failed,
          year: 2026,
          month: 4,
          quarter: 2,
          categoryId: 'cat-b'),
    ];

    final stats = computeMacroGoalsStats(goals, '2026');

    expect(stats['best_category'], 'cat-a');
    expect(stats['best_category_rate'], 100);
    expect(stats['best_month'], 3);
    expect(stats['best_month_rate'], 100);
    expect(stats['best_type'], 'annual');
    expect(stats['best_type_rate'], 50);
  });
}
