import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'desktop_private_db.dart';
import 'app_logger.dart';
import 'import_merge.dart';
import 'import_merge_stats.dart';
import 'streak_utils.dart';

/// Counts shown in the pre-import preview: how many VALID records the file
/// contributes per entity, the canonical data ready to import, and how many
/// rows were dropped as invalid (so the user is warned before confirming).
class BackupImportPreview {
  final int habitsCount;
  final int logsCount;
  final int macroGoalsCount;
  final int categoriesCount;
  final int moodsCount;

  /// Canonical, VALIDATED backup — feed straight to
  /// [DesktopBackupImportService.executeImport].
  final Map<String, dynamic> canonicalData;

  /// How many rows were dropped as invalid during validation, keyed by
  /// 'habits' | 'logs' | 'macroGoals' | 'categories' | 'moods'.
  final Map<String, int> skipped;

  const BackupImportPreview({
    required this.habitsCount,
    required this.logsCount,
    required this.macroGoalsCount,
    required this.categoriesCount,
    required this.moodsCount,
    required this.canonicalData,
    required this.skipped,
  });

  /// Total invalid rows across all entities.
  int get totalSkipped => skipped.values.fold(0, (a, b) => a + b);
}

/// Page size for the windowed existing-state reads of the cloud import. A single
/// unbounded PostgREST `select` is capped by the project's `db-max-rows` (1000
/// by default), so a read built from one silently returns a PARTIAL view of the
/// account: Replace would then prune only the rows it happened to see, and the
/// streak recompute would derive streaks from a truncated history and write them
/// back over the correct values.
const int kImportPageSize = 1000;

/// Fetches one window of rows. Abstracted so the paging loop is unit-testable
/// without a live Supabase client.
typedef ImportPageFetcher =
    Future<List<Map<String, dynamic>>> Function(int offset, int limit);

/// Concatenates every page from [fetchPage], requesting successive windows
/// until a short (final) page comes back. [fetchPage] must impose a stable
/// total order, otherwise windows can repeat or skip rows.
///
/// Mirrors the mobile `BackupImportService`'s helper of the same name (and
/// `fetchAllRowsPaginated` in the desktop settings page), which window the
/// export reads for the same reason.
Future<List<Map<String, dynamic>>> fetchAllRowsPaginated(
  ImportPageFetcher fetchPage, {
  int pageSize = kImportPageSize,
}) async {
  final rows = <Map<String, dynamic>>[];
  var offset = 0;
  while (true) {
    final page = await fetchPage(offset, pageSize);
    rows.addAll(page);
    if (page.length < pageSize) break;
    offset += pageSize;
  }
  return rows;
}

/// Parses and imports backup archives on desktop.
///
/// Three interchange shapes are accepted so that a backup is round-trippable
/// across every Evolve client:
///   1. **Web `.zip`** containing `backup.json` — the legacy web-app schema
///      (`goals`/`goal_logs`/`long_term_goals`/`goal_category_settings.mappings`
///      /`daily_moods`, hsl colors). Handled by [parseZipPreview].
///   2. **Native DB-row `.json`** — the snake_case container shape emitted by
///      pre-1.x desktop exports: `goals`/`goal_logs`/`long_term_goals`
///      /`macro_goal_categories`/`daily_moods` (+ `profile`), hex colors.
///   3. **CamelCase `.json`** — the canonical cross-client export emitted by
///      the mobile app AND by current desktop exports
///      (`evolve_private_export.json` / `mattioli_os_export.json`):
///      `habits`/`habitLogs`/`macroGoals`/`macroGoalCategories`/`dailyMoods`
///      (+ `profile`/`settings`/`schemaVersion`). The array *elements* already
///      use snake_case DB keys, so only the container keys are renamed.
///
/// Every shape is normalized to a single canonical model, VALIDATED (invalid
/// rows are dropped and counted — see `validateCanonical`), previewed, and
/// then reconciled into the encrypted DB (private mode) or Supabase (cloud
/// mode) by identity + last-write-wins, mirroring the mobile client's
/// `BackupImportService` semantics. Records keep their **original** ids so a
/// re-import deduplicates by identity instead of duplicating.
class DesktopBackupImportService {
  final DesktopPrivateDb _privateStore;
  final SupabaseClient? _supabase;
  static const _uuid = Uuid();

