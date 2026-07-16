import 'package:mattioli_os/core/streak_utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// `computeStreak` walks calendar days backwards. Duration arithmetic cannot
/// express that walk: a 24h step back over a 23-hour (spring-forward) day lands
/// at 23:00 of the day *before* it, so that day is never keyed. Fall-back (25h)
/// anchors are covered too, as a guard rail — they land at 01:00 of the right
/// calendar day, so they pass either way.
///
/// These tests run the same assertions over a set of anchor days. In a DST-free
/// zone (CI runs at TZ=UTC) only the plain anchor is exercised and every case
/// passes even against the pre-fix code, so this file is only meaningful when
/// TZ pins a DST-observing zone:
///
///   TZ=Europe/Rome flutter test test/streak_utils_dst_test.dart
///   TZ=America/New_York flutter test test/streak_utils_dst_test.dart
void main() {
  const habitId = 'h1';

  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime shift(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  /// Every calendar day of [year] that is shorter than 24h in the local zone.
  List<DateTime> springForwardDays(int year) {
    final found = <DateTime>[];
    var d = DateTime(year, 1, 1);
    while (d.year == year) {
      final next = shift(d, 1);
      if (next.difference(d) < const Duration(hours: 24)) found.add(d);
      d = next;
    }
    return found;
  }

  /// Every calendar day of [year] that is longer than 24h in the local zone.
  List<DateTime> fallBackDays(int year) {
    final found = <DateTime>[];
    var d = DateTime(year, 1, 1);
    while (d.year == year) {
      final next = shift(d, 1);
      if (next.difference(d) > const Duration(hours: 24)) found.add(d);
      d = next;
    }
    return found;
  }

  /// A plain mid-week day plus every DST transition day in 2024-2026.
  List<DateTime> anchors() => [
    DateTime(2025, 6, 11),
    for (final y in [2024, 2025, 2026]) ...springForwardDays(y),
    for (final y in [2024, 2025, 2026]) ...fallBackDays(y),
  ];

  StreakLogs logsFor(Map<DateTime, String> statuses) => {
    for (final e in statuses.entries)
      key(e.key): {habitId: e.value},
  };

  group('computeStreak walks calendar days across DST transitions', () {
    test('a pending day reads the immediately preceding calendar day', () {
      for (final transition in anchors()) {
        // `date` is the day AFTER the transition and is unlogged, so the
        // pending-day lookback is the code path under test.
        final date = shift(transition, 1);
        final logs = logsFor({
          transition: 'done',
          shift(transition, -1): 'done',
          shift(transition, -2): 'done',
        });

        expect(
          computeStreak(
            habitId: habitId,
            date: date,
            logs: logs,
            startDate: shift(transition, -30),
          ),
          3,
          reason: 'pending ${key(date)} after transition ${key(transition)}',
        );
      }
    });

    test('an unlogged transition day breaks the run', () {
      for (final transition in anchors()) {
        final date = shift(transition, 3);
        // Continuous 'done' run either side of the transition, but the
        // transition day itself is never logged: the streak must stop there.
        final logs = logsFor({
          for (var i = -5; i <= 3; i++)
            if (i != 0) shift(transition, i): 'done',
        });

        expect(
          computeStreak(
            habitId: habitId,
            date: date,
            logs: logs,
            startDate: shift(transition, -30),
          ),
          3,
          reason: 'run over unlogged transition ${key(transition)}',
        );
      }
    });

    test('an unbroken run counts every calendar day it spans', () {
      for (final transition in anchors()) {
        final date = shift(transition, 3);
        final logs = logsFor({
          for (var i = -5; i <= 3; i++) shift(transition, i): 'done',
        });

        expect(
          computeStreak(
            habitId: habitId,
            date: date,
            logs: logs,
            startDate: shift(transition, -5),
          ),
          9,
          reason: 'unbroken run over transition ${key(transition)}',
        );
      }
    });

    test('an explicitly missed transition day breaks a positive run', () {
      for (final transition in anchors()) {
        final date = shift(transition, 3);
        final logs = logsFor({
          for (var i = -5; i <= 3; i++)
            shift(transition, i): i == 0 ? 'missed' : 'done',
        });

        expect(
          computeStreak(
            habitId: habitId,
            date: date,
            logs: logs,
            startDate: shift(transition, -30),
          ),
          3,
          reason: 'run over missed transition ${key(transition)}',
        );
      }
    });
  });
}
