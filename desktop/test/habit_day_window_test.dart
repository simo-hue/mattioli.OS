// The rolling window behind the habit dot strips: the 7 calendar days ending
// TODAY, so the last mark is always the day the user is living in. It replaced a
// Mon..Sun grid read (`weeklyProgress`), which put today last only on Sundays.
//
// `weeklyProgress` itself keeps its weekday meaning — statistics ask "how are
// Mondays going?" — so it survives here only as the current-week fallback for a
// snapshot whose log map lags it.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DashboardHabit habitWith({
    List<bool>? week,
    DateTime? startDate,
    List<int>? frequencyDays,
  }) => DashboardHabit(
    id: 'h1',
    title: 'Read',
    color: EvolveColors.primaryStrong,
    streak: 0,
    weeklyProgress: week ?? List.filled(7, false),
    state: HabitState.pending,
    startDate: startDate,
    frequencyDays: frequencyDays,
  );

  DashboardSnapshot snapshotWith(
    DashboardHabit habit, [
    Map<String, Map<String, String>> logs = const {},
  ]) => DashboardSnapshot(
    habits: [habit],
    goals: const [],
    trend: const [],
    checkIn: const DailyCheckIn(),
    habitLogs: logs,
  );

  Map<String, Map<String, String>> log(Map<DateTime, String> entries) => {
    for (final entry in entries.entries)
      dashboardDateKey(entry.key): {'h1': entry.value},
  };

  DateTime shift(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  group('habitWindowDays', () {
    test('is the 7 calendar days ending on today, oldest first', () {
      final today = DateTime(2026, 7, 27);
      final days = habitWindowDays(today);

      expect(days, hasLength(7));
      expect(days.last, today, reason: 'the last mark must be today');
      expect(days.first, DateTime(2026, 7, 21));
      for (var i = 1; i < days.length; i++) {
        expect(days[i], shift(days[i - 1], 1));
      }
    });

    test('reaches back across a month boundary', () {
      expect(habitWindowDays(DateTime(2026, 3, 3)).first, DateTime(2026, 2, 25));
    });

    test('reaches back across a year boundary', () {
      expect(habitWindowDays(DateTime(2026, 1, 2)).first, DateTime(2025, 12, 27));
    });

    // A duration steps a fixed 24 h. Walking the window forward from `today - 6`
    // that way lands at 23:00/01:00 of a neighbouring day across a DST
    // transition — in Europe/Rome it renders 25 October twice and never renders
    // 26 October, so the "today" mark is yesterday's data.
    //
    // CI runs at TZ=UTC, where the assertions below hold for the broken walk
    // too. They only bite in a DST-observing zone — which is the maintainer's
    // own Europe/Rome, and where they were verified:
    //
    //   TZ=Europe/Rome flutter test test/habit_day_window_test.dart
    //   TZ=America/New_York flutter test test/habit_day_window_test.dart
    group('DST', () {
      /// Every calendar day of [year] whose local length differs from 24 h.
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

      /// Every anchor whose 7-day window straddles a transition, i.e. the six
      /// days after one — plus the transition day itself.
      List<DateTime> anchors() => [
        for (final year in [2025, 2026, 2027])
          for (final transition in transitionDays(year))
            for (var offset = 0; offset <= 6; offset++)
              shift(transition, offset),
      ];

      test('a window straddling a transition still walks 7 distinct days', () {
        for (final anchor in anchors()) {
          final days = habitWindowDays(anchor);
          expect(
            days.map(dashboardDateKey).toSet(),
            hasLength(7),
            reason: 'window ending $anchor repeats or skips a day',
          );
          expect(days.last, anchor);
          expect(days.first, shift(anchor, -6));
        }
      });

      test('a log on the transition day is read exactly once', () {
        for (final anchor in anchors()) {
          final transitionDay = shift(anchor, -1);
          final snapshot = snapshotWith(
            habitWith(),
            log({transitionDay: 'done'}),
          );

          final statuses = snapshot.habitWindowStatuses(
            snapshot.habits.first,
            anchor,
          );

          expect(
            statuses.where((status) => status == 'done'),
            hasLength(1),
            reason: 'window ending $anchor mis-read $transitionDay',
          );
        }
      });
    });
  });

  group('habitWindowStatuses', () {
    final today = DateTime(2026, 7, 27);

    test('is index-aligned with the window days, oldest → today', () {
      final snapshot = snapshotWith(
        habitWith(),
        log({
          shift(today, -6): 'done',
          shift(today, -3): 'missed',
          today: 'done',
        }),
      );

      expect(snapshot.habitWindowStatuses(snapshot.habits.first, today), [
        'done',
        null,
        null,
        'missed',
        null,
        null,
        'done',
      ]);
    });

    test('keeps a missed day distinct from an unrecorded one', () {
      final snapshot = snapshotWith(habitWith(), log({today: 'missed'}));

      expect(
        snapshot.habitWindowStatuses(snapshot.habits.first, today).last,
        'missed',
        reason: 'an explicit "no" is a contribution too',
      );
    });

    test('ignores the day before the window opens', () {
      final snapshot = snapshotWith(
        habitWith(),
        log({shift(today, -7): 'done'}),
      );

      expect(
        snapshot.habitWindowStatuses(snapshot.habits.first, today),
        everyElement(isNull),
      );
    });

    test('leaves days before the habit existed unrecorded, not missed', () {
      final snapshot = snapshotWith(
        habitWith(startDate: today),
        log({today: 'done'}),
      );

      final statuses = snapshot.habitWindowStatuses(
        snapshot.habits.first,
        today,
      );
      expect(statuses.take(6), everyElement(isNull));
      expect(statuses.last, 'done');
    });

    test('does not invent outcomes for unscheduled weekdays', () {
      // Monday-only habit: the other six days of the window are simply blank.
      final snapshot = snapshotWith(habitWith(frequencyDays: const [1]));

      expect(
        snapshot.habitWindowStatuses(snapshot.habits.first, today),
        everyElement(isNull),
      );
    });

    // `_isDashboardCurrentWeek` reads the real wall clock, so this pair runs
    // against today rather than a pinned date.
    group('current-week fallback', () {
      test('fills a logless day from this week\'s Mon..Sun grid', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final snapshot = snapshotWith(habitWith(week: List.filled(7, true)));

        final days = habitWindowDays(today);
        final statuses = snapshot.habitWindowStatuses(
          snapshot.habits.first,
          today,
        );
        final monday = shift(today, -(today.weekday - 1));

        for (var i = 0; i < days.length; i++) {
          final inThisWeek = !days[i].isBefore(monday);
          expect(
            statuses[i],
            inThisWeek ? 'done' : isNull,
            reason:
                '${days[i]} is ${inThisWeek ? 'in' : 'outside'} the current '
                'week; the grid is Mon..Sun for THIS week only, so reading it '
                'for an older day would mark a day that never happened',
          );
        }
      });

      test('a real log always wins over the grid', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final snapshot = snapshotWith(
          habitWith(week: List.filled(7, true)),
          log({today: 'missed'}),
        );

        expect(
          snapshot.habitWindowStatuses(snapshot.habits.first, today).last,
          'missed',
        );
      });

      test('completionFor still honours the same precedence', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        expect(
          snapshotWith(habitWith(week: List.filled(7, true))).completionFor(today),
          1,
        );
        expect(
          snapshotWith(
            habitWith(week: List.filled(7, true)),
            log({today: 'missed'}),
          ).completionFor(today),
          0,
        );
      });
    });
  });
}
