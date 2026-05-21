import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/macro_goal_calendar.dart';

void main() {
  group('macro goal calendar', () {
    test('keeps a Sunday month start inside the first logical week', () {
      expect(logicalWeekOfMonth(DateTime(2026, 2, 1)), 1);
      expect(logicalWeekOfMonth(DateTime(2026, 2, 2)), 1);
      expect(logicalWeekOfMonth(DateTime(2026, 2, 8)), 1);
      expect(logicalWeekOfMonth(DateTime(2026, 2, 9)), 2);
    });

    test('returns the logical number of weeks for each month shape', () {
      expect(logicalWeeksInMonth(2026, 2), 4);
      expect(logicalWeeksInMonth(2026, 3), 5);
      expect(logicalWeeksInMonth(2022, 1), 6);
    });
  });
}
