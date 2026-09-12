// The Insights rolling-trend and week-vs-average panels used to average
// `completionFor()` over CALENDAR days. `completionFor` returns a hard 0 when
// nothing is scheduled, so a perfectly kept Mon–Fri habit scored
// (5 * 1.0 + 2 * 0.0) / 7 = 71% — while the Momentum ring on the same page
// (fed by the habit-day counting `_windowCompletionRate`) said 100%, and the
// week-vs-average pill compared a habit-day figure against a calendar-day one.
//
// Every other completion formula in the app counts habit-days and guards an
// empty denominator (`_weekCompletionRate`, `_windowCompletionRate`,
// `_habitWindowRate`). `DashboardSnapshot.windowCompletionRate` is that same
// shape, and both panels now call it.
//
// (The year-calendar week bars and the contribution heatmap deliberately stay
// calendar-day density views; they are not covered here.)
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime shift(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  DashboardHabit habit({List<int>? frequencyDays}) => DashboardHabit(
    id: 'h1',
    title: 'Gym',
    color: Colors.blue,
    streak: 0,
    weeklyProgress: List.filled(7, false),
    state: HabitState.pending,
    startDate: DateTime(2000, 1, 1),
    frequencyDays: frequencyDays,
  );

  /// Logs [status] for h1 on every day in the inclusive window ending on
  /// [today], but only on days the habit is actually scheduled.
  Map<String, Map<String, String>> logs(
    DashboardHabit h,
    DateTime today,
    int days, {
    String status = 'done',
  }) {
    final out = <String, Map<String, String>>{};
    for (var ago = 0; ago < days; ago++) {
      final date = shift(today, -ago);
      if (!h.isScheduledOn(date)) continue;
      out[dashboardDateKey(date)] = {h.id: status};
    }
    return out;
  }

  DashboardSnapshot snapshotWith(
    DashboardHabit h,
    Map<String, Map<String, String>> habitLogs,
  ) => DashboardSnapshot(
    habits: [h],
    goals: const [],
    trend: const [],
    checkIn: const DailyCheckIn(),
    habitLogs: habitLogs,
  );

  // A Wednesday, so the 7- and 30-day windows below both straddle weekends.
  final today = DateTime(2026, 6, 10);

  test(
    'a fully kept Mon–Fri habit is 100% over a rolling window, not 71%',
    () {
      final h = habit(frequencyDays: const [1, 2, 3, 4, 5]);
      final snapshot = snapshotWith(h, logs(h, today, 60));

      expect(
        snapshot.windowCompletionRate(shift(today, -6), today),
        1.0,
        reason: 'unscheduled Sat/Sun must not be scored as 0% days',
      );
      expect(snapshot.windowCompletionRate(shift(today, -29), today), 1.0);
      expect(snapshot.windowCompletionRate(shift(today, -55), today), 1.0);
    },
  );

  test('an every-day habit still scores per habit-day', () {
    final h = habit();
    final snapshot = snapshotWith(h, logs(h, today, 7));
    expect(snapshot.windowCompletionRate(shift(today, -6), today), 1.0);
  });

  test('missed scheduled days still pull the rate down', () {
    final h = habit(frequencyDays: const [1, 2, 3, 4, 5]);
    // Mon 8th and Tue 9th missed, Wed 10th done → 1 of 3 scheduled days.
    final snapshot = snapshotWith(h, {
      dashboardDateKey(DateTime(2026, 6, 8)): {'h1': 'missed'},
      dashboardDateKey(DateTime(2026, 6, 9)): {'h1': 'missed'},
      dashboardDateKey(DateTime(2026, 6, 10)): {'h1': 'done'},
    });
    expect(
      snapshot.windowCompletionRate(DateTime(2026, 6, 6), today),
      closeTo(1 / 3, 1e-9),
      reason: 'Sat 6th and Sun 7th are unscheduled and must not count',
    );
  });

  test('a window with nothing scheduled is 0, not a division by zero', () {
    final h = habit(frequencyDays: const [6, 7]);
    final snapshot = snapshotWith(h, const {});
    // Mon 8th → Fri 12th: no scheduled day at all.
    expect(
      snapshot.windowCompletionRate(
        DateTime(2026, 6, 8),
        DateTime(2026, 6, 12),
      ),
      0,
    );
  });
}
