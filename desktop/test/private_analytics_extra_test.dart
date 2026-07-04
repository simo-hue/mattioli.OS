// WS4b — correlations + macro-goal stats (ported from mobile's inline
// implementations in private_local_database.dart). Sanity fixtures.
import 'package:evolve_desktop/features/statistics/data/private_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeHabitCorrelations (get_habit_correlations)', () {
    test('co-completion count + percentage vs target done days', () {
      final logs = {
        '2026-06-01': {'g1': 'done', 'g2': 'done'},
        '2026-06-02': {'g1': 'done', 'g2': 'missed'},
        '2026-06-03': {'g1': 'done', 'g2': 'done'},
      };
      final res = computeHabitCorrelations('g1', logs);
      expect(res, hasLength(1));
      expect(res.first['goal_id'], 'g2');
      expect(res.first['together_count'], 2);
      expect(res.first['percentage'], 67); // (2/3*100).round()
    });

    test('no target-done days -> empty', () {
      final res = computeHabitCorrelations('g1', {
        '2026-06-01': {'g1': 'missed', 'g2': 'done'},
      });
      expect(res, isEmpty);
    });

    test('all correlations flattens ordered pairs', () {
      final logs = {
        '2026-06-01': {'g1': 'done', 'g2': 'done'},
      };
      final res = computeAllHabitCorrelations(['g1', 'g2'], logs);
      expect(res, hasLength(2)); // g1->g2 and g2->g1
      expect(res.every((r) => r['together_count'] == 1), isTrue);
    });
  });

  group('computeMacroGoalsStats (get_macro_goals_stats)', () {
    test('all: totals, success rate, type distribution', () {
      final goals = [
        const MacroGoalStat(
          status: 'completed',
          type: 'annual',
          year: 2025,
          quarter: 1,
          month: 1,
          categoryId: 'health',
        ),
        const MacroGoalStat(
          status: 'active',
          type: 'annual',
          year: 2025,
          quarter: 2,
          month: 4,
          categoryId: 'health',
        ),
        const MacroGoalStat(
          status: 'failed',
          type: 'monthly',
          year: 2026,
          quarter: 1,
          month: 2,
          categoryId: 'work',
        ),
      ];
      final stats = computeMacroGoalsStats(goals, 'all');
      expect(stats['total_goals'], 3);
      expect(stats['completed_goals'], 1);
      expect(stats['success_rate'], 33); // (1/3*100).round()
      expect((stats['type_distribution'] as Map)['annual'], 2);
      expect(stats['year_progression'], isA<List>());
    });

    test('specific year filters to that year only', () {
      final goals = [
        const MacroGoalStat(
          status: 'completed',
          type: 'annual',
          year: 2025,
          month: 1,
        ),
        const MacroGoalStat(
          status: 'active',
          type: 'annual',
          year: 2026,
          month: 4,
        ),
      ];
      final stats = computeMacroGoalsStats(goals, '2025');
      expect(stats['total_goals'], 1);
      expect(stats['completed_goals'], 1);
      expect(stats['success_rate'], 100);
      expect((stats['monthly_composed'] as List), hasLength(12));
    });
  });
}
