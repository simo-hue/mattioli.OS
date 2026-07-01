import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'private_data_store.dart';
import 'app_logger.dart';
import 'streak_utils.dart';

class BackupImportPreview {
  final int habitsCount;
  final int logsCount;
  final int macroGoalsCount;
  final int categoriesCount;
  final int moodsCount;
  final Map<String, dynamic> rawData;

  const BackupImportPreview({
    required this.habitsCount,
    required this.logsCount,
    required this.macroGoalsCount,
    required this.categoriesCount,
    required this.moodsCount,
    required this.rawData,
  });
}

class BackupImportResult {
  final int habitsCount;
  final int logsCount;
  final int macroGoalsCount;
  final int categoriesCount;
  final int moodsCount;

  const BackupImportResult({
    required this.habitsCount,
    required this.logsCount,
    required this.macroGoalsCount,
    required this.categoriesCount,
    required this.moodsCount,
  });
}

class BackupImportService {
  final PrivateDataStore _privateStore;
  final SupabaseClient? _supabase;
  final _uuid = const Uuid();

  BackupImportService(this._privateStore, this._supabase);

  Future<BackupImportPreview> parseZipPreview(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    String? jsonContent;

    for (final file in archive) {
      if (file.isFile && file.name.endsWith('backup.json')) {
        jsonContent = utf8.decode(file.content as List<int>);
        break;
      }
    }

    if (jsonContent == null) {
      throw Exception('backup.json not found in ZIP');
    }

    final data = jsonDecode(jsonContent) as Map<String, dynamic>;
    
    // Web backup structure:
    // data['goals'] (habits)
    // data['goal_logs'] (logs)
    // data['long_term_goals'] (macro goals)
    // data['goal_category_settings'] (contains mappings)
    // data['daily_moods'] (moods)

    final goals = (data['goals'] as List?) ?? [];
    final logs = (data['goal_logs'] as List?) ?? [];
    final macroGoals = (data['long_term_goals'] as List?) ?? [];
    final categorySettings = data['goal_category_settings'] as Map<String, dynamic>?;
    final mappings = categorySettings?['mappings'] as Map<String, dynamic>? ?? {};
    final moods = (data['daily_moods'] as List?) ?? [];

    return BackupImportPreview(
      habitsCount: goals.length,
      logsCount: logs.length,
      macroGoalsCount: macroGoals.length,
      categoriesCount: mappings.length,
      moodsCount: moods.length,
      rawData: data,
    );
  }

  Future<BackupImportResult> executeImport({
    required Map<String, dynamic> rawData,
    required bool replaceExisting,
    required bool isPrivateMode,
  }) async {
    final processedData = _processData(rawData, replaceExisting);

    if (isPrivateMode) {
      await _privateStore.importData(
        backupData: processedData,
        replaceExisting: replaceExisting,
      );
    } else {
      await _executeCloudImport(processedData, replaceExisting);
    }

    return BackupImportResult(
      habitsCount: (processedData['goals'] as List?)?.length ?? 0,
      logsCount: (processedData['goal_logs'] as List?)?.length ?? 0,
      macroGoalsCount: (processedData['long_term_goals'] as List?)?.length ?? 0,
      categoriesCount: (processedData['macro_goal_categories'] as List?)?.length ?? 0,
      moodsCount: (processedData['daily_moods'] as List?)?.length ?? 0,
    );
  }

