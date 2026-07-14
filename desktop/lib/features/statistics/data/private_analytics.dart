import 'dart:math' as math;

/// Pure, backend-free reimplementations of the cloud analytics RPCs/view, so
/// Private Mode produces output identical in shape and semantics to Supabase.
///
/// PORTED VERBATIM from the mobile client (`mattioli_os` `lib/core/private_analytics.dart`)
/// so both clients compute byte-identical statistics. Do not diverge from mobile
/// without changing it there too. Each function mirrors a specific cloud
/// definition:
///
///   * [computeHabitStatsRow]      -> view `habit_stats`
///   * [computeYearlyGrid]         -> `get_habit_yearly_grid`
///   * [computePerformanceByDay]   -> `get_habit_performance_by_day`
///   * [computeHabitAlerts]        -> `get_habit_alerts`
///   * [computeAnalyticsRow]       -> `get_habit_analytics`
///   * [computeGlobalCriticalDay]  -> `get_global_critical_day`
///   * [computeCriticalHabits]     -> `get_critical_habits`
///   * [computeBestHabits]         -> `get_best_habits`
///   * [computeGlobalTrend]        -> `get_global_trend`
///
/// Keeping the logic pure makes the parity testable against fixtures without a
/// live SQLCipher database.

/// ISODOW (1=Mon..7=Sun) -> 3-letter token, matching the cloud functions.
const List<String> kIsoDowTokens = [
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];

/// A single `goal_logs` row, normalised for computation.
class HabitLogEntry {
  final String goalId;
  final DateTime date;
  final String status; // 'done' | 'missed' | 'skipped'
  final int streak; // signed: >0 done run, <0 missed run

  HabitLogEntry({
    required this.goalId,
    required DateTime date,
    required this.status,
    this.streak = 0,
  }) : date = DateTime(date.year, date.month, date.day);
}

/// The subset of a goal needed by the trend/critical computations.
class GoalInput {
  final String id;
  final DateTime startDate;
  final DateTime? endDate;
  final List<int>? frequencyDays; // ISODOW values; null = every day

  GoalInput({
    required this.id,
    required this.startDate,
    this.endDate,
    this.frequencyDays,
  });
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

DateTime _addMonths(DateTime monthStart, int delta) =>
    DateTime(monthStart.year, monthStart.month + delta, 1);

/// Calendar days from [from] to [to], DST-safe: measured on UTC midnights so a
/// span crossing a spring-forward (23h) or fall-back (25h) day is not truncated
/// by the missing/extra hour. Replaces `a.difference(b).inDays` on local dates,
/// which under-counts by a day across a DST boundary and can push rate>100%.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// [d] shifted by [n] calendar days, landing on local midnight (DST-safe).
/// Replaces `d.add(Duration(days: n))`, which can land at 23:00/01:00 of an
/// adjacent day across a DST transition and mis-key the calendar day.
DateTime _shiftDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

// ─── habit_stats view ────────────────────────────────────────────────────────

/// One row of the `habit_stats` view for a single goal. [logs] must be only the
/// logs belonging to [goalId].
Map<String, dynamic> computeHabitStatsRow({
  required String goalId,
  required String userId,
  required String? title,
  required DateTime startDate,
  required List<HabitLogEntry> logs,
  required DateTime today,
}) {
  HabitLogEntry? latest;
  int? bestDone; // max streak among 'done'
  int? worstMissed; // min streak among 'missed'
  var totalCompletions = 0;
  var missedDays = 0;

  for (final l in logs) {
    if (latest == null || l.date.isAfter(latest.date)) latest = l;
    if (l.status == 'done') {
      totalCompletions++;
      bestDone = bestDone == null ? l.streak : math.max(bestDone, l.streak);
    } else if (l.status == 'missed') {
      missedDays++;
      worstMissed = worstMissed == null
          ? l.streak
          : math.min(worstMissed, l.streak);
    }
  }

  final totalActiveDays = math.max(_daysBetween(startDate, today) + 1, 1);
  final rate = totalActiveDays == 0
      ? 0.0
      : totalCompletions * 100.0 / totalActiveDays;

  return {
    'goal_id': goalId,
    'user_id': userId,
    'title': title,
    'current_streak': latest?.streak ?? 0,
    'best_streak': bestDone ?? 0,
    'worst_streak': worstMissed == null ? 0 : worstMissed.abs(),
    'total_completions': totalCompletions,
    'missed_days': missedDays,
    'total_active_days': totalActiveDays,
    'rate': rate,
  };
}

// ─── get_habit_yearly_grid ───────────────────────────────────────────────────

/// 365 status codes (oldest -> newest), done=1, missed=2, otherwise 0.
List<int> computeYearlyGrid(List<HabitLogEntry> logs, DateTime today) {
  final byDate = <String, String>{
    for (final l in logs) dateKey(l.date): l.status,
  };
  final start = _shiftDays(today, -364);
  return List.generate(365, (i) {
    final s = byDate[dateKey(_shiftDays(start, i))];
    return switch (s) {
      'done' => 1,
      'missed' => 2,
      _ => 0,
    };
  });
}

// ─── get_habit_performance_by_day ────────────────────────────────────────────

/// Per ISODOW (1=Mon..7=Sun) done/total counts, only for days that have logs,
/// ascending by day_index.
List<Map<String, dynamic>> computePerformanceByDay(List<HabitLogEntry> logs) {
  final total = <int, int>{};
  final done = <int, int>{};
  for (final l in logs) {
    final dow = l.date.weekday;
    total[dow] = (total[dow] ?? 0) + 1;
    if (l.status == 'done') done[dow] = (done[dow] ?? 0) + 1;
  }
  final dows = total.keys.toList()..sort();
  return [
    for (final dow in dows)
      {
        'day_index': dow,
        'done_count': done[dow] ?? 0,
        'total_count': total[dow]!,
      },
  ];
}

// ─── get_habit_alerts ────────────────────────────────────────────────────────

/// {worst_negative_days, worst_negative_start, broken_streaks:[{days,date}]}.
Map<String, dynamic> computeHabitAlerts(List<HabitLogEntry> logs) {
  final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));

  var worstNegDays = 0;
  DateTime? worstNegStart;
  final doneRuns = <({int days, DateTime endDate})>[];

  var i = 0;
  while (i < sorted.length) {
    var j = i;
    while (j + 1 < sorted.length && sorted[j + 1].status == sorted[i].status) {
      j++;
    }
    final runLength = j - i + 1;
    if (sorted[i].status == 'missed') {
      if (runLength > worstNegDays) {
        worstNegDays = runLength;
        worstNegStart = sorted[i].date;
      }
    } else if (sorted[i].status == 'done') {
      doneRuns.add((days: runLength, endDate: sorted[j].date));
    }
    i = j + 1;
  }

  final broken = <({int days, DateTime breakDate})>[];
  for (final run in doneRuns) {
    for (final l in sorted) {
      if (l.status == 'missed' && l.date.isAfter(run.endDate)) {
        broken.add((days: run.days, breakDate: l.date));
        break;
      }
    }
  }
  broken.sort((a, b) => b.breakDate.compareTo(a.breakDate));

  return {
    'worst_negative_days': worstNegDays,
    'worst_negative_start': worstNegStart == null
        ? null
        : dateKey(worstNegStart),
    'broken_streaks': [
      for (final b in broken.take(5))
        {'days': b.days, 'date': dateKey(b.breakDate)},
    ],
  };
}

