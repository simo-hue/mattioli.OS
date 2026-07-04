import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'desktop_private_db.dart';
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

/// Parses and imports backup archives on desktop.
///
/// Three interchange shapes are accepted so that a backup is round-trippable
/// across every Evolve client:
///   1. **Web `.zip`** containing `backup.json` — the legacy web-app schema
///      (`goals`/`goal_logs`/`long_term_goals`/`goal_category_settings.mappings`
///      /`daily_moods`, hsl colors). Handled by [parseZipPreview].
///   2. **Native DB-row `.json`** — the shape emitted by both desktop exports
///      (`DesktopPrivateDb.exportData()` and the cloud export) and by the mobile
///      private export: `goals`/`goal_logs`/`long_term_goals`
///      /`macro_goal_categories`/`daily_moods` (+ `profile`), hex colors.
///   3. **Mobile cloud camelCase `.json`** (`mattioli_os_export.json`):
///      `habits`/`habitLogs`/`macroGoals`/`macroGoalCategories`/`dailyMoods`
///      (+ `profile`). The array *elements* already use snake_case DB keys, so
///      only the container keys are renamed.
///
/// Every shape is normalized to a single canonical model consumed by
/// [buildImportModel]/[_processData] and then persisted to the encrypted DB
/// (private mode) or Supabase (cloud mode).
class DesktopBackupImportService {
  final DesktopPrivateDb _privateStore;
  final SupabaseClient? _supabase;

  DesktopBackupImportService(this._privateStore, this._supabase);

  /// Cloud `profiles` columns that are safe to overwrite on import. Deliberately
  /// conservative — identity (`id`), entitlement (`is_pro`), and the local-path
  /// `avatar_url` are never imported.
  static const _cloudProfileImportColumns = <String>{
    'full_name',
    'username',
    'date_of_birth',
  };

  /// Reads a backup file and returns a preview + the normalized raw data.
  /// Dispatches on file type: `.json` → native/camelCase shape; anything else is
  /// treated as a web `.zip` backup.
  Future<BackupImportPreview> parsePreview(String filePath) {
    if (filePath.toLowerCase().endsWith('.json')) {
      return _parseJsonPreview(filePath);
    }
    return parseZipPreview(filePath);
  }

