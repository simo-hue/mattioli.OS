import 'dart:math' as math;

import 'package:evolve_desktop/features/statistics/data/private_analytics.dart';

/// Net-new desktop statistics that do NOT exist on mobile. Kept in a separate
/// file from [private_analytics.dart] (which is a byte-for-byte mirror of the
/// mobile engine) so the mirror stays faithful.
///
/// Every function here is pure and computes from the same normalised inputs the
/// mobile-mirrored engine uses ([HabitLogEntry], [GoalInput], [dateKey] keyed
/// `logsByDate`), so they run identically in Private mode (encrypted DB) and
/// Cloud mode (dashboard snapshot) via the unified analytics-input provider.

double _mean(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

/// Whether [g] is scheduled/active on [date] — start/end window plus the
/// weekday frequency mask (null frequency = every day). Mirrors the active-day
/// test inside `computeGlobalTrend`.
bool isGoalActiveOn(GoalInput g, DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final start = DateTime(g.startDate.year, g.startDate.month, g.startDate.day);
  if (d.isBefore(start)) return false;
  if (g.endDate != null) {
    final end = DateTime(g.endDate!.year, g.endDate!.month, g.endDate!.day);
    if (d.isAfter(end)) return false;
  }
  if (g.frequencyDays != null && !g.frequencyDays!.contains(d.weekday)) {
    return false;
  }
  return true;
}

// ─── Lifetime summary ────────────────────────────────────────────────────────

/// Aggregate all-time figures for the Info-tab hero grid.
class LifetimeSummary {
  /// Total `done` logs across every habit, all time.
  final int totalCompletions;

  /// Total `missed` logs across every habit, all time.
  final int totalMissed;

  /// Distinct calendar days with at least one log of any status.
  final int activeDays;

  /// Days since the earliest habit start date (inclusive), 0 when no habits.
  final int trackedDays;

  /// Overall completion rate 0–100: Σ done ÷ Σ per-habit active days ×100.
  /// Same definition as mobile's "Global Completion %".
  final double consistency;

  /// Days on which every habit scheduled that day was `done` (strict).
  final int perfectDays;

  final DateTime? firstLogDate;

  const LifetimeSummary({
    required this.totalCompletions,
    required this.totalMissed,
    required this.activeDays,
    required this.trackedDays,
    required this.consistency,
    required this.perfectDays,
    required this.firstLogDate,
  });

  static const empty = LifetimeSummary(
    totalCompletions: 0,
    totalMissed: 0,
    activeDays: 0,
    trackedDays: 0,
    consistency: 0,
    perfectDays: 0,
    firstLogDate: null,
  );
}

LifetimeSummary computeLifetimeSummary({
  required List<HabitLogEntry> allLogs,
  required List<GoalInput> goals,
  required Map<String, Map<String, String>> logsByDate,
  required DateTime today,
}) {
  final t = DateTime(today.year, today.month, today.day);

  var totalCompletions = 0;
  var totalMissed = 0;
  DateTime? firstLog;
  final doneByGoal = <String, int>{};
  for (final l in allLogs) {
    if (l.status == 'done') {
      totalCompletions++;
      doneByGoal.update(l.goalId, (v) => v + 1, ifAbsent: () => 1);
    } else if (l.status == 'missed') {
      totalMissed++;
    }
    if (firstLog == null || l.date.isBefore(firstLog)) firstLog = l.date;
  }

  var sumDone = 0;
  var sumActive = 0;
  DateTime? earliestStart;
  for (final g in goals) {
    final start = DateTime(
      g.startDate.year,
      g.startDate.month,
      g.startDate.day,
    );
    if (earliestStart == null || start.isBefore(earliestStart)) {
      earliestStart = start;
    }
    sumActive += math.max(t.difference(start).inDays + 1, 1);
    sumDone += doneByGoal[g.id] ?? 0;
  }
  final consistency = sumActive > 0 ? sumDone * 100.0 / sumActive : 0.0;
  final trackedDays = earliestStart == null
      ? 0
      : math.max(t.difference(earliestStart).inDays + 1, 1);

  var perfectDays = 0;
  logsByDate.forEach((dk, habits) {
    final date = DateTime.tryParse(dk);
    if (date == null) return;
    final active = goals.where((g) => isGoalActiveOn(g, date));
    if (active.isEmpty) return;
    if (active.every((g) => habits[g.id] == 'done')) perfectDays++;
  });

  return LifetimeSummary(
    totalCompletions: totalCompletions,
    totalMissed: totalMissed,
    activeDays: logsByDate.length,
    trackedDays: trackedDays,
    consistency: consistency,
    perfectDays: perfectDays,
    firstLogDate: firstLog,
  );
}

// ─── Keystone habit ──────────────────────────────────────────────────────────

/// The habit whose completion coincides with the highest completion of every
/// OTHER habit — the "keystone" (Atomic Habits) idea, quantified.
class KeystoneInsight {
  final String goalId;

  /// Avg completion % of the other habits on days this habit was done.
  final double withRate;

  /// Avg completion % of the other habits on days this habit was NOT done.
  final double withoutRate;

  /// [withRate] − [withoutRate]. Higher ⇒ stronger keystone effect.
  final double lift;

  /// Number of done-days that fed [withRate] (confidence).
  final int doneDays;

  const KeystoneInsight({
    required this.goalId,
    required this.withRate,
    required this.withoutRate,
    required this.lift,
    required this.doneDays,
  });
}

/// Returns the habit with the greatest positive lift, or null when there are
/// fewer than two habits or none has enough signal (≥3 done-days and at least
/// one comparison day) to be meaningful.
KeystoneInsight? computeKeystoneHabit({
  required List<GoalInput> goals,
  required Map<String, Map<String, String>> logsByDate,
}) {
  if (goals.length < 2) return null;

  KeystoneInsight? best;
  for (final h in goals) {
    final onDone = <double>[];
    final onWithout = <double>[];
    logsByDate.forEach((dk, habits) {
      final date = DateTime.tryParse(dk);
      if (date == null) return;
      var otherActive = 0;
      var otherDone = 0;
      for (final g in goals) {
        if (g.id == h.id) continue;
        if (!isGoalActiveOn(g, date)) continue;
        otherActive++;
        if (habits[g.id] == 'done') otherDone++;
      }
      if (otherActive == 0) return;
      final frac = otherDone / otherActive;
      if (habits[h.id] == 'done') {
        onDone.add(frac);
      } else {
        onWithout.add(frac);
      }
    });
    if (onDone.length < 3 || onWithout.isEmpty) continue;
    final withRate = _mean(onDone) * 100;
    final withoutRate = _mean(onWithout) * 100;
    final lift = withRate - withoutRate;
    if (best == null || lift > best.lift) {
      best = KeystoneInsight(
        goalId: h.id,
        withRate: withRate,
        withoutRate: withoutRate,
        lift: lift,
        doneDays: onDone.length,
      );
    }
  }
  return best;
}

// ─── Bounce-back (recovery after a miss) ─────────────────────────────────────

class BounceBackHabit {
  final String goalId;
  final double rate; // 0–100
  final int opportunities;
  final int recoveries;

  const BounceBackHabit({
    required this.goalId,
    required this.rate,
    required this.opportunities,
    required this.recoveries,
  });
}

class BounceBackStats {
  final double globalRate; // 0–100
  final int opportunities;
  final int recoveries;
  final List<BounceBackHabit> habits; // sorted best-first

  const BounceBackStats({
    required this.globalRate,
    required this.opportunities,
    required this.recoveries,
    required this.habits,
  });

  static const empty = BounceBackStats(
    globalRate: 0,
    opportunities: 0,
    recoveries: 0,
    habits: [],
  );
}

/// After each `missed`, does the next tracked (non-skipped) log come back
/// `done`? Skipped days are neutral and scanned through.
BounceBackStats computeBounceBackRate({
  required Map<String, List<HabitLogEntry>> logsByGoal,
}) {
  var globalOpp = 0;
  var globalRec = 0;
  final habits = <BounceBackHabit>[];

  logsByGoal.forEach((goalId, logs) {
    final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));
    var opp = 0;
    var rec = 0;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i].status != 'missed') continue;
      var j = i + 1;
      while (j < sorted.length && sorted[j].status == 'skipped') {
        j++;
      }
      if (j >= sorted.length) break;
      opp++;
      if (sorted[j].status == 'done') rec++;
    }
    if (opp > 0) {
      habits.add(
        BounceBackHabit(
          goalId: goalId,
          rate: rec * 100.0 / opp,
          opportunities: opp,
          recoveries: rec,
        ),
      );
      globalOpp += opp;
      globalRec += rec;
    }
  });

  habits.sort((a, b) => b.rate.compareTo(a.rate));
  return BounceBackStats(
    globalRate: globalOpp > 0 ? globalRec * 100.0 / globalOpp : 0,
    opportunities: globalOpp,
    recoveries: globalRec,
    habits: habits,
  );
}

