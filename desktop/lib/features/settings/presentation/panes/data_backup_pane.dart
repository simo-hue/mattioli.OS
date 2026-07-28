import 'dart:io';

import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_pane_scaffold.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the user's data is copied, how it gets in and out, and how it is
/// erased.
///
/// New pane. All of this used to be crammed into Privacy alongside the device
/// lock, account credentials and crash-report consent. Note that the pane
/// exists in BOTH data modes: in account mode the iCloud card collapses to a
/// single status row rather than vanishing, so the dashboard's SyncOffBanner
/// has a deep-link target that does not disappear, and so export, import and
/// erase are never stranded.
///
/// The iCloud state and every flow behind these rows stay on the page: they are
/// long-running, they own `_syncBusy` / `_syncStatus` / `_syncDiagnostics`, and
/// the Advanced pane reads the same diagnostics. The two labels arrive already
/// rendered for the same reason — both read state that stays there.
class SettingsDataBackupPane extends ConsumerWidget {
  const SettingsDataBackupPane({
    super.key,
    required this.syncStatus,
    required this.syncStatusLabel,
    required this.lastSyncedLabel,
    required this.onResetSyncFromThisDevice,
    required this.onSyncToggle,
    required this.onSyncNow,
    required this.onExport,
    required this.onImport,
    required this.onDeletePrivateData,
    required this.onDeleteAccountOrReset,
  });

  final PrivateSyncStatus? syncStatus;
  final String syncStatusLabel;
  final String lastSyncedLabel;
  final VoidCallback onResetSyncFromThisDevice;
  final ValueChanged<bool> onSyncToggle;
  final VoidCallback onSyncNow;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onDeletePrivateData;
  final VoidCallback onDeleteAccountOrReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final syncEnabled = syncStatus?.isEnabled ?? false;
    final undecryptable = syncStatus?.undecryptableCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeading(section: SettingsSection.dataBackup),
        const SizedBox(height: 20),
        SettingsColumn(
          groups: [
            if (isPrivateMode && Platform.isMacOS)
              SettingsGroup(
                title: t.icloudSync.title,
                footnote: t.icloudSync.disclosureBody,
                children: [
                  // Promoted from an ordinary action row that sat two below
                  // "Sync now" and looked identical to it — for the single most
                  // cross-device-destructive action on the page. iOS already
                  // shows this as a card.
                  if (undecryptable > 0)
                    SettingsWarningRow(
                      title: t.icloudSync.keySplitTitle,
                      body: t.icloudSync.keySplitBody(count: undecryptable),
                      actionLabel: t.icloudSync.resetFromDevice,
                      onAction: onResetSyncFromThisDevice,
                    ),
                  SettingsSwitchRow(
                    id: 'data.icloudSync',
                    label: t.icloudSync.enableTitle,
                    detail: syncStatusLabel,
                    value: syncEnabled,
                    onChanged: onSyncToggle,
                  ),
                  SettingsActionRow(
                    id: 'data.syncNow',
                    title: t.icloudSync.syncNow,
                    detail: lastSyncedLabel,
                    // It used to render fully tappable and then return early in
                    // exactly these states, so the click did nothing and said
                    // nothing. iOS disables it; now so do we.
                    state: syncEnabled
                        ? const SettingsRowState.enabled()
                        : SettingsRowState.disabled(
                            t.icloudSync.syncNowNeedsSync,
                          ),
                    onTap: onSyncNow,
                  ),
                ],
              )
            else
              SettingsGroup(
                title: t.icloudSync.title,
                children: [
                  SettingsInfoRow(
                    id: 'data.accountSync',
                    label: t.icloudSync.title,
                    value: isPrivateMode
                        ? t.icloudSync.unavailablePlatform
                        : t.settingsPage.accountSyncOn,
                  ),
                ],
              ),
            SettingsGroup(
              title: t.settingsPage.groupBackups,
              children: [
                SettingsActionRow(
                  id: 'data.export',
                  title: t.settingsPage.exportData,
                  detail: t.settingsPage.exportDataDetail,
                  onTap: onExport,
                ),
                SettingsActionRow(
                  id: 'data.import',
                  title: t.settingsPage.importData,
                  detail: t.settingsPage.importDataDetail,
                  onTap: onImport,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Erasing content is a first-class action here rather than the hidden
        // third option inside the "Delete account and data" dialog — the only
        // route to a non-account-destroying maintenance action used to be the
        // app's most frightening label. Deleting the ACCOUNT lives in Account.
        if (isPrivateMode)
          SettingsDestructiveButton(
            label: t.settingsPage.deletePrivateData,
            caption: t.settingsPage.deletePrivateDataDetail,
            onTap: onDeletePrivateData,
          )
        else
          SettingsDestructiveButton(
            label: t.settingsPage.deleteAccountAndData,
            caption: t.settingsPage.deleteAccountAndDataDetail,
            onTap: onDeleteAccountOrReset,
          ),
      ],
    );
  }
}
