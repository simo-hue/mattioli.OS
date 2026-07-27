import '../models/goal.dart';
import '../models/macro_goal.dart';
import '../models/daily_mood.dart';
import 'import_merge_stats.dart';
import 'macro_goal_calendar.dart';

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

  /// Every `goal_progress` row for the local owner as `date -> goalId -> amount`
  /// — the accumulated number for a quantitative habit-day. Parallel to
  /// [loadHabitLogs] (which loads the verdict) and deliberately separate: a
  /// partial day has a progress number but no log row, and the two tables are
  /// read, written and synced independently.
  Future<Map<String, Map<String, double>>> loadHabitProgress();

  /// Upserts the accumulated [amount] for a habit-day. [source] is the fill
  /// source's wire name (always `'manual'` in v1 — a measured target's number
  /// comes from the verification pipeline, never from this table). Uses the
  /// deterministic `goal_progress` id so two devices cannot mint rival rows.
  Future<void> setHabitProgress({
    required String goalId,
    required String date,
    required double amount,
    String source,
  });

  /// Removes a habit-day's progress row (the number returned to zero, or the
  /// habit's target was cleared). Separate from clearing the verdict — the
  /// caller updates the `goal_logs` row through its own path.
  Future<void> deleteHabitProgress({
    required String goalId,
    required String date,
  });

  Future<List<MacroGoal>> loadMacroGoals();

  /// Sum of a linked habit's `goal_progress.amount` over [range] (null ⇒ all
  /// history) — the derived current progress of a LINKED cumulative macro goal.
  /// The display path calls this for each linked numeric goal; the delete-time
  /// snapshot uses the same underlying query, so the two can never disagree.
  Future<double> linkedHabitProgressSum(
    String habitId,
    MacroGoalDateRange? range,
  );

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

  /// The avatar file path RESOLVED against this device's current container, or
  /// null when there is no readable avatar.
  ///
  /// Deliberately not `loadProfileRow()['avatar_url']`. That column stores an
  /// ABSOLUTE path, and a container path is not a stable identifier — iOS
  /// regenerates it across reinstalls. Rendering the stored value raw is what
  /// showed the default avatar in place of the user's photo while the image was
  /// still on disk.
  Future<String?> resolveAvatarPath();

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

  /// Whether a `.recovery-bak` stash is present on disk.
  ///
  /// A stash is only ever meant to exist DURING one recovery attempt, which
  /// ends by either discarding or restoring it. Finding one at entry therefore
  /// means a previous attempt was interrupted (quit, crash, OS termination)
  /// between the two, and the user's real database is sitting in a file nothing
  /// else ever looks at.
  Future<bool> hasStashedDatabase();

  /// Commit [stashLockedDatabase]: the cloud re-pull succeeded, so delete the
  /// stashed `.bak` set for good. Never throws.
  Future<void> discardStashedDatabase();

  /// Permanently destroys every retained `.locked-*` aside copy and its parked
  /// key. The ONLY operation in the app allowed to destroy private ciphertext —
  /// call it from actions that PROMISE deletion, never from a recovery.
  Future<void> deleteLockedAsideCopy();

  /// Size of the encrypted database on disk, or null when there is none.
  /// Surfaced in the reset confirmation so the user is told what they are about
  /// to displace rather than agreeing to an abstraction.
  Future<int?> databaseSizeBytes();

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
