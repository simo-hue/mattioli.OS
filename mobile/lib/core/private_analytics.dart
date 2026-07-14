import 'dart:math' as math;

/// Pure, backend-free reimplementations of the cloud analytics RPCs/view, so
/// Private Mode produces output identical in shape and semantics to Supabase.
/// Each function mirrors a specific definition captured in `../migrations/`:
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
int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

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
      worstMissed = worstMissed == null ? l.streak : math.min(worstMissed, l.streak);
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
  final byDate = <String, String>{for (final l in logs) dateKey(l.date): l.status};
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
    'worst_negative_start': worstNegStart == null ? null : dateKey(worstNegStart),
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

  final doneDates = logs
      .where((l) => l.status == 'done')
      .map((l) => l.date)
      .toList()
    ..sort();
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

  final ranked = total.keys.map((dow) {
    return (token: kIsoDowTokens[dow - 1], rate: (done[dow] ?? 0) / total[dow]!);
  }).toList()
    ..sort((a, b) {
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
      if (l.status == 'done' && (lastDone == null || l.date.isAfter(lastDone))) {
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
/// token; `bestHabitsProvider` canonicalises the UI's 'timeframe_*' vocabulary
/// via `canonicalBestHabitsTimeframe` before this runs. The `_ => -1` branch
/// below is therefore defensive only: an unrecognised token yields an empty
/// window (rate 0) instead of throwing.
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
        .where((l) =>
            l.status == 'done' &&
            (lastNonDone == null || l.date.isAfter(lastNonDone)))
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
        for (var d = startI;
            !d.isAfter(last);
            d = d.add(const Duration(days: 1))) {
          rates.add(rateForDay(d));
        }
        out.add({'point_index': i, 'date': dateKey(startI), 'rate': avg(rates)});
      }
      return out;
  }
}
