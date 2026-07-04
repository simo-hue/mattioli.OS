// WS4 — Local analytics engine parity.
//
// Ported VERBATIM from the mobile client's `test/private_analytics_test.dart`
// (only the import changed). Same fixtures + same expectations = proof the
// desktop analytics engine computes byte-identically to mobile / the cloud RPCs.
import 'package:evolve_desktop/features/statistics/data/private_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 6, 15);
  DateTime d(int month, int day) => DateTime(2026, month, day);

  HabitLogEntry log(
    String goal,
    DateTime date,
    String status, [
    int streak = 0,
  ]) => HabitLogEntry(goalId: goal, date: date, status: status, streak: streak);

  group('computeHabitStatsRow (habit_stats view)', () {
    test('streaks, counts, active days and rate', () {
      final logs = [
        log('g1', d(6, 10), 'done', 1),
        log('g1', d(6, 11), 'done', 2),
        log('g1', d(6, 12), 'missed', -1),
        log('g1', d(6, 13), 'done', 1),
      ];
      final row = computeHabitStatsRow(
        goalId: 'g1',
        userId: 'u1',
        title: 'Read',
        startDate: d(6, 6), // 9 days before today -> 10 active days
        logs: logs,
        today: today,
      );

      expect(row['current_streak'], 1); // latest log (06-13)
      expect(row['best_streak'], 2); // max streak among 'done'
      expect(row['worst_streak'], 1); // abs(min streak among 'missed')
      expect(row['total_completions'], 3);
      expect(row['missed_days'], 1);
      expect(row['total_active_days'], 10);
      expect(row['rate'], closeTo(30.0, 1e-9)); // 3 * 100 / 10
    });

    test('goal with no logs yields zeros and >=1 active day', () {
      final row = computeHabitStatsRow(
        goalId: 'g1',
        userId: 'u1',
        title: null,
        startDate: today,
        logs: const [],
        today: today,
      );
      expect(row['current_streak'], 0);
      expect(row['best_streak'], 0);
      expect(row['total_active_days'], 1);
      expect(row['rate'], 0.0);
    });
  });

  group('computeYearlyGrid (get_habit_yearly_grid)', () {
    test('365 entries, done=1, missed=2, newest last', () {
      final grid = computeYearlyGrid([
        log('g1', d(6, 15), 'done'),
        log('g1', d(6, 14), 'missed'),
        log('g1', d(6, 13), 'skipped'),
      ], today);
      expect(grid.length, 365);
      expect(grid.last, 1); // today, done
      expect(grid[363], 2); // yesterday, missed
      expect(grid[362], 0); // skipped -> 0
    });
  });

  group('computePerformanceByDay (get_habit_performance_by_day)', () {
    test('groups by ISODOW (1=Mon..7=Sun)', () {
      final monday = d(6, 15);
      final nextMonday = d(6, 22);
      final tuesday = d(6, 16);
      final rows = computePerformanceByDay([
        log('g1', monday, 'done'),
        log('g1', nextMonday, 'missed'),
        log('g1', tuesday, 'done'),
      ]);
      final byDow = {for (final r in rows) r['day_index'] as int: r};
      expect(byDow[monday.weekday]!['total_count'], 2);
      expect(byDow[monday.weekday]!['done_count'], 1);
      expect(byDow[tuesday.weekday]!['total_count'], 1);
      // ascending day_index
      final indices = rows.map((r) => r['day_index'] as int).toList();
      final sorted = [...indices]..sort();
      expect(indices, sorted);
    });
  });

  group('computeHabitAlerts (get_habit_alerts)', () {
    test('longest missed run + broken streaks ordered by break date desc', () {
      final logs = [
        log('g1', d(6, 1), 'done'),
        log('g1', d(6, 2), 'done'),
        log('g1', d(6, 3), 'done'),
        log('g1', d(6, 4), 'missed'),
        log('g1', d(6, 5), 'missed'),
        log('g1', d(6, 6), 'done'),
        log('g1', d(6, 7), 'missed'),
      ];
      final alerts = computeHabitAlerts(logs);
      expect(alerts['worst_negative_days'], 2);
      expect(alerts['worst_negative_start'], '2026-06-04');

      final broken = alerts['broken_streaks'] as List;
      expect(broken.length, 2);
      // most recent break first
      expect(broken[0], {'days': 1, 'date': '2026-06-07'});
      expect(broken[1], {'days': 3, 'date': '2026-06-04'});
    });

    test('no missed logs -> empty alerts', () {
      final alerts = computeHabitAlerts([log('g1', d(6, 1), 'done')]);
      expect(alerts['worst_negative_days'], 0);
      expect(alerts['worst_negative_start'], isNull);
      expect(alerts['broken_streaks'], isEmpty);
    });
  });

  group('computeAnalyticsRow (get_habit_analytics)', () {
    test('worst_dow = lowest done-rate weekday', () {
      final mondayA = d(6, 15);
      final mondayB = d(6, 22);
      final tuesday = d(6, 16);
      final row = computeAnalyticsRow(
        goalId: 'g1',
        logs: [
          log('g1', mondayA, 'done'),
          log('g1', mondayB, 'missed'), // Monday rate 0.5
          log('g1', tuesday, 'done'), // Tuesday rate 1.0
        ],
      );
      expect(row['worst_dow'], mondayA.weekday);
    });

    test('avg_recovery_days = mean gap between done logs', () {
      final row = computeAnalyticsRow(
        goalId: 'g1',
        logs: [
          log('g1', d(6, 1), 'done'),
          log('g1', d(6, 4), 'done'), // gap of 3 days -> 2 non-done days
        ],
      );
      expect(row['avg_recovery_days'], closeTo(2.0, 1e-9));
    });

    test('no logs -> worst_dow defaults to 1, recovery 0', () {
      final row = computeAnalyticsRow(goalId: 'g1', logs: const []);
      expect(row['worst_dow'], 1);
      expect(row['avg_recovery_days'], 0.0);
    });
  });

  group('computeGlobalCriticalDay (get_global_critical_day)', () {
    test('returns lowest done-rate weekday token', () {
      final monday = d(6, 15);
      final tuesday = d(6, 16);
      final token = computeGlobalCriticalDay([
        log('g1', monday, 'missed'), // Monday rate 0
        log('g1', tuesday, 'done'), // Tuesday rate 1
      ]);
      expect(token, kIsoDowTokens[monday.weekday - 1]);
    });

    test('no logs -> N/A', () {
      expect(computeGlobalCriticalDay(const []), 'N/A');
    });
  });

  group('computeCriticalHabits (get_critical_habits)', () {
    test('drop vs last week and neg streak', () {
      final res = computeCriticalHabits(
        goals: [GoalInput(id: 'g1', startDate: d(1, 1))],
        logsByGoal: {
          'g1': [
            log('g1', d(6, 5), 'done'), // last week (age 10) rate 1.0
            log('g1', d(6, 9), 'missed'), // this week
            log('g1', d(6, 10), 'missed'), // this week rate 0.0
          ],
        },
        today: today,
      );
      expect(res, hasLength(1));
      expect(res.first['drop'], closeTo(100.0, 1e-9));
      expect(res.first['neg_streak'], 10); // today - last done (06-05)
    });
  });

  group('computeBestHabits (get_best_habits)', () {
    test('all timeframe: rate over all logs, current positive streak', () {
      final res = computeBestHabits(
        goals: [GoalInput(id: 'g1', startDate: d(1, 1))],
        logsByGoal: {
          'g1': [
            log('g1', d(6, 10), 'missed'),
            log('g1', d(6, 11), 'done'),
            log('g1', d(6, 12), 'done'),
          ],
        },
        timeframe: 'all',
        today: today,
      );
      expect(res.first['rate'], closeTo(66.66666, 1e-3)); // 2/3
      expect(res.first['streak'], 2); // 2 done after last non-done
    });

    test('defensive: unrecognised token -> empty window, rate 0', () {
      final res = computeBestHabits(
        goals: [GoalInput(id: 'g1', startDate: d(1, 1))],
        logsByGoal: {
          'g1': [log('g1', d(6, 11), 'done'), log('g1', d(6, 12), 'done')],
        },
        timeframe: 'timeframe_week_short',
        today: today,
      );
      expect(res.first['rate'], 0.0);
      expect(res.first['streak'], 2);
    });
  });

  group('computeGlobalTrend (get_global_trend)', () {
    GoalInput alwaysActive(String id) => GoalInput(id: id, startDate: d(1, 1));

    test('week: 14 daily points, indices 0..13, dates today-13..today', () {
      final points = computeGlobalTrend(
        goals: [alwaysActive('g1')],
        logs: const {},
        timeframe: 'timeframe_week_short',
        today: today,
      );
      expect(points, hasLength(14));
      expect(points.first['point_index'], 0);
      expect(points.last['point_index'], 13);
      expect(
        points.first['date'],
        dateKey(today.subtract(const Duration(days: 13))),
      );
      expect(points.last['date'], dateKey(today));
      // active but never done -> rate 0
      expect(points.last['rate'], 0.0);
    });

    test('week: a fully-done active day yields rate 100', () {
      final points = computeGlobalTrend(
        goals: [alwaysActive('g1')],
        logs: {
          dateKey(today): {'g1': 'done'},
        },
        timeframe: 'timeframe_week_short',
        today: today,
      );
      expect(points.last['rate'], 100.0);
    });

    test('month: 60 daily points', () {
      final points = computeGlobalTrend(
        goals: [alwaysActive('g1')],
        logs: const {},
        timeframe: 'timeframe_month_short',
        today: today,
      );
      expect(points, hasLength(60));
    });

    test('year: 24 monthly points ending on the current month', () {
      final points = computeGlobalTrend(
        goals: [alwaysActive('g1')],
        logs: const {},
        timeframe: 'timeframe_year_short',
        today: today,
      );
      expect(points, hasLength(24));
      expect(
        points.last['date'],
        dateKey(DateTime(today.year, today.month, 1)),
      );
    });

    test('all: buckets from earliest start to today', () {
      final points = computeGlobalTrend(
        goals: [
          GoalInput(
            id: 'g1',
            startDate: today.subtract(const Duration(days: 5)),
          ),
        ],
        logs: const {},
        timeframe: 'timeframe_all',
        today: today,
      );
      // days = 5 (<=10) -> pointsCount = days + 1 = 6, interval 1.
      expect(points, hasLength(6));
      expect(points.first['point_index'], 0);
      expect(points.last['point_index'], 5);
    });
  });
}
