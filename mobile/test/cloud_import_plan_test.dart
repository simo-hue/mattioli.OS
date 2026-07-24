// Unit tests for planCloudImport (lib/core/import_merge.dart) — the pure,
// network-free decision layer of the Cloud (Supabase) import. Every confirmed
// cloud blocker lived here: the phantom `updated_at` category column, and the
// LWW / dedup decisions. Being pure, it needs no Supabase.
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/import_merge.dart';

void main() {
  const now = '2026-06-01T00:00:00.000Z';
  var idc = 0;
  String newId() => 'gen-${idc++}';

  Map<String, dynamic> canonical({
    List<Map<String, dynamic>> cats = const [],
    List<Map<String, dynamic>> goals = const [],
    List<Map<String, dynamic>> macros = const [],
    List<Map<String, dynamic>> logs = const [],
    List<Map<String, dynamic>> moods = const [],
  }) => {
    kCategoriesKey: cats,
    kGoalsKey: goals,
    kMacrosKey: macros,
    kLogsKey: logs,
    kMoodsKey: moods,
  };

  CloudImportPlan plan({
    required Map<String, dynamic> data,
    bool replace = false,
    List<Map<String, dynamic>> existingCategories = const [],
    Map<String, String?> existingGoals = const {},
    Map<String, String?> existingMacros = const {},
    Map<String, Map<String, dynamic>> existingLogs = const {},
    Map<String, Map<String, dynamic>> existingMoods = const {},
  }) => planCloudImport(
    userId: 'u',
    canonical: data,
    replaceExisting: replace,
    now: now,
    existingCategories: existingCategories,
    existingGoals: existingGoals,
    existingMacros: existingMacros,
    existingLogs: existingLogs,
    existingMoods: existingMoods,
    newId: newId,
  );

  test('#1: a new category row carries NO updated_at column', () {
    final p = plan(
      data: canonical(cats: [
        {'id': 'c1', 'name': 'Health', 'color': '#10B981'},
      ]),
      replace: true,
    );
    expect(p.categories.single.containsKey('updated_at'), isFalse,
        reason: 'cloud macro_goal_categories has no updated_at column');
    expect(p.categories.single['id'], 'c1');
    expect(p.stats.categories.added, 1);
  });

  test('existing category matched by name → macro remapped, no new category',
      () {
    final p = plan(
      data: canonical(
        cats: [
          {'id': 'c2', 'name': 'health', 'color': '#123456'},
        ],
        macros: [
          {'id': 'm1', 'title': 'Fit', 'status': 'active', 'type': 'annual', 'category_id': 'c2'},
        ],
      ),
      existingCategories: [
        {'id': 'c1', 'name': 'Health', 'archived_at': null},
      ],
    );
    expect(p.categories, isEmpty, reason: 'same-name category deduped');
    expect(p.stats.categories.unchanged, 1);
    expect(p.macros.single['category_id'], 'c1', reason: 'remapped onto existing');
  });

  test('archived-at fill is a bare update, not a category write', () {
    final p = plan(
      data: canonical(cats: [
        {'id': 'c1', 'name': 'Health', 'color': '#1', 'archived_at': '2026-05-01T00:00:00.000Z'},
      ]),
      existingCategories: [
        {'id': 'c1', 'name': 'Health', 'archived_at': null},
      ],
    );
    expect(p.categories, isEmpty);
    expect(p.categoryArchiveFills.single.id, 'c1');
    expect(p.categoryArchiveFills.single.archivedAt, '2026-05-01T00:00:00.000Z');
    expect(p.stats.categories.updated, 1);
  });

  test('LWW: newer goal is written as an update, older is skipped', () {
    final newer = plan(
      data: canonical(goals: [
        {'id': 'g1', 'title': 'New', 'color': '#1', 'start_date': '2026-01-01', 'updated_at': '2026-02-01T00:00:00.000Z'},
      ]),
      existingGoals: {'g1': '2026-01-01T00:00:00.000Z'},
    );
    expect(newer.goals.length, 1);
    expect(newer.stats.habits.updated, 1);

    final older = plan(
      data: canonical(goals: [
        {'id': 'g1', 'title': 'Old', 'color': '#1', 'start_date': '2026-01-01', 'updated_at': '2025-01-01T00:00:00.000Z'},
      ]),
      existingGoals: {'g1': '2026-01-01T00:00:00.000Z'},
    );
    expect(older.goals, isEmpty);
    expect(older.stats.habits.unchanged, 1);
  });

  test('intra-file duplicate new logs (same goal_id,date) are deduped', () {
    final p = plan(
      data: canonical(
        goals: [
          {'id': 'g1', 'title': 'G', 'color': '#1', 'start_date': '2026-01-01', 'updated_at': now},
        ],
        logs: [
          {'id': 'a', 'goal_id': 'g1', 'date': '2026-01-01', 'status': 'done'},
          {'id': 'b', 'goal_id': 'g1', 'date': '2026-01-01', 'status': 'missed'},
        ],
      ),
      replace: true,
    );
    expect(p.logs.length, 1,
        reason: 'second (g1,2026-01-01) dropped to avoid UNIQUE(goal_id,date)');
    expect(p.stats.logs.added, 1);
  });

  test('replace mode (no existing state) counts everything as added', () {
    final p = plan(
      data: canonical(
        goals: [
          {'id': 'g1', 'title': 'G', 'color': '#1', 'start_date': '2026-01-01', 'updated_at': now},
        ],
        moods: [
          {'id': 'd1', 'date': '2026-01-01', 'mood_score': 5, 'energy_score': 5},
        ],
      ),
      replace: true,
    );
    expect(p.stats.habits.added, 1);
    expect(p.stats.moods.added, 1);
    expect(p.stats.habits.updated, 0);
  });

  test('verification columns (single + compound) survive the cloud plan', () {
    // Regression: the cloud upsert row must carry the verification rule, or a
    // cloud-mode import silently strips auto-verification from every habit.
    final p = plan(
      data: canonical(goals: [
        {
          'id': 'gsingle',
          'title': 'Steps',
          'color': '#3B82F6',
          'start_date': '2026-01-01',
          'updated_at': now,
          'verify_provider': 'healthkit',
          'verify_metric': 'steps',
          'verify_comparator': 'gte',
          'verify_threshold': 10000,
          'verify_unit': 'count',
          'verify_effective_from': '2026-06-15',
        },
        {
          'id': 'gcompound',
          'title': 'Move',
          'color': '#3B82F6',
          'start_date': '2026-01-01',
          'updated_at': now,
          // Compound: flat columns null, the JSON blob carries the conditions.
          'verify_conditions':
              '{"v":1,"op":"and","conditions":[{"provider":"healthkit","metric":"steps","comparator":"gte","threshold":10000,"unit":"count"},{"provider":"healthkit","metric":"exercise_minutes","comparator":"gte","threshold":30,"unit":"minutes"}]}',
        },
      ]),
      replace: true,
    );

    final single = p.goals.firstWhere((g) => g['id'] == 'gsingle');
    expect(single['verify_metric'], 'steps');
    expect(single['verify_threshold'], 10000);
    expect(single['verify_effective_from'], '2026-06-15');

    final compound = p.goals.firstWhere((g) => g['id'] == 'gcompound');
    expect(compound['verify_conditions'], isNotNull);
    expect(compound['verify_provider'], isNull);
  });
}
