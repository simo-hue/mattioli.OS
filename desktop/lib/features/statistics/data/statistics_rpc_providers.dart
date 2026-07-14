import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/statistics/data/analytics_extra.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Each provider is mode-aware: in Private mode it computes locally from the
// encrypted DB via the ported analytics engine (no Supabase call); otherwise it
// calls the cloud RPC. The private branch returns BEFORE reading any Supabase
// provider, preserving the "no Supabase in Private mode" boundary.

final globalCriticalDayRpcProvider = FutureProvider<String?>((ref) async {
  if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
    final data = await ref.watch(privateAnalyticsDataProvider.future);
    return computeGlobalCriticalDay(data.allLogs);
  }
  final context = _RpcContext.read(ref);
  if (context == null) return null;
  try {
    return await context.client.rpc(
          'get_global_critical_day',
          params: {'p_user_id': context.userId},
        )
        as String?;
  } catch (error, stack) {
    AppLogger.error('Unable to load global critical day RPC', error, stack);
    return null;
  }
});

final globalTrendRpcProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      timeframe,
    ) async {
      if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
        final data = await ref.watch(privateAnalyticsDataProvider.future);
        return computeGlobalTrend(
          goals: data.goals,
          logs: data.logsByDate,
          timeframe: timeframe,
          today: DateTime.now(),
        );
      }
      return _listRpc(
        ref,
        'get_global_trend',
        extraParams: {'p_timeframe': timeframe},
      );
    });

final criticalHabitsRpcProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
    final data = await ref.watch(privateAnalyticsDataProvider.future);
    return computeCriticalHabits(
      goals: data.goals,
      logsByGoal: data.logsByGoal,
      today: DateTime.now(),
    );
  }
  return _listRpc(ref, 'get_critical_habits');
});

final bestHabitsRpcProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      timeframe,
    ) async {
      if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
        final data = await ref.watch(privateAnalyticsDataProvider.future);
        return computeBestHabits(
          goals: data.goals,
          logsByGoal: data.logsByGoal,
          timeframe: canonicalBestHabitsTimeframe(timeframe),
          today: DateTime.now(),
        );
      }
      return _listRpc(
        ref,
        'get_best_habits',
        extraParams: {'p_timeframe': timeframe},
      );
    });

final habitPerformanceRpcProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      goalId,
    ) async {
      if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
        final data = await ref.watch(privateAnalyticsDataProvider.future);
        return computePerformanceByDay(data.logsByGoal[goalId] ?? const []);
      }
      return _listRpc(
        ref,
        'get_habit_performance_by_day',
        extraParams: {'p_goal_id': goalId},
      );
    });

final habitAlertsRpcProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, goalId) async {
      if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
        final data = await ref.watch(privateAnalyticsDataProvider.future);
        return computeHabitAlerts(data.logsByGoal[goalId] ?? const []);
      }
      final response = await _listRpc(
        ref,
        'get_habit_alerts',
        extraParams: {'p_goal_id': goalId},
      );
      return response.firstOrNull ?? {};
    });

final habitYearlyGridRpcProvider = FutureProvider.family<List<int>, String>((
  ref,
  goalId,
) async {
  if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
    final data = await ref.watch(privateAnalyticsDataProvider.future);
    return computeYearlyGrid(
      data.logsByGoal[goalId] ?? const [],
      DateTime.now(),
    );
  }
  final response = await _listRpc(
    ref,
    'get_habit_yearly_grid',
    extraParams: {'p_goal_id': goalId},
  );
  return response
      .map((row) => (row['status_code'] as num?)?.toInt() ?? 0)
      .toList();
});

final habitCorrelationsRpcProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      goalId,
    ) async {
      if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
        final data = await ref.watch(privateAnalyticsDataProvider.future);
        return computeHabitCorrelations(goalId, data.logsByDate);
      }
      return _listRpc(
        ref,
        'get_habit_correlations',
        extraParams: {'p_target_goal_id': goalId},
      );
    });

final allHabitCorrelationsRpcProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
        final data = await ref.watch(privateAnalyticsDataProvider.future);
        return computeAllHabitCorrelations(
          data.goals.map((g) => g.id).toList(),
          data.logsByDate,
        );
      }
      return _listRpc(ref, 'get_all_habit_correlations');
    });