  Future<BackupImportPreview> parseZipPreview(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    String? jsonContent;

    for (final entry in archive) {
      if (entry.isFile && entry.name.endsWith('backup.json')) {
        jsonContent = utf8.decode(entry.content as List<int>);
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
    final categorySettings =
        data['goal_category_settings'] as Map<String, dynamic>?;
    final mappings =
        categorySettings?['mappings'] as Map<String, dynamic>? ?? {};
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

  Future<BackupImportPreview> _parseJsonPreview(String filePath) async {
    final text = await File(filePath).readAsString();
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unsupported JSON backup: expected an object');
    }
    final normalized = _normalizeShape(decoded);
    if (!_looksLikeBackup(normalized)) {
      throw Exception('Unsupported JSON backup: no recognizable data');
    }

    final categories = normalized['macro_goal_categories'] as List? ?? const [];
    return BackupImportPreview(
      habitsCount: (normalized['goals'] as List?)?.length ?? 0,
      logsCount: (normalized['goal_logs'] as List?)?.length ?? 0,
      macroGoalsCount: (normalized['long_term_goals'] as List?)?.length ?? 0,
      categoriesCount: categories.length,
      moodsCount: (normalized['daily_moods'] as List?)?.length ?? 0,
      rawData: normalized,
    );
  }

  Future<BackupImportResult> executeImport({
    required Map<String, dynamic> rawData,
    required bool replaceExisting,
    required bool isPrivateMode,
  }) async {
    final processedData = buildImportModel(
      rawData,
      replaceExisting: replaceExisting,
    );

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
      categoriesCount:
          (processedData['macro_goal_categories'] as List?)?.length ?? 0,
      moodsCount: (processedData['daily_moods'] as List?)?.length ?? 0,
    );
  }

  /// Pure transformation from a (web or normalized-native) raw backup into the
  /// canonical import model persisted by the DB/Supabase layers. Exposed for
  /// round-trip tests.
  static Map<String, dynamic> buildImportModel(
    Map<String, dynamic> rawData, {
    required bool replaceExisting,
  }) => _processData(rawData, replaceExisting);

  /// Builds the canonical import model from a raw `.json` backup (native DB-row
  /// or mobile camelCase shape). This is exactly what the `.json` import path
  /// runs: normalize the shape, then process. Exposed for round-trip tests.
  static Map<String, dynamic> modelFromJson(
    Map<String, dynamic> data, {
    required bool replaceExisting,
  }) => _processData(_normalizeShape(data), replaceExisting);

  static Map<String, dynamic> _processData(
    Map<String, dynamic> rawData,
    bool replaceExisting,
  ) {
    const uuid = Uuid();
    final Map<String, String> idMap = {}; // oldId -> newId

    String mapId(String oldId) {
      if (replaceExisting) return oldId;
      return idMap.putIfAbsent(oldId, () => uuid.v4());
    }

    // 1. Process Categories.
    // Native shape carries `macro_goal_categories` (a list with stable ids and
    // hex colors); the web shape carries `goal_category_settings.mappings`
    // (color-key -> label/hsl) which we synthesize ids for.
    final categoryColorToId = <String, String>{}; // web colorKey -> id
    final processedCategories = <Map<String, dynamic>>[];

    final nativeCategories = rawData['macro_goal_categories'];
    if (nativeCategories is List && nativeCategories.isNotEmpty) {
      for (final raw in nativeCategories) {
        if (raw is! Map) continue;
        final c = Map<String, dynamic>.from(raw);
        // Keep the imported id stable so macro goals' `category_id` still
        // resolves; merge-mode name-collision remapping happens in applyImport.
        final id = (c['id'] as String?) ?? uuid.v4();
        processedCategories.add({
          'id': id,
          'name': c['name'] ?? 'Categoria',
          'color': _hslToHex((c['color'] as String?) ?? '#6B7280'),
          'created_at': c['created_at'],
          // NB: `macro_goal_categories` has no `updated_at` column (cloud or
          // mobile schema) — emitting one would make the Supabase upsert fail
          // with PGRST204. The private importer coalesces its own timestamps.
          'archived_at': c['archived_at'],
        });
      }
    } else {
      final categorySettings =
          rawData['goal_category_settings'] as Map<String, dynamic>?;
      final mappings =
          categorySettings?['mappings'] as Map<String, dynamic>? ?? {};
      mappings.forEach((key, value) {
        final id = uuid.v4();
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
    }

    // 2. Process Goals
    final processedGoals = <Map<String, dynamic>>[];
    for (final raw in (rawData['goals'] as List?) ?? []) {
      if (raw is! Map) continue;
      final g = Map<String, dynamic>.from(raw);
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
        // The private DB stores frequency_days as a JSON *string* ("[1,2,3]");
        // decode to a real list so the cloud `integer[]` column accepts it (the
        // private re-encoder handles a list fine).
        'frequency_days': _decodeFrequency(g['frequency_days']),
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
    for (final raw in rawLogs) {
      if (raw is! Map) continue;
      final l = Map<String, dynamic>.from(raw);
      final goalId = l['goal_id'];
      if (goalId is! String) continue;
      final newGoalId = mapId(goalId);
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
        final dateA =
            DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final dateB =
            DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return dateA.compareTo(dateB);
      });

      final streakLogsMap = <String, Map<String, String>>{};

      for (final l in logs) {
        final oldLogId = l['id'] as String?;
        final newLogId = replaceExisting ? (oldLogId ?? uuid.v4()) : uuid.v4();
        final dateStr = l['date']?.toString();
        if (dateStr == null) continue;
        final status = (l['status'] as String?) ?? 'done';

        int streak = 0;
        final parsedDate = DateTime.tryParse(dateStr);
        if (parsedDate != null) {
          final dateKey =
              '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
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
    for (final raw in (rawData['long_term_goals'] as List?) ?? []) {
      if (raw is! Map) continue;
      final g = Map<String, dynamic>.from(raw);
      final oldId = g['id'] as String;
      final newId = mapId(oldId);

      // Native shape references categories by `category_id`; the web shape
      // references them via the `color` color-key -> synthesized id.
      String? categoryId = g['category_id'] as String?;
      if (categoryId == null) {
        final colorKey = g['color'] as String?;
        if (colorKey != null && categoryColorToId.containsKey(colorKey)) {
          categoryId = categoryColorToId[colorKey];
        }
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
        'category_key': g['category_key'],
        'category_id': categoryId,
        'created_at': g['created_at'],
        'updated_at': g['updated_at'],
      });
    }

    // 5. Process Daily Moods
    final processedMoods = <Map<String, dynamic>>[];
    for (final raw in (rawData['daily_moods'] as List?) ?? []) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final oldId = m['id'] as String?;
      final newId = replaceExisting ? (oldId ?? uuid.v4()) : uuid.v4();

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
      // Passed straight through; applied by the DB/Supabase layers under a safe
      // allow-list. Null for web-zip backups (no profile block).
      'profile': _normalizeProfile(rawData['profile']),
    };
  }

  // ---------------------------------------------------------------------------
  // Shape normalization (native DB-row JSON + mobile camelCase JSON)
  // ---------------------------------------------------------------------------

  /// Maps any `.json` backup shape to the common pre-process schema that
  /// [_processData] consumes (web-style container keys + a
  /// `macro_goal_categories` list + `profile`).
  static Map<String, dynamic> _normalizeShape(Map<String, dynamic> data) {
    final isMobileCamel =
        data.containsKey('habits') ||
        data.containsKey('macroGoals') ||
        data.containsKey('macroGoalCategories') ||
        data.containsKey('dailyMoods');

    if (isMobileCamel) {
      return {
        'goals': _asList(data['habits']),
        'goal_logs': _normalizeLogs(data['habitLogs']),
        'long_term_goals': _asList(data['macroGoals']),
        'macro_goal_categories': _asList(data['macroGoalCategories']),
        'daily_moods': _normalizeMoods(data['dailyMoods']),
        'profile': _normalizeProfile(data['profile']),
      };
    }

    return {
      'goals': _asList(data['goals']),
      'goal_logs': _normalizeLogs(data['goal_logs']),
      'long_term_goals': _asList(data['long_term_goals']),
      'macro_goal_categories': _asList(data['macro_goal_categories']),
      'daily_moods': _normalizeMoods(data['daily_moods']),
      'profile': _normalizeProfile(data['profile']),
      // A raw web `backup.json` picked directly (not inside its .zip) keeps its
      // categories under `goal_category_settings.mappings` with no
      // `macro_goal_categories` list. Carry it through so _processData's web
      // color-key path still resolves categories + macro-goal links.
      if (data['goal_category_settings'] != null)
        'goal_category_settings': data['goal_category_settings'],
    };
  }

  static bool _looksLikeBackup(Map<String, dynamic> normalized) {
    for (final key in const [
      'goals',
      'goal_logs',
      'long_term_goals',
      'macro_goal_categories',
      'daily_moods',
    ]) {
      final value = normalized[key];
      if (value is List && value.isNotEmpty) return true;
    }
    // A profile-only backup is still a valid (if empty) backup.
    return normalized['profile'] is Map;
  }

  static List<Map<String, dynamic>> _asList(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// Frequency days may arrive as a real JSON array (cloud/web) or as a
  /// JSON-encoded string (the private DB stores it as TEXT). Normalizes to a
  /// `List<int>`; null when absent or unparseable.
  static List<int>? _decodeFrequency(Object? value) {
    if (value == null) return null;
    List? list;
    if (value is List) {
      list = value;
    } else if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) list = decoded;
      } catch (_) {
        return null;
      }
    }
    if (list == null) return null;
    return list
        .map((e) => e is int ? e : int.tryParse('$e'))
        .whereType<int>()
        .toList();
  }

  /// Logs may arrive as a list of rows (native shape) or as a nested
  /// `{ date: { goalId: status } }` map (some snapshot exports). Both are
  /// flattened to row maps; the streak is recomputed downstream.
  static List<Map<String, dynamic>> _normalizeLogs(Object? value) {
    if (value is List) return _asList(value);
    if (value is Map) {
      final rows = <Map<String, dynamic>>[];
      value.forEach((date, byGoal) {
        if (byGoal is Map) {
          byGoal.forEach((goalId, status) {
            rows.add({'goal_id': goalId, 'date': date, 'status': status});
          });
        }
      });
      return rows;
    }
    return <Map<String, dynamic>>[];
  }

  /// Moods may arrive as a list of rows or as a `{ date: {...} }` map. The map
  /// values are hoisted to rows, injecting the `date` key when absent.
  static List<Map<String, dynamic>> _normalizeMoods(Object? value) {
    if (value is List) return _asList(value);
    if (value is Map) {
      final rows = <Map<String, dynamic>>[];
      value.forEach((date, row) {
        if (row is Map) {
          final m = Map<String, dynamic>.from(row);
          m.putIfAbsent('date', () => date);
          rows.add(m);
        }
      });
      return rows;
    }
    return <Map<String, dynamic>>[];
  }

  /// Normalizes a profile block to snake_case DB columns. Accepts the native
  /// DB-row shape (already snake_case) and the mobile camelCase shape
  /// (`firstName`/`lastName`/`dateOfBirth`).
  static Map<String, dynamic>? _normalizeProfile(Object? value) {
    if (value is! Map) return null;
    final p = Map<String, dynamic>.from(value);
    if (p.containsKey('firstName') ||
        p.containsKey('lastName') ||
        p.containsKey('dateOfBirth')) {
      final first = (p['firstName'] as String?)?.trim() ?? '';
      final last = (p['lastName'] as String?)?.trim() ?? '';
      final fullName = [first, last].where((s) => s.isNotEmpty).join(' ');
      return {
        if (fullName.isNotEmpty) 'full_name': fullName,
        if (p['dateOfBirth'] != null) 'date_of_birth': p['dateOfBirth'],
      };
    }
    return p;
  }

  /// Merge-mode category reconciliation for the cloud path: an imported category
  /// whose `name` already exists (under a different id) is dropped from the
  /// insert set and its id is remapped onto the existing row's id; referencing
  /// macro goals' `category_id` is rewritten in place. Mirrors the private
  /// importer's `(user_id, name)` reconciliation. Pure & testable — returns the
  /// categories that still need inserting.
  static List<Map<String, dynamic>> reconcileCategoriesByName(
    List<Map<String, dynamic>> categories,
    List<Map<String, dynamic>> macroGoals,
    Map<String, String> existingIdByName,
  ) {
    final remap = <String, String>{};
    final toInsert = <Map<String, dynamic>>[];
    for (final c in categories) {
      final name = c['name'] as String?;
      final importedId = c['id'] as String?;
      final existingId = name == null ? null : existingIdByName[name];
      if (existingId != null && importedId != null) {
        remap[importedId] = existingId;
      } else {
        toInsert.add(c);
      }
    }
    if (remap.isNotEmpty) {
      for (final g in macroGoals) {
        final cid = g['category_id'] as String?;
        if (cid != null && remap.containsKey(cid)) {
          g['category_id'] = remap[cid];
        }
      }
    }
    return toInsert;
  }

  Future<void> _executeCloudImport(
    Map<String, dynamic> data,
    bool replaceExisting,
  ) async {
    final client = _supabase;
    if (client == null) {
      throw Exception(
        'Supabase is not initialized but cloud import was requested.',
      );
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in to cloud');

    // Add user_id to all rows
    void addUser(List<Map<String, dynamic>> list) {
      for (final item in list) {
        item['user_id'] = userId;
      }
    }

    final goals = (data['goals'] as List).cast<Map<String, dynamic>>();
    final logs = (data['goal_logs'] as List).cast<Map<String, dynamic>>();
    final macroGoals = (data['long_term_goals'] as List)
        .cast<Map<String, dynamic>>();
    var categories = (data['macro_goal_categories'] as List)
        .cast<Map<String, dynamic>>();
    final moods = (data['daily_moods'] as List).cast<Map<String, dynamic>>();

    addUser(goals);
    addUser(logs);
    addUser(macroGoals);
    addUser(categories);
    addUser(moods);

    if (replaceExisting) {
      // In replace mode we first delete existing records (children first).
      await client.from('goal_logs').delete().eq('user_id', userId);
      await client.from('daily_moods').delete().eq('user_id', userId);
      await client.from('long_term_goals').delete().eq('user_id', userId);
      await client.from('macro_goal_categories').delete().eq('user_id', userId);
      await client.from('goals').delete().eq('user_id', userId);
    } else if (categories.isNotEmpty) {
      // Merge mode: reconcile categories by (user_id, name) — a name that
      // already exists is reused (its id) and referencing macro goals are
      // remapped — mirroring the private importer, so the (user_id, name)
      // UNIQUE constraint can't abort the upsert and no category_id is left
      // dangling.
      final existing = await client
          .from('macro_goal_categories')
          .select('id, name')
          .eq('user_id', userId);
      final existingIdByName = <String, String>{
        for (final row in (existing as List).cast<Map<String, dynamic>>())
          if (row['name'] != null) row['name'] as String: row['id'] as String,
      };
      categories = reconcileCategoriesByName(
        categories,
        macroGoals,
        existingIdByName,
      );
    }

    // Helper to chunk upserts for supabase (max ~1000 per request). The conflict
    // target must match each table's operative UNIQUE constraint — not just
    // `id` — or a merge collision on a secondary constraint (daily_moods
    // (user_id,date), goal_logs (goal_id,date)) aborts the whole request.
    Future<void> bulkUpsert(
      String table,
      List<Map<String, dynamic>> rows, {
      required String conflictTarget,
    }) async {
      if (rows.isEmpty) return;

      const chunkSize = 500;
      for (var i = 0; i < rows.length; i += chunkSize) {
        final chunk = rows.sublist(
          i,
          i + chunkSize > rows.length ? rows.length : i + chunkSize,
        );
        await client
            .from(table)
            .upsert(
              chunk,
              onConflict: conflictTarget,
              ignoreDuplicates: !replaceExisting,
            );
      }
    }

    await bulkUpsert('macro_goal_categories', categories, conflictTarget: 'id');
    await bulkUpsert('goals', goals, conflictTarget: 'id');
    await bulkUpsert('goal_logs', logs, conflictTarget: 'goal_id,date');
    await bulkUpsert('long_term_goals', macroGoals, conflictTarget: 'id');
    await bulkUpsert('daily_moods', moods, conflictTarget: 'user_id,date');

    // Restore the profile last, under a conservative allow-list (identity and
    // entitlement columns are never overwritten).
    final profile = data['profile'];
    if (profile is Map) {
      final updates = <String, dynamic>{};
      for (final col in _cloudProfileImportColumns) {
        if (profile[col] != null) updates[col] = profile[col];
      }
      if (updates.isNotEmpty) {
        updates['id'] = userId;
        await client.from('profiles').upsert(updates, onConflict: 'id');
      }
    }
  }

  /// Common named color tokens → hex, so a web backup that stored a palette
  /// name (rather than hsl/hex) keeps its color instead of being blue-washed.
  static const _namedColorHex = <String, String>{
    'red': '#EF4444',
    'orange': '#F97316',
    'amber': '#F59E0B',
    'yellow': '#EAB308',
    'lime': '#84CC16',
    'green': '#22C55E',
    'emerald': '#10B981',
    'teal': '#14B8A6',
    'cyan': '#06B6D4',
    'sky': '#0EA5E9',
    'blue': '#3B82F6',
    'indigo': '#6366F1',
    'violet': '#8B5CF6',
    'purple': '#A855F7',
    'fuchsia': '#D946EF',
    'pink': '#EC4899',
    'rose': '#F43F5E',
    'slate': '#64748B',
    'gray': '#6B7280',
    'grey': '#6B7280',
  };

  /// Normalizes an imported color. A valid `#hex` is preserved as-is, a known
  /// named token is mapped to hex, and an `hsl(...)` string is converted. An
  /// unrecognized value is returned unchanged — never silently blue-washed.
  static String _hslToHex(String hslStr) {
    final input = hslStr.trim();
    if (input.startsWith('#')) return input;
    final named = _namedColorHex[input.toLowerCase()];
    if (named != null) return named;
    try {
      if (!input.startsWith('hsl')) return input;

      final regex = RegExp(r'hsl\(\s*([\d\.]+)\s+([\d\.]+)%\s+([\d\.]+)%\s*\)');
      final match = regex.firstMatch(input);
      if (match == null) return input;

      final h = double.parse(match.group(1)!);
      final s = double.parse(match.group(2)!) / 100.0;
      final l = double.parse(match.group(3)!) / 100.0;

      double c = (1.0 - (2.0 * l - 1.0).abs()) * s;
      double x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
      double m = l - c / 2.0;

      double r = 0, g = 0, b = 0;
      if (0 <= h && h < 60) {
        r = c;
        g = x;
        b = 0;
      } else if (60 <= h && h < 120) {
        r = x;
        g = c;
        b = 0;
      } else if (120 <= h && h < 180) {
        r = 0;
        g = c;
        b = x;
      } else if (180 <= h && h < 240) {
        r = 0;
        g = x;
        b = c;
      } else if (240 <= h && h < 300) {
        r = x;
        g = 0;
        b = c;
      } else if (300 <= h && h < 360) {
        r = c;
        g = 0;
        b = x;
      }

      int rInt = ((r + m) * 255).round();
      int gInt = ((g + m) * 255).round();
      int bInt = ((b + m) * 255).round();

      String toHex(int val) =>
          val.toRadixString(16).padLeft(2, '0').toUpperCase();

      return '#${toHex(rInt)}${toHex(gInt)}${toHex(bInt)}';
    } catch (e) {
      AppLogger.warning('Failed to parse color: $input', e);
      return input; // Preserve the original rather than blue-washing it.
    }
  }
}
