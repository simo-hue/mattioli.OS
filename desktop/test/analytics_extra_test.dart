// Unit tests for the net-new desktop statistics in analytics_extra.dart.
import 'package:evolve_desktop/features/statistics/data/analytics_extra.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

HabitLogEntry _log(String goal, String date, String status) =>
    HabitLogEntry(goalId: goal, date: DateTime.parse(date), status: status);

GoalInput _goal(String id, String start, {String? end, List<int>? freq}) =>
    GoalInput(
      id: id,
      startDate: DateTime.parse(start),
      endDate: end == null ? null : DateTime.parse(end),
      frequencyDays: freq,
    );

Map<String, Map<String, String>> _byDate(List<HabitLogEntry> logs) {
  final m = <String, Map<String, String>>{};
  for (final l in logs) {
    m.putIfAbsent(dateKey(l.date), () => {})[l.goalId] = l.status;
  }
  return m;
}

Map<String, List<HabitLogEntry>> _byGoal(List<HabitLogEntry> logs) {
  final m = <String, List<HabitLogEntry>>{};
  for (final l in logs) {
    m.putIfAbsent(l.goalId, () => []).add(l);
  }
  return m;
}

void main() {
  group('isGoalActiveOn', () {
    test('respects start, end and weekday frequency', () {
      // 2026-01-05 is a Monday.
      final g = _goal('g', '2026-01-05', freq: [1]); // Mondays only
      expect(isGoalActiveOn(g, DateTime.parse('2026-01-05')), isTrue);
      expect(isGoalActiveOn(g, DateTime.parse('2026-01-06')), isFalse); // Tue
      expect(isGoalActiveOn(g, DateTime.parse('2026-01-04')), isFalse); // pre
    });

    test('null frequency = every day within window', () {
      final g = _goal('g', '2026-01-01', end: '2026-01-03');
      expect(isGoalActiveOn(g, DateTime.parse('2026-01-02')), isTrue);
      expect(isGoalActiveOn(g, DateTime.parse('2026-01-04')), isFalse);
    });
  });

  group('computeLifetimeSummary', () {
    test('totals, tracked days, consistency and perfect days', () {
      final logs = [
        _log('g1', '2026-01-01', 'done'),
        _log('g1', '2026-01-02', 'done'),
        _log('g1', '2026-01-03', 'missed'),
        _log('g1', '2026-01-04', 'done'),
      ];
      final s = computeLifetimeSummary(
        allLogs: logs,
        goals: [_goal('g1', '2026-01-01')],
        logsByDate: _byDate(logs),
        today: DateTime.parse('2026-01-05'),
      );
      expect(s.totalCompletions, 3);
      expect(s.totalMissed, 1);
      expect(s.activeDays, 4);
      expect(s.trackedDays, 5); // Jan 1..5 inclusive
      expect(s.consistency, closeTo(60, 0.01)); // 3 done / 5 active days
      expect(s.perfectDays, 3); // 01,02,04 all-done days
      expect(s.firstLogDate, DateTime.parse('2026-01-01'));
    });

    test('perfect day requires every active habit done', () {
      final logs = [
        _log('g1', '2026-01-01', 'done'),
        _log('g2', '2026-01-01', 'done'),
        _log('g1', '2026-01-02', 'done'),
        _log('g2', '2026-01-02', 'missed'),
      ];
      final s = computeLifetimeSummary(
        allLogs: logs,
        goals: [_goal('g1', '2026-01-01'), _goal('g2', '2026-01-01')],
        logsByDate: _byDate(logs),
        today: DateTime.parse('2026-01-02'),
      );
      expect(s.perfectDays, 1); // only Jan 1 has both done
    });

    test('empty input yields zeros', () {
      final s = computeLifetimeSummary(
        allLogs: const [],
        goals: const [],
        logsByDate: const {},
        today: DateTime.parse('2026-01-05'),
      );
      expect(s.totalCompletions, 0);
      expect(s.consistency, 0);
      expect(s.trackedDays, 0);
      expect(s.firstLogDate, isNull);
    });
  });

  group('computeKeystoneHabit', () {
    test('picks the habit whose done days lift the others', () {
      final logs = [
        for (final d in ['2026-01-01', '2026-01-02', '2026-01-03']) ...[
          _log('g1', d, 'done'),
          _log('g2', d, 'done'),
        ],
        for (final d in ['2026-01-04', '2026-01-05']) ...[
          _log('g1', d, 'missed'),
          _log('g2', d, 'missed'),
        ],
      ];
      final k = computeKeystoneHabit(
        goals: [_goal('g1', '2026-01-01'), _goal('g2', '2026-01-01')],
        logsByDate: _byDate(logs),
      );
      expect(k, isNotNull);
      expect(k!.goalId, 'g1'); // first-wins on the tie
      expect(k.withRate, closeTo(100, 0.01));
      expect(k.withoutRate, closeTo(0, 0.01));
      expect(k.lift, closeTo(100, 0.01));
      expect(k.doneDays, 3);
    });

    test('null with fewer than two habits', () {
      final k = computeKeystoneHabit(
        goals: [_goal('g1', '2026-01-01')],
        logsByDate: _byDate([_log('g1', '2026-01-01', 'done')]),
      );
      expect(k, isNull);
    });

    test('null when signal is too thin', () {
      final logs = [
        _log('g1', '2026-01-01', 'done'),
        _log('g2', '2026-01-01', 'done'),
      ];
      final k = computeKeystoneHabit(
        goals: [_goal('g1', '2026-01-01'), _goal('g2', '2026-01-01')],
        logsByDate: _byDate(logs),
      );
      expect(k, isNull); // <3 done-days
    });
  });

  group('computeBounceBackRate', () {
    test('recovery after a miss on the next tracked day', () {
      final logs = [
        _log('g1', '2026-01-01', 'missed'),
        _log('g1', '2026-01-02', 'done'),
        _log('g1', '2026-01-03', 'missed'),
        _log('g1', '2026-01-04', 'missed'),
        _log('g1', '2026-01-05', 'done'),
      ];
      final b = computeBounceBackRate(logsByGoal: _byGoal(logs));
      expect(b.opportunities, 3); // misses at 01, 03, 04
      expect(b.recoveries, 2); // 01->02 done, 04->05 done
      expect(b.globalRate, closeTo(66.67, 0.1));
      expect(b.habits.single.goalId, 'g1');
    });

    test('skipped days are scanned through, global aggregates habits', () {
      final logs = [
        // g1: one miss recovered
        _log('g1', '2026-01-01', 'missed'),
        _log('g1', '2026-01-02', 'done'),
        // g2: miss, then skip, then done -> recovered
        _log('g2', '2026-01-01', 'missed'),
        _log('g2', '2026-01-02', 'skipped'),
        _log('g2', '2026-01-03', 'done'),
      ];
      final b = computeBounceBackRate(logsByGoal: _byGoal(logs));
      expect(b.opportunities, 2);
      expect(b.recoveries, 2);
      expect(b.globalRate, 100);
    });

    test('trailing miss with no following log is not an opportunity', () {
      final logs = [
        _log('g1', '2026-01-01', 'done'),
        _log('g1', '2026-01-02', 'missed'),
      ];
      final b = computeBounceBackRate(logsByGoal: _byGoal(logs));
      expect(b.opportunities, 0);
      expect(b, isNotNull);
      expect(b.habits, isEmpty);
    });
  });

  group('computeWeekdayWeekendSplit', () {
    test('splits Mon–Fri vs Sat–Sun (skipped excluded)', () {
      // 2026-01-01 Thu, 02 Fri, 03 Sat, 04 Sun, 05 Mon.
      final logs = [
        _log('g1', '2026-01-01', 'done'), // Thu
        _log('g1', '2026-01-02', 'missed'), // Fri
        _log('g1', '2026-01-05', 'done'), // Mon
        _log('g1', '2026-01-03', 'done'), // Sat
        _log('g1', '2026-01-04', 'missed'), // Sun
        _log('g1', '2026-01-06', 'skipped'), // Tue, ignored
      ];
      final w = computeWeekdayWeekendSplit(logs);
      expect(w.weekdayDone, 2);
      expect(w.weekdayTotal, 3);
      expect(w.weekdayRate, closeTo(66.67, 0.1));
      expect(w.weekendDone, 1);
      expect(w.weekendTotal, 2);
      expect(w.weekendRate, 50);
    });
  });

  group('computeGlobalWeekdayPerformance', () {
    test('always 7 entries Mon→Sun with per-day rates', () {
      final logs = [
        _log('g1', '2026-01-01', 'done'), // Thu (4)
        _log('g2', '2026-01-01', 'missed'), // Thu (4)
      ];
      final rows = computeGlobalWeekdayPerformance(logs);
      expect(rows, hasLength(7));
      expect(rows[0].dayIndex, 1);
      final thu = rows[3];
      expect(thu.dayIndex, 4);
      expect(thu.done, 1);
      expect(thu.total, 2);
      expect(thu.rate, 50);
    });
  });

  group('computeSeasonality', () {
    test('12 months, grouping across years', () {
      final logs = [
        _log('g1', '2025-01-10', 'done'),
        _log('g1', '2026-01-20', 'missed'),
        _log('g1', '2026-03-01', 'done'),
      ];
      final rows = computeSeasonality(logs);
      expect(rows, hasLength(12));
      expect(rows[0].month, 1);
      expect(rows[0].done, 1);
      expect(rows[0].total, 2);
      expect(rows[2].done, 1); // March
      expect(rows[1].total, 0); // February untouched
    });
  });

  group('computeConsistencyScores', () {
    test('perfectly regular habit scores 100, erratic scores lower', () {
      final logs = [
        // g1: every 2 days exactly
        _log('g1', '2026-01-01', 'done'),
        _log('g1', '2026-01-03', 'done'),
        _log('g1', '2026-01-05', 'done'),
        _log('g1', '2026-01-07', 'done'),
        // g2: erratic gaps
        _log('g2', '2026-01-01', 'done'),
        _log('g2', '2026-01-02', 'done'),
        _log('g2', '2026-01-09', 'done'),
        _log('g2', '2026-01-10', 'done'),
      ];
      final scores = computeConsistencyScores(_byGoal(logs));
      expect(scores, hasLength(2));
      expect(scores.first.goalId, 'g1'); // steadiest sorted first
      expect(scores.first.score, closeTo(100, 0.01));
      expect(scores.last.score, lessThan(100));
    });

    test('omits habits with fewer than three completions', () {
      final logs = [
        _log('g1', '2026-01-01', 'done'),
        _log('g1', '2026-01-02', 'done'),
      ];
      expect(computeConsistencyScores(_byGoal(logs)), isEmpty);
    });
  });

  group('computeDangerZone', () {
    test('picks the weekday where done->missed breaks cluster', () {
      // 2026-01-02 Fri, 01-09 Fri, 01-05 Mon.
      final logs = [
        // g1: done Thu(01) -> missed Fri(02)  => break on Fri
        _log('g1', '2026-01-01', 'done'),
        _log('g1', '2026-01-02', 'missed'),
        // g2: done Thu(08) -> missed Fri(09)  => break on Fri
        _log('g2', '2026-01-08', 'done'),
        _log('g2', '2026-01-09', 'missed'),
        // g3: done Sun(04) -> missed Mon(05)  => break on Mon
        _log('g3', '2026-01-04', 'done'),
        _log('g3', '2026-01-05', 'missed'),
      ];
      final d = computeDangerZone(_byGoal(logs));
      expect(d, isNotNull);
      expect(d!.weekday, 5); // Friday
      expect(d.breaks, 2);
      expect(d.totalBreaks, 3);
    });

    test('null when nothing breaks', () {
      final logs = [
        _log('g1', '2026-01-01', 'done'),
        _log('g1', '2026-01-02', 'done'),
      ];
      expect(computeDangerZone(_byGoal(logs)), isNull);
    });
  });

  group('computeMomentumScore', () {
    test('weighted composite 50/30/20', () {
      final m = computeMomentumScore(
        rate7: 1.0,
        ratePrev7: 1.0,
        streaks: [(current: 5, best: 5)],
      );
      // 0.5*1 + 0.3*1 + 0.2*0.5 = 0.9
      expect(m.score, closeTo(90, 0.001));
      expect(m.streakHealth, 1);
      expect(m.trend, 0.5);
    });

    test('empty streaks and zero rate -> trend-only floor', () {
      final m = computeMomentumScore(rate7: 0, ratePrev7: 0, streaks: const []);
      expect(m.streakHealth, 0);
      expect(m.score, closeTo(10, 0.001)); // 0.2*0.5*100
    });

    test('improving trend lifts the score', () {
      final m = computeMomentumScore(
        rate7: 0.8,
        ratePrev7: 0.3,
        streaks: [(current: 4, best: 8)],
      );
      // trend = clamp(0.5 + 0.5) = 1.0; streakHealth = 0.5
      // 0.5*0.8 + 0.3*0.5 + 0.2*1.0 = 0.4 + 0.15 + 0.2 = 0.75
      expect(m.score, closeTo(75, 0.001));
    });
  });
}
