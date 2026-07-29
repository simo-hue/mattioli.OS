import 'dart:async';

import 'package:evolve_desktop/core/calendar_view_preference.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/application/settings_form_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/settings_dialogs.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_pane_scaffold.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Canonical language codes for the Settings language picker, in picker order.
/// These are the values persisted to `pref_language` and to the synced
/// `language` setting, and the ones [SettingsCodec.normalizeLanguage] — the one
/// parser both apps share — resolves to.
const List<String> _kLanguageCodes = [
  SettingsCodec.languageSystem,
  ...SettingsCodec.languageCodes,
];

/// Calendar-view codes in picker order.
const List<String> _kCalendarViewCodes = [
  kCalendarViewMonth,
  kCalendarViewWeek,
  kCalendarViewYear,
  kCalendarViewLife,
];

/// Appearance, language and formats: how the app looks and reads, rather than
/// what it does.
class SettingsGeneralPane extends ConsumerWidget {
  const SettingsGeneralPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(settingsFormControllerProvider);
    final controller = ref.read(settingsFormControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeading(section: SettingsSection.general),
        const SizedBox(height: 20),
        SettingsColumn(
          groups: [
            SettingsGroup(
              title: t.settingsPage.groupAppearance,
              children: [
                // Three options, not a switch. A binary control cannot express
                // `'system'` — which the schema permits and which every user
                // who never picked a theme actually has — so one touch of the
                // old switch wrote a concrete 'dark'/'light' to the synced
                // store, pinned the iPhone too, and left no way back to "follow
                // system" from the Mac.
                SettingsSelectRow<String>(
                  id: 'general.theme',
                  label: t.settingsPage.themeMode,
                  value: form.themeMode,
                  options: [
                    for (final code in SettingsCodec.themeModes)
                      EvolveSelectOption(
                        value: code,
                        label: _themeModeOptionLabel(code),
                      ),
                  ],
                  // The appearance controller is mutated before the write is
                  // attempted, so the rollback restores it too — see
                  // [SettingsFormController.setThemeMode].
                  onChanged: controller.setThemeMode,
                ),
                // Accent finally sits beside Theme. "Appearance and visuals"
                // used to hold Theme alone while the most appearance-like
                // control on the page lived one card further down, under
                // "Calendar, experience and language".
                SettingsColorRow(
                  id: 'general.accent',
                  icon: LucideIcons.palette,
                  label: t.settingsPage.accentColor,
                  detail: t.settingsPage.accentColorDetail,
                  selected: form.accent,
                  // Its OWN rollback path — it does not go through
                  // `_setBool`/`_setString`. See
                  // [SettingsFormController.setAccentColor].
                  onChanged: controller.setAccentColor,
                  // Custom accent color is Pro (mobile parity). Private mode is
                  // always Pro via desktopIsProProvider, so it's never locked.
                  customLocked: !ref.watch(desktopIsProProvider),
                  onCustomLocked: () =>
                      unawaited(showProFeaturesDialog(context, ref)),
                ),
              ],
            ),
            SettingsGroup(
              title: t.settingsPage.groupLanguageFormats,
              // The code has always implemented this distinction and the UI has
              // never shown it: these four dual-write the profiles row, so they
              // reach the paired iPhone.
              footnote: t.settingsPage.syncsToIPhoneNote,
              children: [
                SettingsSelectRow<String>(
                  id: 'general.calendarView',
                  label: t.settingsPage.defaultCalendarView,
                  value: form.calendarView,
                  options: [
                    for (final code in _kCalendarViewCodes)
                      EvolveSelectOption(
                        value: code,
                        label: _calendarViewOptionLabel(code),
                      ),
                  ],
                  onChanged: controller.setCalendarView,
                ),
                SettingsSelectRow<String>(
                  id: 'general.language',
                  label: t.settingsPage.language,
                  value: form.language,
                  options: [
                    for (final code in _kLanguageCodes)
                      EvolveSelectOption(
                        value: code,
                        label: _languageOptionLabel(code),
                      ),
                  ],
                  onChanged: controller.setLanguage,
                ),
                SettingsSwitchRow(
                  id: 'general.timeFormat',
                  label: t.settingsPage.timeFormat24h,
                  detail: t.settingsPage.timeFormat24hDetail,
                  value: form.timeFormat24h,
                  onChanged: controller.setTimeFormat24h,
                ),
              ],
            ),
            SettingsGroup(
              title: t.settingsPage.groupGettingStarted,
              children: [
                SettingsActionRow(
                  id: 'general.replayTour',
                  title: t.settingsPage.resetTutorial,
                  detail: t.settingsPage.resetTutorialDetail,
                  onTap: () => unawaited(_resetTutorials(context, ref)),
                ),
              ],
            ),
            // Gone from this pane:
            //   * "AI & SYSTEM" entirely. AI Suggestions, Milestones and Deep
            //     Work Insights have no consumer on EITHER platform — they are
            //     internal AppSettings fields that were surfaced as switches,
            //     and iOS never showed them. AI Suggestions also carried the
            //     page's only PRO badge, so the Pro signal was attached to the
            //     one control that did nothing. The pref keys and profile
            //     columns stay; only the rows go.
            //   * Focus mode, to Notifications, where the switches it silences
            //     live.
            //   * App Logs, to Advanced. A diagnostics viewer does not belong
            //     under "Calendar, experience and language".
          ],
        ),
      ],
    );
  }

  Future<void> _resetTutorials(BuildContext context, WidgetRef ref) async {
    // Clear the completion flag and rewind the central tour to Overview, then
    // navigate to the Dashboard. The Dashboard's existing onboarding flow
    // watches tourControllerProvider and re-triggers the welcome dialog + tour.
    await ref.read(tourControllerProvider.notifier).resetForReplay();
    ref
        .read(navigationControllerProvider.notifier)
        .select(DesktopSection.overview);
    if (context.mounted) {
      showSettingsGate(
        context,
        t.settingsPage.tutorialResetTitle,
        t.settingsPage.tutorialResetMessage,
      );
    }
  }
}

String _languageOptionLabel(String code) => switch (code) {
  'it' => t.settingsPage.languageOptions.italian,
  'en' => t.settingsPage.languageOptions.english,
  'es' => t.settingsPage.languageOptions.spanish,
  'de' => t.settingsPage.languageOptions.german,
  'ar' => t.settingsPage.languageOptions.arabic,
  _ => t.settingsPage.languageOptions.system,
};

/// The canonical CODE stays the value; only the label follows the UI
/// language, exactly like the calendar-view and language rows.
String _themeModeOptionLabel(String code) => switch (code) {
  SettingsCodec.themeLight => t.settingsPage.themeLight,
  SettingsCodec.themeDark => t.settingsPage.themeDark,
  _ => t.settingsPage.themeSystem,
};

String _calendarViewOptionLabel(String code) => switch (code) {
  kCalendarViewMonth => t.settingsPage.calendarViewOptions.month,
  kCalendarViewYear => t.settingsPage.calendarViewOptions.year,
  kCalendarViewLife => t.settingsPage.calendarViewOptions.life,
  _ => t.settingsPage.calendarViewOptions.week,
};