/// The `habit_stats` view, one row per goal. Private mode computes each row
/// locally via [computeHabitStatsRow]; cloud reads the view directly (mirrors
/// mobile's `habitStatsProvider`).
final habitStatsRpcProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
    final data = await ref.watch(privateAnalyticsDataProvider.future);
    final today = DateTime.now();
    return [
      for (final g in data.goals)
        computeHabitStatsRow(
          goalId: g.id,
          userId: '',
          title: data.titles[g.id],
          startDate: data.startDates[g.id] ?? g.startDate,
          logs: data.logsByGoal[g.id] ?? const [],
          today: today,
        ),
    ];
  }
  final context = _RpcContext.read(ref);
  if (context == null) return [];
  try {
    final response = await context.client
        .from('habit_stats')
        .select('*')
        .eq('user_id', context.userId);
    return List<Map<String, dynamic>>.from(response as List);
  } catch (error, stack) {
    AppLogger.error('Unable to load habit_stats', error, stack);
    return [];
  }
});

/// `get_habit_analytics`: {goal_id: {worst_dow, avg_recovery_days}} for every
/// goal. Private mode runs [computeAnalyticsRow] per goal; cloud calls the RPC
/// and re-keys by goal_id (mirrors mobile's `habitAnalyticsProvider`).
final habitAnalyticsRpcProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
      if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
        final data = await ref.watch(privateAnalyticsDataProvider.future);
        return {
          for (final g in data.goals)
            g.id: computeAnalyticsRow(
              goalId: g.id,
              logs: data.logsByGoal[g.id] ?? const [],
            ),
        };
      }
      final context = _RpcContext.read(ref);
      if (context == null) return {};
      try {
        final response = await context.client.rpc(
          'get_habit_analytics',
          params: {'p_user_id': context.userId},
        );
        if (response is! List) return {};
        final result = <String, Map<String, dynamic>>{};
        for (final row in response) {
          final map = Map<String, dynamic>.from(row as Map);
          result[map['goal_id'] as String] = map;
        }
        return result;
      } catch (error, stack) {
        AppLogger.error('Unable to load get_habit_analytics RPC', error, stack);
        return {};
      }
    });

/// Per-habit mood/energy correlations. Mirrors mobile's `moodCorrelationProvider`
/// which is a PURE client-side computation (no cloud RPC exists): both modes run
/// [computeMoodCorrelations]. Private mode reads moods from the encrypted DB via
/// [privateAnalyticsDataProvider]; cloud mode reads them from the dashboard
/// snapshot (populated from `daily_moods`).
final moodCorrelationsRpcProvider = FutureProvider<List<MoodCorrelation>>((
  ref,
) async {
  if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
    final data = await ref.watch(privateAnalyticsDataProvider.future);
    return computeMoodCorrelations(
      moodsByDate: data.moodsByDate,
      logsByDate: data.logsByDate,
    );
  }
  final snapshot = ref.watch(dashboardControllerProvider);
  final moodsByDate = <String, MoodEntry>{
    for (final entry in snapshot.moods.entries)
      entry.key: MoodEntry(
        moodScore: entry.value.mood ?? 0,
        energyScore: entry.value.energy ?? 0,
      ),
  };
  return computeMoodCorrelations(
    moodsByDate: moodsByDate,
    logsByDate: snapshot.habitLogs,
  );
});

final macroGoalsStatsRpcProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, year) async {
      if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
        final goals = ref.watch(dashboardControllerProvider).goals;
        final stats = goals
            .map(
              (g) => MacroGoalStat(
                status: g.state.name,
                type: g.type.name,
                year: g.year,
                month: g.month,
                quarter: g.quarter,
                categoryId: g.categoryId,
                categoryKey: g.category.isEmpty ? null : g.category,
              ),
            )
            .toList();
        return computeMacroGoalsStats(stats, year);
      }
      final context = _RpcContext.read(ref);
      if (context == null) return {};
      try {
        final response = await context.client.rpc(
          'get_macro_goals_stats',
          params: {'p_user_id': context.userId, 'p_year': year},
        );
        return response is Map
            ? Map<String, dynamic>.from(response)
            : <String, dynamic>{};
      } catch (error, stack) {
        AppLogger.error(
          'Unable to load macro goal statistics RPC',
          error,
          stack,
        );
        return {};
      }
    });

Future<List<Map<String, dynamic>>> _listRpc(
  Ref ref,
  String name, {
  Map<String, dynamic> extraParams = const {},
}) async {
  final context = _RpcContext.read(ref);
  if (context == null) return [];
  try {
    final response = await context.client.rpc(
      name,
      params: {'p_user_id': context.userId, ...extraParams},
    );
    if (response is! List) return [];
    return response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  } catch (error, stack) {
    AppLogger.error('Unable to load $name RPC', error, stack);
    return [];
  }
}

class _RpcContext {
  const _RpcContext({required this.client, required this.userId});

