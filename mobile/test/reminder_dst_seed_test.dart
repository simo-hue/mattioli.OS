// A reminder's SEED date is built with calendar arithmetic, not `Duration`.
//
// `Duration(days: 1)` is a fixed 24 hours. A calendar day across a DST
// transition is 23 or 25, so stepping a `tz.TZDateTime` by a Duration lands on a
// different wall-clock time. Both seed builders did exactly that.
//
// Only the SEED was ever wrong: `matchDateTimeComponents` re-matches wall clock
// on every later firing, so the reminder self-corrects from the second
// occurrence onward. That is precisely why it survived — the bug is one late
// notification, once or twice a year, on the day the clocks change.
//
// The weekly builder compounds it: it loops up to six times to reach the target
// weekday, so the drift accumulates. It does NOT produce a wrong weekday, which
// is the intuitive guess and is wrong — that loop exits only when the weekday
// already matches, so the day is always the requested one. What it gets wrong is
// the hour, and for a reminder set near midnight an hour of drift is a ~23-hour
// displacement of when it actually fires within that correct day.
//
// These tests hold under any host zone, and not by luck: the builders construct
// in `now.location`, so passing a Rome `now` gets a Rome answer. That is
// load-bearing — while they used `tz.local`, running under `TZ=UTC` answered in
// a zone with no transitions, and every test here passed against the very
// arithmetic it exists to reject.
//
// 2026 Rome transitions: forward 29 March 02:00->03:00, back 25 Oct 03:00->02:00.
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location rome;

  setUpAll(() {
    tzdata.initializeTimeZones();
    rome = tz.getLocation('Europe/Rome');
    // Belt and braces: the functions under test build in `now.location`, so this
    // is not what makes the tests work. It keeps the PRODUCTION wrappers
    // (`_nextInstanceOfTime`, which passes `tz.TZDateTime.now(tz.local)`)
    // consistent with the fixture for anyone reading this alongside them.
    tz.setLocalLocation(rome);
  });

  group('the daily seed', () {
    test('keeps its wall-clock hour across a spring-forward', () {
      // 20:00 on the eve, reminder at 09:00 — already past, so it rolls to
      // tomorrow, and tomorrow is 23 hours long. `add(Duration(days: 1))` from
      // 09:00 on the 28th is 09:00 UTC+1 + 24h = 10:00 UTC+2 on the 29th: the
      // user's 09:00 reminder first fires at 10:00.
      final now = tz.TZDateTime(rome, 2026, 3, 28, 20);

      final seed = nextInstanceOfTimeFrom(now, 9, 0);

      expect(seed.year, 2026);
      expect(seed.month, 3);
      expect(seed.day, 29);
      expect(seed.hour, 9, reason: 'the hour the user chose, not 10');
      expect(seed.minute, 0);
    });

    test('keeps its wall-clock hour across a fall-back', () {
      // The mirror image: 25 October is 25 hours long, so a Duration step
      // lands an hour EARLY.
      final now = tz.TZDateTime(rome, 2026, 10, 24, 20);

      final seed = nextInstanceOfTimeFrom(now, 9, 0);

      expect(seed.day, 25);
      expect(seed.hour, 9, reason: 'not 08');
    });

    test('today, when the time has not passed yet', () {
      final now = tz.TZDateTime(rome, 2026, 3, 28, 7);

      final seed = nextInstanceOfTimeFrom(now, 9, 0);

      expect(seed.day, 28, reason: 'no roll-forward when today still works');
      expect(seed.hour, 9);
    });
  });

  group('the weekly seed', () {
    test('lands on the requested weekday, across a spring-forward', () {
      // Thursday 26 March 2026, 20:00. Next Monday is 30 March — the walk
      // crosses the transition on the 29th.
      final now = tz.TZDateTime(rome, 2026, 3, 26, 20);

      final seed = nextInstanceOfWeekdayTimeFrom(now, DateTime.monday, 9, 0);

      expect(seed.weekday, DateTime.monday);
      expect(seed.day, 30);
      expect(seed.hour, 9);
    });

    test('a reminder near midnight keeps its hour, not just its weekday', () {
      // The worst case for the drift, and the one that reads as a bigger bug
      // than it is. The weekday IS always right — the loop guarantees it. But at
      // 00:30 an hour of drift moves the reminder to 01:30, which for the user
      // is the difference between "just after midnight" and "the middle of the
      // night", every week until the next transition puts it back.
      final now = tz.TZDateTime(rome, 2026, 3, 26, 20);

      final seed = nextInstanceOfWeekdayTimeFrom(now, DateTime.monday, 0, 30);

      expect(seed.weekday, DateTime.monday,
          reason: 'never actually at risk — pinned so the claim above stays '
              'honest if someone rewrites the loop');
      expect(seed.hour, 0, reason: 'THIS is what drifted: 00:30 became 01:30');
      expect(seed.minute, 30);
    });

    test('across a fall-back too', () {
      // Thursday 22 October 2026 -> Monday 26 October, crossing the 25th.
      final now = tz.TZDateTime(rome, 2026, 10, 22, 20);

      final seed = nextInstanceOfWeekdayTimeFrom(now, DateTime.monday, 9, 0);

      expect(seed.weekday, DateTime.monday);
      expect(seed.day, 26);
      expect(seed.hour, 9);
    });
  });
}