// ─── get_habit_analytics ─────────────────────────────────────────────────────

/// {goal_id, worst_dow, avg_recovery_days} for a single goal. [logs] must be
/// only this goal's logs.
Map<String, dynamic> computeAnalyticsRow({
  required String goalId,
  required List<HabitLogEntry> logs,
}) {
  final total = <int, int>{};
  final done = <int, int>{};
  for (final l in logs) {
    final dow = l.date.weekday;
    total[dow] = (total[dow] ?? 0) + 1;
    if (l.status == 'done') done[dow] = (done[dow] ?? 0) + 1;
  }

  var worstDow = 1;
  double? worstRate;
  for (final dow in total.keys.toList()..sort()) {
    final rate = (done[dow] ?? 0) / total[dow]!;
    if (worstRate == null || rate < worstRate) {
      worstRate = rate;
      worstDow = dow;
    }
  }

  final doneDates =
      logs.where((l) => l.status == 'done').map((l) => l.date).toList()..sort();
  var avgRecovery = 0.0;
  if (doneDates.length >= 2) {
    var sum = 0;
    for (var k = 1; k < doneDates.length; k++) {
      sum += _daysBetween(doneDates[k - 1], doneDates[k]) - 1;
    }
    avgRecovery = sum / (doneDates.length - 1);
  }

  return {
    'goal_id': goalId,
    'worst_dow': worstDow,
    'avg_recovery_days': avgRecovery,
  };
}

// ─── get_global_critical_day ─────────────────────────────────────────────────

/// Lowest done-rate weekday token ('mon'..'sun'), tie-broken alphabetically by
/// token (matching the cloud `day_of_week ASC`). 'N/A' when there are no logs.
String computeGlobalCriticalDay(List<HabitLogEntry> logs) {
  final total = <int, int>{};
  final done = <int, int>{};
  for (final l in logs) {
    if (l.status != 'done' && l.status != 'missed') continue;
    final dow = l.date.weekday;
    total[dow] = (total[dow] ?? 0) + 1;
    if (l.status == 'done') done[dow] = (done[dow] ?? 0) + 1;
  }
  if (total.isEmpty) return 'N/A';

  final ranked =
      total.keys.map((dow) {
        return (
          token: kIsoDowTokens[dow - 1],
          rate: (done[dow] ?? 0) / total[dow]!,
        );
      }).toList()..sort((a, b) {
        final c = a.rate.compareTo(b.rate);
        return c != 0 ? c : a.token.compareTo(b.token);
      });
  return ranked.first.token;
}

