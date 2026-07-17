import re

with open('desktop/lib/core/desktop_private_db.dart', 'r') as f:
    content = f.read()

import_data_code = """
  String _now() => DateTime.now().toUtc().toIso8601String();

  Future<void> importData({
    required Map<String, dynamic> backupData,
    required bool replaceExisting,
  }) async {
    final db = await database;
    final now = _now();
    // Default desktop owner id for local
    final owner = 'local_user';

    await db.transaction((txn) async {
      if (replaceExisting) {
        // Wipe existing user data (except profiles and settings)
        await txn.delete('goal_logs');
        await txn.delete('daily_moods');
        await txn.delete('long_term_goals');
        await txn.delete('macro_goal_categories');
        await txn.delete('goals');
      }

      // Insert Categories
      if (backupData.containsKey('macro_goal_categories')) {
        for (final cat in (backupData['macro_goal_categories'] as List).cast<Map<String, dynamic>>()) {
          final catRow = {
            'id': cat['id'],
            'user_id': owner,
            'name': cat['name'],
            'color': cat['color'],
            'created_at': cat['created_at'] ?? now,
            'archived_at': cat['archived_at'],
          };
          await txn.insert('macro_goal_categories', catRow, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Insert Goals (Habits)
      if (backupData.containsKey('goals')) {
        for (final g in (backupData['goals'] as List).cast<Map<String, dynamic>>()) {
          final goalRow = {
            'id': g['id'],
            'user_id': owner,
            'title': g['title'],
            'description': g['description'],
            'icon': g['icon'],
            'color': g['color'],
            'frequency_days': g['frequency_days'] != null ? jsonEncode(g['frequency_days']) : null,
            'start_date': g['start_date'],
            'end_date': g['end_date'],
            'display_order': g['display_order'],
            'created_at': g['created_at'] ?? now,
            'updated_at': g['updated_at'] ?? now,
            'reminder_time': g['reminder_time'],
          };
          await txn.insert('goals', goalRow, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Insert Goal Logs
      if (backupData.containsKey('goal_logs')) {
        for (final l in (backupData['goal_logs'] as List).cast<Map<String, dynamic>>()) {
          final logRow = {
            'id': l['id'],
            'user_id': owner,
            'goal_id': l['goal_id'],
            'date': l['date'],
            'status': l['status'],
            'value': l['value'],
            'created_at': l['created_at'] ?? now,
            'updated_at': l['updated_at'] ?? now,
            'streak': l['streak'] ?? 0,
          };
          await txn.insert('goal_logs', logRow, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Insert Macro Goals
      if (backupData.containsKey('long_term_goals')) {
        for (final g in (backupData['long_term_goals'] as List).cast<Map<String, dynamic>>()) {
          final ltgRow = {
            'id': g['id'],
            'user_id': owner,
            'title': g['title'],
            'status': g['status'],
            'type': g['type'],
            'year': g['year'],
            'month': g['month'],
            'week_number': g['week_number'],
            'quarter': g['quarter'],
            'category_key': g['category_key'],
            'category_id': g['category_id'],
            'created_at': g['created_at'] ?? now,
            'updated_at': g['updated_at'] ?? now,
          };
          await txn.insert('long_term_goals', ltgRow, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // Insert Daily Moods
      if (backupData.containsKey('daily_moods')) {
        for (final m in (backupData['daily_moods'] as List).cast<Map<String, dynamic>>()) {
          final moodRow = {
            'id': m['id'],
            'user_id': owner,
            'date': m['date'],
            'mood_score': m['mood_score'],
            'energy_score': m['energy_score'],
            'created_at': m['created_at'] ?? now,
            'updated_at': m['updated_at'] ?? now,
          };
          await txn.insert('daily_moods', moodRow, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }

  // --- Database Setup ---
"""

content = content.replace('  // --- Database Setup ---', import_data_code)

with open('desktop/lib/core/desktop_private_db.dart', 'w') as f:
    f.write(content)
