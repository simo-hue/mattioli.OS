import 'dart:async';

import 'package:evolve_desktop/features/settings/application/settings_form_controller.dart';
import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/settings_dialogs.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_pane_scaffold.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Focus mode, the daily reminders it silences, and how macOS delivers them.
class SettingsNotificationsPane extends ConsumerWidget {
  const SettingsNotificationsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(settingsFormControllerProvider);
    final controller = ref.read(settingsFormControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeading(section: SettingsSection.notifications),
        const SizedBox(height: 20),
        SettingsColumn(
          groups: [
            // Focus mode leads the pane because it overrides everything under
            // it. It used to live in the Application pane's "AI & SYSTEM" card,
            // three destinations away from the switches it silences.
            SettingsGroup(
              title: t.settingsPage.groupFocus,
              children: [
                SettingsSwitchRow(
                  id: 'notifications.focusMode',
                  label: t.settingsPage.focusMode,
                  detail: t.settingsPage.focusModeDetail,
                  value: form.focusMode,
                  onChanged: controller.setFocusMode,
                ),
              ],
            ),
            SettingsGroup(
              title: t.settingsPage.groupDailyReminders,
              footnote: t.settingsPage.perHabitRemindersNote,
              children: [
                SettingsSwitchRow(
                  id: 'notifications.morningBrief',
                  label: t.settingsPage.habitReminders,
                  detail: t.settingsPage.habitRemindersDetail,
                  value: form.habitReminders,
                  onChanged: controller.setHabitReminders,
                ),
                // Always rendered, disabled when its switch is off. It used to
                // be `if (_habitReminders)`, so the pane changed height under
                // the cursor and the rows below jumped on every toggle.
                SettingsTimeRow(
                  id: 'notifications.morningBriefTime',
                  label: t.settingsPage.morningBriefTime,
                  value: form.morningTime,
                  use24hFormat: form.timeFormat24h,
                  state: form.habitReminders
                      ? const SettingsRowState.enabled()
                      : SettingsRowState.disabled(
                          t.settingsPage.disabledTurnOnFirst,
                        ),
                  onChanged: controller.setMorningTime,
                ),
                SettingsSwitchRow(
                  id: 'notifications.eveningReview',
                  label: t.settingsPage.eveningReview,
                  detail: t.settingsPage.eveningReviewDetail,
                  value: form.eveningReview,
                  onChanged: controller.setEveningReview,
                ),
                SettingsTimeRow(
                  id: 'notifications.eveningReviewTime',
                  label: t.settingsPage.eveningReviewTime,
                  value: form.eveningTime,
                  use24hFormat: form.timeFormat24h,
                  state: form.eveningReview
                      ? const SettingsRowState.enabled()
                      : SettingsRowState.disabled(
                          t.settingsPage.disabledTurnOnFirst,
                        ),
                  onChanged: controller.setEveningTime,
                ),
                if (form.focusMode)
                  SettingsWarningRow(
                    title: t.settingsPage.focusModeOnTitle,
                    body: t.settingsPage.focusModeOnBody,
                    destructive: false,
                  ),
              ],
            ),
            // "Insights and reports" is gone: notif_ai_insights and
            // notif_weekly_reports have no scheduler on macOS
            // (DesktopNotificationService.sync takes neither) and an empty
            // placeholder on iOS, so nothing was ever delivered for either.
            // Both keys and both profile columns stay — the iPhone still
            // round-trips them.
            SettingsGroup(
              title: t.settingsPage.groupDelivery,
              footnote: DesktopNotificationService.instance.platformSummary,
              children: [
                SettingsActionRow(
                  id: 'notifications.permission',
                  icon: LucideIcons.bell,
                  title: t.settingsPage.requestNotificationPermissions,
                  detail: t.settingsPage.requestNotificationPermissionsDetail,
                  onTap: () =>
                      unawaited(_requestNotificationPermissions(context)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _requestNotificationPermissions(BuildContext context) async {
    final granted = await DesktopNotificationService.instance
        .requestPermissions();
    if (!context.mounted) return;
    showSettingsGate(
      context,
      t.settingsPage.notificationPermissionsTitle,
      granted
          ? t.settingsPage.notificationPermissionsGranted
          : t.settingsPage.notificationPermissionsDenied,
    );
  }
}