// ─── get_critical_habits ─────────────────────────────────────────────────────

/// Goals whose 7-day completion rate dropped vs the prior 7 days, or that have
/// gone too long without a 'done'. Each: {goal_id, drop, neg_streak}.
List<Map<String, dynamic>> computeCriticalHabits({
  required List<GoalInput> goals,
  required Map<String, List<HabitLogEntry>> logsByGoal,
  required DateTime today,
}) {
  final t = _dateOnly(today);
  final result = <Map<String, dynamic>>[];

  for (final g in goals) {
    final logs = logsByGoal[g.id] ?? const [];
    var twDone = 0, twTotal = 0, lwDone = 0, lwTotal = 0;
    DateTime? lastDone;

    for (final l in logs) {
      final age = _daysBetween(l.date, t);
      if (age > 14) continue; // recent 14-day window
      if (age <= 7) {
        twTotal++;
        if (l.status == 'done') twDone++;
      } else {
        lwTotal++;
        if (l.status == 'done') lwDone++;
      }
      if (l.status == 'done' &&
          (lastDone == null || l.date.isAfter(lastDone))) {
        lastDone = l.date;
      }
    }

    final twRate = twTotal > 0 ? twDone / twTotal : 0.0;
    final lwRate = lwTotal > 0 ? lwDone / lwTotal : 0.0;
    final drop = (lwRate - twRate) * 100;
    final negStreak = lastDone == null ? 14 : _daysBetween(lastDone, t);

    if (drop > 0 || negStreak > 3) {
      result.add({'goal_id': g.id, 'drop': drop, 'neg_streak': negStreak});
    }
  }

  result.sort((a, b) {
    final c = (b['drop'] as num).compareTo(a['drop'] as num);
    return c != 0
        ? c
        : (b['neg_streak'] as num).compareTo(a['neg_streak'] as num);
  });
  return result;
}

// ─── get_best_habits ─────────────────────────────────────────────────────────

/// Top-5 goals by completion rate within [timeframe] ('week'|'month'|'year'|
/// 'all'), then by current positive streak. Each: {goal_id, rate, streak}.
///
/// Mirrors the cloud function's exact filter. Callers must pass a canonical
/// token; use [canonicalBestHabitsTimeframe] on the UI's 'timeframe_*'
/// vocabulary before this runs. The `_ => -1` branch below is therefore
/// defensive only: an unrecognised token yields an empty window (rate 0).
List<Map<String, dynamic>> computeBestHabits({
  required List<GoalInput> goals,
  required Map<String, List<HabitLogEntry>> logsByGoal,
  required String timeframe,
  required DateTime today,
}) {
  final t = _dateOnly(today);
  // null = no date filter ('all'); -1 sentinel = no window matched -> empty set.
  final int? windowDays = switch (timeframe) {
    'week' => 7,
    'month' => 30,
    'year' => 365,
    'all' => null,
    _ => -1,
  };

  final rows = <Map<String, dynamic>>[];
  for (final g in goals) {
    final logs = logsByGoal[g.id] ?? const [];
    var done = 0, total = 0;
    DateTime? lastNonDone;

    for (final l in logs) {
      final inWindow = windowDays == null
          ? true
          : windowDays == -1
          ? false
          : _daysBetween(l.date, t) <= windowDays;
      if (inWindow) {
        total++;
        if (l.status == 'done') done++;
      }
      if (l.status != 'done' &&
          (lastNonDone == null || l.date.isAfter(lastNonDone))) {
        lastNonDone = l.date;
      }
    }

    final streak = logs
        .where(
          (l) =>
              l.status == 'done' &&
              (lastNonDone == null || l.date.isAfter(lastNonDone)),
        )
        .length;
    final rate = total > 0 ? done / total * 100 : 0.0;
    rows.add({'goal_id': g.id, 'rate': rate, 'streak': streak});
  }

  rows.sort((a, b) {
    final c = (b['rate'] as num).compareTo(a['rate'] as num);
    return c != 0 ? c : (b['streak'] as num).compareTo(a['streak'] as num);
  });
  return rows.take(5).toList();
}

/// Canonicalises the UI's `timeframe_*` vocabulary to the token
/// [computeBestHabits] expects. Mirrors the mobile client.
String canonicalBestHabitsTimeframe(String timeframe) {
  switch (timeframe) {
    case 'week':
    case 'month':
    case 'year':
    case 'all':
      return timeframe;
    case 'timeframe_week_short':
    case 'timeframe_week':
      return 'week';
    case 'timeframe_month_short':
    case 'timeframe_month':
      return 'month';
    case 'timeframe_year_short':
    case 'timeframe_year':
      return 'year';
    case 'timeframe_all':
      return 'all';
    default:
      return 'all';
  }
}

