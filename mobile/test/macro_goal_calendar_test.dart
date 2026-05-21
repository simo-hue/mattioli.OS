import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/macro_goal_calendar.dart';

void main() {
  group('macro goal calendar', () {
    test('keeps the first seven month days inside the first logical week', () {
      expect(logicalWeekOfMonth(DateTime(2026, 2, 1)), 1);
      expect(logicalWeekOfMonth(DateTime(2026, 2, 2)), 1);
      expect(logicalWeekOfMonth(DateTime(2026, 2, 7)), 1);
      expect(logicalWeekOfMonth(DateTime(2026, 2, 8)), 2);
    });

    test('returns the logical number of weeks for each month shape', () {
      expect(logicalWeeksInMonth(2026, 2), 4);
      expect(logicalWeeksInMonth(2024, 2), 5);
      expect(logicalWeeksInMonth(2026, 5), 5);
    });

    test('returns a same-month range for a complete logical week', () {
      final range = logicalWeekRange(2026, 5, 1);

      expect(range.start, DateTime.utc(2026, 5, 1));
      expect(range.end, DateTime.utc(2026, 5, 7));
    });

    test('returns a cross-month range for the final logical week', () {
      final range = logicalWeekRange(2026, 5, 5);

      expect(range.start, DateTime.utc(2026, 5, 29));
      expect(range.end, DateTime.utc(2026, 6, 4));
    });

    test('returns a cross-year range for the final logical week', () {
      final range = logicalWeekRange(2025, 12, 5);

      expect(range.start, DateTime.utc(2025, 12, 29));
      expect(range.end, DateTime.utc(2026, 1, 4));
    });
  });
}