// ─── Weekday vs weekend ──────────────────────────────────────────────────────

class WeekdaySplit {
  final double weekdayRate; // 0–100 (Mon–Fri)
  final double weekendRate; // 0–100 (Sat–Sun)
  final int weekdayDone;
  final int weekdayTotal;
  final int weekendDone;
  final int weekendTotal;

  const WeekdaySplit({
    required this.weekdayRate,
    required this.weekendRate,
    required this.weekdayDone,
    required this.weekdayTotal,
    required this.weekendDone,
    required this.weekendTotal,
  });

  bool get hasData => weekdayTotal > 0 || weekendTotal > 0;
}

/// Completion on weekdays (Mon–Fri) vs weekends (Sat–Sun). Skipped days are
/// excluded from both the numerator and denominator.
WeekdaySplit computeWeekdayWeekendSplit(List<HabitLogEntry> allLogs) {
  var wdDone = 0, wdTotal = 0, weDone = 0, weTotal = 0;
  for (final l in allLogs) {
    if (l.status != 'done' && l.status != 'missed') continue;
    if (l.date.weekday >= 6) {
      weTotal++;
      if (l.status == 'done') weDone++;
    } else {
      wdTotal++;
      if (l.status == 'done') wdDone++;
    }
  }
  return WeekdaySplit(
    weekdayRate: wdTotal > 0 ? wdDone * 100.0 / wdTotal : 0,
    weekendRate: weTotal > 0 ? weDone * 100.0 / weTotal : 0,
    weekdayDone: wdDone,
    weekdayTotal: wdTotal,
    weekendDone: weDone,
    weekendTotal: weTotal,
  );
}

