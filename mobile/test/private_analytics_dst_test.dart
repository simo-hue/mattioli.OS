// The analytics chart series are built from calendar days, not 24-hour blocks.
//
//   TZ=Europe/Rome flutter test test/private_analytics_dst_test.dart
//
// These drive the REAL `computeGlobalTrend` rather than a re-implementation of
// its arithmetic. Against the previous `Duration`-based code under Europe/Rome
// they fail: a 14-day series skipped 2026-03-29 (and so covered 15 calendar days
// while claiming 14), and the 24-month walk ran each month one day past its end.
//
// The invariants asserted are zone-independent, so this suite passes in CI's UTC
// and can only *fail* where a transition falls inside a window.
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_analytics.dart';

List<String> _dates(List<Map<String, dynamic>> points) =>
    [for (final p in points) p['date'] as String];

void _expectConsecutive(List<String> dates) {
  expect(dates.toSet().length, dates.length, reason: 'a day appears twice');
  for (var i = 1; i < dates.length; i++) {
    final prev = DateTime.parse(dates[i - 1]);
    expect(
      dates[i],
      '${DateTime(prev.year, prev.month, prev.day + 1).year}-'
      '${DateTime(prev.year, prev.month, prev.day + 1).month.toString().padLeft(2, '0')}-'
      '${DateTime(prev.year, prev.month, prev.day + 1).day.toString().padLeft(2, '0')}',
      reason: 'a day was skipped between ${dates[i - 1]} and ${dates[i]}',
    );
  }
}

void main() {
  List<Map<String, dynamic>> trend(String timeframe, DateTime today) =>
      computeGlobalTrend(
        goals: const [],
        logs: const {},
        timeframe: timeframe,
        today: today,
      );

  group('computeGlobalTrend day series', () {
    // Europe/Rome springs forward 2026-03-29 and falls back 2026-10-25.
    for (final today in [
      DateTime(2026, 3, 30), // the day after spring-forward
      DateTime(2026, 4, 5), // transition inside the 14-day window
      DateTime(2026, 10, 26), // the day after fall-back
      DateTime(2026, 11, 1),
    ]) {
      test('the 14-day series ending ${today.month}/${today.day} is 14 '
          'consecutive days ending on that day', () {
        final dates = _dates(trend('timeframe_week_short', today));
        expect(dates, hasLength(14));
        _expectConsecutive(dates);
        expect(dates.last,
            '${today.year}-${today.month.toString().padLeft(2, '0')}-'
            '${today.day.toString().padLeft(2, '0')}',
            reason: 'the series must END on today, or every point is '
                'attributed to the wrong day');
      });

      test('the 60-day series ending ${today.month}/${today.day} is clean', () {
        final dates = _dates(trend('timeframe_month_short', today));
        expect(dates, hasLength(60));
        _expectConsecutive(dates);
      });
    }

    test('the 60-day series spans exactly 60 calendar days', () {
      // The failure this catches is subtle: the OLD code still returned 60
      // points, but they covered 61 calendar days because one was skipped — so
      // the chart silently mislabelled every point before the transition.
      final dates = _dates(trend('timeframe_month_short', DateTime(2026, 4, 20)));
      final first = DateTime.parse(dates.first);
      final last = DateTime.parse(dates.last);
      final span = DateTime.utc(last.year, last.month, last.day)
          .difference(DateTime.utc(first.year, first.month, first.day))
          .inDays;
      expect(span, 59, reason: '60 points must cover 60 calendar days');
    });
  });

  group('computeGlobalTrend month buckets', () {
    test('each of the 24 monthly points is the FIRST of its month', () {
      // The month walk derived its end as `firstOfNextMonth - 24h`, which across
      // a transition landed back on the 1st of the next month — so a month
      // bucket averaged one day too many.
      for (final today in [DateTime(2026, 3, 30), DateTime(2026, 10, 26)]) {
        final dates = _dates(trend('timeframe_year_short', today));
        expect(dates, isNotEmpty);
        for (final d in dates) {
          expect(DateTime.parse(d).day, 1,
              reason: '$d is not a month start');
        }
        expect(dates.toSet().length, dates.length);
      }
    });
  });
}
