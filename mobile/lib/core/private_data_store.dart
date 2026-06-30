import '../models/goal.dart';
import '../models/macro_goal.dart';
import '../models/daily_mood.dart';

/// Abstraction over the on-device Private-mode store.
///
/// Every mode-aware provider, in its `private` branch, talks to the store
/// exclusively through this interface (via `privateLocalDatabaseProvider`) and
/// returns BEFORE any Supabase call. Extracting the interface lets tests swap
/// in a fake to prove that Private-mode CRUD never reaches the network — see
/// `test/private_mode_no_supabase_test.dart`.
///
/// The concrete implementation is [PrivateLocalDatabase] (a SQLCipher-backed
/// local database). This declares EXACTLY the public methods reachable through
/// `privateLocalDatabaseProvider`; the concrete class has additional members
/// (e.g. `setHabitLogWithStreak`, used directly by the notification isolate)
/// that are intentionally not part of this surface.
abstract interface class PrivateDataStore {
  Future<String> ownerId();

  Future<void> ensureReady();

  Future<List<Goal>> loadGoals();

  Future<void> upsertGoal(Goal goal);

  Future<void> deleteGoal(String id);

  Future<Map<String, Map<String, String>>> loadHabitLogs();

  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int streak = 0,
  });

  Future<void> deleteHabitLog({
    required String goalId,
    required String date,
  });

  Future<List<MacroGoal>> loadMacroGoals();

  Future<void> upsertMacroGoal(MacroGoal goal);

  Future<void> deleteMacroGoal(String id);

  Future<List<GoalCategory>> loadMacroGoalCategories({
    bool includeArchived = false,
  });

  Future<String> addMacroGoalCategory(String name, String colorHex);

  Future<void> updateMacroGoalCategory(
    String id,
    String name,
    String colorHex,
  );

  Future<void> archiveMacroGoalCategory(String id);

  Future<Map<String, DailyMood>> loadDailyMoods();

  Future<DailyMood> saveMood(DateTime date, int mood, int energy);

  Future<Map<String, dynamic>> loadProfileRow();

  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? dateOfBirth,
    bool clearDateOfBirth = false,
  });

  Future<Map<String, dynamic>> loadSettingsRow();

  Future<void> updateSettingsRow(Map<String, Object?> values);

  Future<bool> hasPrivateAiExternalConsent();

  Future<void> setPrivateAiExternalConsent(bool value);

  Future<Map<String, dynamic>> exportData();

  Future<void> importData({
    required Map<String, dynamic> backupData,
    required bool replaceExisting,
  });

  Future<void> deleteAllPrivateData();

  Future<List<Map<String, dynamic>>> habitStats();

  Future<Map<String, Map<String, dynamic>>> habitAnalytics();

  Future<String> globalCriticalDay();

  Future<List<Map<String, dynamic>>> globalTrend(String timeframe);

  Future<List<Map<String, dynamic>>> criticalHabits();

  Future<List<Map<String, dynamic>>> bestHabits(String timeframe);

  Future<List<Map<String, dynamic>>> habitPerformanceByDay(String goalId);

  Future<Map<String, dynamic>> habitAlerts(String goalId);

  Future<List<int>> habitYearlyGrid(String goalId);

  Future<List<Map<String, dynamic>>> habitCorrelations(String targetGoalId);

  Future<List<Map<String, dynamic>>> allHabitCorrelations();

  Future<Map<String, dynamic>> macroGoalsStats(String year);
}
