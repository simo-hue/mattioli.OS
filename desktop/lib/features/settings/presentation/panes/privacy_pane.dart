import 'dart:async';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/settings/application/desktop_biometric_controller.dart';
import 'package:evolve_desktop/features/settings/application/settings_form_controller.dart';
import 'package:evolve_desktop/features/settings/data/desktop_system_settings_service.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/settings_dialogs.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_pane_scaffold.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_legal/evolve_legal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Narrowed to what a user would actually call privacy. Sync, backups and
/// erasure moved to Data & Backup; account credentials moved to Account.
class SettingsPrivacyPane extends ConsumerWidget {
  const SettingsPrivacyPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometric = ref.watch(desktopBiometricControllerProvider);
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final privacyPolicy = LegalUrls.privacy(
      LocaleSettings.currentLocale.languageCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeading(section: SettingsSection.privacy),
        const SizedBox(height: 20),
        SettingsColumn(
          groups: [
            // Hidden rather than disabled off macOS/Windows: the controller
            // refuses outright on Linux, and a permanently impossible control
            // is noise, not information.
            if (ref
                .read(desktopBiometricControllerProvider.notifier)
                .isSupportedPlatform)
              SettingsGroup(
                title: t.settingsPage.groupAppLock,
                children: [
                  SettingsSwitchRow(
                    id: 'privacy.appLock',
                    label: t.settingsPage.biometricLock,
                    detail: t.settingsPage.biometricLockDetail,
                    value: biometric.enabled,
                    onChanged: (value) =>
                        unawaited(_setBiometricLock(context, ref, value)),
                  ),
                ],
              ),
            if (!isPrivateMode)
              SettingsGroup(
                title: t.settingsPage.groupDiagnosticsConsent,
                children: [
                  SettingsSwitchRow(
                    id: 'privacy.crashReports',
                    label: t.settingsPage.sendCrashReports,
                    detail: t.settingsPage.sendCrashReportsDetail,
                    value: ref
                        .watch(settingsFormControllerProvider)
                        .crashReports,
                    onChanged: ref
                        .read(settingsFormControllerProvider.notifier)
                        .setCrashReports,
                  ),
                ],
              ),
            SettingsGroup(
              title: t.settingsPage.systemPermissionsTitle,
              children: [
                SettingsActionRow(
                  id: 'privacy.systemPermissions',
                  title: t.settingsPage.systemPermissionsManagement,
                  detail: t.settingsPage.systemPermissionsManagementDetail,
                  external: true,
                  onTap: () => unawaited(_openSystemPermissions(context)),
                ),
              ],
            ),
            // These existed only inside the Pro purchase surface, which is
            // filtered out of the rail entirely in Private mode — so a
            // Private-mode user could not reach the privacy policy from
            // Settings at all. They stay in the paywall too, for App Store
            // compliance.
            SettingsGroup(
              title: t.settingsPage.groupLegal,
              children: [
                SettingsActionRow(
                  id: 'privacy.privacyPolicy',
                  title: t.settingsPage.privacyPolicy,
                  external: true,
                  onTap: () => unawaited(
                    launchUrl(
                      privacyPolicy,
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
                SettingsActionRow(
                  id: 'privacy.terms',
                  title: t.settingsPage.termsEula,
                  external: true,
                  onTap: () => unawaited(
                    launchUrl(
                      LegalUrls.appleEula,
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _setBiometricLock(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final changed = await ref
        .read(desktopBiometricControllerProvider.notifier)
        .setEnabled(value);
    if (!context.mounted) return;
    if (!changed) {
      final message = ref.read(desktopBiometricControllerProvider).errorMessage;
      showSettingsGate(
        context,
        t.settingsPage.biometricLock,
        message ?? t.settingsPage.biometricActivationCancelled,
      );
    }
  }

  Future<void> _openSystemPermissions(BuildContext context) async {
    try {
      await DesktopSystemSettingsService.openPermissions();
    } catch (error, stack) {
      AppLogger.error('Unable to open system permissions', error, stack);
      if (context.mounted) {
        showSettingsGate(
          context,
          t.settingsPage.systemPermissionsTitle,
          t.settingsPage.systemPermissionsOpenFailed,
        );
      }
    }
  }
}
