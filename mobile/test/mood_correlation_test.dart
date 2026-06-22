import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/models/daily_mood.dart';
import 'package:mattioli_os/providers/goal_provider.dart' show HabitLogsMap;
import 'package:mattioli_os/providers/mood_provider.dart';

/// Locks in the 0–10 mood scale for [computeMoodCorrelations]:
/// high mood == moodScore >= 6, low mood == moodScore < 4, 4–5 is neutral.
/// (Regression guard for the stale 0–100 thresholds that used >= 60 / < 40.)
void main() {
  // Date keys are yyyy-MM-dd; DailyMood stores them as strings.
  DailyMood mood(String date, int moodScore, int energyScore) => DailyMood(
        id: 'mood-$date',
        userId: 'u1',
        date: date,
        moodScore: moodScore,
        energyScore: energyScore,
      );

  MoodCorrelation correlationFor(
    List<MoodCorrelation> result,
    String goalId,
  ) =>
      result.firstWhere((c) => c.goalId == goalId);

  group('computeMoodCorrelations', () {
    test('bands done/missed by the 0–10 mood scale', () {
      final moods = <String, DailyMood>{
        // High band (>= 6): two done, one missed -> highMoodPct = 2/3.
        '2026-06-01': mood('2026-06-01', 8, 7),
        '2026-06-02': mood('2026-06-02', 6, 5),
        '2026-06-03': mood('2026-06-03', 9, 8),
        // Neutral band (4–5): ignored by both high and low tallies.
        '2026-06-04': mood('2026-06-04', 5, 5),
        '2026-06-05': mood('2026-06-05', 4, 4),
        // Low band (< 4): two missed, one done -> lowMoodPct = 1/3.
        '2026-06-06': mood('2026-06-06', 3, 2),
        '2026-06-07': mood('2026-06-07', 1, 1),
        '2026-06-08': mood('2026-06-08', 0, 0),
      };

      final HabitLogsMap logs = {
        '2026-06-01': {'g1': 'done'},
        '2026-06-02': {'g1': 'done'},
        '2026-06-03': {'g1': 'missed'},
        '2026-06-04': {'g1': 'done'}, // neutral: counts for averages, not bands
        '2026-06-05': {'g1': 'missed'},
        '2026-06-06': {'g1': 'missed'},
        '2026-06-07': {'g1': 'missed'},
        '2026-06-08': {'g1': 'done'},
      };

      final result = computeMoodCorrelations(moods: moods, logs: logs);
      expect(result, hasLength(1));
      final c = correlationFor(result, 'g1');

      // High band: high_done = 2 (06-01, 06-02), high_total = 3 -> 67%.
      expect(c.highMoodPct, 67);
      // Low band: low_done = 1 (06-08), low_total = 3 -> 33%.
      expect(c.lowMoodPct, 33);

      // Percentages live on a 0–100 scale.
      expect(c.highMoodPct, inInclusiveRange(0, 100));
      expect(c.lowMoodPct, inInclusiveRange(0, 100));

      // Derived metrics.
      expect(c.sensitivity, c.highMoodPct - c.lowMoodPct);
      expect(c.resilience, c.lowMoodPct);

      // avgMoodDone = mean moodScore over done days (8, 6, 5, 0) = 19/4.
      expect(c.avgMoodDone, closeTo(19 / 4, 1e-9));
      // avgEnergyDone = mean energyScore over done days (7, 5, 5, 0) = 17/4.
      expect(c.avgEnergyDone, closeTo(17 / 4, 1e-9));
      // avgMoodMissed = mean moodScore over missed days (9, 4, 3, 1) = 17/4.
      expect(c.avgMoodMissed, closeTo(17 / 4, 1e-9));
      // avgEnergyMissed = mean energyScore over missed days (8, 4, 2, 1) = 15/4.
      expect(c.avgEnergyMissed, closeTo(15 / 4, 1e-9));
    });

    test('a moodScore of 4 or 5 is neutral (neither high nor low)', () {
      final moods = <String, DailyMood>{
        '2026-06-04': mood('2026-06-04', 4, 4),
        '2026-06-05': mood('2026-06-05', 5, 5),
      };
      final HabitLogsMap logs = {
        '2026-06-04': {'g1': 'done'},
        '2026-06-05': {'g1': 'missed'},
      };

      final c = correlationFor(
        computeMoodCorrelations(moods: moods, logs: logs),
        'g1',
      );

      // No high or low days contributed, so both percentages collapse to 0.
      expect(c.highMoodPct, 0);
      expect(c.lowMoodPct, 0);
      expect(c.sensitivity, 0);
      expect(c.resilience, 0);
    });

    test('a missed habit on a low-mood day counts toward the low-mood total',
        () {
      final moods = <String, DailyMood>{
        '2026-06-06': mood('2026-06-06', 2, 2),
      };
      final HabitLogsMap logs = {
        '2026-06-06': {'g1': 'missed'},
      };

      final c = correlationFor(
        computeMoodCorrelations(moods: moods, logs: logs),
        'g1',
      );

      // low_total = 1, low_done = 0 -> resilience (lowMoodPct) is 0% completion.
      expect(c.lowMoodPct, 0);
      expect(c.resilience, 0);
      // The missed day still feeds the missed averages.
      expect(c.avgMoodMissed, closeTo(2.0, 1e-9));
    });

    test(
      'regression: a done habit on a moodScore 8 day must register as high mood',
      () {
        // Under the OLD 0–100 rule (high == moodScore >= 60) an 8 would never
        // count, leaving highMoodPct == 0. The 0–10 fix must give 100%.
        final moods = <String, DailyMood>{
          '2026-06-10': mood('2026-06-10', 8, 8),
        };
        final HabitLogsMap logs = {
          '2026-06-10': {'g1': 'done'},
        };

        final c = correlationFor(
          computeMoodCorrelations(moods: moods, logs: logs),
          'g1',
        );

        expect(c.highMoodPct, greaterThan(0));
        expect(c.highMoodPct, 100);
      },
    );

    test('days without a matching mood entry are skipped', () {
      final moods = <String, DailyMood>{
        '2026-06-01': mood('2026-06-01', 7, 7),
      };
      final HabitLogsMap logs = {
        // Has a mood -> counted.
        '2026-06-01': {'g1': 'done'},
        // No mood for this date -> ignored entirely.
        '2026-06-02': {'g1': 'missed'},
      };

      final c = correlationFor(
        computeMoodCorrelations(moods: moods, logs: logs),
        'g1',
      );

      expect(c.highMoodPct, 100); // only the matched done day counts
      expect(c.avgMoodMissed, 0.0); // missed day had no mood -> no contribution
    });
  });
}
