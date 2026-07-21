import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The user's synced settings, read out of the encrypted private database.
///
/// Private mode never has a Supabase session, so the settings page's old
/// "select from `profiles` as the signed-in user" read-back returned
/// immediately and the Mac hydrated *every* field from its own
/// SharedPreferences. It wrote settings to the synced row and read none of them
/// back — which is exactly why the accent was orange on the iPhone and yellow
/// on the Mac, and the two apps ran in different languages.
///
/// Empty in Supabase mode: there the profiles table is the source and the
/// settings page reads it directly.
///
/// Invalidated by `refreshPrivateAfterPull`, so a change made on the iPhone
/// lands on the Mac on the next pull instead of on the next restart.
final desktopSyncedSettingsProvider = FutureProvider<Map<String, String?>>((
  ref,
) async {
  if (!ref.watch(activeDesktopDataModeProvider).isPrivate) {
    return const <String, String?>{};
  }
  try {
    return await DesktopPrivateDb.instance.loadSettingsRow();
  } catch (error, stack) {
    // Best-effort: a locked/absent private DB (PrivateModeGate drives recovery)
    // must not take down the app root that listens to this.
    AppLogger.warning(
      '[Settings] unable to read the synced settings',
      error,
      stack,
    );
    return const <String, String?>{};
  }
});

/// The synced-settings WRITE, behind a provider.
///
/// `DesktopPrivateDb.instance` is a private-constructor singleton with no
/// override hook, so a widget test could not inject a failing write — and a
/// failed write was precisely the case that had no coverage and no user-facing
/// signal. The default is the real method, so nothing that does not override it
/// changes behaviour.
final desktopSyncedSettingsWriterProvider =
    Provider<Future<void> Function(Map<String, String?>)>(
      (_) => DesktopPrivateDb.instance.writeSyncedSettings,
    );

/// Pushes the settings that have a live controller behind them — theme, accent
/// and language — into that controller.
///
/// Reading is not the point; applying is. Without this the settings page would
/// show the pulled values while the app kept rendering the old theme and
/// speaking the old language.
///
/// Keys absent from [values] are left alone: the store distinguishes "never
/// set" from "set to null", and neither is a reason to overwrite a live choice.
void applyDesktopSyncedSettings(WidgetRef ref, Map<String, String?> values) {
  if (values.containsKey(kSettingThemeMode) ||
      values.containsKey(kSettingAccentColor)) {
    ref
        .read(desktopAppearanceControllerProvider.notifier)
        .applyProfile(
          themeMode: values[kSettingThemeMode],
          accentColor: values[kSettingAccentColor],
        );
  }
  if (values.containsKey(kSettingLanguage)) {
    ref
        .read(desktopLocaleControllerProvider.notifier)
        .applyProfile(values[kSettingLanguage]);
  }
}

// Key constants for the handful of settings this app reaches for by name. They
// are spelled here once rather than inline so a typo is a compile error instead
// of a setting that silently refuses to sync; every one of them is in
// [PrivateDbSchema.syncedSettingKeys].
const String kSettingLanguage = 'language';
const String kSettingThemeMode = 'theme_mode';
const String kSettingAccentColor = 'accent_color';
const String kSettingCalendarView = 'pref_default_calendar_view';
const String kSettingTimeFormat24h = 'pref_time_format_24h';
const String kSettingAiSuggestions = 'pref_ai_suggestions';
const String kSettingFocusMode = 'pref_focus_mode';
const String kSettingMilestones = 'pref_milestones';
const String kSettingDeepWorkInsights = 'pref_deep_work_insights';
const String kSettingHabitReminders = 'notif_habit_reminders';
const String kSettingGoalDeadlines = 'notif_goal_deadlines';
const String kSettingAiInsights = 'notif_ai_insights';
const String kSettingWeeklyReports = 'notif_weekly_reports';
const String kSettingEveningReview = 'notif_evening_review';
const String kSettingMorningBriefTime = 'morning_brief_time';
const String kSettingEveningReviewTime = 'evening_review_time';
const String kSettingHapticFeedback = 'pref_haptic_feedback';

/// Encodes a Dart value into the canonical TEXT the shared store expects.
/// Booleans become `'1'`/`'0'` — the encoding both apps already use on the
/// legacy `profiles` columns, so the dual-write never has to translate.
String? encodeDesktopSetting(Object? value) {
  if (value == null) return null;
  if (value is bool) return SyncedSettingsStore.encodeBool(value);
  if (value is int) return SyncedSettingsStore.encodeInt(value);
  return '$value';
}
