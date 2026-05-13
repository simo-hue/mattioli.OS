import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/macro_goal.dart';
import 'auth_provider.dart';

class MacroGoalCategoriesNotifier extends AsyncNotifier<List<GoalCategory>> {
  @override
  Future<List<GoalCategory>> build() async {
    final authState = ref.watch(authProvider);
    if (!authState.isLoggedIn || authState.user == null) {
      return [];
    }

    final supabase = Supabase.instance.client;
    
    try {
      final response = await supabase
          .from('macro_goal_categories')
          .select()
          .eq('user_id', authState.user!.id)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => GoalCategory.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  Future<void> addCategory(String name, String colorHex) async {
    final authState = ref.read(authProvider);
    if (!authState.isLoggedIn || authState.user == null) return;

    final supabase = Supabase.instance.client;
    
    try {
      await supabase.from('macro_goal_categories').insert({
        'user_id': authState.user!.id,
        'name': name,
        'color': colorHex,
      });
      
      // Invalidate to refetch
      ref.invalidateSelf();
    } catch (e) {
      print('Error adding category: $e');
    }
  }

  Future<void> deleteCategory(String id) async {
    final supabase = Supabase.instance.client;
    
    try {
      await supabase.from('macro_goal_categories').delete().eq('id', id);
      
      // Invalidate to refetch
      ref.invalidateSelf();
    } catch (e) {
      print('Error deleting category: $e');
    }
  }
}

final macroGoalCategoriesProvider =
    AsyncNotifierProvider<MacroGoalCategoriesNotifier, List<GoalCategory>>(
  MacroGoalCategoriesNotifier.new,
);
