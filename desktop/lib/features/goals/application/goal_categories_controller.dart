import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

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
  static const _uuid = Uuid();

  @override
  Future<List<DesktopGoalCategory>> build() async {
    final dataMode = ref.watch(activeDesktopDataModeProvider);

    if (dataMode.isPrivate) {
      return _loadLocal();
    }

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
    final dataMode = ref.read(activeDesktopDataModeProvider);

    if (dataMode.isPrivate) {
      return _addLocal(label, color);
    }

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
    final dataMode = ref.read(activeDesktopDataModeProvider);

    if (dataMode.isPrivate) {
      return _archiveLocal(id);
    }

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
    final dataMode = ref.read(activeDesktopDataModeProvider);

    if (dataMode.isPrivate) {
      return _updateLocal(id, label, color);
    }

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

  // ---------------------------------------------------------------------------
  // Private mode — local encrypted DB
  // ---------------------------------------------------------------------------

  Future<List<DesktopGoalCategory>> _loadLocal() async {
    try {
      final db = await DesktopPrivateDb.instance.database;
      final ownerId = await DesktopPrivateDb.instance.ownerId;
      final rows = await db.query(
        'macro_goal_categories',
        where: 'user_id = ?',
        whereArgs: [ownerId],
        orderBy: 'created_at ASC',
      );
      return rows.map((row) {
        return DesktopGoalCategory(
          id: row['id'] as String,
          label: row['name'] as String,
          color: dashboardColorFromHex(row['color'] as String?),
          archivedAt: DateTime.tryParse(row['archived_at'] as String? ?? ''),
        );
      }).toList();
    } catch (error, stack) {
      AppLogger.error(
        'Unable to load local macro goal categories',
        error,
        stack,
      );
      return [];
    }
  }

  Future<DesktopGoalCategory?> _addLocal(String label, Color color) async {
    try {
      final db = await DesktopPrivateDb.instance.database;
      final ownerId = await DesktopPrivateDb.instance.ownerId;
      final now = DateTime.now().toUtc().toIso8601String();
      final colorHex = dashboardColorToHex(color);
      // macro_goal_categories is UNIQUE(user_id, name) (case-sensitive) and
      // delete is a SOFT archive that keeps the row in that uniqueness slot. A
      // bare insert of a previously-deleted name hits "UNIQUE constraint
      // failed", which mobile silently swallowed and desktop reported as a
      // causeless toast. Revive the archived row instead — clear archived_at,
      // apply the new colour, bump updated_at — mirroring the import path's
      // reconcileCategoriesByName and mobile's addMacroGoalCategory. This
      // resurrects the category's prior macro-goal associations, which the
      // owner accepts. Match the name with the same (binary) collation the
      // UNIQUE constraint enforces. A LIVE same-name row is a genuine
      // duplicate: fall through to the insert so the violation surfaces.
      final existing = await db.query(
        'macro_goal_categories',
        columns: ['id', 'archived_at'],
        where: 'user_id = ? AND name = ?',
        whereArgs: [ownerId, label],
        limit: 1,
      );
      if (existing.isNotEmpty && existing.first['archived_at'] != null) {
        final revivedId = existing.first['id'] as String;
        await db.update(
          'macro_goal_categories',
          {'archived_at': null, 'color': colorHex, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [revivedId],
        );
        DesktopPrivateDb.notifyWrite();
        ref.invalidateSelf();
        return DesktopGoalCategory(id: revivedId, label: label, color: color);
      }
      final id = _uuid.v4();
      await db.insert('macro_goal_categories', {
        'id': id,
        'user_id': ownerId,
        'name': label,
        'color': colorHex,
        'created_at': now,
        'updated_at': now,
      });
      DesktopPrivateDb.notifyWrite();
      ref.invalidateSelf();
      return DesktopGoalCategory(id: id, label: label, color: color);
    } catch (error, stack) {
      // Mirror mobile's MacroGoalCategoriesNotifier.addCategory private branch:
      // the controller is the error boundary — log and return null (e.g. a
      // locked private DB / PrivateDatabaseLockedException) instead of
      // rethrowing, so a private-mode write can never surface as an uncaught
      // async error. The call site turns null into a failure toast.
      AppLogger.error('Unable to create local category', error, stack);
      return null;
    }
  }

  Future<void> _archiveLocal(String id) async {
    try {
      final db = await DesktopPrivateDb.instance.database;
      final now = DateTime.now().toUtc().toIso8601String();
      // updated_at must move with the archive or last-write-wins would let an
      // older remote edit un-archive this row on the next sync.
      await db.update(
        'macro_goal_categories',
        {'archived_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      DesktopPrivateDb.notifyWrite();
      ref.invalidateSelf();
    } catch (error, stack) {
      AppLogger.error('Unable to archive local category', error, stack);
      rethrow;
    }
  }

  Future<DesktopGoalCategory?> _updateLocal(
    String id,
    String label,
    Color color,
  ) async {
    try {
      final db = await DesktopPrivateDb.instance.database;
      await db.update(
        'macro_goal_categories',
        {
          'name': label,
          'color': dashboardColorToHex(color),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      DesktopPrivateDb.notifyWrite();
      ref.invalidateSelf();
      return DesktopGoalCategory(id: id, label: label, color: color);
    } catch (error, stack) {
      AppLogger.error('Unable to update local category', error, stack);
      rethrow;
    }
  }
}
