import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/streak_utils.dart';

// Helpers to build the logs map: { 'yyyy-MM-dd': { habitId: status } }.
String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, Map<String, String>> _logsFrom(
  String habitId,
  Map<DateTime, String> entries,
) {
  final map = <String, Map<String, String>>{};
  entries.forEach((date, status) {
    map[_key(date)] = {habitId: status};
  });
  return map;
}

void main() {
  const habit = 'h1';
  final start = DateTime(2026, 1, 1);
  // A reference "today" well after start; computeStreak is date-relative so
  // the absolute value of "today" never matters here.
  DateTime day(int n) => start.add(Duration(days: n));

  group('computeStreak — sign + basics', () {
    test('date before startDate returns 0', () {
      final logs = _logsFrom(habit, {start.subtract(const Duration(days: 1)): 'done'});
      expect(
        computeStreak(
          habitId: habit,
          date: start.subtract(const Duration(days: 1)),
          logs: logs,
          startDate: start,
        ),
        0,
      );
    });

    test('single done day is +1', () {
      final logs = _logsFrom(habit, {day(5): 'done'});
      expect(
        computeStreak(habitId: habit, date: day(5), logs: logs, startDate: start),
        1,
      );
    });

    test('single missed day is -1', () {
      final logs = _logsFrom(habit, {day(5): 'missed'});
      expect(
        computeStreak(habitId: habit, date: day(5), logs: logs, startDate: start),
        -1,
      );
    });

    test('three consecutive done days is +3 on the last day', () {
      final logs = _logsFrom(habit, {
        day(3): 'done',
        day(4): 'done',
        day(5): 'done',
      });
      expect(
        computeStreak(habitId: habit, date: day(5), logs: logs, startDate: start),
        3,
      );
    });

    test('three consecutive missed days is -3 on the last day', () {
      final logs = _logsFrom(habit, {
        day(3): 'missed',
        day(4): 'missed',
        day(5): 'missed',
      });
      expect(
        computeStreak(habitId: habit, date: day(5), logs: logs, startDate: start),
        -3,
      );
    });
  });

  group('computeStreak — gaps break the streak (strict calendar / web logic)', () {
    test('an unlogged day breaks the positive streak', () {
      final logs = _logsFrom(habit, {
        day(2): 'done',
        // day(3) unlogged
        day(4): 'done',
        day(5): 'done',
      });
      expect(
        computeStreak(habitId: habit, date: day(5), logs: logs, startDate: start),
        2,
      );
    });

    test('a missed day caps the positive streak (sign flip stops the count)', () {
      final logs = _logsFrom(habit, {
        day(3): 'done',
        day(4): 'done',
        day(5): 'missed',
      });
      // Last day is missed -> negative direction, only counts the missed run.
      expect(
        computeStreak(habitId: habit, date: day(5), logs: logs, startDate: start),
        -1,
      );
    });

    test('a done day caps the negative streak', () {
      final logs = _logsFrom(habit, {
        day(3): 'missed',
        day(4): 'missed',
        day(5): 'done',
      });
      expect(
        computeStreak(habitId: habit, date: day(5), logs: logs, startDate: start),
        1,
      );
    });
  });

  group('computeStreak — pending day looks back one day', () {
    test('pending today continues an ongoing positive streak from yesterday', () {
      final logs = _logsFrom(habit, {
        day(3): 'done',
        day(4): 'done',
        // day(5) pending/unlogged
      });
      expect(
        computeStreak(habitId: habit, date: day(5), logs: logs, startDate: start),
        2,
      );
    });

    test('pending today continues an ongoing negative streak from yesterday', () {
      final logs = _logsFrom(habit, {
        day(4): 'missed',
        // day(5) pending
      });
      expect(
        computeStreak(habitId: habit, date: day(5), logs: logs, startDate: start),
        -1,
      );
    });

    test('pending today with nothing yesterday is 0', () {
      final logs = _logsFrom(habit, {day(2): 'done'});
      expect(
        computeStreak(habitId: habit, date: day(5), logs: logs, startDate: start),
        0,
      );
    });
  });

  group('computeStreak — historical edits compute from history up to that day', () {
    test('computing for a past day ignores future logs', () {
      final logs = _logsFrom(habit, {
        day(3): 'done',
        day(4): 'done', // editing/viewing this day
        day(5): 'done', // future relative to day(4)
      });
      // For day(4), only day(3)+day(4) count -> +2, regardless of day(5).
      expect(
        computeStreak(habitId: habit, date: day(4), logs: logs, startDate: start),
        2,
      );
    });

    test('start boundary caps the walk', () {
      final logs = _logsFrom(habit, {
        start: 'done',
        day(1): 'done',
      });
      expect(
        computeStreak(habitId: habit, date: day(1), logs: logs, startDate: start),
        2,
      );
    });
  });
}
