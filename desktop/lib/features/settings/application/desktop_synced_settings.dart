import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The user's synced settings, whichever store owns them in the active mode:
/// the encrypted private database, or the `profiles` row of the signed-in
/// account.
///
/// Private mode never has a Supabase session, so the settings page's old
/// "select from `profiles` as the signed-in user" read-back returned
/// immediately and the Mac hydrated *every* field from its own
/// SharedPreferences. It wrote settings to the synced row and read none of them
/// back — which is exactly why the accent was orange on the iPhone and yellow
/// on the Mac, and the two apps ran in different languages.
///
/// Account mode used to return an EMPTY map here, on the grounds that "the
/// settings page reads profiles directly". It does — but only when it is on
/// screen. `loadProfilePreferences` has exactly one caller chain
/// (hydrate <- initState), so a Mac that never opened Settings rendered in the
/// system language with the default appearance while the account said
/// otherwise, and after A signed out B inherited A's theme. The app root
/// listens to THIS provider (see `evolve_desktop_app.dart`) precisely so a
/// theme/accent/language changed on the iPhone repaints the Mac with Settings
/// closed; account mode was simply not plugged into it.
///
/// Invalidated by `refreshPrivateAfterPull`, so a change made on the iPhone
/// lands on the Mac on the next pull instead of on the next restart.
final desktopSyncedSettingsProvider = FutureProvider<Map<String, String?>>((
  ref,
) async {
  if (!ref.watch(activeDesktopDataModeProvider).isPrivate) {
    return _readAccountSettings(ref);
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

/// The synced settings columns of `profiles`, returned in the same canonical
/// shape the private store uses so both modes feed one set of listeners.
///
/// `biometric_lock` is deliberately absent — App Lock is device-local (see
/// `desktop_biometric_controller.dart`), and so are `is_pro` and the crash
/// consent.
const List<String> _accountSettingColumns = <String>[
  kSettingThemeMode,
  kSettingAccentColor,
  kSettingLanguage,
  kSettingCalendarView,
  kSettingTimeFormat24h,
  kSettingAiSuggestions,
  kSettingFocusMode,
  kSettingMilestones,
  kSettingDeepWorkInsights,
  kSettingHabitReminders,
  kSettingGoalDeadlines,
  kSettingAiInsights,
  kSettingWeeklyReports,
  kSettingEveningReview,
  kSettingMorningBriefTime,
  kSettingEveningReviewTime,
];

Future<Map<String, String?>> _readAccountSettings(Ref ref) async {
  // WATCHED, not read: this read has to run again when the ACCOUNT changes, or
  // a fresh sign-in never sees the account's appearance and — worse — B keeps
  // rendering A's theme, accent and language after A signs out.
  //
  // The `select` is not a micro-optimisation. `DesktopAuthState` has no `==`,
  // so watching it whole compares by identity and re-runs on every auth event —
  // both legs of `_execute`, and every Supabase token refresh, which re-emits
  // `onAuthStateChange` roughly hourly. Since the appearance controller
  // persists a local theme/accent choice to SharedPreferences and never to
  // `profiles`, re-applying this row on a timer would silently revert the ⌘K
  // "Switch to light/dark" the user just used. Same reason the statistics,
  // goals and dashboard providers next door watch the id.
  final userId = ref.watch(
    desktopAuthControllerProvider.select((state) => state.user?.id),
  );
  final client = ref.read(supabaseClientProvider);
  if (client == null || userId == null) return const <String, String?>{};
  try {
    final row = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return const <String, String?>{};
    // NULL columns are omitted rather than passed through as null: every
    // listener treats an absent key as "the store has no opinion" and keeps its
    // own value, which is the right answer for a column the account never set.
    return <String, String?>{
      for (final column in _accountSettingColumns)
        if (row[column] != null) column: encodeDesktopSetting(row[column]),
    };
  } catch (error, stack) {
    // Best-effort, exactly like the private branch: an offline launch or a
    // pre-migration column must not take down the app root that listens here.
    AppLogger.warning(
      '[Settings] unable to read the account settings',
      error,
      stack,
    );
    return const <String, String?>{};
  }
}

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
  _applyDesktopSyncedSettings(
    values,
    appearance: () => ref.read(desktopAppearanceControllerProvider.notifier),
    locale: () => ref.read(desktopLocaleControllerProvider.notifier),
  );
}

/// [applyDesktopSyncedSettings] for a provider [Ref].
///
/// `WidgetRef` and `Ref` share no supertype in Riverpod 3, and the settings
/// form controller — which owns the read-back — holds the latter. Both spellings
/// delegate to the same body so the "which keys travel" decision cannot fork.
void applyDesktopSyncedSettingsFromRef(Ref ref, Map<String, String?> values) {
  _applyDesktopSyncedSettings(
    values,
    appearance: () => ref.read(desktopAppearanceControllerProvider.notifier),
    locale: () => ref.read(desktopLocaleControllerProvider.notifier),
  );
}

/// The notifiers are LAZY: a controller must only be instantiated when the key
/// it owns actually travelled, exactly as the two inline `ref.read`s did.
void _applyDesktopSyncedSettings(
  Map<String, String?> values, {
  required DesktopAppearanceController Function() appearance,
  required DesktopLocaleController Function() locale,
}) {
  if (values.containsKey(kSettingThemeMode) ||
      values.containsKey(kSettingAccentColor)) {
    appearance().applyProfile(
      themeMode: values[kSettingThemeMode],
      accentColor: values[kSettingAccentColor],
    );
  }
  if (values.containsKey(kSettingLanguage)) {
    locale().applyProfile(values[kSettingLanguage]);
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
