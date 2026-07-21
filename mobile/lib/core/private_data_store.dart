import '../models/goal.dart';
import '../models/macro_goal.dart';
import '../models/daily_mood.dart';
import 'import_merge_stats.dart';

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

  /// Persists a reordered list of goals atomically (one transaction). Used by
  /// drag-reorder so a partial failure can't leave `display_order` half-applied.
  Future<void> reorderGoals(List<Goal> goals);

  Future<void> deleteGoal(String id);

  Future<Map<String, Map<String, String>>> loadHabitLogs();

  Future<void> setHabitLog({
    required String goalId,
    required String date,
    required String status,
    int streak = 0,
    double? value,
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

  /// Every SYNCED setting for the local owner, as canonical
  /// `PrivateDbSchema.syncedSettingKeys` -> string value.
  ///
  /// Backed by the shared `SyncedSettingsStore`, so the per-key `user_settings`
  /// record wins over the legacy `profiles` column and both apps read the value
  /// through exactly one parser. Keys absent from both stores are OMITTED, which
  /// is what lets the caller tell "never set" from "set to null" and apply its
  /// own default.
  Future<Map<String, String?>> loadSyncedSettings();

  /// Writes ONLY [values] — one independent record per key.
  ///
  /// The old whole-row write coupled every setting's fate: touching one toggle
  /// re-stamped all ~20 columns, so a stale in-memory value (or a plain default
  /// seeded before the async load resolved) silently overwrote settings the user
  /// had set on another device. Per-key writes make that structurally impossible.
  ///
  /// Throws [ArgumentError] for a key outside `PrivateDbSchema.syncedSettingKeys`
  /// — device-local settings must not travel through here.
  Future<void> writeSyncedSettings(Map<String, String?> values);

  Future<bool> hasPrivateAiExternalConsent();

  Future<void> setPrivateAiExternalConsent(bool value);

  Future<Map<String, dynamic>> exportData();

  /// Imports [backupData] (already normalized to canonical shape by
  /// [normalizeBackup]) either by replacing existing data or by a true
  /// identity-based merge. Returns the per-entity add/update/unchanged counts.
  Future<ImportMergeStats> importData({
    required Map<String, dynamic> backupData,
    required bool replaceExisting,
  });

  Future<void> deleteAllPrivateData();

  /// Whether the encrypted private database is in the recoverable *locked*
  /// state — the file exists on disk but its key is unreadable from the
  /// Keychain, so opening it would throw `PrivateDatabaseLockedException`. See
  /// `PrivateLocalDatabase.isDatabaseLocked`.
  Future<bool> isDatabaseLocked();

  /// Deletes the orphaned encrypted database file (+ sidecars + avatar folder)
  /// so the next open mints a fresh key over an empty schema. DESTRUCTIVE —
  /// only behind an explicit, user-confirmed recovery action. See
  /// `PrivateLocalDatabase.resetLockedDatabase`.
  Future<void> resetLockedDatabase();

  /// Auto-recovery: renames the locked DB (+ sidecars) ASIDE to a `.bak` set
  /// (instead of deleting) and clears the unreadable key, so a fresh empty DB
  /// can be re-pulled from iCloud. Reversible via [restoreStashedDatabase] if
  /// the pull doesn't actually run. Returns true if a DB file was stashed.
  /// Never throws. See `PrivateLocalDatabase.stashLockedDatabase`.
  Future<bool> stashLockedDatabase();

  /// Undo [stashLockedDatabase]: discards the fresh (empty) DB and restores the
  /// stashed copy, leaving it LOCKED again so a later launch retries recovery.
  /// Never throws.
  Future<void> restoreStashedDatabase();

  /// Commit [stashLockedDatabase]: the cloud re-pull succeeded, so delete the
  /// stashed `.bak` set for good. Never throws.
  Future<void> discardStashedDatabase();

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