// ─── get_global_trend ────────────────────────────────────────────────────────

/// Completion-rate trend over [timeframe]. Each point: {point_index, date, rate}
/// where rate = done / active * 100 for that day (100 when no goal is active).
List<Map<String, dynamic>> computeGlobalTrend({
  required List<GoalInput> goals,
  required Map<String, Map<String, String>> logs, // dateKey -> goalId -> status
  required String timeframe,
  required DateTime today,
}) {
  final t = _dateOnly(today);

  double rateForDay(DateTime date) {
    final dayLogs = logs[dateKey(date)] ?? const <String, String>{};
    var active = 0, done = 0;
    for (final g in goals) {
      if (date.isBefore(_dateOnly(g.startDate))) continue;
      if (g.endDate != null && date.isAfter(_dateOnly(g.endDate!))) continue;
      if (g.frequencyDays != null && !g.frequencyDays!.contains(date.weekday)) {
        continue;
      }
      final status = dayLogs[g.id];
      if (status == null || status != 'skipped') active++;
      if (status == 'done') done++;
    }
    return active > 0 ? done / active * 100 : 100.0;
  }

  List<Map<String, dynamic>> daily(int n) => [
    for (var i = 0; i < n; i++)
      () {
        final date = t.subtract(Duration(days: n - 1 - i));
        return {
          'point_index': i,
          'date': dateKey(date),
          'rate': rateForDay(date),
        };
      }(),
  ];

  double avg(Iterable<double> xs) {
    var sum = 0.0, n = 0;
    for (final x in xs) {
      sum += x;
      n++;
    }
    return n == 0 ? 0.0 : sum / n;
  }

  switch (timeframe) {
    case 'timeframe_week_short':
      return daily(14);
    case 'timeframe_month_short':
      return daily(60);
    case 'timeframe_year_short':
      final monthStart0 = _firstOfMonth(t);
      final out = <Map<String, dynamic>>[];
      for (var i = 0; i < 24; i++) {
        final ms = _addMonths(monthStart0, -(23 - i));
        final monthEnd = _addMonths(ms, 1).subtract(const Duration(days: 1));
        final last = monthEnd.isAfter(t) ? t : monthEnd;
        if (ms.isAfter(last)) continue;
        final rates = <double>[];
        for (var d = ms; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
          rates.add(rateForDay(d));
        }
        out.add({'point_index': i, 'date': dateKey(ms), 'rate': avg(rates)});
      }
      return out;
    default: // 'timeframe_all' and any unrecognised token
      DateTime earliest;
      if (goals.isEmpty) {
        earliest = t.subtract(const Duration(days: 30));
      } else {
        earliest = goals
            .map((g) => _dateOnly(g.startDate))
            .reduce((a, b) => a.isBefore(b) ? a : b);
      }
      final days = t.difference(earliest).inDays;
      final interval = days > 10 ? (days / 10).ceil() : 1;
      final pointsCount = days > 10 ? 10 : days + 1;
      final out = <Map<String, dynamic>>[];
      for (var i = 0; i < pointsCount; i++) {
        final startI = earliest.add(Duration(days: i * interval));
        final endI = earliest.add(Duration(days: (i + 1) * interval - 1));
        final last = endI.isAfter(t) ? t : endI;
        if (startI.isAfter(last)) continue;
        final rates = <double>[];
        for (
          var d = startI;
          !d.isAfter(last);
          d = d.add(const Duration(days: 1))
        ) {
          rates.add(rateForDay(d));
        }
        out.add({
          'point_index': i,
          'date': dateKey(startI),
          'rate': avg(rates),
        });
      }
      return out;
  }
}

// ─── get_habit_correlations ──────────────────────────────────────────────────

/// For each other habit, how often it was also 'done' on days the target was
/// 'done'. Mirrors the cloud correlation logic. [logsByDate] is
/// dateKey -> goalId -> status.
List<Map<String, dynamic>> computeHabitCorrelations(
  String targetGoalId,
  Map<String, Map<String, String>> logsByDate,
) {
  final together = <String, int>{};
  var targetDone = 0;

  logsByDate.forEach((date, habits) {
    if (habits[targetGoalId] != 'done') return;
    targetDone++;
    habits.forEach((goalId, status) {
      if (goalId != targetGoalId && status == 'done') {
        together.update(goalId, (v) => v + 1, ifAbsent: () => 1);
      }
    });
  });

  return together.entries.map((entry) {
    return {
      'goal_id': entry.key,
      'together_count': entry.value,
      'percentage': targetDone == 0
          ? 0
          : (entry.value / targetDone * 100).round(),
    };
  }).toList();
}

