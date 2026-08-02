// The Habits week calendar builds its seven day columns, and pages between
// weeks, with calendar arithmetic rather than 24-hour Durations.
//
// Run these under a zone that actually has transitions to see them bite:
//   TZ=Europe/Rome flutter test test/calendar_days_dst_test.dart
// The invariants asserted are zone-independent and hold everywhere, so the
// suite is meaningful in CI's UTC too — it simply cannot fail there.
//
// Against the previous `Duration`-based code under Europe/Rome these fail with,
// among others, a grid of [.. 03-28, 03-30] (2026-03-29 skipped) and a grid
// containing 2026-10-25 twice.
import 'package:evolve_desktop/core/calendar_days.dart';
import 'package:flutter_test/flutter_test.dart';

String key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Seven distinct days, consecutive, Monday first — the whole contract of a
/// week grid whose seven columns are labelled MON..SUN.
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
  group('weekDaysFor — a week spanning a DST transition', () {
    // Europe/Rome springs forward on 2026-03-29 and falls back on 2026-10-25.
    // Both are Sundays, so each is the LAST cell of its Monday-start week —
    // which is exactly why the old code's failures showed up as the seventh
    // column holding the wrong date.
    test('spring-forward week (2026-03-29) has seven consecutive days', () {
      final days = weekDaysFor(DateTime(2026, 3, 25, 14, 30));
      expectAWeek(days);
      expect(days.map(key), [
        '2026-03-23',
        '2026-03-24',
        '2026-03-25',
        '2026-03-26',
        '2026-03-27',
        '2026-03-28',
        '2026-03-29',
      ]);
    });

    test('fall-back week (2026-10-25) has seven consecutive days', () {
      final days = weekDaysFor(DateTime(2026, 10, 21, 14, 30));
      expectAWeek(days);
      expect(days.map(key), [
        '2026-10-19',
        '2026-10-20',
        '2026-10-21',
        '2026-10-22',
        '2026-10-23',
        '2026-10-24',
        '2026-10-25',
      ]);
    });

    test('holds for EVERY hour of the anchor, not just a convenient one', () {
      // The anchor is `DateTime.now()`, so its time-of-day is whatever the user
      // happened to open the page at. The old code was correct at most hours and
      // wrong at 23:xx — a bug that reproduces for one hour a day, twice a year,
      // which is precisely the kind that ships.
      for (final transitionWeek in [DateTime(2026, 3, 25), DateTime(2026, 10, 21)]) {
        for (var hour = 0; hour < 24; hour++) {
          final anchor = DateTime(transitionWeek.year, transitionWeek.month,
              transitionWeek.day, hour, 30);
          expectAWeek(weekDaysFor(anchor));
        }
      }
    });

    test('every week of 2026 and 2027 is seven consecutive days', () {
      for (var year = 2026; year <= 2027; year++) {
        for (var doy = 0; doy < 365; doy++) {
          expectAWeek(weekDaysFor(DateTime(year, 1, 1 + doy, 23, 30)));
        }
      }
    });
  });

  group('shiftDays — week paging', () {
    test('paging forward a year never drifts, and never repeats a week', () {
      // The paging steps ACCUMULATE (each press shifts the stored anchor), so a
      // one-hour DST slip is permanent: the old code, from a 23:30 start, landed
      // on 2026-03-31 at week 11 instead of 2026-03-30 and stayed a day off for
      // every week after. A user who paged past March saw MON..SUN labels over
      // TUE..MON dates and opened the wrong day's details.
      var anchor = DateTime(2026, 1, 5, 23, 30); // a Monday
      final seen = <String>{};
      for (var week = 0; week < 104; week++) {
        anchor = shiftDays(anchor, 7);
        expect(anchor.weekday, DateTime.monday,
            reason: 'paging drifted off Monday at week $week');
        expect(seen.add(key(anchor)), isTrue,
            reason: 'week $week repeated ${key(anchor)}');
      }
    });

    test('paging back and forth returns to the same day', () {
      for (final start in [DateTime(2026, 3, 29, 23, 30), DateTime(2026, 10, 25, 0, 30)]) {
        var d = start;
        for (var i = 0; i < 10; i++) {
          d = shiftDays(d, 7);
        }
        for (var i = 0; i < 10; i++) {
          d = shiftDays(d, -7);
        }
        expect(key(d), key(start));
      }
    });

    test('a 7-day span from the first of a month covers seven distinct days',
        () {
      // The month view's per-week completion average. Under the old code the
      // week containing 2026-10-25 counted that day twice and dropped 10-28,
      // skewing the average it displays.
      final first = DateTime(2026, 10, 22);
      final days = [for (var d = 0; d < 7; d++) shiftDays(first, d)];
      expect(days.map(key).toSet(), hasLength(7));
      expect(days.map(key).last, '2026-10-28');
    });
  });
}
