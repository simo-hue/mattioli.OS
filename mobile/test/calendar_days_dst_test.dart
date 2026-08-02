// Mirror of the desktop client's calendar_days_dst_test — the weekly view builds
// its seven day cells, and pages between weeks, with calendar arithmetic rather
// than 24-hour Durations.
//
//   TZ=Europe/Rome flutter test test/calendar_days_dst_test.dart
//
// The mobile case is the worse of the two: `_WeeklyViewWidgetState` keeps a
// running `_currentWeekStart` and each ‹ › press shifted it by a Duration, so a
// one-hour DST slip was PERMANENT — every later week stayed a day off, the grid
// showed MON..SUN labels over TUE..MON dates, and tapping a cell opened the
// wrong day's DayDetailsModal (a write path) and looked up the wrong `_dateKey`.
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/calendar_days.dart';

String key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void expectAWeek(List<DateTime> days) {
  expect(days, hasLength(7));
  expect(days.map(key).toSet(), hasLength(7), reason: 'a day appears twice');
  expect(days.first.weekday, DateTime.monday);
  for (var i = 0; i < 7; i++) {
    expect(days[i].hour, 0, reason: 'day cells must be midnight-normalised');
    if (i > 0) {
      final prev = days[i - 1];
      expect(days[i], DateTime(prev.year, prev.month, prev.day + 1),
          reason: 'a day was skipped between ${key(prev)} and ${key(days[i])}');
    }
  }
}

void main() {
  group('weekDaysFor', () {
    test('the spring-forward week (2026-03-29) is seven consecutive days', () {
      expectAWeek(weekDaysFor(DateTime(2026, 3, 25, 23, 30)));
      expect(weekDaysFor(DateTime(2026, 3, 25, 23, 30)).map(key).last,
          '2026-03-29');
    });

    test('the fall-back week (2026-10-25) is seven consecutive days', () {
      expectAWeek(weekDaysFor(DateTime(2026, 10, 21, 23, 30)));
      expect(weekDaysFor(DateTime(2026, 10, 21, 23, 30)).map(key).last,
          '2026-10-25');
    });

    test('every week of 2026 and 2027 holds, at every hour of the anchor', () {
      for (var year = 2026; year <= 2027; year++) {
        for (var doy = 0; doy < 365; doy += 1) {
          expectAWeek(weekDaysFor(DateTime(year, 1, 1 + doy, 23, 30)));
        }
      }
      for (var hour = 0; hour < 24; hour++) {
        expectAWeek(weekDaysFor(DateTime(2026, 3, 29, hour, 30)));
        expectAWeek(weekDaysFor(DateTime(2026, 10, 25, hour, 30)));
      }
    });
  });

  group('startOfWeek', () {
    test('lands on Monday midnight regardless of the time of day', () {
      for (var hour = 0; hour < 24; hour++) {
        final monday = startOfWeek(DateTime(2026, 3, 29, hour, 30)); // a Sunday
        expect(monday.weekday, DateTime.monday);
        expect(monday.hour, 0);
        expect(key(monday), '2026-03-23');
      }
    });
  });

  group('shiftDays — the accumulating week paging', () {
    test('two years of forward paging never drifts off Monday', () {
      // The regression that mattered: the drift compounds. Under the old code,
      // from a 23:30 start, week 11 of 2026 landed on 03-31 instead of 03-30 and
      // never recovered.
      var week = startOfWeek(DateTime(2026, 1, 7, 23, 30));
      final seen = <String>{};
      for (var i = 0; i < 104; i++) {
        week = shiftDays(week, 7);
        expect(week.weekday, DateTime.monday,
            reason: 'paging drifted off Monday at week $i');
        expect(seen.add(key(week)), isTrue, reason: 'week $i repeated');
      }
    });

    test('forward then back is a round trip across both transitions', () {
      for (final start in [
        DateTime(2026, 3, 23),
        DateTime(2026, 10, 19),
      ]) {
        var d = start;
        for (var i = 0; i < 12; i++) {
          d = shiftDays(d, 7);
        }
        for (var i = 0; i < 12; i++) {
          d = shiftDays(d, -7);
        }
        expect(key(d), key(start));
      }
    });

    test('the 6-day span used for the week label stays inside the week', () {
      // `_formatDateRange` renders "19 - 25 October" from start + 6 days.
      expect(key(shiftDays(DateTime(2026, 10, 19), 6)), '2026-10-25');
      expect(key(shiftDays(DateTime(2026, 3, 23), 6)), '2026-03-29');
    });
  });
}
