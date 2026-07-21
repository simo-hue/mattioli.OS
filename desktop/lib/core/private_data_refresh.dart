import 'dart:async';

import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:evolve_desktop/features/statistics/data/private_analytics_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Refreshes the full in-memory private-data surface after a pull applied remote
/// changes (or a notification-driven local write). The sync engine writes
/// pulled records straight to the encrypted DB, bypassing the controllers, so
/// these in-memory caches won't otherwise notice.
///
/// Kept in ONE place so the automatic pull paths (launch / window-refocus /
/// periodic / after-write) can't drift from the manual "Sync now" button.
/// Critically this refreshes the profile, goal categories AND the synced
/// settings too — not just the dashboard + analytics — so a cross-device edit to
/// the user's name/DOB/avatar (shell header), a goal category, or a preference
/// like theme/accent/language shows up without a manual sync or restart,
/// matching mobile's `invalidatePrivateDataProviders` (which invalidates its
/// `settingsProvider` for the same reason).
///
/// The settings invalidation is only half the job on its own: the app root
/// listens to [desktopSyncedSettingsProvider] and pushes theme/accent/language
/// into the live controllers, so the pulled values are applied and not merely
/// re-read.
void refreshPrivateAfterPull(ProviderContainer container) {
  unawaited(container.read(dashboardControllerProvider.notifier).refresh());
  container.invalidate(privateAnalyticsDataProvider);
  container.invalidate(privateProfileProvider);
  container.invalidate(desktopGoalCategoriesControllerProvider);
  container.invalidate(desktopSyncedSettingsProvider);
}
