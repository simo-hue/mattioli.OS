import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final globalCriticalDayRpcProvider = FutureProvider<String?>((ref) async {
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
      return _listRpc(
        ref,
        'get_global_trend',
        extraParams: {'p_timeframe': timeframe},
      );
    });

final criticalHabitsRpcProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) {
  return _listRpc(ref, 'get_critical_habits');
});

final bestHabitsRpcProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, timeframe) {
      return _listRpc(
        ref,
        'get_best_habits',
        extraParams: {'p_timeframe': timeframe},
      );
    });

final habitPerformanceRpcProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, goalId) {
      return _listRpc(
        ref,
        'get_habit_performance_by_day',
        extraParams: {'p_goal_id': goalId},
      );
    });

final habitAlertsRpcProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, goalId) async {
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
