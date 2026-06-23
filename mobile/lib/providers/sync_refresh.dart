import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'goal_provider.dart';
import 'macro_goal_categories_provider.dart';
import 'macro_goals_provider.dart';
import 'macro_goals_stats_provider.dart';
import 'mood_provider.dart';
import 'settings_provider.dart';
import 'user_provider.dart';

/// Invalidate the in-memory private-data providers after a sync applied remote
/// changes, so the UI reflects the pulled data. The sync engine writes straight
/// to the local DB; these providers cache in memory and won't otherwise notice.
/// Mirrors the invalidation the delete/reset flow performs.
void invalidatePrivateDataProviders(WidgetRef ref) {
  ref.invalidate(goalsProvider);
  ref.invalidate(habitLogsProvider);
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