// ─── Global weekday performance (all habits) ─────────────────────────────────

class WeekdayPerf {
  final int dayIndex; // ISODOW 1=Mon..7=Sun
  final int done;
  final int total;

  const WeekdayPerf({
    required this.dayIndex,
    required this.done,
    required this.total,
  });

  double get rate => total > 0 ? done * 100.0 / total : 0;
}

/// Per-weekday completion across ALL habits (skipped excluded). Always returns
/// all 7 days (Mon→Sun), filling untracked days with 0/0.
List<WeekdayPerf> computeGlobalWeekdayPerformance(List<HabitLogEntry> allLogs) {
  final total = <int, int>{};
  final done = <int, int>{};
  for (final l in allLogs) {
    if (l.status != 'done' && l.status != 'missed') continue;
    final d = l.date.weekday;
    total[d] = (total[d] ?? 0) + 1;
    if (l.status == 'done') done[d] = (done[d] ?? 0) + 1;
  }
  return [
    for (var d = 1; d <= 7; d++)
      WeekdayPerf(dayIndex: d, done: done[d] ?? 0, total: total[d] ?? 0),
  ];
}

// ─── Seasonality (per calendar month, all years) ─────────────────────────────

class MonthPerf {
  final int month; // 1=Jan..12=Dec
  final int done;
  final int total;

  const MonthPerf({
    required this.month,
    required this.done,
    required this.total,
  });

  double get rate => total > 0 ? done * 100.0 / total : 0;
}

/// Completion grouped by calendar month across all history (skipped excluded).
/// Always returns 12 entries (Jan→Dec).
List<MonthPerf> computeSeasonality(List<HabitLogEntry> allLogs) {
  final total = <int, int>{};
  final done = <int, int>{};
  for (final l in allLogs) {
    if (l.status != 'done' && l.status != 'missed') continue;
    final m = l.date.month;
    total[m] = (total[m] ?? 0) + 1;
    if (l.status == 'done') done[m] = (done[m] ?? 0) + 1;
  }
  return [
    for (var m = 1; m <= 12; m++)
      MonthPerf(month: m, done: done[m] ?? 0, total: total[m] ?? 0),
  ];
}

// ─── Consistency (regularity) score ──────────────────────────────────────────

class ConsistencyScore {
  final String goalId;

  /// 0–100. 100 = perfectly evenly-spaced completions; lower = more erratic.
  /// Derived from the coefficient of variation of gaps between done-days.
  final double score;
  final int doneCount;