  Map<String, dynamic> _processData(Map<String, dynamic> rawData, bool replaceExisting) {
    final Map<String, String> idMap = {}; // oldId -> newId

    String mapId(String oldId) {
      if (replaceExisting) return oldId;
      return idMap.putIfAbsent(oldId, () => _uuid.v4());
    }

    // 1. Process Categories
    final categorySettings = rawData['goal_category_settings'] as Map<String, dynamic>?;
    final mappings = categorySettings?['mappings'] as Map<String, dynamic>? ?? {};
    
    final categoryColorToId = <String, String>{}; // e.g. "red" -> newId
    final processedCategories = <Map<String, dynamic>>[];
    
    mappings.forEach((key, value) {
      final id = _uuid.v4();
      categoryColorToId[key] = id;
      
      String colorStr = '#6B7280';
      String name = key;

      if (value is String) {
        name = value;
      } else if (value is Map<String, dynamic>) {
        name = value['label'] as String? ?? key;
        final c = value['color'] as String?;
        if (c != null) {
          colorStr = _hslToHex(c);
        }
      }

      processedCategories.add({
        'id': id,
        'name': name,
        'color': colorStr,
        'created_at': categorySettings?['created_at'],
        'archived_at': null,
      });
    });

    // 2. Process Goals
    final processedGoals = <Map<String, dynamic>>[];
    for (final g in (rawData['goals'] as List?) ?? []) {
      final oldId = g['id'] as String;
      final newId = mapId(oldId);
      
      String colorHex = '#3B82F6';
      if (g['color'] != null) {
        colorHex = _hslToHex(g['color'] as String);
      }

      processedGoals.add({
        'id': newId,
        'title': g['title'],
        'description': g['description'],
        'icon': g['icon'],
        'color': colorHex,
        'frequency_days': g['frequency_days'],
        'start_date': g['start_date'],
        'end_date': g['end_date'],
        'display_order': g['display_order'],
        'created_at': g['created_at'],
        'updated_at': g['updated_at'],
        'reminder_time': g['reminder_time'],
      });
    }

    // 3. Process Goal Logs
    final rawLogs = (rawData['goal_logs'] as List?) ?? [];
    final logsByGoal = <String, List<Map<String, dynamic>>>{};
    for (final l in rawLogs) {
      final newGoalId = mapId(l['goal_id'] as String);
      logsByGoal.putIfAbsent(newGoalId, () => []).add(l);
    }

    final processedLogs = <Map<String, dynamic>>[];
    for (final entry in logsByGoal.entries) {
      final newGoalId = entry.key;
      final logs = entry.value;

      final matchedGoal = processedGoals.firstWhere(
        (g) => g['id'] == newGoalId,
        orElse: () => <String, dynamic>{},
      );
      final startDateStr = matchedGoal['start_date'] as String?;
      final startDate = startDateStr != null
          ? (DateTime.tryParse(startDateStr) ?? DateTime(2000))
          : DateTime(2000);

      logs.sort((a, b) {
        final dateA = DateTime.tryParse(a['date'] as String) ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['date'] as String) ?? DateTime(2000);
        return dateA.compareTo(dateB);
      });

      final streakLogsMap = <String, Map<String, String>>{};

      for (final l in logs) {
        final oldLogId = l['id'] as String;
        final newLogId = replaceExisting ? oldLogId : _uuid.v4();
        final dateStr = l['date'] as String;
        final status = l['status'] as String;

        int streak = 0;
        final parsedDate = DateTime.tryParse(dateStr);
        if (parsedDate != null) {
          final dateKey = '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
          streakLogsMap.putIfAbsent(dateKey, () => {})[newGoalId] = status;

          streak = computeStreak(
            habitId: newGoalId,
            date: parsedDate,
            logs: streakLogsMap,
            startDate: startDate,
          );
        }

        processedLogs.add({
          'id': newLogId,
          'goal_id': newGoalId,
          'date': dateStr,
          'status': status,
          'value': l['value'],
          'created_at': l['created_at'],
          'updated_at': l['updated_at'],
          'streak': streak,
        });
      }
    }

    // 4. Process Macro Goals
    final processedMacroGoals = <Map<String, dynamic>>[];
    for (final g in (rawData['long_term_goals'] as List?) ?? []) {
      final oldId = g['id'] as String;
      final newId = mapId(oldId);

      final colorKey = g['color'] as String?;
      String? categoryId;
      if (colorKey != null && categoryColorToId.containsKey(colorKey)) {
        categoryId = categoryColorToId[colorKey];
      }

      processedMacroGoals.add({
        'id': newId,
        'title': g['title'],
        'status': g['status'],
        'type': g['type'],
        'year': g['year'],
        'month': g['month'],
        'week_number': g['week_number'],
        'quarter': g['quarter'],
        'category_key': null, // We map to ID instead
        'category_id': categoryId,
        'created_at': g['created_at'],
        'updated_at': g['updated_at'],
      });
    }

    // 5. Process Daily Moods
    final processedMoods = <Map<String, dynamic>>[];
    for (final m in (rawData['daily_moods'] as List?) ?? []) {
      final oldId = m['id'] as String;
      final newId = replaceExisting ? oldId : _uuid.v4();

      processedMoods.add({
        'id': newId,
        'date': m['date'],
        'mood_score': m['mood_score'],
        'energy_score': m['energy_score'],
        'created_at': m['created_at'],
        'updated_at': m['updated_at'],
      });
    }

