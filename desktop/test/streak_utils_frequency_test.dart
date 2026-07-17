// Schedule-aware streak semantics: days a habit is NOT scheduled on (its
// off-days) are transparent to the streak — they neither count toward it nor
// break it — while a missed or unlogged *scheduled* day still breaks it. Kept in
// lock-step with the mobile copy (`mobile/test/streak_utils_frequency_test.dart`).
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve_desktop/core/streak_utils.dart';

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, Map<String, String>> _logs(
  String habit,
  Map<DateTime, String> entries,
) {
  final map = <String, Map<String, String>>{};
  entries.forEach((date, status) => map[_key(date)] = {habit: status});
  return map;
}

void main() {
  const habit = 'h1';
  // 2026-01-05 is a Monday, so a Mon/Wed/Fri habit is frequencyDays [1, 3, 5].
  final start = DateTime(2026, 1, 5);
  const mwf = [1, 3, 5];
  DateTime d(int day) => DateTime(2026, 1, day); // Jan 5=Mon … Jan 9=Fri

  group('computeStreak — frequency-aware (off-days are transparent)', () {
    test('off-days between scheduled done-days do not break the streak', () {
      // Mon 5, Wed 7, Fri 9 all done → 3 on Fri (Tue/Thu are skipped).
      final logs = _logs(habit, {d(5): 'done', d(7): 'done', d(9): 'done'});
      expect(
        computeStreak(
          habitId: habit,
          date: d(9),
          logs: logs,
          startDate: start,
          frequencyDays: mwf,
        ),
        3,
      );
    });

    test('without frequencyDays the same logs cap at 1 (Tuesday breaks it)', () {
      final logs = _logs(habit, {d(5): 'done', d(7): 'done', d(9): 'done'});
      expect(
        computeStreak(
          habitId: habit,
          date: d(9),
          logs: logs,
          startDate: start,
        ),
        1,
      );
    });

    test('an off-day "today" anchors on the most recent scheduled day', () {
      // Today = Sat 10 (off-day, pending). Anchor = Fri 9 (done) → 3.
      final logs = _logs(habit, {d(5): 'done', d(7): 'done', d(9): 'done'});
      expect(
        computeStreak(
          habitId: habit,
          date: d(10),
          logs: logs,
          startDate: start,
          frequencyDays: mwf,
        ),
        3,
      );
    });

    test('a pending scheduled "today" continues from the previous scheduled '
        'day', () {
      // Today = Mon 12 (scheduled, pending); Fri 9, Wed 7, Mon 5 done → 3.
      final logs = _logs(habit, {d(5): 'done', d(7): 'done', d(9): 'done'});
      expect(
        computeStreak(
          habitId: habit,
          date: d(12),
          logs: logs,
          startDate: start,
          frequencyDays: mwf,
        ),
        3,
      );
    });

    test('a missed scheduled day breaks the run', () {
      // Fri 9 done, Wed 7 done, Mon 5 missed → 2 on Fri.
      final logs = _logs(habit, {d(5): 'missed', d(7): 'done', d(9): 'done'});
      expect(
        computeStreak(
          habitId: habit,
          date: d(9),
          logs: logs,
          startDate: start,
          frequencyDays: mwf,
        ),
        2,
      );
    });

    test('an unlogged scheduled day breaks the run', () {
      // Fri 9 done, Mon 5 done, Wed 7 unlogged → 1 on Fri.
      final logs = _logs(habit, {d(5): 'done', d(9): 'done'});
      expect(
        computeStreak(
          habitId: habit,
          date: d(9),
          logs: logs,
          startDate: start,
          frequencyDays: mwf,
        ),
        1,
      );
    });

    test('negative streak counts only scheduled missed days', () {
      // Mon 5, Wed 7, Fri 9 all missed → -3.
      final logs = _logs(habit, {d(5): 'missed', d(7): 'missed', d(9): 'missed'});
      expect(
        computeStreak(
          habitId: habit,
          date: d(9),
          logs: logs,
          startDate: start,
          frequencyDays: mwf,
        ),
        -3,
      );
    });

    test('empty frequencyDays is treated as every-day', () {
      final logs = _logs(habit, {d(5): 'done', d(6): 'done', d(7): 'done'});
      expect(
        computeStreak(
          habitId: habit,
          date: d(7),
          logs: logs,
          startDate: start,
          frequencyDays: const [],
        ),
        3,
      );
    });

    test('all-7 frequencyDays matches the every-day (null) result', () {
      final logs = _logs(habit, {d(5): 'done', d(6): 'done', d(7): 'done'});
      final all = computeStreak(
        habitId: habit,
        date: d(7),
        logs: logs,
        startDate: start,
        frequencyDays: const [1, 2, 3, 4, 5, 6, 7],
      );
      final everyDay = computeStreak(
        habitId: habit,
        date: d(7),
        logs: logs,
        startDate: start,
      );
      expect(all, everyDay);
      expect(all, 3);
    });
  });
}