  DesktopBackupImportService(this._privateStore, this._supabase);

  /// Cloud `profiles` columns that are safe to overwrite on import. Deliberately
  /// conservative — identity (`id`), entitlement (`is_pro`), and the local-path
  /// `avatar_url` are never imported.
  static const _cloudProfileImportColumns = <String>{
    'full_name',
    'username',
    'date_of_birth',
  };

  /// Reads a backup file and returns a preview + the canonical validated data.
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
    return _previewOf(buildCanonicalModel(data));
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
    return _previewOf(validateCanonical(_processData(normalized)));
  }

  static BackupImportPreview _previewOf(ValidatedBackup validated) {
    final canonical = validated.canonical;
    return BackupImportPreview(
      habitsCount: (canonical[kGoalsKey] as List).length,
      logsCount: (canonical[kLogsKey] as List).length,
      macroGoalsCount: (canonical[kMacrosKey] as List).length,
      categoriesCount: (canonical[kCategoriesKey] as List).length,
      moodsCount: (canonical[kMoodsKey] as List).length,
      canonicalData: canonical,
      skipped: validated.skipped,
    );
  }

  /// Imports already-validated [canonicalData] into the active store and
  /// returns the per-entity merge outcome. [skipped] (from [parsePreview]) is
  /// folded into the result so the summary can report how many rows were
  /// dropped as invalid.
  Future<ImportMergeStats> executeImport({
    required Map<String, dynamic> canonicalData,
    required bool replaceExisting,
    required bool isPrivateMode,
    Map<String, int> skipped = const {},
  }) async {
    final stats = isPrivateMode
        ? await _privateStore.importData(
            backupData: canonicalData,
            replaceExisting: replaceExisting,
          )
        : await _executeCloudImport(canonicalData, replaceExisting);

    stats.habits.skipped = skipped['habits'] ?? 0;
    stats.logs.skipped = skipped['logs'] ?? 0;
    stats.macroGoals.skipped = skipped['macroGoals'] ?? 0;
    stats.categories.skipped = skipped['categories'] ?? 0;
    stats.moods.skipped = skipped['moods'] ?? 0;
    return stats;
  }

  /// Pure pipeline from any raw `.json`/`.zip` backup map to the canonical
  /// VALIDATED import model: normalize the container shape, process (colors,
  /// web-category synthesis, frequency decode), validate (drop + count invalid
  /// rows). Exposed for round-trip tests.
  static ValidatedBackup buildCanonicalModel(Map<String, dynamic> data) =>
      validateCanonical(_processData(_normalizeShape(data)));

  static Map<String, dynamic> _processData(Map<String, dynamic> rawData) {
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
        // resolves; identity/name reconciliation happens at merge time.
        processedCategories.add({
          'id': _sid(c['id']) ?? _uuid.v4(),
          'name': c['name'],
          'color': _hslToHex((c['color'] as String?) ?? '#6B7280'),
          'created_at': c['created_at'],
          // Carried for the private store (its schema has the column); the
          // cloud plan deliberately omits it (the Supabase table doesn't).
          'updated_at': c['updated_at'],
          'archived_at': c['archived_at'],
        });
      }
    } else {
      final categorySettings =
          rawData['goal_category_settings'] as Map<String, dynamic>?;
      final mappings =
          categorySettings?['mappings'] as Map<String, dynamic>? ?? {};
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
          'updated_at': null,
          'archived_at': null,
        });
      });
    }

    // 2. Process Goals — original ids are KEPT (identity-based merge dedups a
    // re-import; a fresh id here would duplicate every habit instead).
    final processedGoals = <Map<String, dynamic>>[];
    for (final raw in (rawData['goals'] as List?) ?? []) {
      if (raw is! Map) continue;
      final g = Map<String, dynamic>.from(raw);

      String colorHex = '#3B82F6';
      if (g['color'] != null) {
        colorHex = _hslToHex(g['color'].toString());
      }

      processedGoals.add({
        'id': _sid(g['id']) ?? _uuid.v4(),
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
        'verify_provider': g['verify_provider'],
        'verify_metric': g['verify_metric'],
        'verify_comparator': g['verify_comparator'],
        'verify_threshold': g['verify_threshold'],
        'verify_unit': g['verify_unit'],
      });
    }

    // 3. Process Goal Logs — ids and goal references are passed through; the
    // stores match by (goal_id, date) and recompute streaks AFTER the merge
    // from the combined history (a file-local streak would be wrong whenever
    // the device already has logs for the same habit).
    final processedLogs = <Map<String, dynamic>>[];
    for (final raw in (rawData['goal_logs'] as List?) ?? []) {
      if (raw is! Map) continue;
      final l = Map<String, dynamic>.from(raw);
      processedLogs.add({
        'id': _sid(l['id']),
        'goal_id': _sid(l['goal_id']),
        'date': l['date']?.toString(),
        'status': l['status'],
        // Preserve the quantitative log value (steps/minutes/reps, incl.
        // HealthKit-measured quantities) so it survives the round-trip — mobile
        // carries this too; dropping it here silently loses the column.
        'value': l['value'],
        'created_at': l['created_at'],
        'updated_at': l['updated_at'],
        'streak': l['streak'],
      });
    }

    // 4. Process Macro Goals
    final processedMacroGoals = <Map<String, dynamic>>[];
    for (final raw in (rawData['long_term_goals'] as List?) ?? []) {
      if (raw is! Map) continue;
      final g = Map<String, dynamic>.from(raw);

      // Native shape references categories by `category_id`; the web shape
      // references them via the `color` color-key -> synthesized id.
      String? categoryId = _sid(g['category_id']);
      if (categoryId == null) {
        final colorKey = g['color'] as String?;
        if (colorKey != null && categoryColorToId.containsKey(colorKey)) {
          categoryId = categoryColorToId[colorKey];
        }
      }

      processedMacroGoals.add({
        'id': _sid(g['id']) ?? _uuid.v4(),
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
      processedMoods.add({
        'id': _sid(m['id']),
        'date': m['date']?.toString(),
        'mood_score': m['mood_score'],
        'energy_score': m['energy_score'],
        'created_at': m['created_at'],
        'updated_at': m['updated_at'],
      });
    }

    return {
      kGoalsKey: processedGoals,
      kLogsKey: processedLogs,
      kMacrosKey: processedMacroGoals,
      kCategoriesKey: processedCategories,
      kMoodsKey: processedMoods,
      // Passed straight through; applied by the DB/Supabase layers under a safe
      // allow-list. Null for web-zip backups (no profile block).
      kProfileKey: _normalizeProfile(rawData['profile']),
    };
  }

  /// Coerce any JSON scalar id to a trimmed non-empty String, or null — an id
  /// exported as a number must not crash the parse.
  static String? _sid(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  // ---------------------------------------------------------------------------
  // Shape normalization (native DB-row JSON + camelCase JSON)
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
    if (normalized['goal_category_settings'] != null) return true;
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
  /// `{ date: { goalId: status } }` map (legacy snapshot exports). Both are
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

  // ---------------------------------------------------------------------------
  // Cloud (Supabase) import
  //
  // Mirrors the private-mode merge (identity + last-write-wins), but since
  // Supabase has no client-side transaction, the entire plan is computed from
  // the fetched existing state FIRST — so a malformed file can never delete
  // data and then fail. Only once the plan is built do we mutate the server.
  // ---------------------------------------------------------------------------

  Future<ImportMergeStats> _executeCloudImport(
    Map<String, dynamic> canonical,
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

    final now = DateTime.now().toUtc().toIso8601String();

    // Fetch existing state (empty in replace mode) BEFORE building the plan.
    // Windowed: the plan classifies an incoming row as new when it finds no
    // match here, so a row hidden past the row cap would be re-inserted under a
    // fresh id and collide with the table's natural-key UNIQUE constraint — the
    // completeness the comment below the plan relies on.
    Future<List<Map<String, dynamic>>> fetch(String table, String cols) async {
      if (replaceExisting) return const [];
      return fetchAllRowsPaginated((offset, limit) async {
        final res = await client
            .from(table)
            .select(cols)
            .eq('user_id', userId)
            .order('id')
            .range(offset, offset + limit - 1);
        return (res as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      });
    }

    final existingCategories = await fetch(
      'macro_goal_categories',
      'id,name,archived_at',
    );
    final existingGoals = {
      for (final r in await fetch('goals', 'id,updated_at'))
        r['id'] as String: r['updated_at'] as String?,
    };
    final existingMacros = {
      for (final r in await fetch('long_term_goals', 'id,updated_at'))
        r['id'] as String: r['updated_at'] as String?,
    };
    final existingLogs = {
      for (final r in await fetch('goal_logs', 'id,goal_id,date,updated_at'))
        '${r['goal_id']}|${r['date']}': r,
    };
    final existingMoods = {
      for (final r in await fetch('daily_moods', 'id,date,updated_at'))
        r['date'] as String: r,
    };

    // Build the whole plan with NO writes — validate-before-delete.
    final plan = planCloudImport(
      userId: userId,
      canonical: canonical,
      replaceExisting: replaceExisting,
      now: now,
      existingCategories: existingCategories,
      existingGoals: existingGoals,
      existingMacros: existingMacros,
      existingLogs: existingLogs,
      existingMoods: existingMoods,
      newId: () => _uuid.v4(),
    );

    // Fill archived_at on existing categories — bare update, no updated_at
    // (the cloud macro_goal_categories table has no such column).
    for (final f in plan.categoryArchiveFills) {
      await client
          .from('macro_goal_categories')
          .update({'archived_at': f.archivedAt})
          .eq('id', f.id);
    }

    // Write parents before children so foreign keys resolve. In REPLACE mode we
    // upsert the backup rows FIRST and only AFTERWARDS delete the rows the backup
    // doesn't contain — so a mid-import failure (network drop, RLS error, app
    // kill) leaves a superset (a few stale rows), never an emptied account.
    // The previous order deleted everything first, so any failure before the
    // re-insert wiped the data with no client-side transaction to roll it back.
    // The plan reuses existing row ids for updates and drops intra-file
    // duplicates, so conflicting on `id` can never trip the secondary UNIQUE
    // constraints (goal_logs (goal_id,date), daily_moods (user_id,date)).
    await _bulkUpsert(client, 'macro_goal_categories', plan.categories);
    await _bulkUpsert(client, 'goals', plan.goals);
    await _bulkUpsert(client, 'long_term_goals', plan.macros);
    await _bulkUpsert(client, 'goal_logs', plan.logs);
    await _bulkUpsert(client, 'daily_moods', plan.moods);

    if (replaceExisting) {
      // Remove this user's rows that aren't part of the backup, children before
      // parents so foreign keys resolve. Each table is pruned to exactly the
      // backup's rows without ever passing through an empty state.
      await _deleteComplement(client, 'goal_logs', userId, plan.logs);
      await _deleteComplement(client, 'daily_moods', userId, plan.moods);
      await _deleteComplement(client, 'long_term_goals', userId, plan.macros);
      await _deleteComplement(client, 'goals', userId, plan.goals);
      await _deleteComplement(
        client,
        'macro_goal_categories',
        userId,
        plan.categories,
      );
    }

    await _recomputeCloudStreaks(client, userId, plan.affectedGoals);

    // Restore the profile last, under a conservative allow-list (identity and
    // entitlement columns are never overwritten). ONLY on a REPLACE import: a
    // MERGE brings the file in alongside the live profile and must not silently
    // overwrite the active user's name/DOB (mobile parity — see the private-mode
    // path in DesktopPrivateDb.applyImport).
    final profile = canonical[kProfileKey];
    if (replaceExisting && profile is Map) {
      final updates = <String, dynamic>{};
      for (final col in _cloudProfileImportColumns) {
        if (profile[col] != null) updates[col] = profile[col];
      }
      if (updates.isNotEmpty) {
        updates['id'] = userId;
        await client.from('profiles').upsert(updates, onConflict: 'id');
      }
    }

    return plan.stats;
  }

  /// Deletes the user's rows in [table] whose id is NOT among the just-upserted
  /// backup rows [keep]. Fetches the existing ids and deletes only the
  /// difference (in id chunks), so replacing never empties the table first — the
  /// atomicity guarantee the delete-then-upsert order lacked.
  ///
  /// The id read is windowed: the complement is only as complete as the set it
  /// is computed against, so a single capped read would silently leave every
  /// row past the cap in place — the opposite of what Replace promises.
  Future<void> _deleteComplement(
    SupabaseClient client,
    String table,
    String userId,
    List<Map<String, dynamic>> keep,
  ) async {
    final keepIds = keep.map((r) => r['id'] as String).toSet();
    final existing = await fetchAllRowsPaginated((offset, limit) async {
      final res = await client
          .from(table)
          .select('id')
          .eq('user_id', userId)
          .order('id')
          .range(offset, offset + limit - 1);
      return (res as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    });
    final toDelete = existing
        .map((r) => r['id'] as String)
        .where((id) => !keepIds.contains(id))
        .toList();
    if (toDelete.isEmpty) return;
    const chunk = 200;
    for (var i = 0; i < toDelete.length; i += chunk) {
      final end = (i + chunk < toDelete.length) ? i + chunk : toDelete.length;
      await client
          .from(table)
          .delete()
          .eq('user_id', userId)
          .inFilter('id', toDelete.sublist(i, end));
    }
  }

  /// Chunked bulk upsert (Supabase caps request sizes around ~1000 rows).
  Future<void> _bulkUpsert(
    SupabaseClient client,
    String table,
    List<Map<String, dynamic>> rows, {
    String onConflict = 'id',
  }) async {
    if (rows.isEmpty) return;
    const chunk = 500;
    for (var i = 0; i < rows.length; i += chunk) {
      final end = (i + chunk < rows.length) ? i + chunk : rows.length;
      await client
          .from(table)
          .upsert(rows.sublist(i, end), onConflict: onConflict);
    }
  }

  /// Recomputes `goal_logs.streak` over the merged history for [goalIds] and
  /// writes back the rows that changed. Best-effort: a failure here never fails
  /// the import (the data landed; only the denormalized streak may be stale).
  ///
  /// Bounded network cost: two reads (start dates + all affected logs) and one
  /// chunked bulk upsert of the changed rows — not one UPDATE per log.
  Future<void> _recomputeCloudStreaks(
    SupabaseClient client,
    String userId,
    Set<String> goalIds,
  ) async {
    if (goalIds.isEmpty) return;
    try {
      final ids = goalIds.toList();

      // Left unpaginated on purpose: this read is bounded by `ids` (the
      // affected-goals list), not a user-wide scan, so it returns at most one
      // row per affected goal — well under the row cap. Mirrors the mobile fix,
      // which intentionally left its equivalent `goals` read unwindowed too.
      final goalRes = await client
          .from('goals')
          .select('id,start_date')
          .inFilter('id', ids);
      final startById = {
        for (final r in (goalRes as List).map(
          (e) => (e as Map).cast<String, dynamic>(),
        ))
          r['id'] as String:
              DateTime.tryParse((r['start_date'] as String?) ?? '') ??
              DateTime(2000),
      };

      // Windowed: a streak computed from a truncated history is wrong, and it
      // gets written back over the correct value — so the full log set for the
      // affected goals has to be read past the row cap.
      final logRes = await fetchAllRowsPaginated((offset, limit) async {
        final res = await client
            .from('goal_logs')
            .select()
            .inFilter('goal_id', ids)
            .order('id')
            .range(offset, offset + limit - 1);
        return (res as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      });
      final byGoal = <String, List<Map<String, dynamic>>>{};
      for (final r in logRes) {
        (byGoal[r['goal_id'] as String] ??= []).add(r);
      }

      final changed = <Map<String, dynamic>>[];
      for (final goalId in ids) {
        final rows = byGoal[goalId] ?? const [];
        final startDate = startById[goalId] ?? DateTime(2000);
        final map = <String, Map<String, String>>{};
        final dateByRow = <Map<String, dynamic>, DateTime>{};
        for (final r in rows) {
          final d = DateTime.tryParse(r['date'] as String);
          if (d == null) continue;
          final key =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          (map[key] ??= <String, String>{})[goalId] = r['status'] as String;
          dateByRow[r] = d;
        }
        for (final r in rows) {
          final d = dateByRow[r];
          if (d == null) continue;
          final newStreak = computeStreak(
            habitId: goalId,
            date: d,
            logs: map,
            startDate: startDate,
          );
          if (newStreak != ((r['streak'] as num?)?.toInt() ?? 0)) {
            changed.add({...r, 'streak': newStreak});
          }
        }
      }

      await _bulkUpsert(client, 'goal_logs', changed);
    } catch (e, s) {
      AppLogger.warning('[Import] cloud streak recompute failed', e, s);
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
