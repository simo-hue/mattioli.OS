// `computeConsistencyScores` measures the gap between two consecutive
// completions. Its dates are LOCAL midnights (HabitLogEntry normalises with
// `DateTime(y, m, d)`), so `dates[i].difference(dates[i-1]).inDays` truncates
// the 23-hour spring-forward day to a gap of ZERO: a habit done every single
// day for a year got 363 gaps of 1 and one of 0, a CV of ~0.05, and Insights >
// Habits > Consistency read ~95 for a perfect unbroken record — flipping the
// "steadiest habit" ranking against any rival scoring between 95 and 100.
//
// `computeGapStats`, one function away in the same file, measures the same
// quantity correctly with `_calDays`; the file's own comment spells out the
// hazard. This is the same class of defect as `year_heatmap_dst_test.dart`, and
// like that test it only BITES in a DST-observing zone: CI runs at TZ=UTC,
// where the assertions below hold for the broken code too. It was verified to
// catch the regression under the maintainer's own machine default:
//
//   TZ=Europe/Rome flutter test test/consistency_dst_test.dart
//   TZ=America/New_York flutter test test/consistency_dst_test.dart
import 'package:evolve_desktop/features/statistics/data/analytics_extra.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime shift(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  /// Every calendar day of [year] that is SHORTER than 24h locally — the
  /// spring-forward days, the ones `.inDays` truncates to a zero gap.
  List<DateTime> shortDays(int year) {
    final found = <DateTime>[];
    var d = DateTime(year, 1, 1);
    while (d.year == year) {
      final next = shift(d, 1);
      if (next.difference(d) < const Duration(hours: 24)) found.add(d);
      d = next;
    }
    return found;
  }

  /// A plain DST-free window, plus one centred on each spring-forward day.
  List<DateTime> starts() => [
    DateTime(2025, 6, 1),
    for (final y in [2024, 2025, 2026])
      for (final t in shortDays(y)) shift(t, -10),
  ];

  test('an unbroken daily record scores 100 across a spring-forward', () {
    for (final start in starts()) {
      final logs = [
        for (var i = 0; i < 21; i++)
          HabitLogEntry(goalId: 'g1', date: shift(start, i), status: 'done'),
      ];

      final scores = computeConsistencyScores({'g1': logs});

      expect(scores, hasLength(1), reason: 'window from $start');
      expect(
        scores.single.score,
        100,
        reason:
            'every gap is one calendar day, so the record is perfectly steady '
            '(window from $start)',
      );
      expect(scores.single.doneCount, 21, reason: 'window from $start');
    }
  });

  test('a genuinely irregular record still scores below 100', () {
    final logs = [
      for (final day in [1, 2, 3, 10, 20])
        HabitLogEntry(
          goalId: 'g1',
          date: DateTime(2025, 6, day),
          status: 'done',
        ),
    ];
    expect(computeConsistencyScores({'g1': logs}).single.score, lessThan(100));
  });
}
