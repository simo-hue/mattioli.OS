import 'package:evolve_desktop/core/desktop_backup_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/settings/application/desktop_biometric_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:evolve_desktop/features/settings/data/desktop_system_settings_service.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/rtl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum _SettingsSection {
  profile,
  appearance,
  notifications,
  privacy,
  subscription,
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _SettingsSection _section = _SettingsSection.profile;
  bool _darkMode = true;
  bool _timeFormat24h = true;
  bool _habitReminders = true;
  bool _eveningReview = true;
  bool _goalDeadlines = true;
  bool _aiInsights = true;
  bool _weeklyReport = true;
  bool _crashReports = true;
  String _calendarView = 'Settimana';
  String _language = 'Sistema';
  String _morningTime = '08:00';
  String _eveningTime = '20:30';
  Color _accent = EvolveColors.primaryStrong;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    final preferences = ref.read(sharedPreferencesProvider);
    final appearance = ref.read(desktopAppearanceControllerProvider);
    _darkMode = appearance.themeMode != ThemeMode.light;
    _accent = appearance.accentColor;
    if (preferences == null) return;
    _timeFormat24h = preferences.getBool('pref_time_format_24h') ?? true;
    _habitReminders = preferences.getBool('notif_habit_reminders') ?? true;
    _eveningReview = preferences.getBool('notif_evening_review') ?? true;
    _goalDeadlines = preferences.getBool('notif_goal_deadlines') ?? true;
    _aiInsights = preferences.getBool('notif_ai_insights') ?? true;
    _weeklyReport = preferences.getBool('notif_weekly_reports') ?? true;
    _crashReports = preferences.getBool('has_sentry_consent') ?? true;
    _calendarView =
        preferences.getString('pref_default_calendar_view') ?? 'Settimana';
    _language = _languageLabel(
      preferences.getString('pref_language') ??
          preferences.getString('language'),
    );
    _morningTime =
        preferences.getString('notif_morning_brief_time') ??
        preferences.getString('morning_brief_time') ??
        '09:00';
    _eveningTime =
        preferences.getString('notif_evening_review_time') ??
        preferences.getString('evening_review_time') ??
        '21:00';
    unawaited(_loadProfilePreferences());
  }

  @override
  Widget build(BuildContext context) {
    final dataMode = ref.watch(activeDesktopDataModeProvider);
    final isPrivateMode = dataMode.isPrivate;

    // Filter available sections based on mode
    final availableSections = _SettingsSection.values.where((section) {
      if (isPrivateMode && section == _SettingsSection.subscription) {
        return false;
      }
      return true;
    }).toList();

    return DesktopPage(
      title: t.settingsPage.pageTitle,
      subtitle: t.settingsPage.pageSubtitle,
      child: EvolvePanel(
        padding: EdgeInsets.zero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 225,
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  children: [
                    for (final section in availableSections)
                      _SettingsDestination(
                        section: section,
                        selected: section == _section,
                        onTap: () => setState(() => _section = section),
                      ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: switch (_section) {
                  _SettingsSection.profile => _profile(),
                  _SettingsSection.appearance => _appearance(),
                  _SettingsSection.notifications => _notifications(),
                  _SettingsSection.privacy => _privacy(),
                  _SettingsSection.subscription =>
                    const _SubscriptionSettings(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profile() {
    final auth = ref.watch(desktopAuthControllerProvider);
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.profileLabel,
          subtitle: t.settingsPage.profileSubtitle,
        ),
        const SizedBox(height: 17),
        _ProfileCard(
          user: auth.user,
          image: _profileImage,
          isPro: isPrivateMode
              ? false
              : ref.watch(desktopSubscriptionControllerProvider).isPro,
          onPickAvatar: _pickAvatar,
          isPrivateMode: isPrivateMode,
          privateProfile: isPrivateMode
              ? ref.watch(privateProfileProvider).value
              : null,
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: t.settingsPage.accountAndOnboarding,
          children: [
            _InfoRow(
              label: t.settingsPage.account,
              value: isPrivateMode
                  ? t.settingsPage.privateMode
                  : auth.user?.email ?? t.settingsPage.sessionUnavailable,
            ),
            _InfoRow(
              label: t.settingsPage.dataRepository,
              value: isPrivateMode
                  ? t.settingsPage.encryptedLocalDatabase
                  : t.settingsPage.supabaseWithEncryptedCache,
            ),
            if (!isPrivateMode) ...[
              _ActionRow(
                icon: Icons.badge_outlined,
                title: t.settingsPage.personalInfo,
                detail: t.settingsPage.personalInfoDetail,
                onTap: auth.isLoggedIn
                    ? () => showEvolveDialog<void>(
                        context: context,
                        builder: (context) => const _PersonalInfoDialog(),
                      )
                    : () => _showGate(
                        t.settingsPage.gateProfile,
                        t.settingsPage.gateRequiresActiveSession,
                      ),
              ),
              _ActionRow(
                icon: Icons.photo_camera_outlined,
                title: t.settingsPage.updateAvatar,
                detail: t.settingsPage.updateAvatarDetail,
                onTap: _pickAvatar,
              ),
              _ActionRow(
                icon: Icons.fact_check_outlined,
                title: t.settingsPage.reviewInitialConsent,
                detail: t.settingsPage.reviewInitialConsentDetail,
                onTap: _reviewConsent,
              ),
              _ActionRow(
                icon: Icons.logout_rounded,
                title: t.settingsPage.signOut,
                detail: auth.isLoggedIn
                    ? t.settingsPage.signOutDetailActive
                    : t.settingsPage.availableWithActiveSession,
                destructive: true,
                onTap: auth.isLoggedIn
                    ? () => _confirmSignOut()
                    : () => _showGate(
                        t.settingsPage.gateLogout,
                        t.settingsPage.gateRequiresActiveSession,
                      ),
              ),
            ] else ...[
              _ActionRow(
                icon: Icons.login_outlined,
                title: t.settingsPage.goToLogin,
                detail: t.settingsPage.goToLoginDetail,
                onTap: () {
                  ref.read(desktopAuthControllerProvider.notifier).goToLogin();
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _appearance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.appearanceTitle,
          subtitle: t.settingsPage.appearanceSubtitle,
        ),
        const SizedBox(height: 17),
        _SettingsGroup(
          title: t.settingsPage.appearanceAndVisual,
          children: [
            _SwitchRow(
              label: t.settingsPage.darkMode,
              detail: t.settingsPage.darkModeDetail,
              value: _darkMode,
              onChanged: (value) {
                ref
                    .read(desktopAppearanceControllerProvider.notifier)
                    .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
                _setBool(
                  'desktop_dark_mode',
                  value,
                  () => _darkMode = value,
                  profileColumn: 'theme_mode',
                  profileValue: value ? 'dark' : 'light',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: t.settingsPage.calendarExperienceLanguage,
          children: [
            _ColorRow(
              label: t.settingsPage.accentColor,
              detail: t.settingsPage.accentColorDetail,
              selected: _accent,
              onChanged: (color) {
                ref
                    .read(desktopAppearanceControllerProvider.notifier)
                    .setAccentColor(color);
                final accent = ref.read(
                  desktopAppearanceControllerProvider.select(
                    (appearance) => appearance.accentColor,
                  ),
                );
                setState(() => _accent = accent);
                unawaited(
                  _syncProfile({'accent_color': dashboardColorToHex(accent)}),
                );
              },
            ),
            _SelectRow(
              label: t.settingsPage.defaultCalendarView,
              value: _calendarView,
              options: const ['Mese', 'Settimana', 'Anno', 'Vita'],
              onChanged: (value) => _setString(
                'pref_default_calendar_view',
                value,
                () => _calendarView = value,
                profileColumn: 'pref_default_calendar_view',
                profileValue: _calendarProfileValue(value),
              ),
            ),
            _SelectRow(
              label: t.settingsPage.language,
              value: _language,
              options: const [
                'Sistema',
                'Italiano',
                'English',
                'Espanol',
                'Deutsch',
                'Arabic',
              ],
              onChanged: (value) => _setString(
                'pref_language',
                value,
                () {
                  _language = value;
                  ref
                      .read(desktopLocaleControllerProvider.notifier)
                      .setLanguage(_languageProfileValue(value));
                },
                profileColumn: 'language',
                profileValue: _languageProfileValue(value),
              ),
            ),
            _SwitchRow(
              label: t.settingsPage.timeFormat24h,
              detail: t.settingsPage.timeFormat24hDetail,
              value: _timeFormat24h,
              onChanged: (value) => _setBool(
                'pref_time_format_24h',
                value,
                () => _timeFormat24h = value,
                profileColumn: 'pref_time_format_24h',
              ),
            ),
            _SwitchRow(
              label: t.settingsPage.hapticFeedback,
              detail: t.settingsPage.hapticFeedbackDetail,
              value:
                  ref
                      .read(sharedPreferencesProvider)
                      ?.getBool('pref_haptic_feedback') ??
                  true,
              onChanged: (value) => _setBool(
                'pref_haptic_feedback',
                value,
                () {},
                profileColumn: 'pref_haptic_feedback',
              ),
            ),
            _ActionRow(
              icon: Icons.restart_alt_rounded,
              title: t.settingsPage.resetTutorial,
              detail: t.settingsPage.resetTutorialDetail,
              onTap: _resetTutorials,
            ),
          ],
        ),
      ],
    );
  }

  Widget _notifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.notifications,
          subtitle: t.settingsPage.notificationsSubtitle,
        ),
        const SizedBox(height: 17),
        _SettingsGroup(
          title: t.settingsPage.operationalReminders,
          children: [
            _SwitchRow(
              label: t.settingsPage.habitReminders,
              detail: t.settingsPage.habitRemindersDetail,
              value: _habitReminders,
              onChanged: (value) => _setNotificationBool(
                key: 'notif_habit_reminders',
                value: value,
                update: () => _habitReminders = value,
                profileColumn: 'notif_habit_reminders',
                requestPermissions: value,
              ),
            ),
            if (_habitReminders)
              _TimeRow(
                label: t.settingsPage.morningBriefTime,
                value: _morningTime,
                use24hFormat: _timeFormat24h,
                onChanged: (value) => _setNotificationString(
                  'notif_morning_brief_time',
                  value,
                  () => _morningTime = value,
                  profileColumn: 'morning_brief_time',
                ),
              ),
            _SwitchRow(
              label: t.settingsPage.eveningReview,
              detail: t.settingsPage.eveningReviewDetail,
              value: _eveningReview,
              onChanged: (value) => _setNotificationBool(
                key: 'notif_evening_review',
                value: value,
                update: () => _eveningReview = value,
                profileColumn: 'notif_evening_review',
                requestPermissions: value,
              ),
            ),
            if (_eveningReview)
              _TimeRow(
                label: t.settingsPage.eveningReviewTime,
                value: _eveningTime,
                use24hFormat: _timeFormat24h,
                onChanged: (value) => _setNotificationString(
                  'notif_evening_review_time',
                  value,
                  () => _eveningTime = value,
                  profileColumn: 'evening_review_time',
                ),
              ),
            _ActionRow(
              icon: Icons.notifications_active_outlined,
              title: t.settingsPage.requestNotificationPermissions,
              detail: t.settingsPage.requestNotificationPermissionsDetail,
              onTap: _requestNotificationPermissions,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _PlatformNote(
          title: t.settingsPage.nativeDeliveryTitle,
          detail: DesktopNotificationService.instance.platformSummary,
        ),
      ],
    );
  }

  Widget _privacy() {
    final biometric = ref.watch(desktopBiometricControllerProvider);
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.privacyTitle,
          subtitle: t.settingsPage.privacySubtitle,
        ),
        const SizedBox(height: 17),
        _SettingsGroup(
          title: t.settingsPage.accessProtection,
          children: [
            _SwitchRow(
              label: t.settingsPage.biometricLock,
              detail: t.settingsPage.biometricLockDetail,
              value: biometric.enabled,
              onChanged: _setBiometricLock,
            ),
            if (!isPrivateMode)
              _ActionRow(
                icon: Icons.key_outlined,
                title: t.settingsPage.changePassword,
                detail: t.settingsPage.changePasswordDetail,
                onTap: ref.watch(desktopAuthControllerProvider).isLoggedIn
                    ? () => showEvolveDialog<void>(
                        context: context,
                        builder: (context) => const _ChangePasswordDialog(),
                      )
                    : () => _showGate(
                        t.settingsPage.gateChangePassword,
                        t.settingsPage.gateRequiresActiveSession,
                      ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: t.settingsPage.dataAndConsents,
          children: [
            if (!isPrivateMode)
              _SwitchRow(
                label: t.settingsPage.sendCrashReports,
                detail: t.settingsPage.sendCrashReportsDetail,
                value: _crashReports,
                onChanged: _setCrashReportingConsent,
              ),
            _ActionRow(
              icon: Icons.download_outlined,
              title: t.settingsPage.exportData,
              detail: t.settingsPage.exportDataDetail,
              onTap: _exportData,
            ),
            _ActionRow(
              icon: Icons.upload_outlined,
              title: t.settingsPage.importData,
              detail: t.settingsPage.importDataDetail,
              onTap: _importData,
            ),
            _ActionRow(
              icon: Icons.settings_outlined,
              title: t.settingsPage.systemPermissionsManagement,
              detail: t.settingsPage.systemPermissionsManagementDetail,
              onTap: _openSystemPermissions,
            ),
            if (isPrivateMode)
              _ActionRow(
                icon: Icons.delete_forever_outlined,
                title: t.settingsPage.deletePrivateData,
                detail: t.settingsPage.deletePrivateDataDetail,
                destructive: true,
                onTap: _deletePrivateData,
              )
            else
              _ActionRow(
                icon: Icons.delete_forever_outlined,
                title: t.settingsPage.deleteAccountAndData,
                detail: t.settingsPage.deleteAccountAndDataDetail,
                destructive: true,
                onTap: _showDeleteOrResetDialog,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportData() async {
    // Private mode: export the full local data space from the encrypted DB
    // (profile, habits, logs, macro goals, categories, moods).
    if (ref.read(activeDesktopDataModeProvider).isPrivate) {
      final payload = await DesktopPrivateDb.instance.exportData();
      final privateJson = const JsonEncoder.withIndent('  ').convert(payload);
      if (Platform.isLinux) {
        await Clipboard.setData(ClipboardData(text: privateJson));
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                utf8.encode(privateJson),
                mimeType: 'application/json',
              ),
            ],
            fileNameOverrides: const ['evolve_private_export.json'],
            text: t.settingsPage.exportPrivateShareText,
          ),
        );
      }
      if (!mounted) return;
      _showGate(
        t.privateData.exportDoneTitle,
        Platform.isLinux
            ? t.privateData.exportDoneClipboard
            : t.privateData.exportDoneShare,
      );
      return;
    }
    final snapshot = ref.read(dashboardControllerProvider);
    final json = const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'source': 'evolve-desktop-supabase-cache',
      'settings': {
        'themeMode': _darkMode ? 'dark' : 'light',
        'accentColor': dashboardColorToHex(_accent),
        'defaultCalendarView': _calendarProfileValue(_calendarView),
        'language': _languageProfileValue(_language),
        'timeFormat24h': _timeFormat24h,
        'habitReminders': _habitReminders,
        'goalDeadlines': _goalDeadlines,
        'aiInsights': _aiInsights,
        'weeklyReports': _weeklyReport,
        'eveningReview': _eveningReview,
        'biometricLock': ref.read(desktopBiometricControllerProvider).enabled,
        'morningBriefTime': _morningTime,
        'eveningReviewTime': _eveningTime,
      },
      'habits': [
        for (final habit in snapshot.habits)
          {
            'id': habit.id,
            'title': habit.title,
            'category': habit.category,
            'weekly_progress': habit.weeklyProgress,
            'reminder_time': habit.reminderTime,
          },
      ],
      'goals': [
        for (final goal in snapshot.goals)
          {
            'id': goal.id,
            'title': goal.title,
            'state': goal.state.name,
            'type': goal.type.name,
          },
      ],
      'habitLogs': snapshot.habitLogs,
      'moods': {
        for (final entry in snapshot.moods.entries)
          entry.key: entry.value.toJson(),
      },
    });
    if (Platform.isLinux) {
      await Clipboard.setData(ClipboardData(text: json));
    } else {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(utf8.encode(json), mimeType: 'application/json'),
          ],
          fileNameOverrides: const ['mattioli_os_export.json'],
          text: t.settingsPage.exportShareText,
        ),
      );
    }
    if (!mounted) return;
    _showGate(
      t.settingsPage.exportDoneTitle,
      Platform.isLinux
          ? t.settingsPage.exportDoneClipboard
          : t.settingsPage.exportDoneShare,
    );
  }

  Future<void> _signOut() async {
    try {
      await ref.read(desktopAuthControllerProvider.notifier).signOut();
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;

      final isPrivateMode = ref.read(activeDesktopDataModeProvider).isPrivate;
      if (isPrivateMode) {
        final supportDir = await getApplicationSupportDirectory();
        final avatarDir = Directory(p.join(supportDir.path, 'private_profile'));
        await avatarDir.create(recursive: true);
        final avatarFile = File(
          p.join(avatarDir.path, 'avatar${p.extension(image.path)}'),
        );
        final selectedFile = await File(image.path).copy(avatarFile.path);
        await ref
            .read(privateProfileProvider.notifier)
            .updateAvatar(selectedFile.path);
        setState(() => _profileImage = selectedFile);
      } else {
        setState(() => _profileImage = File(image.path));
      }
    } catch (error, stack) {
      AppLogger.error('Unable to pick desktop avatar', error, stack);
      if (mounted) {
        _showGate(
          t.settingsPage.avatarGateTitle,
          t.settingsPage.avatarPickFailed,
        );
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await _confirm(
      title: t.settingsPage.confirmSignOutTitle,
      message: t.settingsPage.confirmSignOutMessage,
      destructive: true,
    );
    if (confirmed) await _signOut();
  }

  Future<void> _setBiometricLock(bool value) async {
    final changed = await ref
        .read(desktopBiometricControllerProvider.notifier)
        .setEnabled(value);
    if (!mounted) return;
    if (!changed) {
      final message = ref.read(desktopBiometricControllerProvider).errorMessage;
      _showGate(
        t.settingsPage.biometricLock,
        message ?? t.settingsPage.biometricActivationCancelled,
      );
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final granted = await DesktopNotificationService.instance
        .requestPermissions();
    if (!mounted) return;
    _showGate(
      t.settingsPage.notificationPermissionsTitle,
      granted
          ? t.settingsPage.notificationPermissionsGranted
          : t.settingsPage.notificationPermissionsDenied,
    );
  }

  void _setNotificationBool({
    required String key,
    required bool value,
    required VoidCallback update,
    required String profileColumn,
    bool requestPermissions = false,
  }) {
    _setBool(key, value, update, profileColumn: profileColumn);
    if (requestPermissions) {
      unawaited(DesktopNotificationService.instance.requestPermissions());
    }
    unawaited(_syncNotifications());
  }

  void _setNotificationString(
    String key,
    String value,
    VoidCallback update, {
    required String profileColumn,
  }) {
    _setString(key, value, update, profileColumn: profileColumn);
    unawaited(_syncNotifications());
  }

  Future<void> _syncNotifications() async {
    await DesktopNotificationService.instance.sync(
      habitReminders: _habitReminders,
      eveningReview: _eveningReview,
      morningBriefTime: _morningTime,
      eveningReviewTime: _eveningTime,
      habits: ref.read(dashboardControllerProvider).habits,
    );
  }

  Future<void> _openSystemPermissions() async {
    try {
      await DesktopSystemSettingsService.openPermissions();
    } catch (error, stack) {
      AppLogger.error('Unable to open system permissions', error, stack);
      if (mounted) {
        _showGate(
          t.settingsPage.systemPermissionsTitle,
          t.settingsPage.systemPermissionsOpenFailed,
        );
      }
    }
  }

  Future<void> _resetTutorials() async {
    await Future.wait([
      ref.read(tutorialProvider.notifier).setTutorialSeen(false),
      ref.read(goalsTutorialProvider.notifier).setTutorialSeen(false),
      ref.read(statsTutorialProvider.notifier).setTutorialSeen(false),
    ]);
    if (mounted) {
      _showGate(
        t.settingsPage.tutorialResetTitle,
        t.settingsPage.tutorialResetMessage,
      );
    }
  }

  Future<void> _showDeleteOrResetDialog() async {
    final action = await showEvolveDialog<String>(
      context: context,
      builder: (context) => EvolveAlertDialog(
        icon: Icons.manage_accounts_outlined,
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
    if (!mounted || action == null) return;
    if (action == 'reset') {
      final confirmed = await _confirm(
        title: t.settingsPage.confirmResetDataTitle,
        message: t.settingsPage.confirmResetDataMessage,
        destructive: true,
      );
      if (confirmed) await _resetData();
      return;
    }

    final confirmed = await _confirm(
      title: t.settingsPage.confirmDeleteAccountTitle,
      message: t.settingsPage.confirmDeleteAccountMessage,
      destructive: true,
    );
    if (confirmed) await _deleteAccount();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    bool destructive = false,
  }) async {
    return await showEvolveDialog<bool>(
          context: context,
          builder: (context) => EvolveAlertDialog(
            icon: destructive
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            iconColor: destructive ? EvolveColors.rose : null,
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t.settingsPage.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: destructive
                    ? FilledButton.styleFrom(backgroundColor: EvolveColors.rose)
                    : null,
                child: Text(t.settingsPage.confirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _resetData() async {
    try {
      await ref.read(dashboardControllerProvider.notifier).resetData();
      await _resetSettingsToDefaults();
      if (mounted) {
        _showGate(
          t.settingsPage.resetDataTitle,
          t.settingsPage.resetDataSuccess,
        );
      }
    } catch (error, stack) {
      AppLogger.error('Unable to reset desktop data', error, stack);
      if (mounted) {
        _showGate(
          t.settingsPage.resetDataTitle,
          t.settingsPage.operationFailed,
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (!ref.read(desktopAuthControllerProvider).isLoggedIn) {
      _showGate(
        t.settingsPage.deleteAccountGateTitle,
        t.settingsPage.gateRequiresActiveSession,
      );
      return;
    }
    try {
      await ref.read(desktopAuthControllerProvider.notifier).deleteAccount();
      if (mounted) {
        _showGate(
          t.settingsPage.deleteAccountGateTitle,
          t.settingsPage.accountDeleted,
        );
      }
    } catch (error, stack) {
      AppLogger.error('Unable to delete desktop account', error, stack);
      if (mounted) {
        _showGate(
          t.settingsPage.deleteAccountGateTitle,
          t.settingsPage.operationFailed,
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      final isPrivateMode =
          ref.read(activeDesktopDataModeProvider) == DesktopDataMode.private;
      if (!isPrivateMode) {
        _showGate(
          t.settingsPage.importDataGateTitle,
          t.settingsPage.importPrivateOnly,
        );
        return;
      }

      final privateStore = DesktopPrivateDb.instance;
      final importService = DesktopBackupImportService(privateStore, null);

      // 1. Preview
      final preview = await importService.parseZipPreview(path);

      if (!mounted) return;

      // 2. Ask for Replace/Merge
      bool replaceExisting = true;
      final confirm = await showEvolveDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: context.evolveColors.background,
                title: Text(
                  t.settingsPage.importSummaryTitle,
                  style: TextStyle(
                    color: context.evolveColors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ${t.settingsPage.importHabitsCount(count: preview.habitsCount)}',
                        style: TextStyle(
                          color: context.evolveColors.foreground,
                        ),
                      ),
                      Text(
                        '• ${t.settingsPage.importLogsCount(count: preview.logsCount)}',
                        style: TextStyle(
                          color: context.evolveColors.foreground,
                        ),
                      ),
                      Text(
                        '• ${t.settingsPage.importMacroGoalsCount(count: preview.macroGoalsCount)}',
                        style: TextStyle(
                          color: context.evolveColors.foreground,
                        ),
                      ),
                      Text(
                        '• ${t.settingsPage.importCategoriesCount(count: preview.categoriesCount)}',
                        style: TextStyle(
                          color: context.evolveColors.foreground,
                        ),
                      ),
                      Text(
                        '• ${t.settingsPage.importMoodsCount(count: preview.moodsCount)}',
                        style: TextStyle(
                          color: context.evolveColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 24),
                      RadioListTile<bool>(
                        title: Text(
                          t.settingsPage.importReplaceTitle,
                          style: TextStyle(
                            color: context.evolveColors.foreground,
                          ),
                        ),
                        subtitle: Text(
                          t.settingsPage.importReplaceSubtitle,
                          style: TextStyle(
                            color: context.evolveColors.foreground.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 12,
                          ),
                        ),
                        value: true,
                        groupValue: replaceExisting,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (val) =>
                            setState(() => replaceExisting = val!),
                      ),
                      RadioListTile<bool>(
                        title: Text(
                          t.settingsPage.importMergeTitle,
                          style: TextStyle(
                            color: context.evolveColors.foreground,
                          ),
                        ),
                        subtitle: Text(
                          t.settingsPage.importMergeSubtitle,
                          style: TextStyle(
                            color: context.evolveColors.foreground.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 12,
                          ),
                        ),
                        value: false,
                        groupValue: replaceExisting,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (val) =>
                            setState(() => replaceExisting = val!),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      t.settingsPage.cancel,
                      style: TextStyle(
                        color: context.evolveColors.foreground.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(t.settingsPage.importConfirmButton),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirm != true) return;
      if (!mounted) return;

      // 3. Execute
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.evolveColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(t.settingsPage.importInProgress),
                ],
              ),
            ),
          ),
        ),
      );

      await importService.executeImport(
        rawData: preview.rawData,
        replaceExisting: replaceExisting,
        isPrivateMode: true,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.settingsPage.importSuccess),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh dashboard
      ref.invalidate(dashboardControllerProvider);
    } catch (e, st) {
      AppLogger.error('Errore durante importData', e, st);
      if (!mounted) return;
      // Close loading if still open
      if (Navigator.canPop(context)) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.settingsPage.importError(error: e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePrivateData() async {
    final confirmed = await _confirm(
      title: t.privateData.deleteTitle,
      message: t.privateData.deleteMessage,
      destructive: true,
    );
    if (!confirmed) return;

    try {
      // Wipe all private data but stay in Private mode with a fresh, empty
      // profile (mirrors the mobile client — non-destructive to the mode).
      await DesktopPrivateDb.instance.deleteAllPrivateData();
      await ref.read(dashboardControllerProvider.notifier).refresh();
      ref.invalidate(privateProfileProvider);
      ref.invalidate(desktopGoalCategoriesControllerProvider);
      if (mounted) {
        _showGate(t.privateData.deleteTitle, t.privateData.deleteSuccess);
      }
    } catch (error, stack) {
      AppLogger.error('Unable to delete private database', error, stack);
      if (mounted) {
        _showGate(t.privateData.deleteTitle, t.privateData.deleteFailed);
      }
    }
  }

  Future<void> _resetSettingsToDefaults() async {
    final preferences = ref.read(sharedPreferencesProvider);
    final keys = preferences?.getKeys().where(
      (key) => key.startsWith('pref_') || key.startsWith('notif_'),
    );
    if (preferences != null && keys != null) {
      await Future.wait([for (final key in keys) preferences.remove(key)]);
    }
    ref
        .read(desktopAppearanceControllerProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    ref
        .read(desktopAppearanceControllerProvider.notifier)
        .setAccentColor(DesktopAppearanceController.defaultAccent);
    setState(() {
      _darkMode = true;
      _accent = DesktopAppearanceController.defaultAccent;
      _calendarView = 'Settimana';
      _language = 'Sistema';
      _timeFormat24h = true;
      _habitReminders = true;
      _goalDeadlines = true;
      _aiInsights = false;
      _weeklyReport = false;
      _eveningReview = true;
      _morningTime = '09:00';
      _eveningTime = '21:00';
    });
    await ref
        .read(desktopBiometricControllerProvider.notifier)
        .setEnabled(false);
    await _syncProfile({
      'theme_mode': 'dark',
      'accent_color': '#FAFAFA',
      'pref_default_calendar_view': 'settimana',
      'pref_haptic_feedback': true,
      'language': 'system',
      'pref_time_format_24h': true,
      'notif_habit_reminders': true,
      'notif_goal_deadlines': true,
      'notif_ai_insights': false,
      'notif_weekly_reports': false,
      'notif_evening_review': true,
      'biometric_lock': false,
      'morning_brief_time': '09:00',
      'evening_review_time': '21:00',
    });
    await _syncNotifications();
  }

  Future<void> _reviewConsent() async {
    final consent = ref.read(desktopConsentControllerProvider);
    await ref
        .read(desktopConsentControllerProvider.notifier)
        .setConsent(
          acceptedTerms: false,
          sentryConsent: consent.hasSentryConsent,
          completed: false,
        );
  }

  Future<void> _setCrashReportingConsent(bool value) async {
    final consent = ref.read(desktopConsentControllerProvider);
    setState(() => _crashReports = value);
    await ref
        .read(desktopConsentControllerProvider.notifier)
        .setConsent(
          acceptedTerms: consent.hasAcceptedTerms,
          sentryConsent: value,
          completed: consent.hasCompletedOnboarding,
        );
  }

  void _setBool(
    String key,
    bool value,
    VoidCallback update, {
    String? profileColumn,
    Object? profileValue,
  }) {
    setState(update);
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences != null) unawaited(preferences.setBool(key, value));
    if (profileColumn != null) {
      unawaited(_syncProfile({profileColumn: profileValue ?? value}));
    }
  }

  void _setString(
    String key,
    String value,
    VoidCallback update, {
    String? profileColumn,
    Object? profileValue,
  }) {
    setState(update);
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences != null) unawaited(preferences.setString(key, value));
    if (profileColumn != null) {
      unawaited(_syncProfile({profileColumn: profileValue ?? value}));
    }
  }

  Future<void> _loadProfilePreferences() async {
    final client = ref.read(supabaseClientProvider);
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      final profile = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || profile == null) return;
      ref
          .read(desktopAppearanceControllerProvider.notifier)
          .applyProfile(
            themeMode: profile['theme_mode'] as String?,
            accentColor: profile['accent_color'] as String?,
          );
      final appearance = ref.read(desktopAppearanceControllerProvider);
      setState(() {
        _darkMode = appearance.themeMode != ThemeMode.light;
        _timeFormat24h =
            profile['pref_time_format_24h'] as bool? ?? _timeFormat24h;
        _habitReminders =
            profile['notif_habit_reminders'] as bool? ?? _habitReminders;
        _eveningReview =
            profile['notif_evening_review'] as bool? ?? _eveningReview;
        _goalDeadlines =
            profile['notif_goal_deadlines'] as bool? ?? _goalDeadlines;
        _aiInsights = profile['notif_ai_insights'] as bool? ?? _aiInsights;
        _weeklyReport =
            profile['notif_weekly_reports'] as bool? ?? _weeklyReport;
        _calendarView = _calendarLabel(
          profile['pref_default_calendar_view'] as String?,
        );
        _language = _languageLabel(profile['language'] as String?);
        _morningTime = profile['morning_brief_time'] as String? ?? _morningTime;
        _eveningTime =
            profile['evening_review_time'] as String? ?? _eveningTime;
        _accent = appearance.accentColor;
      });
      final preferences = ref.read(sharedPreferencesProvider);
      if (preferences != null) {
        await Future.wait([
          preferences.setBool('desktop_dark_mode', _darkMode),
          preferences.setBool('pref_time_format_24h', _timeFormat24h),
          preferences.setBool('notif_habit_reminders', _habitReminders),
          preferences.setBool('notif_evening_review', _eveningReview),
          preferences.setBool('notif_goal_deadlines', _goalDeadlines),
          preferences.setBool('notif_ai_insights', _aiInsights),
          preferences.setBool('notif_weekly_reports', _weeklyReport),
          preferences.setString('pref_default_calendar_view', _calendarView),
          preferences.setString(
            'pref_language',
            _languageProfileValue(_language),
          ),
          preferences.setString('notif_morning_brief_time', _morningTime),
          preferences.setString('notif_evening_review_time', _eveningTime),
          preferences.setInt('accent_color', _accent.toARGB32()),
        ]);
      }
      final biometric = profile['biometric_lock'] as bool?;
      if (biometric != null) {
        await ref
            .read(desktopBiometricControllerProvider.notifier)
            .applyProfile(biometric);
      }
      await _syncNotifications();
    } catch (error, stack) {
      AppLogger.error('Unable to download desktop preferences', error, stack);
    }
  }

  Future<void> _syncProfile(Map<String, dynamic> values) async {
    // Private mode: persist settings to the encrypted DB profiles row (never
    // Supabase), keeping them Phase-2-sync-ready.
    if (ref.read(activeDesktopDataModeProvider).isPrivate) {
      await DesktopPrivateDb.instance.updateSettings(values);
      return;
    }
    final client = ref.read(supabaseClientProvider);
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      await client.from('profiles').upsert({'id': user.id, ...values});
    } catch (error, stack) {
      AppLogger.error('Unable to sync desktop preferences', error, stack);
    }
  }

  String _calendarProfileValue(String label) => switch (label) {
    'Mese' => 'mese',
    'Anno' => 'anno',
    'Vita' => 'vita',
    _ => 'settimana',
  };

  String _calendarLabel(String? value) => switch (value?.toLowerCase()) {
    'mese' || 'month' => 'Mese',
    'anno' || 'year' => 'Anno',
    'vita' || 'life' => 'Vita',
    _ => 'Settimana',
  };

  String _languageProfileValue(String label) => switch (label) {
    'Italiano' => 'it',
    'English' => 'en',
    'Espanol' => 'es',
    'Deutsch' => 'de',
    'Arabic' => 'ar',
    _ => 'system',
  };

  String _languageLabel(String? value) => switch (value?.toLowerCase()) {
    'it' => 'Italiano',
    'en' => 'English',
    'es' => 'Espanol',
    'de' => 'Deutsch',
    'ar' => 'Arabic',
    _ => 'Sistema',
  };

  void _showGate(String title, String detail) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title: $detail')));
  }
}

class _SettingsDestination extends StatelessWidget {
  const _SettingsDestination({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected
            ? context.evolveAccent.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                Icon(
                  section.icon,
                  color: selected
                      ? context.evolveAccent
                      : context.evolveColors.muted,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? context.evolveAccent
                          : context.evolveColors.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.evolveColors.panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 9),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _RowCopy(label: label, detail: detail),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<String>(
            value: value,
            items: [
              for (final option in options)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.use24hFormat,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool use24hFormat;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          OutlinedButton(
            onPressed: () async {
              final parts = value.split(':');
              final selected = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: int.tryParse(parts.first) ?? 9,
                  minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(alwaysUse24HourFormat: use24hFormat),
                  child: child!,
                ),
              );
              if (selected == null) return;
              onChanged(
                '${selected.hour.toString().padLeft(2, '0')}:'
                '${selected.minute.toString().padLeft(2, '0')}',
              );
            },
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final Color selected;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFFAFAFA),
      const Color(0xFFEAB308),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFFF97316),
    ].map((color) => _visibleAccent(context, color));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _RowCopy(label: label, detail: detail),
          ),
          SizedBox(
            width: 220,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in colors)
                  Tooltip(
                    message: t.settingsPage.useAccent(hex: _toHex(color)),
                    child: InkWell(
                      onTap: () => onChanged(color),
                      customBorder: const CircleBorder(),
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: color,
                        child: selected == color
                            ? Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: _checkColor(color),
                              )
                            : null,
                      ),
                    ),
                  ),
                Tooltip(
                  message: t.settingsPage.customColor,
                  child: InkWell(
                    onTap: () => _showFullColorPicker(context),
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: context.evolveColors.panelRaised,
                      child: Icon(
                        Icons.add_rounded,
                        size: 15,
                        color: context.evolveColors.foreground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFullColorPicker(BuildContext context) async {
    var color = selected;
    final picked = await showEvolveDialog<Color>(
      context: context,
      builder: (context) => EvolveAlertDialog(
        icon: Icons.palette_outlined,
        title: Text(t.settingsPage.accentColor),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: color,
            onColorChanged: (value) => color = value,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.settingsPage.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, color),
            child: Text(t.settingsPage.applyAction),
          ),
        ],
      ),
    );
    if (picked != null) onChanged(picked);
  }

  Color _visibleAccent(BuildContext context, Color color) {
    if (Theme.of(context).brightness == Brightness.light &&
        color.toARGB32() == 0xFFFAFAFA) {
      return const Color(0xFF09090B);
    }
    return color;
  }

  Color _checkColor(Color color) =>
      color.computeLuminance() > 0.45 ? const Color(0xFF09090B) : Colors.white;

  String _toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? EvolveColors.rose
        : context.evolveColors.foreground;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: _RowCopy(label: title, detail: detail, color: color),
            ),
            DirectionalIcon(
              Icons.chevron_right_rounded,
              Icons.chevron_left_rounded,
              color: context.evolveColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: context.evolveColors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowCopy extends StatelessWidget {
  const _RowCopy({required this.label, required this.detail, this.color});

  final String label;
  final String detail;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color ?? context.evolveColors.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.user,
    required this.image,
    required this.isPro,
    required this.onPickAvatar,
    this.isPrivateMode = false,
    this.privateProfile,
  });

  final User? user;
  final File? image;
  final bool isPro;
  final VoidCallback onPickAvatar;
  final bool isPrivateMode;
  final PrivateProfileState? privateProfile;

  @override
  Widget build(BuildContext context) {
    final metadata = user?.userMetadata;
    final fullName = isPrivateMode
        ? privateProfile?.fullName
        : (metadata?['full_name'] as String?)?.trim();
    final avatarUrl = isPrivateMode
        ? privateProfile?.avatarPath
        : metadata?['avatar_url'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.evolveColors.panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onPickAvatar,
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: context.evolveAccent.withValues(alpha: 0.13),
              backgroundImage: image != null
                  ? FileImage(image!)
                  : avatarUrl != null
                  ? (isPrivateMode
                            ? FileImage(File(avatarUrl))
                            : NetworkImage(avatarUrl))
                        as ImageProvider
                  : null,
              child: image == null && avatarUrl == null
                  ? Icon(
                      Icons.person_outline_rounded,
                      color: context.evolveAccent,
                    )
                  : null,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPrivateMode
                      ? t.settingsPage.privateMode
                      : fullName?.isNotEmpty ?? false
                      ? fullName!
                      : user?.email?.split('@').first ??
                            t.settingsPage.profileFallback,
                  style: TextStyle(
                    color: context.evolveColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isPrivateMode
                      ? t.settingsPage.privateModeDataProtected
                      : user?.email ?? t.settingsPage.sessionUnavailable,
                  style: TextStyle(
                    color: context.evolveColors.subtle,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isPro)
            const StatusPill(
              label: 'PRO',
              color: EvolveColors.amber,
              icon: Icons.workspace_premium_outlined,
            )
          else
            StatusPill(
              label: user == null
                  ? t.settingsPage.notAuthenticated
                  : t.settingsPage.verified,
              color: user == null ? EvolveColors.amber : context.evolveAccent,
              icon: user == null
                  ? Icons.lock_outline_rounded
                  : Icons.verified_outlined,
            ),
        ],
      ),
    );
  }
}

class _PlatformNote extends StatelessWidget {
  const _PlatformNote({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      color: const Color(0xFF151522),
      child: Row(
        children: [
          const Icon(Icons.devices_outlined, color: EvolveColors.violet),
          const SizedBox(width: 13),
          Expanded(
            child: _RowCopy(label: title, detail: detail),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionSettings extends ConsumerStatefulWidget {
  const _SubscriptionSettings();

  @override
  ConsumerState<_SubscriptionSettings> createState() =>
      _SubscriptionSettingsState();
}

class _SubscriptionSettingsState extends ConsumerState<_SubscriptionSettings> {
  String _plan = 'yearly';

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(desktopSubscriptionControllerProvider);
    final monthly = subscription.monthlyPackage;
    final yearly = subscription.yearlyPackage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.proTitle,
          subtitle: t.settingsPage.proSubtitle,
        ),
        const SizedBox(height: 17),
        _PlatformNote(
          title: subscription.isSupportedPlatform
              ? t.settingsPage.revenueCatMacos
              : t.settingsPage.commercialChannelRequired,
          detail: subscription.isSupportedPlatform
              ? subscription.isConfigured
                    ? t.settingsPage.revenueCatOffersRead
                    : t.settingsPage.revenueCatConfigureKey
              : t.settingsPage.revenueCatNotSupported,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _PlanCard(
                title: t.settingsPage.planMonthly,
                price:
                    monthly?.storeProduct.priceString ??
                    t.settingsPage.planMonthly,
                selected: _plan == 'monthly',
                onTap: () => setState(() => _plan = 'monthly'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _PlanCard(
                title: t.settingsPage.planAnnual,
                price:
                    yearly?.storeProduct.priceString ??
                    t.settingsPage.planAnnual,
                detail: t.settingsPage.bestValue,
                selected: _plan == 'yearly',
                onTap: () => setState(() => _plan = 'yearly'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          title: t.settingsPage.planManagement,
          children: [
            _ActionRow(
              icon: Icons.workspace_premium_outlined,
              title: t.settingsPage.activateEvolvePro,
              detail: subscription.isPro
                  ? t.settingsPage.activateEvolveProActive
                  : t.settingsPage.activateEvolveProStart,
              onTap: subscription.isLoading
                  ? () {}
                  : () {
                      final package = _plan == 'monthly' ? monthly : yearly;
                      if (package == null) {
                        unawaited(
                          ref
                              .read(
                                desktopSubscriptionControllerProvider.notifier,
                              )
                              .refresh(),
                        );
                        return;
                      }
                      unawaited(
                        ref
                            .read(
                              desktopSubscriptionControllerProvider.notifier,
                            )
                            .purchase(package),
                      );
                    },
            ),
            _ActionRow(
              icon: Icons.restore_rounded,
              title: t.settingsPage.restorePurchases,
              detail: t.settingsPage.restorePurchasesDetail,
              onTap: () => unawaited(
                ref
                    .read(desktopSubscriptionControllerProvider.notifier)
                    .restore(),
              ),
            ),
            _ActionRow(
              icon: Icons.manage_accounts_outlined,
              title: t.settingsPage.manageSubscription,
              detail: t.settingsPage.manageSubscriptionDetail,
              onTap: () => unawaited(
                ref
                    .read(desktopSubscriptionControllerProvider.notifier)
                    .manageSubscription(),
              ),
            ),
          ],
        ),
        if (subscription.message != null) ...[
          const SizedBox(height: 12),
          Text(subscription.message!),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String title;
  final String price;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? context.evolveAccent.withValues(alpha: 0.08)
              : context.evolveColors.panelRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? context.evolveAccent
                : context.evolveColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              price,
              style: TextStyle(
                color: context.evolveAccent,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 5),
              Text(detail!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonalInfoDialog extends ConsumerStatefulWidget {
  const _PersonalInfoDialog();

  @override
  ConsumerState<_PersonalInfoDialog> createState() =>
      _PersonalInfoDialogState();
}

class _PersonalInfoDialogState extends ConsumerState<_PersonalInfoDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _birthDateController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
    if (isPrivate) {
      final profile = ref.read(privateProfileProvider).value;
      _nameController = TextEditingController(text: profile?.fullName);
      _birthDateController = TextEditingController(text: profile?.dateOfBirth);
    } else {
      final user = ref.read(desktopAuthControllerProvider).user;
      _nameController = TextEditingController(
        text: user?.userMetadata?['full_name'] as String?,
      );
      _birthDateController = TextEditingController(
        text: user?.userMetadata?['date_of_birth'] as String?,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPrivate = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final email = ref.watch(desktopAuthControllerProvider).user?.email;
    return EvolveAlertDialog(
      icon: Icons.person_outline_rounded,
      title: Text(t.settingsPage.personalInfo),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: t.settingsPage.fullName),
            ),
            if (!isPrivate) ...[
              const SizedBox(height: 10),
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: t.settingsPage.email,
                  hintText: email ?? t.settingsPage.sessionUnavailable,
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _birthDateController,
              decoration: InputDecoration(
                labelText: t.settingsPage.dateOfBirth,
                hintText: t.settingsPage.dateOfBirthHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.settingsPage.cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t.settingsPage.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final birthDate = _birthDateController.text.trim();
    if (birthDate.isNotEmpty && DateTime.tryParse(birthDate) == null) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
      if (isPrivate) {
        await ref
            .read(privateProfileProvider.notifier)
            .updateProfile(fullName: name, dateOfBirth: birthDate);
      } else {
        await ref
            .read(desktopAuthControllerProvider.notifier)
            .updatePersonalInfo(fullName: name, dateOfBirth: birthDate);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      icon: Icons.lock_reset_rounded,
      title: Text(t.settingsPage.changePassword),
      content: SizedBox(
        width: 470,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.settingsPage.currentPassword,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.settingsPage.newPassword,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.settingsPage.confirmNewPassword,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: EvolveColors.rose)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.settingsPage.cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t.settingsPage.updatePassword),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_currentController.text.isEmpty) {
      setState(() => _error = t.settingsPage.enterCurrentPassword);
      return;
    }
    if (_newController.text.length < 8) {
      setState(() => _error = t.settingsPage.newPasswordMinLength);
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() => _error = t.settingsPage.passwordsDontMatch);
      return;
    }
    setState(() {
      _error = null;
      _isSaving = true;
    });
    try {
      await ref
          .read(desktopAuthControllerProvider.notifier)
          .updatePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = t.settingsPage.passwordUpdateFailed;
        });
      }
    }
  }
}

extension on _SettingsSection {
  String get label => switch (this) {
    _SettingsSection.profile => t.settingsPage.profileLabel,
    _SettingsSection.appearance => t.settingsPage.sectionApplication,
    _SettingsSection.notifications => t.settingsPage.notifications,
    _SettingsSection.privacy => t.settingsPage.sectionPrivacy,
    _SettingsSection.subscription => t.settingsPage.subscription,
  };

  IconData get icon => switch (this) {
    _SettingsSection.profile => Icons.person_outline_rounded,
    _SettingsSection.appearance => Icons.tune_rounded,
    _SettingsSection.notifications => Icons.notifications_outlined,
    _SettingsSection.privacy => Icons.shield_outlined,
    _SettingsSection.subscription => Icons.workspace_premium_outlined,
  };
}
