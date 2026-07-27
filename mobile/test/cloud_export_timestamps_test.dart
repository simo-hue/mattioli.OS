import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/import_merge.dart';

/// Phase 0 finding #4.
///
/// The Account-mode export serialised habits, macro goals and moods through the
/// in-memory MODELS (`Goal.toJson()` / `MacroGoal.toJson()` / a hand-built mood
/// map). None of those emit `updated_at` — `Goal` has no such field at all — and
/// `incomingWins` treats a null incoming timestamp as OLDEST. So on the DEFAULT
/// Merge import every record whose id already existed was skipped as
/// "unchanged": a same-account export-then-restore was a total no-op for those
/// three entities, while logs and progress (raw rows, real timestamps) merged
/// normally. A user who restored a backup to undo an edit got the mixed state —
/// a habit reverted to Checkbox still owning its `goal_progress` numbers — and a
/// summary that said "unchanged".
void main() {
  const userId = 'u1';

  CloudImportPlan planWith(Map<String, dynamic> habit) => planCloudImport(
        userId: userId,
        canonical: {
          kGoalsKey: [habit],
          kLogsKey: const [],
          kMacrosKey: const [],
          kCategoriesKey: const [],
          kMoodsKey: const [],
        },
        replaceExisting: false, // Merge — the pre-selected mode
        now: '2026-07-27T00:00:00.000Z',
        existingCategories: const [],
        // The account already holds this habit, edited AFTER the backup.
        existingGoals: const {'h1': '2026-07-20T00:00:00.000Z'},
        existingMacros: const {},
        existingLogs: const {},
        existingMoods: const {},
        newId: () => 'generated',
      );

  Map<String, dynamic> habitRow({String? updatedAt}) => {
        'id': 'h1',
        'title': 'Push-ups',
        'color': '#3B82F6',
        'start_date': '2026-07-01T00:00:00.000Z',
        'target': '{"v":1,"dir":"atLeast","amount":80}',
        'updated_at': ?updatedAt,
      };

  test('a row WITHOUT updated_at is silently skipped on Merge', () {
    // Documents the mechanism the export used to trip. Not a bug in the planner
    // — with no timestamp there is nothing to compare, so skipping is the only
    // safe answer. The bug was feeding it timestamp-less rows.
    final plan = planWith(habitRow());
    expect(plan.goals, isEmpty,
        reason: 'nothing is written back, so the restore is a no-op');
    expect(plan.stats.habits.unchanged, 1,
        reason: 'and it is reported to the user as "unchanged"');
  });

  test('a row WITH a newer updated_at is written back', () {
    final plan = planWith(habitRow(updatedAt: '2026-07-26T00:00:00.000Z'));
    expect(plan.goals, hasLength(1),
        reason: 'the backup is newer than the server row, so it must restore');
    expect(plan.goals.single['target'], isNotNull,
        reason: 'and the target must survive — the field the user lost');
  });

  test('the cloud export reads raw table rows, not model toJson()', () {
    // The behavioural tests above cannot see WHERE the export gets its rows, and
    // that is precisely what regressed. The export lives in a widget callback
    // behind a Supabase client, so a source assertion is the honest instrument —
    // same approach as schema_drift_test and the desktop privacy guard.
    final file = File('${_repoRoot().path}/mobile/lib/ui/screens/privacy_settings_screen.dart');
    expect(file.existsSync(), isTrue);
    final src = file.readAsStringSync();

    // Isolate the exported payload literal.
    final habitsLine = RegExp(r"'habits':\s*([^,\n]*)").firstMatch(src);
    final macrosLine = RegExp(r"'macroGoals':\s*([^,\n]*)").firstMatch(src);
    final moodsLine = RegExp(r"'dailyMoods':\s*([^,\n]*)").firstMatch(src);

    for (final entry in {
      'habits': habitsLine,
      'macroGoals': macrosLine,
      'dailyMoods': moodsLine,
    }.entries) {
      expect(entry.value, isNotNull,
          reason: 'could not find the ${entry.key} key in the export payload');
      final value = entry.value!.group(1)!;
      expect(
        value.contains('toJson'),
        isFalse,
        reason: 'the export serialises ${entry.key} through a model toJson(), '
            'which emits no updated_at — a Merge re-import will silently skip '
            'every one of these records. Read the table instead. Found: '
            '${value.trim()}',
      );
    }
  });
}

Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/mobile').existsSync() &&
        Directory('${dir.path}/desktop').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Could not locate the repo root from ${Directory.current.path}');
}