  final SupabaseClient client;
  final String userId;

  static _RpcContext? read(Ref ref) {
    final client = ref.watch(supabaseClientProvider);
    final userId = ref.watch(
      desktopAuthControllerProvider.select((state) => state.user?.id),
    );
    if (client == null || userId == null) return null;
    return _RpcContext(client: client, userId: userId);
  }
}

// ─── Net-new desktop statistics (analytics_extra) ────────────────────────────
//
// These have no cloud RPC (mobile doesn't compute them either). Both modes feed
// the pure engine in analytics_extra.dart the SAME normalised inputs via
// [unifiedAnalyticsDataProvider]: Private reads the encrypted DB
// ([privateAnalyticsDataProvider]); Cloud reconstructs them from the dashboard
// snapshot, whose habitLogs already carry the full history.

/// Rebuilds the analytics inputs from a cloud [DashboardSnapshot]. The signed
/// per-log streak is unavailable here (defaults to 0), which the extra stats do
/// not use; anything streak-accurate goes through [habitStatsRpcProvider].
PrivateAnalyticsData buildAnalyticsDataFromSnapshot(
  DashboardSnapshot snapshot,
) {
  final allLogs = <HabitLogEntry>[];
  final logsByGoal = <String, List<HabitLogEntry>>{};
  final logsByDate = <String, Map<String, String>>{};
  snapshot.habitLogs.forEach((dk, habits) {
    // Skip empty per-date maps: the optimistic dashboard state can retain a
    // `dateKey -> {}` entry after the last habit on a day is cleared, which the
    // SQLite-backed private path never has. Keeping them would inflate
    // activeDays and add spurious zero-completion days to keystone/perfect-days.
    if (habits.isEmpty) return;
    final date = DateTime.tryParse(dk);
    if (date == null) return;
    logsByDate[dk] = Map<String, String>.from(habits);
    habits.forEach((goalId, status) {
      final entry = HabitLogEntry(goalId: goalId, date: date, status: status);
      allLogs.add(entry);
      logsByGoal.putIfAbsent(goalId, () => []).add(entry);
    });
  });

  final goals = <GoalInput>[];
  final startDates = <String, DateTime>{};
  final titles = <String, String?>{};
  for (final h in snapshot.habits) {
    final start = h.startDate ?? DateTime.now();
    goals.add(
      GoalInput(
        id: h.id,
        startDate: start,
        endDate: h.endDate,
        frequencyDays: h.frequencyDays,
      ),
    );
    startDates[h.id] = start;
    titles[h.id] = h.title;
  }

  final moodsByDate = <String, MoodEntry>{};
  snapshot.moods.forEach((dk, checkIn) {
    moodsByDate[dk] = MoodEntry(
      moodScore: checkIn.mood ?? 0,
      energyScore: checkIn.energy ?? 0,
    );
  });

  return PrivateAnalyticsData(
    allLogs: allLogs,
    logsByGoal: logsByGoal,
    logsByDate: logsByDate,
    goals: goals,
    startDates: startDates,
    titles: titles,
    moodsByDate: moodsByDate,
  );
}

/// The shared analytics inputs for every net-new stat, mode-aware in one place.
final unifiedAnalyticsDataProvider = FutureProvider<PrivateAnalyticsData>((
  ref,
) async {
  if (ref.watch(activeDesktopDataModeProvider).isPrivate) {
    return ref.watch(privateAnalyticsDataProvider.future);
  }
  final snapshot = ref.watch(dashboardControllerProvider);
  return buildAnalyticsDataFromSnapshot(snapshot);
});

final lifetimeSummaryProvider = FutureProvider<LifetimeSummary>((ref) async {
  final data = await ref.watch(unifiedAnalyticsDataProvider.future);
  return computeLifetimeSummary(
    allLogs: data.allLogs,
    goals: data.goals,
    logsByDate: data.logsByDate,
    today: DateTime.now(),
  );
});

final keystoneHabitProvider = FutureProvider<KeystoneInsight?>((ref) async {
  final data = await ref.watch(unifiedAnalyticsDataProvider.future);
  return computeKeystoneHabit(goals: data.goals, logsByDate: data.logsByDate);
});

final bounceBackProvider = FutureProvider<BounceBackStats>((ref) async {
  final data = await ref.watch(unifiedAnalyticsDataProvider.future);
  return computeBounceBackRate(logsByGoal: data.logsByGoal);
});

final weekdayWeekendProvider = FutureProvider<WeekdaySplit>((ref) async {
  final data = await ref.watch(unifiedAnalyticsDataProvider.future);
  return computeWeekdayWeekendSplit(data.allLogs);
});