  const ConsistencyScore({
    required this.goalId,
    required this.score,
    required this.doneCount,
  });
}

/// Per-habit regularity: `100 × (1 − min(CV, 1))` where CV is the coefficient
/// of variation (σ/μ) of day-gaps between consecutive completions. Habits with
/// fewer than 3 completions are omitted (not enough signal). Sorted steadiest
/// first.
List<ConsistencyScore> computeConsistencyScores(
  Map<String, List<HabitLogEntry>> logsByGoal,
) {
  final out = <ConsistencyScore>[];
  logsByGoal.forEach((goalId, logs) {
    final dates =
        logs.where((l) => l.status == 'done').map((l) => l.date).toList()
          ..sort();
    if (dates.length < 3) return;
    final gaps = <int>[
      for (var i = 1; i < dates.length; i++)
        dates[i].difference(dates[i - 1]).inDays,
    ];
    final mean = gaps.reduce((a, b) => a + b) / gaps.length;
    double score;
    if (mean <= 0) {
      score = 100;
    } else {
      final variance =
          gaps
              .map((g) => math.pow(g - mean, 2).toDouble())
              .reduce((a, b) => a + b) /
          gaps.length;
      final cv = math.sqrt(variance) / mean;
      score = (1 - cv.clamp(0.0, 1.0)) * 100;
    }
    out.add(
      ConsistencyScore(goalId: goalId, score: score, doneCount: dates.length),
    );
  });
  out.sort((a, b) => b.score.compareTo(a.score));
  return out;
}

// ─── Danger zone (when streaks break) ───────────────────────────────────────

class DangerZone {
  /// ISODOW 1=Mon..7=Sun with the most streak-breaks.
  final int weekday;

  /// Breaks that fell on [weekday].
  final int breaks;

  /// Total streak-breaks across all habits.
  final int totalBreaks;

  const DangerZone({
    required this.weekday,
    required this.breaks,
    required this.totalBreaks,
  });
}

/// The weekday on which streaks most often break — a `missed` that directly
/// follows a `done` for the same habit. Returns null when nothing has broken.
DangerZone? computeDangerZone(Map<String, List<HabitLogEntry>> logsByGoal) {
  final byWeekday = <int, int>{};
  var total = 0;
  logsByGoal.forEach((_, logs) {
    final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].status == 'missed' && sorted[i - 1].status == 'done') {
        byWeekday.update(
          sorted[i].date.weekday,
          (v) => v + 1,
          ifAbsent: () => 1,
        );
        total++;
      }
    }
  });
  if (total == 0) return null;
  final top = byWeekday.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return DangerZone(weekday: top.key, breaks: top.value, totalBreaks: total);
}

// ─── Momentum / Form gauge ───────────────────────────────────────────────────

class MomentumScore {
  final double score; // 0–100 composite
  final double rate7; // 0–1
  final double streakHealth; // 0–1
  final double trend; // 0–1 (0.5 = flat)

  const MomentumScore({
    required this.score,
    required this.rate7,
    required this.streakHealth,
    required this.trend,
  });

  static const empty = MomentumScore(
    score: 0,
    rate7: 0,
    streakHealth: 0,
    trend: 0.5,
  );
}

/// Composite 0–100 "current form":
/// `50·rate7 + 30·streakHealth + 20·trend`.
///  * rate7        — last-7-day completion fraction (0–1)
///  * streakHealth — mean over habits of clamp(current ÷ best, 0, 1)
///  * trend        — clamp(0.5 + (rate7 − ratePrev7), 0, 1); 0.5 is flat
MomentumScore computeMomentumScore({
  required double rate7,
  required double ratePrev7,
  required List<({int current, int best})> streaks,
}) {
  var sum = 0.0;
  var n = 0;
  for (final s in streaks) {
    final best = math.max(s.best, 1);
    sum += (s.current / best).clamp(0.0, 1.0);
    n++;
  }
  final streakHealth = n > 0 ? sum / n : 0.0;
  final r7 = rate7.clamp(0.0, 1.0);
  final trend = (0.5 + (rate7 - ratePrev7)).clamp(0.0, 1.0);
  final score = (0.5 * r7 + 0.3 * streakHealth + 0.2 * trend) * 100;
  return MomentumScore(
    score: score,
    rate7: r7,
    streakHealth: streakHealth,
    trend: trend,
  );
}
