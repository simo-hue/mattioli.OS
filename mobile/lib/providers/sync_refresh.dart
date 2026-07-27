import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'goal_provider.dart';
import 'macro_goal_categories_provider.dart';
import 'macro_goals_provider.dart';
import 'macro_goals_stats_provider.dart';
import 'mood_provider.dart';
import 'settings_provider.dart';
import 'shared_prefs_provider.dart';
import 'user_provider.dart';

/// Reactive mirror of the per-device "iCloud sync enabled" flag. The flag is a
/// plain SharedPreferences bool the sync service writes (`enable`/`disable`);
/// reading it directly inside `build()` is NOT reactive (the SharedPreferences
/// instance identity never changes), so widgets that must reflect the toggle —
/// e.g. the data-loss `SyncOffBanner` — watch THIS provider instead and the
/// toggle sites call [refreshSyncEnabled] to force a rebuild. Keyed identically
/// to `PrefsSyncEnabledStore._key` in the evolve_sync package.
const String kSyncEnabledPrefKey = 'private_sync_enabled_v1';

final syncEnabledProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return prefs.getBool(kSyncEnabledPrefKey) ?? false;
});

/// Re-read [syncEnabledProvider] after sync has been enabled/disabled so any
/// widget watching it rebuilds. Call from every site that toggles sync.
void refreshSyncEnabled(WidgetRef ref) => ref.invalidate(syncEnabledProvider);

/// Invalidate the in-memory private-data providers after a sync applied remote
/// changes, so the UI reflects the pulled data. The sync engine writes straight
/// to the local DB; these providers cache in memory and won't otherwise notice.
/// Mirrors the invalidation the delete/reset flow performs.
void invalidatePrivateDataProviders(WidgetRef ref) {
  ref.invalidate(goalsProvider);
  ref.invalidate(habitLogsProvider);
  // Quantitative-target progress. Its absence here was a DATA-LOSS bug, not a
  // stale-UI one: `goal_progress` rows pulled by the sync engine (or written by
  // a backup import) never reached the in-memory map, and the next foreground
  // `reconcileManualTargets` read that stale map, saw no entry for a limit
  // habit's day, resolved it as a quiet success, and wrote amount 0 — which
  // DELETES the row and tombstones the deletion to CloudKit. A breach recorded
  // on the Mac silently became a success everywhere.
  ref.invalidate(habitProgressProvider);
  ref.invalidate(habitStatsProvider);
  ref.invalidate(habitAnalyticsProvider);
  ref.invalidate(globalCriticalDayProvider);
  ref.invalidate(globalTrendProvider);
  ref.invalidate(criticalHabitsProvider);
  ref.invalidate(bestHabitsProvider);
  ref.invalidate(habitPerformanceProvider);
  ref.invalidate(habitAlertsProvider);
  ref.invalidate(habitYearlyGridProvider);
  ref.invalidate(habitCorrelationsProvider);
  ref.invalidate(allHabitCorrelationsProvider);
  ref.invalidate(macroGoalsProvider);
  ref.invalidate(macroGoalCategoriesProvider);
  ref.invalidate(macroGoalsStatsProvider);
  ref.invalidate(dailyMoodsProvider);
  ref.invalidate(userProfileProvider);
  ref.invalidate(settingsProvider);
}