/// Mirrors `get_all_habit_correlations`: every goal's co-completion rows.
List<Map<String, dynamic>> computeAllHabitCorrelations(
  List<String> goalIds,
  Map<String, Map<String, String>> logsByDate,
) {
  final result = <Map<String, dynamic>>[];
  for (final goalId in goalIds) {
    for (final correlation in computeHabitCorrelations(goalId, logsByDate)) {
      result.add({
        'goal_id': goalId,
        'other_goal_id': correlation['goal_id'],
        'percentage': correlation['percentage'],
        'together_count': correlation['together_count'],
      });
    }
  }
  return result;
}

// ─── mood correlations (per-habit mood/energy sensitivity) ───────────────────

/// One habit's mood/energy correlation, mirroring mobile's `MoodCorrelation`
/// (`mattioli_os` `lib/providers/mood_provider.dart`). Percentages are ints;
/// avg mood/energy are on the 0–10 check-in scale.
class MoodCorrelation {
  final String goalId;
  final int lowMoodPct;
  final int highMoodPct;
  final int sensitivity;
  final int resilience;
  final double avgMoodDone;
  final double avgEnergyDone;
  final double avgMoodMissed;
  final double avgEnergyMissed;

  const MoodCorrelation({
    required this.goalId,
    required this.lowMoodPct,
    required this.highMoodPct,
    required this.sensitivity,
    required this.resilience,
    required this.avgMoodDone,
    required this.avgEnergyDone,
    required this.avgMoodMissed,
    required this.avgEnergyMissed,
  });
}

/// A single day's mood/energy check-in, normalised for the correlation engine.
/// Mood/energy are on a 0–10 scale (matching the daily check-in slider and the
/// `daily_moods` columns). Missing values are treated as 0, mirroring how the
/// private store persists them.
class MoodEntry {
  final int moodScore;
  final int energyScore;

  const MoodEntry({required this.moodScore, required this.energyScore});
}

/// Ported verbatim from mobile's `computeMoodCorrelations`
/// (`lib/providers/mood_provider.dart`). For each habit, computes low-vs-high
/// mood completion %, sensitivity (high − low), resilience (low-mood %), and the
/// average mood/energy on done vs missed days. [moodsByDate] and [logsByDate]
/// are both keyed by dateKey (`YYYY-MM-DD`).
///
/// The 0–10 banding: high = mood ≥ 6, low = mood < 4, 4–5 neutral — identical to
/// mobile so both clients produce the same numbers.
List<MoodCorrelation> computeMoodCorrelations({
  required Map<String, MoodEntry> moodsByDate,
  required Map<String, Map<String, String>> logsByDate,
}) {
  final habitCorrelations = <String, Map<String, num>>{};

  logsByDate.forEach((dateStr, habits) {
    final mood = moodsByDate[dateStr];
    if (mood == null) return;
    final isHighMood = mood.moodScore >= 6;
    final isLowMood = mood.moodScore < 4;

    habits.forEach((goalId, status) {
      final data = habitCorrelations.putIfAbsent(
        goalId,
        () => {
          'high_done': 0,
          'high_total': 0,
          'low_done': 0,
          'low_total': 0,
          'mood_done_sum': 0,
          'mood_done_count': 0,
          'energy_done_sum': 0,
          'energy_done_count': 0,
          'mood_missed_sum': 0,
          'mood_missed_count': 0,
          'energy_missed_sum': 0,
          'energy_missed_count': 0,
        },
      );

      if (isHighMood) {
        data['high_total'] = data['high_total']! + 1;
        if (status == 'done') data['high_done'] = data['high_done']! + 1;
      } else if (isLowMood) {
        data['low_total'] = data['low_total']! + 1;
        if (status == 'done') data['low_done'] = data['low_done']! + 1;
      }

      if (status == 'done') {
        data['mood_done_sum'] = data['mood_done_sum']! + mood.moodScore;
        data['mood_done_count'] = data['mood_done_count']! + 1;
        data['energy_done_sum'] = data['energy_done_sum']! + mood.energyScore;
        data['energy_done_count'] = data['energy_done_count']! + 1;
      } else if (status == 'missed') {
        data['mood_missed_sum'] = data['mood_missed_sum']! + mood.moodScore;
        data['mood_missed_count'] = data['mood_missed_count']! + 1;
        data['energy_missed_sum'] =
            data['energy_missed_sum']! + mood.energyScore;
        data['energy_missed_count'] = data['energy_missed_count']! + 1;
      }
    });
  });

  final result = <MoodCorrelation>[];

  habitCorrelations.forEach((goalId, data) {
    final highTotal = data['high_total']!;
    final lowTotal = data['low_total']!;

    final highPct = highTotal > 0
        ? (data['high_done']! / highTotal * 100).round()
        : 0;
    final lowPct = lowTotal > 0
        ? (data['low_done']! / lowTotal * 100).round()
        : 0;

    final sensitivity = highPct - lowPct;
    final resilience = lowPct;

    final moodDoneCount = data['mood_done_count']!;
    final energyDoneCount = data['energy_done_count']!;
    final moodMissedCount = data['mood_missed_count']!;
    final energyMissedCount = data['energy_missed_count']!;

    final avgMoodDone = moodDoneCount > 0
        ? data['mood_done_sum']! / moodDoneCount
        : 0.0;
    final avgEnergyDone = energyDoneCount > 0
        ? data['energy_done_sum']! / energyDoneCount
        : 0.0;
    final avgMoodMissed = moodMissedCount > 0
        ? data['mood_missed_sum']! / moodMissedCount
        : 0.0;
    final avgEnergyMissed = energyMissedCount > 0
        ? data['energy_missed_sum']! / energyMissedCount
        : 0.0;

    result.add(
      MoodCorrelation(
        goalId: goalId,
        lowMoodPct: lowPct,
        highMoodPct: highPct,
        sensitivity: sensitivity,
        resilience: resilience,
        avgMoodDone: avgMoodDone.toDouble(),
        avgEnergyDone: avgEnergyDone.toDouble(),
        avgMoodMissed: avgMoodMissed.toDouble(),
        avgEnergyMissed: avgEnergyMissed.toDouble(),
      ),
    );
  });

  return result;
}

