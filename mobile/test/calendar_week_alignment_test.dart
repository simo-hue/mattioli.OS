import 'package:mattioli_os/models/macro_goal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/macro_goal_calendar.dart';

void main() {
  test(
    'stored goals convert once and keep target/status through serialization',
    () {
      final goal = MacroGoal.fromJson({
        'id': 'g',
        'title': 'Read',
        'type': 'weekly',
        'status': 'completed',
        'year': 2026,
        'month': 5,
        'week_number': 1,
        'created_at': '2026-01-01T00:00:00Z',
        'target_amount': 42,
        'progress_amount': 17,
        'linked_goal_id': 'h',
      });
      expect(goal.weekStartDate, '2026-04-27');
      expect((goal.year, goal.month, goal.weekNumber), (2026, 4, 5));
      final restored = MacroGoal.fromJson(goal.toJson());
      expect(restored.weekStartDate, goal.weekStartDate);
      expect(restored.status.name, 'completed');
      expect(restored.targetAmount, 42);
      expect(restored.progressAmount, 17);
      expect(restored.linkedGoalId, 'h');
      // A NEW May week 1 must stay May 4, rather than being treated as legacy.
      final next = goal.copyWith(month: 5, weekNumber: 1);
      expect(MacroGoal.fromJson(next.toJson()).weekStartDate, '2026-05-04');
    },
  );

  test('Goals uses the same Monday–Sunday dates as Habits', () {
    final range = weekBucketRange(2026, 9, 1);
    expect(range.start, DateTime.utc(2026, 8, 31));
    expect(range.end, DateTime.utc(2026, 9, 6));
    expect(range.end.difference(range.start).inDays + 1, 7);
    expect(
      weekBucketOf(DateTime(2026, 8, 31)),
      const WeekBucket(year: 2026, month: 9, week: 1),
    );
  });
}
