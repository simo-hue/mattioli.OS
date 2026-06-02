import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopGoalCategory {
  const DesktopGoalCategory({
    required this.id,
    required this.label,
    required this.color,
    this.archivedAt,
  });

  final String id;
  final String label;
  final Color color;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  factory DesktopGoalCategory.fromRemoteJson(Map<String, dynamic> json) {
    return DesktopGoalCategory(
      id: json['id'] as String,
      label: json['name'] as String,
      color: dashboardColorFromHex(json['color'] as String?),
      archivedAt: DateTime.tryParse(json['archived_at'] as String? ?? ''),
    );
  }
}

final desktopGoalCategoriesControllerProvider =
    AsyncNotifierProvider<
      DesktopGoalCategoriesController,
      List<DesktopGoalCategory>
    >(DesktopGoalCategoriesController.new);

class DesktopGoalCategoriesController
    extends AsyncNotifier<List<DesktopGoalCategory>> {
  @override
  Future<List<DesktopGoalCategory>> build() async {
    final client = ref.watch(supabaseClientProvider);
    final userId = ref.watch(
      desktopAuthControllerProvider.select((state) => state.user?.id),
    );
    if (client == null || userId == null) return [];

    try {
      final response = await client
          .from('macro_goal_categories')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      return (response as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(DesktopGoalCategory.fromRemoteJson)
          .toList();
    } catch (error, stack) {
      AppLogger.error('Unable to load macro goal categories', error, stack);
      return [];
    }
  }

  Future<DesktopGoalCategory?> addCategory(String label, Color color) async {
    final client = ref.read(supabaseClientProvider);
    final userId = ref.read(desktopAuthControllerProvider).user?.id;
    if (client == null || userId == null) return null;

    try {
      final response = await client
          .from('macro_goal_categories')
          .insert({
            'user_id': userId,
            'name': label,
            'color': dashboardColorToHex(color),
          })
          .select()
          .single();
      final category = DesktopGoalCategory.fromRemoteJson(
        Map<String, dynamic>.from(response),
      );
      ref.invalidateSelf();
      return category;
    } catch (error, stack) {
      AppLogger.error('Unable to create macro goal category', error, stack);
      rethrow;
    }
  }

  Future<void> archiveCategory(String id) async {
    final client = ref.read(supabaseClientProvider);
    final userId = ref.read(desktopAuthControllerProvider).user?.id;
    if (client == null || userId == null) return;

    try {
      await client
          .from('macro_goal_categories')
          .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .eq('user_id', userId);
      ref.invalidateSelf();
    } catch (error, stack) {
      AppLogger.error('Unable to archive macro goal category', error, stack);
      rethrow;
    }
  }

  Future<DesktopGoalCategory?> updateCategory(
    String id,
    String label,
    Color color,
  ) async {
    final client = ref.read(supabaseClientProvider);
    final userId = ref.read(desktopAuthControllerProvider).user?.id;
    if (client == null || userId == null) return null;

    try {
      final response = await client
          .from('macro_goal_categories')
          .update({'name': label, 'color': dashboardColorToHex(color)})
          .eq('id', id)
          .eq('user_id', userId)
          .select()
          .single();
      final category = DesktopGoalCategory.fromRemoteJson(
        Map<String, dynamic>.from(response),
      );
      ref.invalidateSelf();
      return category;
    } catch (error, stack) {
      AppLogger.error('Unable to update macro goal category', error, stack);
      rethrow;
    }
  }
}