// ─── get_macro_goals_stats ───────────────────────────────────────────────────

/// The subset of a macro goal (`long_term_goals` row) the macro stats need.
class MacroGoalStat {
  final String status; // 'active' | 'completed' | 'failed'
  final String type; // 'lifetime'|'annual'|'quarterly'|'monthly'|'weekly'
  final int? year;
  final int? month;
  final int? quarter;
  final String? categoryId;
  final String? categoryKey;

  const MacroGoalStat({
    required this.status,
    required this.type,
    this.year,
    this.month,
    this.quarter,
    this.categoryId,
    this.categoryKey,
  });

  String? get category => categoryId ?? categoryKey;
}

/// Mirrors the cloud `get_macro_goals_stats` RPC. Ported verbatim from mobile's
/// inline implementation; `year` is 'all' or a specific year string.
Map<String, dynamic> computeMacroGoalsStats(
  List<MacroGoalStat> allGoals,
  String year,
) {
  if (year == 'all') {
    final totalGoals = allGoals.length;
    final completedGoals = allGoals
        .where((g) => g.status == 'completed')
        .length;
    final successRate = totalGoals > 0
        ? (completedGoals / totalGoals * 100).round()
        : 0;

    final yearStats = <int, Map<String, int>>{};
    for (final g in allGoals) {
      if (g.year != null) {
        yearStats.putIfAbsent(g.year!, () => {'total': 0, 'completed': 0});
        yearStats[g.year!]!['total'] = yearStats[g.year!]!['total']! + 1;
        if (g.status == 'completed') {
          yearStats[g.year!]!['completed'] =
              yearStats[g.year!]!['completed']! + 1;
        }
      }
    }

    int? bestYear;
    int bestYearRate = -1;
    int? mostProdYear;
    int mostProdCount = -1;

    final yearProgression = <Map<String, dynamic>>[];
    final sortedYears = yearStats.keys.toList()..sort();
    for (final y in sortedYears) {
      final t = yearStats[y]!['total']!;
      final c = yearStats[y]!['completed']!;
      final r = t > 0 ? (c / t * 100).round() : 0;

      if (r > bestYearRate ||
          (r == bestYearRate && t > (yearStats[bestYear]?['total'] ?? 0))) {
        bestYearRate = r;
        bestYear = y;
      }
      if (c > mostProdCount) {
        mostProdCount = c;
        mostProdYear = y;
      }
      yearProgression.add({
        'year': y,
        'active': allGoals
            .where((g) => g.year == y && g.status == 'active')
            .length,
        'failed': allGoals
            .where((g) => g.year == y && g.status == 'failed')
            .length,
        'completed': c,
        'total': t,
      });
    }

    final categoryStats = <String, Map<String, int>>{};
    for (final g in allGoals) {
      final cat = g.category;
      if (cat != null) {
        categoryStats.putIfAbsent(cat, () => {'total': 0, 'completed': 0});
        categoryStats[cat]!['total'] = categoryStats[cat]!['total']! + 1;
        if (g.status == 'completed') {
          categoryStats[cat]!['completed'] =
              categoryStats[cat]!['completed']! + 1;
        }
      }
    }

    final categoryPerformance = categoryStats.entries.map((e) {
      final t = e.value['total']!;
      final c = e.value['completed']!;
      return {'category': e.key, 'rate': t > 0 ? (c / t * 100).round() : 0};
    }).toList();

    final typeDistribution = <String, int>{};
    for (final g in allGoals) {
      typeDistribution.update(g.type, (v) => v + 1, ifAbsent: () => 1);
    }

    final seasonalityStats = <int, Map<String, int>>{};
    for (final g in allGoals) {
      if (g.quarter != null) {
        seasonalityStats.putIfAbsent(
          g.quarter!,
          () => {'active': 0, 'failed': 0, 'completed': 0},
        );
        if (g.status == 'active') {
          seasonalityStats[g.quarter!]!['active'] =
              seasonalityStats[g.quarter!]!['active']! + 1;
        }
        if (g.status == 'failed') {
          seasonalityStats[g.quarter!]!['failed'] =
              seasonalityStats[g.quarter!]!['failed']! + 1;
        }
        if (g.status == 'completed') {
          seasonalityStats[g.quarter!]!['completed'] =
              seasonalityStats[g.quarter!]!['completed']! + 1;
        }
      }
    }
    final seasonality =
        seasonalityStats.entries
            .map(
              (e) => {
                'quarter': e.key,
                'active': e.value['active'],
                'failed': e.value['failed'],
                'completed': e.value['completed'],
              },
            )
            .toList()
          ..sort(
            (a, b) => (a['quarter'] as int).compareTo(b['quarter'] as int),
          );

    final monthlyStats = <int, Map<String, int>>{};
    for (final g in allGoals) {
      if (g.month != null) {
        monthlyStats.putIfAbsent(g.month!, () => {'total': 0, 'completed': 0});
        monthlyStats[g.month!]!['total'] =
            monthlyStats[g.month!]!['total']! + 1;
        if (g.status == 'completed') {
          monthlyStats[g.month!]!['completed'] =
              monthlyStats[g.month!]!['completed']! + 1;
        }
      }
    }
    final monthlyHistory =
        monthlyStats.entries.map((e) {
            final t = e.value['total']!;
            final c = e.value['completed']!;
            return {'month': e.key, 'rate': t > 0 ? (c / t * 100).round() : 0};
          }).toList()
          ..sort((a, b) => (a['month'] as int).compareTo(b['month'] as int));

    final interestEvolution = <Map<String, dynamic>>[];
    for (final y in sortedYears) {
      final catsForYear = <String, int>{};
      for (final g in allGoals.where((g) => g.year == y)) {
        final cat = g.category;
        if (cat != null) {
          catsForYear.update(cat, (v) => v + 1, ifAbsent: () => 1);
        }
      }
      interestEvolution.add({'year': y, 'categories': catsForYear});
    }

    return {
      'total_goals': totalGoals,
      'completed_goals': completedGoals,
      'success_rate': successRate,
      'best_year': bestYear,
      'best_year_rate': bestYearRate,
      'most_productive_year': mostProdYear,
      'most_productive_count': mostProdCount,
      'year_progression': yearProgression,
      'category_performance': categoryPerformance,
      'type_distribution': typeDistribution,
      'seasonality': seasonality,
      'monthly_history': monthlyHistory,
      'interest_evolution': interestEvolution,
    };
  } else {
    final yInt = int.tryParse(year);
    final yearGoals = allGoals.where((g) => g.year == yInt).toList();

    final totalGoals = yearGoals.length;
    final completedGoals = yearGoals
        .where((g) => g.status == 'completed')
        .length;
    final successRate = totalGoals > 0
        ? (completedGoals / totalGoals * 100).round()
        : 0;

    final categoryStats = <String, Map<String, int>>{};
    for (final g in yearGoals) {
      final cat = g.category;
      if (cat != null) {
        categoryStats.putIfAbsent(cat, () => {'total': 0, 'completed': 0});
        categoryStats[cat]!['total'] = categoryStats[cat]!['total']! + 1;
        if (g.status == 'completed') {
          categoryStats[cat]!['completed'] =
              categoryStats[cat]!['completed']! + 1;
        }
      }
    }

    String? bestCategory;
    int bestCategoryRate = -1;
    int maxCatTotal = -1;
    for (final e in categoryStats.entries) {
      final t = e.value['total']!;
      final c = e.value['completed']!;
      final r = t > 0 ? (c / t * 100).round() : 0;
      if (r > bestCategoryRate || (r == bestCategoryRate && t > maxCatTotal)) {
        bestCategoryRate = r;
        bestCategory = e.key;
        maxCatTotal = t;
      }
    }

    final monthStats = <int, Map<String, int>>{};
    for (final g in yearGoals) {
      if (g.month != null) {
        monthStats.putIfAbsent(
          g.month!,
          () => {'total': 0, 'completed': 0, 'active': 0, 'failed': 0},
        );
        monthStats[g.month!]!['total'] = monthStats[g.month!]!['total']! + 1;
        if (g.status == 'completed') {
          monthStats[g.month!]!['completed'] =
              monthStats[g.month!]!['completed']! + 1;
        }
        if (g.status == 'active') {
          monthStats[g.month!]!['active'] =
              monthStats[g.month!]!['active']! + 1;
        }
        if (g.status == 'failed') {
          monthStats[g.month!]!['failed'] =
              monthStats[g.month!]!['failed']! + 1;
        }
      }
    }

    int? bestMonth;
    int bestMonthRate = -1;
    int maxMonthTotal = -1;
    for (final e in monthStats.entries) {
      final t = e.value['total']!;
      final c = e.value['completed']!;
      final r = t > 0 ? (c / t * 100).round() : 0;
      if (r > bestMonthRate || (r == bestMonthRate && t > maxMonthTotal)) {
        bestMonthRate = r;
        bestMonth = e.key;
        maxMonthTotal = t;
      }
    }

    final typeStats = <String, Map<String, int>>{};
    for (final g in yearGoals) {
      typeStats.putIfAbsent(g.type, () => {'total': 0, 'completed': 0});
      typeStats[g.type]!['total'] = typeStats[g.type]!['total']! + 1;
      if (g.status == 'completed') {
        typeStats[g.type]!['completed'] = typeStats[g.type]!['completed']! + 1;
      }
    }

    String? bestType;
    int bestTypeRate = -1;
    int maxTypeTotal = -1;
    for (final e in typeStats.entries) {
      final t = e.value['total']!;
      final c = e.value['completed']!;
      final r = t > 0 ? (c / t * 100).round() : 0;
      if (r > bestTypeRate || (r == bestTypeRate && t > maxTypeTotal)) {
        bestTypeRate = r;
        bestType = e.key;
        maxTypeTotal = t;
      }
    }

    final quarterlyStats = <int, Map<String, int>>{};
    for (final g in yearGoals) {
      if (g.quarter != null) {
        quarterlyStats.putIfAbsent(
          g.quarter!,
          () => {'total': 0, 'completed': 0, 'active': 0, 'failed': 0},
        );
        quarterlyStats[g.quarter!]!['total'] =
            quarterlyStats[g.quarter!]!['total']! + 1;
        if (g.status == 'completed') {
          quarterlyStats[g.quarter!]!['completed'] =
              quarterlyStats[g.quarter!]!['completed']! + 1;
        }
        if (g.status == 'active') {
          quarterlyStats[g.quarter!]!['active'] =
              quarterlyStats[g.quarter!]!['active']! + 1;
        }
        if (g.status == 'failed') {
          quarterlyStats[g.quarter!]!['failed'] =
              quarterlyStats[g.quarter!]!['failed']! + 1;
        }
      }
    }
    final quarterlyActivity =
        quarterlyStats.entries
            .map(
              (e) => {
                'quarter': e.key,
                'total': e.value['total'],
                'completed': e.value['completed'],
                'active': e.value['active'],
                'failed': e.value['failed'],
              },
            )
            .toList()
          ..sort(
            (a, b) => (a['quarter'] as int).compareTo(b['quarter'] as int),
          );

    final monthlyComposed = <Map<String, dynamic>>[];
    final cumulativeMonthly = <Map<String, dynamic>>[];
    int cumTotal = 0;
    int cumCompleted = 0;
    for (int m = 1; m <= 12; m++) {
      final s =
          monthStats[m] ??
          {'total': 0, 'completed': 0, 'active': 0, 'failed': 0};
      monthlyComposed.add({
        'month': m,
        'total': s['total'],
        'completed': s['completed'],
        'active': s['active'],
        'failed': s['failed'],
      });
      cumTotal += s['total']!;
      cumCompleted += s['completed']!;
      cumulativeMonthly.add({
        'month': m,
        'total': cumTotal,
        'completed': cumCompleted,
      });
    }

    final categoryRates = categoryStats.entries.map((e) {
      final t = e.value['total']!;
      final c = e.value['completed']!;
      return {'category': e.key, 'rate': t > 0 ? (c / t * 100).round() : 0};
    }).toList();

    final categoryDistribution = categoryStats.entries
        .map((e) => {'category': e.key, 'count': e.value['total']})
        .toList();

    return {
      'total_goals': totalGoals,
      'completed_goals': completedGoals,
      'success_rate': successRate,
      'best_category': bestCategory,
      'best_category_rate': bestCategoryRate,
      'best_month': bestMonth,
      'best_month_rate': bestMonthRate,
      'best_type': bestType,
      'best_type_rate': bestTypeRate,
      'cumulative_monthly': cumulativeMonthly,
      'category_rates': categoryRates,
      'quarterly_activity': quarterlyActivity,
      'monthly_composed': monthlyComposed,
      'category_distribution': categoryDistribution,
    };
  }
}