    return {
      'goals': processedGoals,
      'goal_logs': processedLogs,
      'long_term_goals': processedMacroGoals,
      'macro_goal_categories': processedCategories,
      'daily_moods': processedMoods,
    };
  }

  Future<void> _executeCloudImport(
      Map<String, dynamic> data, bool replaceExisting) async {
    final client = _supabase;
    if (client == null) throw Exception("Supabase is not initialized but cloud import was requested.");

    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in to cloud');

    // Add user_id to all rows
    void addUser(List<Map<String, dynamic>> list) {
      for (final item in list) {
        item['user_id'] = userId;
      }
    }

    final goals = data['goals'] as List<Map<String, dynamic>>;
    final logs = data['goal_logs'] as List<Map<String, dynamic>>;
    final macroGoals = data['long_term_goals'] as List<Map<String, dynamic>>;
    final categories = data['macro_goal_categories'] as List<Map<String, dynamic>>;
    final moods = data['daily_moods'] as List<Map<String, dynamic>>;

    addUser(goals);
    addUser(logs);
    addUser(macroGoals);
    addUser(categories);
    addUser(moods);

    if (replaceExisting) {
      // In replace mode we first delete existing records
      await client.from('goal_logs').delete().eq('user_id', userId);
      await client.from('daily_moods').delete().eq('user_id', userId);
      await client.from('long_term_goals').delete().eq('user_id', userId);
      await client.from('macro_goal_categories').delete().eq('user_id', userId);
      await client.from('goals').delete().eq('user_id', userId);
    }

    // Helper to chunk inserts for supabase (max 1000 per request)
    Future<void> bulkUpsert(String table, List<Map<String, dynamic>> rows) async {
      if (rows.isEmpty) return;
      
      const chunkSize = 500;
      for (var i = 0; i < rows.length; i += chunkSize) {
        final chunk = rows.sublist(i, i + chunkSize > rows.length ? rows.length : i + chunkSize);
        await client.from(table).upsert(chunk, onConflict: 'id', ignoreDuplicates: !replaceExisting);
      }
    }

    await bulkUpsert('macro_goal_categories', categories);
    await bulkUpsert('goals', goals);
    await bulkUpsert('goal_logs', logs);
    await bulkUpsert('long_term_goals', macroGoals);
    await bulkUpsert('daily_moods', moods);
  }

  // Very basic HSL to Hex (e.g. hsl(187 94% 47%) -> #...)
  String _hslToHex(String hslStr) {
    try {
      if (!hslStr.startsWith('hsl')) return hslStr;
      
      final regex = RegExp(r'hsl\(\s*([\d\.]+)\s+([\d\.]+)%\s+([\d\.]+)%\s*\)');
      final match = regex.firstMatch(hslStr);
      if (match == null) return '#3B82F6';

      final h = double.parse(match.group(1)!);
      final s = double.parse(match.group(2)!) / 100.0;
      final l = double.parse(match.group(3)!) / 100.0;

      double c = (1.0 - (2.0 * l - 1.0).abs()) * s;
      double x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
      double m = l - c / 2.0;

      double r = 0, g = 0, b = 0;
      if (0 <= h && h < 60) {
        r = c; g = x; b = 0;
      } else if (60 <= h && h < 120) {
        r = x; g = c; b = 0;
      } else if (120 <= h && h < 180) {
        r = 0; g = c; b = x;
      } else if (180 <= h && h < 240) {
        r = 0; g = x; b = c;
      } else if (240 <= h && h < 300) {
        r = x; g = 0; b = c;
      } else if (300 <= h && h < 360) {
        r = c; g = 0; b = x;
      }

      int rInt = ((r + m) * 255).round();
      int gInt = ((g + m) * 255).round();
      int bInt = ((b + m) * 255).round();

      String toHex(int val) => val.toRadixString(16).padLeft(2, '0').toUpperCase();
      
      return '#${toHex(rInt)}${toHex(gInt)}${toHex(bInt)}';
    } catch (e) {
      AppLogger.warning('Failed to parse HSL color: $hslStr', e);
      return '#3B82F6'; // Default blue
    }
  }
}
