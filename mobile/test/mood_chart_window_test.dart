import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/ui/widgets/statistics/global_mood_tab_widget.dart';

void main() {
  group('MoodChartWindow', () {
    test(
      'starts at the first mood date when history is shorter than range',
      () {
        final window = MoodChartWindow.resolve(
          now: DateTime(2026, 5, 26, 10),
          selectedDays: 14,
          moodDateKeys: const ['2026-05-20', '2026-05-23', '2026-05-26'],
        );

        expect(window.startDate, DateTime(2026, 5, 20));
        expect(window.dayCount, 7);
        expect(window.maxX, 6);
        expect(window.labelInterval, 1);
      },
    );

    test('uses the selected range when there are no mood entries', () {
      final window = MoodChartWindow.resolve(
        now: DateTime(2026, 5, 26, 10),
        selectedDays: 14,
        moodDateKeys: const [],
      );

      expect(window.startDate, DateTime(2026, 5, 13));
      expect(window.dayCount, 14);
      expect(window.maxX, 13);
      expect(window.labelInterval, 2);
    });

    test('ignores mood dates outside the selected range', () {
      final window = MoodChartWindow.resolve(
        now: DateTime(2026, 5, 26, 10),
        selectedDays: 14,
        moodDateKeys: const ['2026-04-01', '2026-05-22', '2026-06-01'],
      );

      expect(window.startDate, DateTime(2026, 5, 22));
      expect(window.dayCount, 5);
      expect(window.maxX, 4);
      expect(window.labelInterval, 1);
    });

    test('counts a window that straddles a DST transition in whole days', () {
      // Regression: `dayCount` used to be measured with
      // `today.difference(startDate).inDays`, on two LOCAL midnights. A span
      // containing a 23-hour spring-forward day is 24h*n - 1h, which `inDays`
      // truncates, so the window came out one day short and the plot loop
      // (`i < dayCount`) dropped its last point — today — from the chart.
      //
      // The assertion below is a pure calendar invariant: with no mood entries
      // the window is always exactly `selectedDays` long, in every zone. It can
      // only FAIL where the local zone actually observes DST (e.g.
      // Europe/Rome, where 58 of these 730 days regressed); under TZ=UTC it
      // passes either way rather than flaking.
      for (final selectedDays in const [14, 30, 90]) {
        for (var offset = 0; offset < 730; offset++) {
          final now = DateTime(2026, 1, 1 + offset, 10);
          final window = MoodChartWindow.resolve(
            now: now,
            selectedDays: selectedDays,
            moodDateKeys: const [],
          );

          expect(
            window.dayCount,
            selectedDays,
            reason:
                'now=$now selectedDays=$selectedDays '
                'startDate=${window.startDate}',
          );
        }
      }
    });

    test('anchors a single mood point to the right edge', () {
      final window = MoodChartWindow.resolve(
        now: DateTime(2026, 5, 26, 10),
        selectedDays: 14,
        moodDateKeys: const ['2026-05-26'],
      );

      expect(window.startDate, DateTime(2026, 5, 26));
      expect(window.dayCount, 1);
      expect(window.minX, -1);
      expect(window.maxX, 0);
    });
  });
}
