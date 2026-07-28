import 'dart:async';
import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/features/ai_coach/presentation/coach_settings_panels.dart';
import 'package:evolve_desktop/features/settings/application/settings_form_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/app_logs_dialog.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/sync_diagnostics_dialog.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_pane_scaffold.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Expert and developer-adjacent surface, in one place at the bottom of the
/// rail where Mac users expect it.
///
/// App Logs used to be the last row of the Application pane's "Calendar,
/// experience and language" card, directly under "Reset tutorial".
///
/// [syncDiagnostics] is owned by the page, which also refreshes it: the Data &
/// Backup pane's status line is derived from the same read.
class SettingsAdvancedPane extends ConsumerWidget {
  const SettingsAdvancedPane({super.key, required this.syncDiagnostics});

  final SyncDiagnostics? syncDiagnostics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final diagnostics = syncDiagnostics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeading(section: SettingsSection.advanced),
        const SizedBox(height: 20),
        SettingsColumn(
          groups: [
            // System prompt and temperature were a collapsed disclosure inside
            // the coach modal. They are genuinely expert controls — a Pro
            // subscriber can rewrite the prompt for the managed engine — so
            // they belong here rather than in front of everyone configuring an
            // engine.
            SettingsGroup(
              title: t.coachSettings.groupTuning,
              footnote: t.coachSettings.tuningFootnote,
              children: const [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: CoachAdvancedPanel(),
                ),
              ],
            ),
            SettingsGroup(
              title: t.settingsPage.groupDiagnostics,
              children: [
                SettingsActionRow(
                  id: 'advanced.appLogs',
                  title: t.settingsPage.appLogsTitle,
                  detail: t.settingsPage.appLogsDetail,
                  onTap: () => unawaited(showAppLogsDialog(context)),
                ),
                if (isPrivateMode && Platform.isMacOS && diagnostics != null)
                  SettingsActionRow(
                    id: 'advanced.syncReport',
                    title: t.icloudSync.detailsTitle,
                    detail: _diagnosticsLabel(diagnostics),
                    onTap: () => unawaited(
                      showSyncDiagnosticsDialog(context, diagnostics),
                    ),
                  ),
              ],
            ),
            // Previously reachable ONLY by pressing the red "Delete account and
            // data" button and picking the third option in the dialog that
            // opened — a settings reset hidden behind the app's most
            // destructive label.
            SettingsGroup(
              title: t.settingsPage.sectionAdvanced,
              children: [
                SettingsActionRow(
                  id: 'advanced.restoreDefaults',
                  title: t.settingsPage.restoreDefaults,
                  detail: t.settingsPage.restoreDefaultsDetail,
                  destructive: true,
                  onTap: () => unawaited(_confirmRestoreDefaults(context, ref)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmRestoreDefaults(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showEvolveDialog<bool>(
      context: context,
      builder: (dialogContext) => EvolveAlertDialog(
        icon: LucideIcons.rotateCcw,
        title: Text(t.settingsPage.restoreDefaults),
        content: Text(
          t.settingsPage.restoreDefaultsDetail,
          style: TextStyle(
            color: dialogContext.evolveColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.settingsPage.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.settingsPage.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(settingsFormControllerProvider.notifier)
        .resetSettingsToDefaults();
  }
}

/// The one-line truth about whether anything is stranded. Failures are named
/// ahead of the pending count: a user with both needs to know that retrying
/// is not what is missing.
String _diagnosticsLabel(SyncDiagnostics d) {
  // totalStuck, not a hand-rolled sum: adding a bucket to SyncDiagnostics
  // (as `heldByReason` was) must not silently under-count here.
  final stuck = d.totalStuck;
  if (stuck > 0) return t.icloudSync.detailsFailed(count: stuck);
  if (d.totalPending > 0) {
    return t.icloudSync.detailsPending(count: d.totalPending);
  }
  return t.icloudSync.detailsAllSynced;
}
