import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import 'macro_goals_provider.dart';

/// Provider for macro goals statistics.
/// Uses ref.keepAlive() to cache results and avoid continuous calls.
final macroGoalsStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, year) async {
  final authState = ref.watch(authProvider);
  
  // Watch macro goals to invalidate cache when data changes
  ref.watch(macroGoalsProvider);
  if (!authState.isLoggedIn || authState.user == null) {
    throw Exception('User not logged in');
  }

  final supabase = Supabase.instance.client;
  
  // Keep state alive to avoid continuous calls as requested
  ref.keepAlive();

  try {
    final response = await supabase.rpc(
      'get_macro_goals_stats',
      params: {
        'p_user_id': authState.user!.id,
        'p_year': year,
      },
    );

    if (response is Map<String, dynamic>) {
      return response;
    } else {
      throw Exception('Invalid response format');
    }
  } catch (e) {
    throw Exception('Failed to fetch stats: $e');
  }
});
