import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/providers/goal_provider.dart';

/// The statistics UI shares the trend chart's 'timeframe_*' vocabulary, but
/// get_best_habits (cloud + Private) filter on 'week'/'month'/'year'/'all'.
/// canonicalBestHabitsTimeframe bridges the two so habits don't come back rate 0.
void main() {
  test('maps the four UI tokens to the cloud vocabulary', () {
    expect(canonicalBestHabitsTimeframe('timeframe_week_short'), 'week');
    expect(canonicalBestHabitsTimeframe('timeframe_month_short'), 'month');
    expect(canonicalBestHabitsTimeframe('timeframe_year_short'), 'year');
    expect(canonicalBestHabitsTimeframe('timeframe_all'), 'all');
  });

  test('is idempotent: canonical tokens pass through unchanged', () {
    for (final t in ['week', 'month', 'year', 'all']) {
      expect(canonicalBestHabitsTimeframe(t), t);
    }
  });

  test('unrecognised tokens fall back to lifetime (all), never rate 0', () {
    expect(canonicalBestHabitsTimeframe(''), 'all');
    expect(canonicalBestHabitsTimeframe('garbage'), 'all');
    expect(canonicalBestHabitsTimeframe('timeframe_decade'), 'all');
  });
}
