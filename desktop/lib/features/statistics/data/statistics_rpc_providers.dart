import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
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

// NOTE (WS4b): correlations + macro-goal stats are still RPC-only, so they
// return empty in Private mode until the inline correlation/macro-stats logic
// from mobile's private_local_database.dart is ported.
final habitCorrelationsRpcProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, goalId) {
      return _listRpc(
        ref,
        'get_habit_correlations',
        extraParams: {'p_target_goal_id': goalId},
      );
    });

final allHabitCorrelationsRpcProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
      return _listRpc(ref, 'get_all_habit_correlations');
    });

final macroGoalsStatsRpcProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, year) async {
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
