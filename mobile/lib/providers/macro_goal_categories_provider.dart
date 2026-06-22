import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/macro_goal.dart';
import 'auth_provider.dart';
import '../core/data_mode.dart';
import '../core/private_local_database.dart';
import '../core/navigator_key.dart';
import '../core/app_logger.dart';
import '../ui/widgets/error_modal.dart';
import '../i18n/translations.g.dart';

class MacroGoalCategoriesNotifier extends AsyncNotifier<List<GoalCategory>> {
  @override
  Future<List<GoalCategory>> build() async {
    if (ref.watch(activeDataModeProvider) == AppDataMode.private) {
      return ref.read(privateLocalDatabaseProvider).loadMacroGoalCategories();
    }

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
    } catch (e, stack) {
      AppLogger.error('[Categories] Fetch error', e, stack);
      return [];
    }
  }

  Future<String?> addCategory(String name, String colorHex) async {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        final id = await ref
            .read(privateLocalDatabaseProvider)
            .addMacroGoalCategory(name, colorHex);
        ref.invalidateSelf();
        return id;
      } catch (e, stack) {
        AppLogger.error('[Categories] Private add error', e, stack);
        return null;
      }
    }

    final authState = ref.read(authProvider);
    if (!authState.isLoggedIn || authState.user == null) return null;

    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('macro_goal_categories')
          .insert({
            'user_id': authState.user!.id,
            'name': name,
            'color': colorHex,
          })
          .select('id')
          .single();

      // Invalidate to refetch
      ref.invalidateSelf();

      return response['id'] as String;
    } catch (e, stack) {
      AppLogger.error('[Categories] Add error', e, stack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: context.t.common.errorCreatingCategory,
          message: context.t.common.categoryCreateFailed,
          details: e.toString(),
        );
      }
      return null;
    }
  }

  Future<bool> updateCategory(String id, String name, String colorHex) async {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        await ref
            .read(privateLocalDatabaseProvider)
            .updateMacroGoalCategory(id, name, colorHex);
        ref.invalidateSelf();
        return true;
      } catch (e, stack) {
        AppLogger.error('[Categories] Private update error', e, stack);
        return false;
      }
    }

    final authState = ref.read(authProvider);
    if (!authState.isLoggedIn || authState.user == null) return false;

    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('macro_goal_categories')
          .update({'name': name, 'color': colorHex})
          .eq('id', id)
          .eq('user_id', authState.user!.id);

      ref.invalidateSelf();
      return true;
    } catch (e, stack) {
      AppLogger.error('[Categories] Update error', e, stack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: context.t.common.errorEditingCategory,
          message: context.t.common.categoryUpdateFailed,
          details: e.toString(),
        );
      }
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        await ref
            .read(privateLocalDatabaseProvider)
            .archiveMacroGoalCategory(id);
        ref.invalidateSelf();
        return true;
      } catch (e, stack) {
        AppLogger.error('[Categories] Private archive error', e, stack);
        return false;
      }
    }

    final authState = ref.read(authProvider);
    if (!authState.isLoggedIn || authState.user == null) return false;

    final supabase = Supabase.instance.client;

    try {
      await supabase
          .from('macro_goal_categories')
          .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .eq('user_id', authState.user!.id);

      // Invalidate to refetch
      ref.invalidateSelf();
      return true;
    } catch (e, stack) {
      AppLogger.error('[Categories] Delete error', e, stack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: context.t.common.categoryArchiveErrorTitle,
          message: context.t.common.categoryArchiveFailed,
          details: e.toString(),
        );
      }
      return false;
    }
  }
}

final macroGoalCategoriesProvider =
    AsyncNotifierProvider<MacroGoalCategoriesNotifier, List<GoalCategory>>(
      MacroGoalCategoriesNotifier.new,
    );
