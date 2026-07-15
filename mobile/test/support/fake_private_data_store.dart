// Shared test double for [PrivateDataStore].
//
// Several tests need to swap the real on-device Private-mode store for a fake
// that (a) returns sensible empties for every read a provider performs while
// building, and (b) records every WRITE so the test can assert what was
// persisted locally. This used to be copy-pasted into each test as a private
// `_FakePrivateDataStore`; it now lives here as a single reusable
// [FakePrivateDataStore] so the 37-method surface is maintained in one place.
//
// Design notes:
//   * Reads return harmless empties (`[]` / `{}` / `''`) so any mode-aware
//     provider can complete its async `build()` without throwing.
//   * Writes append their method name to [calls] and return sensible values.
//   * Analytics methods also return empties (rather than throwing) so the fake
//     is broadly reusable across analytics-touching tests.
//
// The whole point of the tests that use this fake is what they deliberately do
// NOT do: they never call `Supabase.initialize`. So any code path that reached
// for `Supabase.instance` would throw. Driving CRUD through this fake proves
// Private-mode writes stay entirely on-device.

import 'package:mattioli_os/core/import_merge_stats.dart';
import 'package:mattioli_os/core/private_data_store.dart';
import 'package:mattioli_os/models/daily_mood.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/models/macro_goal.dart';

/// A reusable [PrivateDataStore] fake that records writes into [calls] and
/// returns empties for reads. See the file header for the rationale.
class FakePrivateDataStore implements PrivateDataStore {
  /// Names of every WRITE method invoked, in call order. Tests assert that the
  /// expected local write happened, e.g. `expect(fake.calls, contains('upsertGoal'))`.
  final List<String> calls = <String>[];

  // ── Identity / lifecycle ────────────────────────────────────────────────
  @override
  Future<String> ownerId() async => 'fake';

  @override
  Future<void> ensureReady() async {
    calls.add('ensureReady');
  }

  // ── Goals ───────────────────────────────────────────────────────────────
  @override
  Future<List<Goal>> loadGoals() async => <Goal>[];

  @override
  Future<void> upsertGoal(Goal goal) async {
    calls.add('upsertGoal');
  }

  @override
  Future<void> reorderGoals(List<Goal> goals) async {
    calls.add('reorderGoals');
  }

  @override
  Future<void> deleteGoal(String id) async {
    calls.add('deleteGoal');
  }

  // ── Habit logs ──────────────────────────────────────────────────────────
  @override
  Future<Map<String, Map<String, String>>> loadHabitLogs() async =>
      <String, Map<String, String>>{};

  @override
  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int streak = 0,
    double? value,
  }) async {
    calls.add('setHabitLog');
  }

  @override
  Future<void> deleteHabitLog({
    required String goalId,
    required String date,
  }) async {
    calls.add('deleteHabitLog');
  }

  // ── Macro goals ─────────────────────────────────────────────────────────
  @override
  Future<List<MacroGoal>> loadMacroGoals() async => <MacroGoal>[];

  @override
  Future<void> upsertMacroGoal(MacroGoal goal) async {
    calls.add('upsertMacroGoal');
  }

  @override
  Future<void> deleteMacroGoal(String id) async {
    calls.add('deleteMacroGoal');
  }

  // ── Macro goal categories ───────────────────────────────────────────────
  @override
  Future<List<GoalCategory>> loadMacroGoalCategories({
    bool includeArchived = false,
  }) async =>
      <GoalCategory>[];

  @override
  Future<String> addMacroGoalCategory(String name, String colorHex) async {
    calls.add('addMacroGoalCategory');
    return 'fake-category-id';
  }

  @override
  Future<void> updateMacroGoalCategory(
    String id,
    String name,
    String colorHex,
  ) async {
    calls.add('updateMacroGoalCategory');
  }

  @override
  Future<void> archiveMacroGoalCategory(String id) async {
    calls.add('archiveMacroGoalCategory');
  }

  // ── Moods ───────────────────────────────────────────────────────────────
  @override
  Future<Map<String, DailyMood>> loadDailyMoods() async =>
      <String, DailyMood>{};

  @override
  Future<DailyMood> saveMood(DateTime date, int mood, int energy) async {
    calls.add('saveMood');
    return DailyMood(
      id: 'fake',
      userId: 'fake',
      date: '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
      moodScore: mood,
      energyScore: energy,
    );
  }

  // ── Profile ─────────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> loadProfileRow() async =>
      <String, dynamic>{'id': 'fake'};

  @override
  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? dateOfBirth,
    bool clearDateOfBirth = false,
  }) async {
    calls.add('updateProfile');
  }

  // ── Settings ────────────────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> loadSettingsRow() async =>
      <String, dynamic>{'id': 'fake'};

  @override
  Future<void> updateSettingsRow(Map<String, Object?> values) async {
    calls.add('updateSettingsRow');
  }

  // ── Privacy / consent ───────────────────────────────────────────────────
  @override
  Future<bool> hasPrivateAiExternalConsent() async => false;

  @override
  Future<void> setPrivateAiExternalConsent(bool value) async {
    calls.add('setPrivateAiExternalConsent');
  }

  // ── Import / export / wipe ──────────────────────────────────────────────
  @override
  Future<ImportMergeStats> importData({
    required Map<String, dynamic> backupData,
    bool replaceExisting = false,
  }) async {
    calls.add('importData');
    return ImportMergeStats(replaced: replaceExisting);
  }

  @override
  Future<Map<String, dynamic>> exportData() async => <String, dynamic>{};

  @override
  Future<void> deleteAllPrivateData() async {
    calls.add('deleteAllPrivateData');
  }

  /// Simulated lock state for recovery-flow tests; defaults to unlocked.
  bool locked = false;

  @override
  Future<bool> isDatabaseLocked() async {
    calls.add('isDatabaseLocked');
    return locked;
  }

  @override
  Future<void> resetLockedDatabase() async {
    calls.add('resetLockedDatabase');
    locked = false;
  }

  /// Whether a locked DB is currently stashed aside (recovery in progress).
  bool stashed = false;

  @override
  Future<bool> stashLockedDatabase() async {
    calls.add('stashLockedDatabase');
    stashed = true;
    locked = false;
    return true;
  }

  @override
  Future<void> restoreStashedDatabase() async {
    calls.add('restoreStashedDatabase');
    stashed = false;
    locked = true;
  }

  @override
  Future<void> discardStashedDatabase() async {
    calls.add('discardStashedDatabase');
    stashed = false;
  }

  // ── Analytics (return harmless empties so the fake stays reusable) ───────
  @override
  Future<List<Map<String, dynamic>>> habitStats() async =>
      <Map<String, dynamic>>[];

  @override
  Future<Map<String, Map<String, dynamic>>> habitAnalytics() async =>
      <String, Map<String, dynamic>>{};

  @override
  Future<String> globalCriticalDay() async => '';

  @override
  Future<List<Map<String, dynamic>>> globalTrend(String timeframe) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> criticalHabits() async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> bestHabits(String timeframe) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> habitPerformanceByDay(
    String goalId,
  ) async =>
      <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> habitAlerts(String goalId) async =>
      <String, dynamic>{};

  @override
  Future<List<int>> habitYearlyGrid(String goalId) async => <int>[];

  @override
  Future<List<Map<String, dynamic>>> habitCorrelations(
    String targetGoalId,
  ) async =>
      <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> allHabitCorrelations() async =>
      <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> macroGoalsStats(String year) async =>
      <String, dynamic>{};
}
