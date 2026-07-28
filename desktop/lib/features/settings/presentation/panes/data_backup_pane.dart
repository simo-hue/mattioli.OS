import 'dart:async';
import 'dart:io';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/features/settings/application/settings_data_controller.dart';
import 'package:evolve_desktop/features/settings/application/settings_form_controller.dart';
import 'package:evolve_desktop/features/settings/application/sync_settings_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/import_mode_dialog.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/import_result_dialog.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/settings_dialogs.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_pane_scaffold.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
/// The iCloud state lives in [syncSettingsControllerProvider] — the Advanced
/// pane reads the same diagnostics, and neither pane should have to be handed
/// them by the page. What stays HERE is the dialog sequencing: enabling asks
/// for consent, then acts, then may offer "start fresh"; the reset row confirms
/// and then toasts. A controller cannot hold a BuildContext across an await, so
/// this pane drives the order and the controller performs each step.
class SettingsDataBackupPane extends ConsumerWidget {
  const SettingsDataBackupPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final sync = ref.watch(syncSettingsControllerProvider);
    final syncEnabled = sync.isEnabled;
    final undecryptable = sync.undecryptableCount;

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
                      onAction: () =>
                          unawaited(_resetSyncFromThisDevice(context, ref)),
                    ),
                  SettingsSwitchRow(
                    id: 'data.icloudSync',
                    label: t.icloudSync.enableTitle,
                    detail: sync.statusLabel,
                    value: syncEnabled,
                    onChanged: (value) =>
                        unawaited(_toggleSync(context, ref, value)),
                  ),
                  SettingsActionRow(
                    id: 'data.syncNow',
                    title: t.icloudSync.syncNow,
                    detail: _lastSyncedLabel(context, ref, sync.status),
                    // It used to render fully tappable and then return early in
                    // exactly these states, so the click did nothing and said
                    // nothing. iOS disables it; now so do we.
                    state: syncEnabled
                        ? const SettingsRowState.enabled()
                        : SettingsRowState.disabled(
                            t.icloudSync.syncNowNeedsSync,
                          ),
                    onTap: () => unawaited(
                      ref
                          .read(syncSettingsControllerProvider.notifier)
                          .syncNow(),
                    ),
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
                  onTap: () => unawaited(_exportData(context, ref)),
                ),
                SettingsActionRow(
                  id: 'data.import',
                  title: t.settingsPage.importData,
                  detail: t.settingsPage.importDataDetail,
                  onTap: () => unawaited(_importData(context, ref)),
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
            onTap: () => unawaited(_deletePrivateData(context, ref)),
          )
        else
          SettingsDestructiveButton(
            label: t.settingsPage.deleteAccountAndData,
            caption: t.settingsPage.deleteAccountAndDataDetail,
            onTap: () => unawaited(_showDeleteOrResetDialog(context, ref)),
          ),
      ],
    );
  }

  /// "Never synced" or "Last synced `<date> <time>`" under the Sync-now row.
  ///
  /// Stays in the widget layer: it needs [MaterialLocalizations], which is a
  /// BuildContext lookup, so the controller cannot produce it.
  String _lastSyncedLabel(
    BuildContext context,
    WidgetRef ref,
    PrivateSyncStatus? status,
  ) {
    final at = status?.lastSyncedAt;
    if (at == null) return t.icloudSync.lastSyncedNever;
    final local = at.toLocal();
    final materialLocalizations = MaterialLocalizations.of(context);
    final date = materialLocalizations.formatShortDate(local);
    final time = materialLocalizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: ref.watch(
        settingsFormControllerProvider.select((form) => form.timeFormat24h),
      ),
    );
    return t.icloudSync.lastSyncedAt(time: '$date $time');
  }

  Future<void> _toggleSync(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final controller = ref.read(syncSettingsControllerProvider.notifier);
    if (ref.read(syncSettingsControllerProvider).busy) return;
    if (value) {
      final accepted = await confirmSettingsAction(
        context,
        title: t.icloudSync.disclosureTitle,
        message: t.icloudSync.disclosureBody,
      );
      if (!accepted) return;
      await controller.enable();
      // enable() DEFERS rather than minting a rival key when the zone already
      // holds data this Mac has no key for. Explain and offer the deliberate
      // override instead of letting the toggle snap silently back to off.
      if (context.mounted &&
          ref.read(syncSettingsControllerProvider).keyPending) {
        await _offerStartFresh(context, ref);
      }
    } else {
      await controller.disable();
    }
    // The reactive data-loss banner watches desktopSyncEnabledProvider (a plain
    // prefs bool whose instance identity never changes); invalidate so it
    // clears/returns immediately instead of after an app restart.
    if (context.mounted) refreshDesktopSyncEnabled(ref);
  }

  /// The escape hatch from a permanent deferral: a Mac whose iCloud Keychain
  /// will never deliver the key would otherwise wait forever. Destructive, so
  /// never automatic — the user is told what it costs and has to agree.
  Future<void> _offerStartFresh(BuildContext context, WidgetRef ref) async {
    final accepted = await confirmSettingsAction(
      context,
      title: t.icloudSync.forceEnableTitle,
      message: t.icloudSync.forceEnableBody,
      destructive: true,
    );
    if (!accepted) return;
    await ref.read(syncSettingsControllerProvider.notifier).enable(force: true);
  }

  Future<void> _resetSyncFromThisDevice(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final accepted = await confirmSettingsAction(
      context,
      title: t.icloudSync.resetFromDevice,
      message: t.icloudSync.resetFromDeviceConfirm,
      destructive: true,
    );
    if (!accepted) return;
    await ref
        .read(syncSettingsControllerProvider.notifier)
        .resetSyncFromThisDevice();
    if (context.mounted) {
      showEvolveToast(context, message: t.icloudSync.resetFromDeviceDone);
    }
  }

  // ---------------------------------------------------------------------------
  // Backups
  // ---------------------------------------------------------------------------

  /// The controller builds the backup and delivers it; this only names what
  /// happened. The mode comes back WITH the result rather than being re-read
  /// here, so the confirmation always describes the export that actually ran.
  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(settingsDataControllerProvider).exportData();
    if (!context.mounted) return;
    final isPrivateMode = result.isPrivateMode;
    final doneTitle = isPrivateMode
        ? t.privateData.exportDoneTitle
        : t.settingsPage.exportDoneTitle;
    switch (result.outcome) {
      case SettingsExportOutcome.cancelled:
        return;
      case SettingsExportOutcome.savedToFile:
        showSettingsGate(context, doneTitle, t.settingsPage.exportDoneSaved);
      case SettingsExportOutcome.copiedToClipboard:
        showSettingsGate(
          context,
          doneTitle,
          isPrivateMode
              ? t.privateData.exportDoneClipboard
              : t.settingsPage.exportDoneClipboard,
        );
      case SettingsExportOutcome.shared:
        showSettingsGate(
          context,
          doneTitle,
          isPrivateMode
              ? t.privateData.exportDoneShare
              : t.settingsPage.exportDoneShare,
        );
      case SettingsExportOutcome.failed:
        // Always the generic title: a failure this early may not have got far
        // enough to know which export the user was owed.
        showSettingsGate(
          context,
          t.settingsPage.exportDoneTitle,
          t.settingsPage.operationFailed,
        );
    }
  }

  /// Drives the import's four decision points — recover a locked DB, Replace or
  /// Merge, confirm the loss a Replace costs, and the summary — around the
  /// controller steps that do the work.
  ///
  /// The whole sequence stays under ONE try/catch, as it was on the page: the
  /// error toast quotes the exception, so every step has to fail into the same
  /// handler that closes the spinner.
  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(settingsDataControllerProvider);
    try {
      final session = await controller.beginImport();
      if (session == null) return;
      if (!context.mounted) return;

      // A locked DB is unrecoverable (its key is gone), but the user's backup
      // imports cleanly onto a fresh key — so offer that trade explicitly
      // rather than failing the import with an opaque error.
      if (session.isDatabaseLocked) {
        final recover = await confirmSettingsAction(
          context,
          title: t.settingsPage.importLockedTitle,
          message: t.settingsPage.importLockedMessage,
          destructive: true,
          confirmLabel: t.settingsPage.importLockedResetButton,
        );
        if (!recover) return;
        await controller.resetLockedPrivateDatabase();
      }

      // 1. Preview (accepts both the web `.zip` and native `.json` backups).
      final preview = await controller.parseImportPreview(session);

      if (!context.mounted) return;

      // 2. Ask for Replace/Merge.
      final replaceExisting = await showImportModeDialog(context, preview);

      if (replaceExisting == null) return;
      if (!context.mounted) return;

      // Replace deletes every record not in the backup and, in private mode,
      // tombstones the deletions to iCloud — so a stale or partial backup can
      // take out a full history on every device at once. Require a second,
      // explicit confirmation that names the loss with a real count.
      if (replaceExisting) {
        final proceed = await confirmSettingsAction(
          context,
          title: t.settingsPage.importReplaceConfirmTitle,
          message: t.settingsPage.importReplaceConfirmMessage(
            count: controller.habitLogCount(),
          ),
          confirmLabel: t.settingsPage.importReplaceConfirmButton,
          destructive: true,
        );
        if (!proceed) return;
        if (!context.mounted) return;
      }

      // 3. Execute
      showSettingsLoadingDialog(context, t.settingsPage.importInProgress);

      final stats = await controller.executeImport(
        session,
        preview: preview,
        replaceExisting: replaceExisting,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // close loading

      // Per-entity outcome summary (added / updated / unchanged / skipped),
      // mirroring the mobile client's post-import dialog.
      await showImportResultDialog(context, stats);
    } catch (e, st) {
      AppLogger.error('Errore durante importData', e, st);
      if (!context.mounted) return;
      // Close loading if still open
      if (Navigator.canPop(context)) Navigator.pop(context);

      showEvolveToast(
        context,
        message: t.settingsPage.importError(error: e),
        kind: EvolveToastKind.error,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Reset and deletion
  // ---------------------------------------------------------------------------

  Future<void> _showDeleteOrResetDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final action = await showEvolveDialog<String>(
      context: context,
      builder: (context) => EvolveAlertDialog(
        icon: LucideIcons.userCog,
        title: Text(t.settingsPage.accountDataManagementTitle),
        content: Text(t.settingsPage.accountDataManagementContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.settingsPage.cancel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'reset'),
            child: Text(t.settingsPage.resetDataAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            child: Text(t.settingsPage.deleteAccountAction),
          ),
        ],
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'reset') {
      final confirmed = await confirmSettingsAction(
        context,
        title: t.settingsPage.confirmResetDataTitle,
        message: t.settingsPage.confirmResetDataMessage,
        destructive: true,
      );
      if (confirmed && context.mounted) await _resetData(context, ref);
      return;
    }

    final confirmed = await confirmSettingsAction(
      context,
      title: t.settingsPage.confirmDeleteAccountTitle,
      message: t.settingsPage.confirmDeleteAccountMessage,
      destructive: true,
    );
    if (confirmed && context.mounted) await _deleteAccount(context, ref);
  }

  Future<void> _resetData(BuildContext context, WidgetRef ref) async {
    showSettingsLoadingDialog(context, t.settingsPage.resetDataTitle);
    final reset = await ref.read(settingsDataControllerProvider).resetData();
    if (!context.mounted) return;
    Navigator.pop(context); // close loading dialog
    showSettingsResultDialog(
      context,
      t.settingsPage.resetDataTitle,
      reset ? t.settingsPage.resetDataSuccess : t.settingsPage.operationFailed,
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(settingsDataControllerProvider);
    if (!controller.hasActiveSession) {
      showSettingsResultDialog(
        context,
        t.settingsPage.deleteAccountGateTitle,
        t.settingsPage.gateRequiresActiveSession,
      );
      return;
    }
    // The spinner lives on the root navigator and outlives this pane: deleting
    // the account signs out, which swaps the shell for the sign-in page and
    // disposes this widget. gotrue notifies its auth subscribers BEFORE awaiting
    // the /logout round trip, so that swap lands while we are still suspended
    // here — a `mounted`-gated pop would leave a barrier-blocking, buttonless
    // spinner over the sign-in page with force-quit as the only way out. Hold
    // the navigator captured before the await and pop it unconditionally.
    final navigator = Navigator.of(context, rootNavigator: true);
    showSettingsLoadingDialog(context, t.settingsPage.deleteAccountGateTitle);
    final deleted = await controller.deleteAccount();
    navigator.pop();
    // Success disposes this pane, so the confirmation is best-effort: it can
    // only render on the rare path where the swap has not landed yet.
    if (!context.mounted) return;
    showSettingsResultDialog(
      context,
      t.settingsPage.deleteAccountGateTitle,
      deleted ? t.settingsPage.accountDeleted : t.settingsPage.operationFailed,
    );
  }

  Future<void> _deletePrivateData(BuildContext context, WidgetRef ref) async {
    // With sync on, deleting is a FULL reset (local + the user's iCloud copy);
    // the disclosure must also say other devices keep their local copy.
    final syncEnabled = ref.read(syncSettingsControllerProvider).isEnabled;
    final message = syncEnabled
        ? '${t.privateData.deleteMessage}\n\n${t.icloudSync.deleteSyncNote}'
        : t.privateData.deleteMessage;
    final confirmed = await confirmSettingsAction(
      context,
      title: t.privateData.deleteTitle,
      message: message,
      destructive: true,
    );
    if (!confirmed) return;
    // Long-standing gap, fixed here rather than suppressed: the spinner used to
    // open after this await with no mounted check, so a page disposed while the
    // confirm dialog was up handed a defunct context to showDialog. Bailing
    // changes no outcome — that call threw before deletePrivateData() could
    // run, so the data was not deleted either way — it just stops the throw.
    if (!context.mounted) return;
    showSettingsLoadingDialog(context, t.privateData.deleteTitle);
    final deleted = await ref
        .read(settingsDataControllerProvider)
        .deletePrivateData();
    if (!context.mounted) return;
    Navigator.pop(context); // close loading dialog
    showSettingsResultDialog(
      context,
      t.privateData.deleteTitle,
      deleted ? t.privateData.deleteSuccess : t.privateData.deleteFailed,
    );
  }
}
