// The Info-tab lifetime figures count calendar days, not 24-hour blocks.
//
//   TZ=Europe/Rome flutter test test/analytics_extra_dst_test.dart
//
// `computeLifetimeSummary` used `today.difference(start).inDays + 1` on local
// midnights, so any habit whose start predates a spring-forward transition was
// credited one active day fewer than the mobile-mirrored `computeHabitStatsRow`
// gives the very same habit on the very same screen: `trackedDays` read one
// short and Consistency % — done ÷ active days — read high off the shrunken
// denominator (for a fully-completed habit it can exceed 100%).
//
// The invariants asserted are zone-independent (they compare the two engines
// against each other), so this suite passes in CI's UTC and can only *fail*
// where a transition falls inside the span.
import 'package:evolve_desktop/features/statistics/data/analytics_extra.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Europe/Rome springs forward 2026-03-29 and falls back 2026-10-25.
  for (final today in [
    DateTime(2026, 3, 30), // the day after spring-forward
    DateTime(2026, 6, 15), // one transition behind us
    DateTime(2026, 10, 26), // spring-forward and fall-back both behind us
  ]) {
    test(
      'lifetime active days agree with computeHabitStatsRow on '
      '${today.month}/${today.day}',
      () {
        final start = DateTime(2026, 1, 1);
        final logs = [
          HabitLogEntry(
            goalId: 'g1',
            date: DateTime(2026, 1, 2),
            status: 'done',
          ),
          HabitLogEntry(
            goalId: 'g1',
            date: DateTime(2026, 1, 3),
            status: 'done',
          ),
        ];

        final row = computeHabitStatsRow(
          goalId: 'g1',
          userId: 'u',
          title: 'g1',
          startDate: start,
          logs: logs,
          today: today,
        );
        final activeDays = row['total_active_days'] as int;

        final s = computeLifetimeSummary(
          allLogs: logs,
          goals: [GoalInput(id: 'g1', startDate: start)],
          logsByDate: {
            for (final l in logs) dateKey(l.date): {l.goalId: l.status},
          },
          today: today,
        );

        expect(
          s.trackedDays,
          activeDays,
          reason: 'trackedDays must count the same calendar days as the '
              'per-habit row rendered on the same screen',
        );
        // Consistency shares that denominator, so a short count inflates it.
        expect(s.consistency, closeTo(row['rate'] as double, 1e-9));
      },
    );
  }
}
