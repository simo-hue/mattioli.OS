import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/statistics/presentation/statistics_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The year contribution heatmaps walk 365 *calendar* days. Duration arithmetic
/// cannot express that walk: a 24h step lands at 23:00/01:00 of an adjacent day
/// across a DST transition, so `dashboardDateKey` reads a neighbouring day's
/// data for every cell between the fall-back and the following spring-forward.
///
/// A 365-day window in a DST zone always straddles both transitions, so the
/// defect is unconditional there — but invisible under a DST-free zone. CI runs
/// at TZ=UTC, where these assertions hold for the broken walk too; the anchors
/// below only bite in a DST-observing zone such as the maintainer's own
/// Europe/Rome (the machine default), which is where they were verified to
/// catch the regression:
///
///   TZ=Europe/Rome flutter test test/year_heatmap_dst_test.dart
///   TZ=America/New_York flutter test test/year_heatmap_dst_test.dart
void main() {
  DateTime shift(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  /// Every calendar day of [year] whose local length differs from 24h.
  List<DateTime> transitionDays(int year) {
    final found = <DateTime>[];
    var d = DateTime(year, 1, 1);
    while (d.year == year) {
      final next = shift(d, 1);
      if (next.difference(d) != const Duration(hours: 24)) found.add(d);
      d = next;
    }
    return found;
  }

  /// A plain mid-week day, plus every day whose 365-day window ends on or just
  /// after a DST transition.
  List<DateTime> anchors() => [
    DateTime(2025, 6, 11),
    for (final y in [2024, 2025, 2026])
      for (final t in transitionDays(y)) ...[t, shift(t, 1), shift(t, 200)],
  ];

  DashboardSnapshot snapshotWith({
    Map<String, Map<String, String>> logs = const {},
    List<DashboardHabit> habits = const [],
  }) => DashboardSnapshot(
    habits: habits,
    goals: const [],
    trend: const [],
    checkIn: const DailyCheckIn(),
    habitLogs: logs,
  );

  DashboardHabit habit(String id) => DashboardHabit(
    id: id,
    title: id,
    color: Colors.blue,
    streak: 0,
    weeklyProgress: List.filled(7, false),
    state: HabitState.pending,
    startDate: DateTime(2000, 1, 1),
  );

  group('yearHeatmapDays walks calendar days across DST transitions', () {
    test('covers 365 distinct consecutive days ending on today', () {
      for (final today in anchors()) {
        final days = yearHeatmapDays(today);

        expect(days, hasLength(365), reason: 'window for $today');
        expect(
          days.toSet(),
          hasLength(365),
          reason: 'a day is duplicated and another lost for today=$today',
        );
        expect(days.last, today, reason: 'window must end on today=$today');
        expect(
          days.first,
          shift(today, -364),
          reason: 'window must start 364 days back from today=$today',
        );

        for (var i = 0; i < 365; i++) {
          expect(
            days[i],
            shift(today, -364 + i),
            reason: 'cell $i of the window ending $today',
          );
        }
      }
    });

    test('every day sits at local midnight, so date keys are unambiguous', () {
      for (final today in anchors()) {
        for (final day in yearHeatmapDays(today)) {
          expect(
            [day.hour, day.minute, day.second],
            [0, 0, 0],
            reason: '$day drifted off midnight in the window ending $today',
          );
        }
      }
    });
  });

  group('heatmap cells key the calendar day they render', () {
    test('habitYearlyStatuses maps each status onto its own day', () {
      for (final today in anchors()) {
        // Mark one day 'done' and the next 'missed', at three offsets that
        // straddle the transitions a 365-day window always contains.
        for (final offset in [-364, -200, -104, -1, 0]) {
          final done = shift(today, offset);
          final missed = shift(done, 1);
          final logs = {
            dashboardDateKey(done): {'h1': 'done'},
            if (!missed.isAfter(today)) dashboardDateKey(missed): {
              'h1': 'missed',
            },
          };

          final statuses = habitYearlyStatuses(
            snapshotWith(logs: logs),
            'h1',
            today,
          );
          final doneIndex = 364 + offset;

          expect(
            statuses[doneIndex],
            1,
            reason: 'done on ${dashboardDateKey(done)} (today=$today)',
          );
          if (!missed.isAfter(today)) {
            expect(
              statuses[doneIndex + 1],
              2,
              reason: 'missed on ${dashboardDateKey(missed)} (today=$today)',
            );
          }
          expect(
            statuses.where((s) => s != 0).length,
            logs.length,
            reason: 'exactly the logged days are non-zero (today=$today)',
          );
        }
      }
    });

    test('yearContributionValues scores each habit on its own day', () {
      for (final today in anchors()) {
        for (final offset in [-364, -200, -104, 0]) {
          final day = shift(today, offset);
          final values = yearContributionValues(
            snapshotWith(
              habits: [habit('h1')],
              logs: {
                dashboardDateKey(day): {'h1': 'done'},
              },
            ),
            today,
          );

          expect(values, hasLength(365));
          expect(
            values[364 + offset],
            1.0,
            reason: 'completion for ${dashboardDateKey(day)} (today=$today)',
          );
          expect(
            values.where((v) => v > 0).length,
            1,
            reason: 'only the logged day is active (today=$today)',
          );
        }
      }
    });
  });
}