final globalWeekdayPerformanceProvider = FutureProvider<List<WeekdayPerf>>((
  ref,
) async {
  final data = await ref.watch(unifiedAnalyticsDataProvider.future);
  return computeGlobalWeekdayPerformance(data.allLogs);
});

final seasonalityProvider = FutureProvider<List<MonthPerf>>((ref) async {
  final data = await ref.watch(unifiedAnalyticsDataProvider.future);
  return computeSeasonality(data.allLogs);
});

final consistencyScoresProvider = FutureProvider<List<ConsistencyScore>>((
  ref,
) async {
  final data = await ref.watch(unifiedAnalyticsDataProvider.future);
  return computeConsistencyScores(data.logsByGoal);
});

final dangerZoneProvider = FutureProvider<DangerZone?>((ref) async {
  final data = await ref.watch(unifiedAnalyticsDataProvider.future);
  return computeDangerZone(data.logsByGoal);
});

final momentumProvider = FutureProvider<MomentumScore>((ref) async {
  final data = await ref.watch(unifiedAnalyticsDataProvider.future);
  // Current streak comes from the REACTIVE dashboard snapshot (updates
  // immediately on a habit toggle in both modes), not from habitStatsRpcProvider
  // — whose cloud branch reads the habit_stats view once and caches it for the
  // session, which would leave streakHealth frozen while rate7 moves. Best
  // streak (slow-moving, only grows) is still sourced from habit_stats.
  final snapshot = ref.watch(dashboardControllerProvider);
  final stats = await ref.watch(habitStatsRpcProvider.future);
  final bestById = {
    for (final r in stats)
      (r['goal_id'] as String? ?? ''): (r['best_streak'] as num?)?.toInt() ?? 0,
  };
  final streaks = [
    for (final h in snapshot.habits)
      (
        current: h.streak,
        best: bestById[h.id] ?? (h.streak > 0 ? h.streak : 0),
      ),
  ];
  final today = DateTime.now();
  return computeMomentumScore(
    rate7: _windowCompletionRate(data, today, 0, 6),
    ratePrev7: _windowCompletionRate(data, today, 7, 13),
    streaks: streaks,
  );
});

/// Completion fraction (0–1) over an inclusive [startAgo]…[endAgo] window of
/// days-ago from [today], counting scheduled non-skipped habit-days. Returns 0
/// when nothing was scheduled in the window.
double _windowCompletionRate(
  PrivateAnalyticsData data,
  DateTime today,
  int startAgo,
  int endAgo,
) {
  final t = DateTime(today.year, today.month, today.day);
  var done = 0;
  var active = 0;
  for (var ago = startAgo; ago <= endAgo; ago++) {
    final date = t.subtract(Duration(days: ago));
    final dayLogs = data.logsByDate[dateKey(date)] ?? const <String, String>{};
    for (final g in data.goals) {
      if (!isGoalActiveOn(g, date)) continue;
      final status = dayLogs[g.id];
      if (status == 'skipped') continue;
      active++;
      if (status == 'done') done++;
    }
  }
  return active > 0 ? done / active : 0.0;
}

// ─── Per-habit analytics bundle ──────────────────────────────────────────────
//
// One family provider (keyed by habitId) computes every enriched per-habit stat
// in a single pass from the shared [unifiedAnalyticsDataProvider] (Private/Cloud
// aware) plus this habit's [habitStatsRpcProvider] row. The per-habit tab
// widgets watch this and read the fields they need.

class HabitAnalyticsBundle {
  final GapStats gap;
  final Adherence adherence;
  final List<StreakRun> streakHistory;
  final NextDayMood nextDayMood;
  final HabitMilestones milestones;

  /// Bounce-back for this habit only ([BounceBackStats.globalRate] == its rate).
  final BounceBackStats bounceBack;
  final ConsistencyScore? consistency;
  final List<MonthPerf> seasonality;
  final WeekdaySplit weekdayWeekend;
  final MomentumScore momentum;
  final DangerZone? dangerDay;

  /// This habit's completion-rate percentile among all habits (null if <2).
  final int? percentileRank;
  final int currentStreak;
  final int bestStreak;
  final double rate;

  const HabitAnalyticsBundle({
    required this.gap,
    required this.adherence,
    required this.streakHistory,
    required this.nextDayMood,
    required this.milestones,
    required this.bounceBack,
    required this.consistency,
    required this.seasonality,
    required this.weekdayWeekend,
    required this.momentum,
    required this.dangerDay,
    required this.percentileRank,
    required this.currentStreak,
    required this.bestStreak,
    required this.rate,
  });

  static final empty = HabitAnalyticsBundle(
    gap: GapStats.empty,
    adherence: Adherence.empty,
    streakHistory: const [],
    nextDayMood: NextDayMood.empty,
    milestones: const HabitMilestones(
      firstLogDate: null,
      totalCompletions: 0,
      daysSinceStart: 0,
      currentStreak: 0,
      nextStreakMilestone: null,
    ),
    bounceBack: BounceBackStats.empty,
    consistency: null,
    seasonality: const [],
    weekdayWeekend: const WeekdaySplit(
      weekdayRate: 0,
      weekendRate: 0,
      weekdayDone: 0,
      weekdayTotal: 0,
      weekendDone: 0,
      weekendTotal: 0,
    ),
    momentum: MomentumScore.empty,
    dangerDay: null,
    percentileRank: null,
    currentStreak: 0,
    bestStreak: 0,
    rate: 0,
  );
}

final habitAnalyticsBundleProvider =
    FutureProvider.family<HabitAnalyticsBundle, String>((ref, habitId) async {
      final data = await ref.watch(unifiedAnalyticsDataProvider.future);
      final stats = await ref.watch(habitStatsRpcProvider.future);
      final today = DateTime.now();

      final logs = data.logsByGoal[habitId] ?? const <HabitLogEntry>[];
      GoalInput? found;
      for (final g in data.goals) {
        if (g.id == habitId) {
          found = g;
          break;
        }
      }
      final goal = found ?? GoalInput(id: habitId, startDate: today);

      Map<String, dynamic>? row;
      for (final r in stats) {
        if (r['goal_id'] == habitId) {
          row = r;
          break;
        }
      }
      final best = (row?['best_streak'] as num?)?.toInt() ?? 0;
      final rate = (row?['rate'] as num?)?.toDouble() ?? 0;

      // Current streak from the REACTIVE dashboard snapshot (updates on a toggle
      // in both modes); the habit_stats view is session-cached in Cloud mode and
      // would leave the momentum gauge's streak term stale while rate7 moves.
      final snapshot = ref.watch(dashboardControllerProvider);
      var current = (row?['current_streak'] as num?)?.toInt() ?? 0;
      for (final h in snapshot.habits) {
        if (h.id == habitId) {
          current = h.streak;
          break;
        }
      }

      // Percentile "ahead of X% of your OTHER habits": exclude self, strict <.
      int? percentile;
      if (stats.length >= 2) {
        var below = 0;
        for (final r in stats) {
          if (identical(r, row)) continue;
          if (((r['rate'] as num?)?.toDouble() ?? 0) < rate) below++;
        }
        percentile = (below * 100 / (stats.length - 1)).round();
      }

      // Per-habit momentum: completion of THIS habit over its scheduled days.
      final byDate = <String, String>{
        for (final l in logs) dateKey(l.date): l.status,
      };
      double windowRate(int startAgo, int endAgo) {
        final t = DateTime(today.year, today.month, today.day);
        var done = 0;
        var active = 0;
        for (var ago = startAgo; ago <= endAgo; ago++) {
          final date = DateTime(t.year, t.month, t.day - ago);
          if (!isGoalActiveOn(goal, date)) continue;
          final st = byDate[dateKey(date)];
          if (st == 'skipped') continue;
          active++;
          if (st == 'done') done++;
        }
        return active > 0 ? done / active : 0.0;
      }

      final oneGoal = {habitId: logs};
      final consistencyList = computeConsistencyScores(oneGoal);

      return HabitAnalyticsBundle(
        gap: computeGapStats(logs, today),
        adherence: computeAdherence(logs: logs, goal: goal, today: today),
        streakHistory: computeStreakHistory(logs),
        nextDayMood: computeNextDayMoodImpact(
          logs: logs,
          moodsByDate: data.moodsByDate,
        ),
        milestones: computeHabitMilestones(
          logs: logs,
          today: today,
          currentStreak: current,
        ),
        bounceBack: computeBounceBackRate(logsByGoal: oneGoal),
        consistency: consistencyList.isEmpty ? null : consistencyList.first,
        seasonality: computeSeasonality(logs),
        weekdayWeekend: computeWeekdayWeekendSplit(logs),
        momentum: computeMomentumScore(
          rate7: windowRate(0, 6),
          ratePrev7: windowRate(7, 13),
          streaks: [(current: current, best: best)],
        ),
        dangerDay: computeDangerZone(oneGoal),
        percentileRank: percentile,
        currentStreak: current,
        bestStreak: best,
        rate: rate,
      );
    });
