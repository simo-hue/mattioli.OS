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
import 'package:evolve_desktop/features/settings/presentation/app_logs_dialog.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
      // The group-card grid goes 2-up when the page content width (inside the
      // 28px gutters, LAYOUT_SPEC scale) reaches ~1280; below that the cards
      // stack full width.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumn = constraints.maxWidth >= 1280;
          return EvolvePanel(
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: AlignmentDirectional.topStart,
                        children: [...previousChildren, ?currentChild],
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_section),
                        child: switch (_section) {
                          _SettingsSection.profile => _profile(twoColumn),
                          _SettingsSection.appearance => _appearance(twoColumn),
                          _SettingsSection.notifications => _notifications(
                            twoColumn,
                          ),
                          _SettingsSection.privacy => _privacy(twoColumn),
                          _SettingsSection.subscription =>
                            _SubscriptionSettings(twoColumn: twoColumn),
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _profile(bool twoColumn) {
    final auth = ref.watch(desktopAuthControllerProvider);
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.profileLabel,
          subtitle: t.settingsPage.profileSubtitle,
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 24),
        _GroupGrid(
          twoColumn: twoColumn,
          groups: [
            _SettingsGroup(
              title: t.settingsPage.accountAndOnboarding,
              children: [
                _InfoRow(
                  icon: LucideIcons.mail,
                  label: t.settingsPage.account,
                  value: isPrivateMode
                      ? t.settingsPage.privateMode
                      : auth.user?.email ?? t.settingsPage.sessionUnavailable,
                ),
                _InfoRow(
                  icon: LucideIcons.database,
                  label: t.settingsPage.dataRepository,
                  value: isPrivateMode
                      ? t.settingsPage.encryptedLocalDatabase
                      : t.settingsPage.supabaseWithEncryptedCache,
                ),
                if (!isPrivateMode) ...[
                  _ActionRow(
                    icon: LucideIcons.user,
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
                    icon: LucideIcons.camera,
                    title: t.settingsPage.updateAvatar,
                    detail: t.settingsPage.updateAvatarDetail,
                    onTap: _pickAvatar,
                  ),
                  _ActionRow(
                    icon: LucideIcons.fileText,
                    title: t.settingsPage.reviewInitialConsent,
                    detail: t.settingsPage.reviewInitialConsentDetail,
                    onTap: _reviewConsent,
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (!isPrivateMode)
          _DestructiveButton(
            label: t.settingsPage.signOut,
            caption: auth.isLoggedIn
                ? t.settingsPage.signOutDetailActive
                : t.settingsPage.availableWithActiveSession,
            onTap: auth.isLoggedIn
                ? () => _confirmSignOut()
                : () => _showGate(
                    t.settingsPage.gateLogout,
                    t.settingsPage.gateRequiresActiveSession,
                  ),
          )
        else
          _DestructiveButton(
            label: t.settingsPage.goToLogin,
            caption: t.settingsPage.goToLoginDetail,
            onTap: () {
              ref.read(desktopAuthControllerProvider.notifier).goToLogin();
            },
          ),
      ],
    );
  }

  Widget _appearance(bool twoColumn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.appearanceTitle,
          subtitle: t.settingsPage.appearanceSubtitle,
        ),
        const SizedBox(height: 20),
        _GroupGrid(
          twoColumn: twoColumn,
          groups: [
            _SettingsGroup(
              title: t.settingsPage.appearanceAndVisual,
              children: [
                _SwitchRow(
                  icon: LucideIcons.moon,
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
            _SettingsGroup(
              title: t.settingsPage.calendarExperienceLanguage,
              children: [
                _ColorRow(
                  icon: LucideIcons.palette,
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
                      _syncProfile({
                        'accent_color': dashboardColorToHex(accent),
                      }),
                    );
                  },
                ),
                _SelectRow(
                  icon: LucideIcons.calendar,
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
                  icon: LucideIcons.languages,
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
                  icon: LucideIcons.clock,
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
                  icon: LucideIcons.vibrate,
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
                  icon: LucideIcons.info,
                  title: t.settingsPage.resetTutorial,
                  detail: t.settingsPage.resetTutorialDetail,
                  onTap: _resetTutorials,
                ),
                _ActionRow(
                  icon: LucideIcons.scrollText,
                  title: t.settingsPage.appLogsTitle,
                  detail: t.settingsPage.appLogsDetail,
                  onTap: () => unawaited(showAppLogsDialog(context)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _notifications(bool twoColumn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.notifications,
          subtitle: t.settingsPage.notificationsSubtitle,
        ),
        const SizedBox(height: 20),
        _GroupGrid(
          twoColumn: twoColumn,
          groups: [
            _SettingsGroup(
              title: t.settingsPage.operationalReminders,
              children: [
                _SwitchRow(
                  icon: LucideIcons.calendarCheck,
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
                    icon: LucideIcons.sunrise,
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
                  icon: LucideIcons.bellRing,
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
                    icon: LucideIcons.sunset,
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
                  icon: LucideIcons.bell,
                  title: t.settingsPage.requestNotificationPermissions,
                  detail: t.settingsPage.requestNotificationPermissionsDetail,
                  onTap: _requestNotificationPermissions,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        _PlatformNote(
          title: t.settingsPage.nativeDeliveryTitle,
          detail: DesktopNotificationService.instance.platformSummary,
        ),
      ],
    );
  }

  Widget _privacy(bool twoColumn) {
    final biometric = ref.watch(desktopBiometricControllerProvider);
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsHeading(
          title: t.settingsPage.privacyTitle,
          subtitle: t.settingsPage.privacySubtitle,
        ),
        const SizedBox(height: 20),
        _GroupGrid(
          twoColumn: twoColumn,
          groups: [
            _SettingsGroup(
              title: t.settingsPage.accessProtection,
              children: [
                _SwitchRow(
                  icon: LucideIcons.shield,
                  label: t.settingsPage.biometricLock,
                  detail: t.settingsPage.biometricLockDetail,
                  value: biometric.enabled,
                  onChanged: _setBiometricLock,
                ),
                if (!isPrivateMode)
                  _ActionRow(
                    icon: LucideIcons.keyRound,
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
            _SettingsGroup(
              title: t.settingsPage.dataAndConsents,
              children: [
                if (!isPrivateMode)
                  _SwitchRow(
                    icon: LucideIcons.circleAlert,
                    label: t.settingsPage.sendCrashReports,
                    detail: t.settingsPage.sendCrashReportsDetail,
                    value: _crashReports,
                    onChanged: _setCrashReportingConsent,
                  ),
                _ActionRow(
                  icon: LucideIcons.download,
                  title: t.settingsPage.exportData,
                  detail: t.settingsPage.exportDataDetail,
                  onTap: _exportData,
                ),
                _ActionRow(
                  icon: LucideIcons.upload,
                  title: t.settingsPage.importData,
                  detail: t.settingsPage.importDataDetail,
                  onTap: _importData,
                ),
                _ActionRow(
                  icon: LucideIcons.externalLink,
                  title: t.settingsPage.systemPermissionsManagement,
                  detail: t.settingsPage.systemPermissionsManagementDetail,
                  onTap: _openSystemPermissions,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (isPrivateMode)
          _DestructiveButton(
            label: t.settingsPage.deletePrivateData,
            caption: t.settingsPage.deletePrivateDataDetail,
            onTap: _deletePrivateData,
          )
        else
          _DestructiveButton(
            label: t.settingsPage.deleteAccountAndData,
            caption: t.settingsPage.deleteAccountAndDataDetail,
            onTap: _showDeleteOrResetDialog,
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
    // Cloud mode: emit a full, lossless snapshot of the user's Supabase rows in
    // the same native DB-row shape as the Private-mode export, so the exact same
    // importer round-trips it (categories + goals + logs + macro goals + moods +
    // profile). Read straight from the tables — the in-memory dashboard snapshot
    // is lossy (no log ids/streaks, no category list).
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      _showGate(t.settingsPage.exportDoneTitle, t.settingsPage.operationFailed);
      return;
    }
    Future<List<Map<String, dynamic>>> rows(String table) async {
      final res = await client.from(table).select().eq('user_id', userId);
      return List<Map<String, dynamic>>.from(res);
    }

    final profileRow = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    final json = const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'mode': 'cloud',
      'profile': profileRow,
      'goals': await rows('goals'),
      'goal_logs': await rows('goal_logs'),
      'long_term_goals': await rows('long_term_goals'),
      'daily_moods': await rows('daily_moods'),
      'macro_goal_categories': await rows('macro_goal_categories'),
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
                ? LucideIcons.triangleAlert
                : LucideIcons.circleCheck,
            iconColor: destructive ? EvolveColors.destructive : null,
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
                    ? FilledButton.styleFrom(
                        backgroundColor: EvolveColors.destructive,
                      )
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
        allowedExtensions: ['zip', 'json'],
      );

      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      final isPrivateMode =
          ref.read(activeDesktopDataModeProvider) == DesktopDataMode.private;

      final privateStore = DesktopPrivateDb.instance;
      final importService = DesktopBackupImportService(
        privateStore,
        isPrivateMode ? null : Supabase.instance.client,
      );

      // 1. Preview (accepts both the web `.zip` and native `.json` backups).
      final preview = await importService.parsePreview(path);

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
                      RadioGroup<bool>(
                        groupValue: replaceExisting,
                        onChanged: (val) => setState(
                          () => replaceExisting = val ?? replaceExisting,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                                  color: context.evolveColors.foreground
                                      .withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                              value: true,
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.primary,
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
                                  color: context.evolveColors.foreground
                                      .withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                              value: false,
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          ],
                        ),
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
        isPrivateMode: isPrivateMode,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.settingsPage.importSuccess),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh dashboard + category/profile providers so imported data shows.
      ref.invalidate(dashboardControllerProvider);
      ref.invalidate(desktopGoalCategoriesControllerProvider);
      if (isPrivateMode) ref.invalidate(privateProfileProvider);
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
      // Match the initial-state defaults (both ON), not false.
      _aiInsights = true;
      _weeklyReport = true;
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
    final contentColor = selected
        ? Theme.of(context).colorScheme.onPrimary
        : context.evolveColors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: selected ? context.evolveAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            hoverColor: selected
                ? Colors.transparent
                : context.evolveColors.panel.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              child: Row(
                children: [
                  Icon(section.icon, color: contentColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        letterSpacing: -0.2,
                        color: contentColor,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
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

/// One settings group as a single titled card: the tiny uppercase muted label
/// sits inside an [EvolvePanel] (radius 20) above its rows, which render as
/// flat list tiles separated by hairline dividers — the macOS
/// grouped-settings look in the Evolve skin.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  /// Row count used by [_GroupGrid] to balance the two columns.
  int get rowCount => children.length;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      padding: EdgeInsets.zero,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 6),
            child: EvolveSectionLabel(title, withRule: false),
          ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const _RowHairline(),
            children[i],
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// 1px divider between the flat rows of a group card, indented past the icon
/// chip (16 content padding + 36 chip + 16 title gap).
class _RowHairline extends StatelessWidget {
  const _RowHairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsetsDirectional.only(start: 68),
      color: context.evolveColors.border.withValues(alpha: 0.35),
    );
  }
}

/// Adaptive tiling for the group cards: a single full-width column, or — when
/// the page content is wide enough — two columns filled greedily by row count
/// so their heights stay balanced. Cards never split across columns.
class _GroupGrid extends StatelessWidget {
  const _GroupGrid({required this.twoColumn, required this.groups});

  final bool twoColumn;
  final List<_SettingsGroup> groups;

  static const _gap = 18.0;

  Widget _column(List<_SettingsGroup> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: _gap),
          items[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!twoColumn || groups.length < 2) return _column(groups);
    final start = <_SettingsGroup>[];
    final end = <_SettingsGroup>[];
    var startRows = 0;
    var endRows = 0;
    for (final group in groups) {
      if (startRows <= endRows) {
        start.add(group);
        startRows += group.rowCount;
      } else {
        end.add(group);
        endRows += group.rowCount;
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _column(start)),
        const SizedBox(width: _gap),
        Expanded(child: _column(end)),
      ],
    );
  }
}

TextStyle _rowTitleStyle(BuildContext context) => TextStyle(
  color: context.evolveColors.foreground,
  fontSize: 15,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
);

TextStyle _rowSubtitleStyle(BuildContext context) => TextStyle(
  color: context.evolveColors.muted.withValues(alpha: 0.8),
  fontSize: 12,
  fontWeight: FontWeight.w500,
);

Widget _rowIconChip(BuildContext context, IconData icon) => EvolveIconChip(
  icon: icon,
  color: context.evolveAccent,
  size: 36,
  iconSize: 18,
  outlined: true,
);

/// Full-width destructive action styled exactly like the mobile
/// "Go to login" button (destructive .1 fill, .2 border, radius 14), with the
/// row's original detail text kept as a small muted caption underneath.
class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: EvolveColors.destructive.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: EvolveColors.destructive.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: EvolveColors.destructive,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.evolveColors.muted.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _rowIconChip(context, icon),
      title: Text(label, style: _rowTitleStyle(context)),
      subtitle: Text(detail, style: _rowSubtitleStyle(context)),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _rowIconChip(context, icon),
      title: Text(label, style: _rowTitleStyle(context)),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
        dropdownColor: context.evolveColors.panelRaised,
        style: Theme.of(context).textTheme.titleMedium,
        icon: Icon(
          LucideIcons.chevronDown,
          size: 16,
          color: context.evolveColors.muted,
        ),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.use24hFormat,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool use24hFormat;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _rowIconChip(context, icon),
      title: Text(label, style: _rowTitleStyle(context)),
      trailing: OutlinedButton(
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
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _rowIconChip(context, icon),
          const SizedBox(width: 16),
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
                      child: _Swatch(
                        color: color,
                        isSelected: selected == color,
                        child: selected == color
                            ? Icon(
                                LucideIcons.check,
                                size: 12,
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
                    child: _Swatch(
                      color: context.evolveColors.panelRaised,
                      isSelected: false,
                      outlined: true,
                      child: Icon(
                        LucideIcons.plus,
                        size: 14,
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
        icon: LucideIcons.palette,
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

/// 24px color swatch circle; the selected one gets a foreground ring and a
/// soft tint glow (mobile color-picker recipe).
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.isSelected,
    this.outlined = false,
    this.child,
  });

  final Color color;
  final bool isSelected;
  final bool outlined;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: isSelected
            ? Border.all(color: context.evolveColors.foreground, width: 2)
            : outlined
            ? Border.all(color: context.evolveColors.border)
            : null,
        boxShadow: isSelected
            ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
            : null,
      ),
      child: child == null ? null : Center(child: child),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _rowIconChip(context, icon),
      title: Text(title, style: _rowTitleStyle(context)),
      subtitle: Text(detail, style: _rowSubtitleStyle(context)),
      trailing: DirectionalIcon(
        LucideIcons.chevronRight,
        LucideIcons.chevronLeft,
        size: 18,
        color: context.evolveColors.muted,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _rowIconChip(context, icon),
      title: Text(label, style: _rowTitleStyle(context)),
      subtitle: Text(value, style: _rowSubtitleStyle(context)),
    );
  }
}

class _RowCopy extends StatelessWidget {
  const _RowCopy({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _rowTitleStyle(context)),
        const SizedBox(height: 3),
        Text(detail, style: _rowSubtitleStyle(context)),
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
    return EvolvePanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          InkWell(
            onTap: onPickAvatar,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPro
                      ? EvolveColors.amber
                      : context.evolveAccent.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: context.evolveColors.panel,
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
                        LucideIcons.user,
                        size: 20,
                        color: context.evolveAccent,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 14),
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
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPrivateMode
                      ? t.settingsPage.privateModeDataProtected
                      : user?.email ?? t.settingsPage.sessionUnavailable,
                  style: TextStyle(
                    color: context.evolveColors.muted.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isPro)
            const StatusPill(
              label: 'PRO',
              color: EvolveColors.amber,
              icon: LucideIcons.sparkles,
            )
          else
            StatusPill(
              label: user == null
                  ? t.settingsPage.notAuthenticated
                  : t.settingsPage.verified,
              color: user == null ? EvolveColors.amber : context.evolveAccent,
              icon: user == null ? LucideIcons.lock : LucideIcons.shieldCheck,
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
      glowColor: EvolveColors.violet,
      child: Row(
        children: [
          const EvolveIconChip(
            icon: LucideIcons.monitor,
            color: EvolveColors.violet,
            size: 36,
            iconSize: 18,
          ),
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
  const _SubscriptionSettings({required this.twoColumn});

  final bool twoColumn;

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
        const SizedBox(height: 20),
        if (!subscription.isPro) ...[
          EvolvePanel(
            padding: const EdgeInsets.all(20),
            radius: 20,
            glowColor: proAccent,
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: proAccent.withValues(alpha: 0.1),
                      border: Border.all(
                        color: proAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.sparkles,
                      size: 26,
                      color: proAccent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t.settingsPage.proUpsellTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.evolveColors.foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.settingsPage.proUpsellSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.evolveColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          EvolveSectionLabel(t.proModal.featuresHeader, withRule: false),
          const SizedBox(height: 12),
          for (final feature in proFeatures()) ...[
            ProFeatureRow(feature: feature),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 6),
        ],
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
        const SizedBox(height: 24),
        _GroupGrid(
          twoColumn: widget.twoColumn,
          groups: [
            _SettingsGroup(
              title: t.settingsPage.planManagement,
              children: [
                _ActionRow(
                  icon: LucideIcons.sparkles,
                  title: t.settingsPage.activateEvolvePro,
                  detail: subscription.isPro
                      ? t.settingsPage.activateEvolveProActive
                      : t.settingsPage.activateEvolveProStart,
                  onTap: subscription.isLoading
                      ? () {}
                      : () async {
                          final package = _plan == 'monthly' ? monthly : yearly;
                          if (package == null) {
                            await ref
                                .read(
                                  desktopSubscriptionControllerProvider
                                      .notifier,
                                )
                                .refresh();
                            return;
                          }
                          final activated = await ref
                              .read(
                                desktopSubscriptionControllerProvider.notifier,
                              )
                              .purchase(package);
                          if (activated && mounted) {
                            _showProSuccessDialog();
                          }
                        },
                ),
                _ActionRow(
                  icon: LucideIcons.refreshCw,
                  title: t.settingsPage.restorePurchases,
                  detail: t.settingsPage.restorePurchasesDetail,
                  onTap: () => unawaited(
                    ref
                        .read(desktopSubscriptionControllerProvider.notifier)
                        .restore(),
                  ),
                ),
                _ActionRow(
                  icon: LucideIcons.creditCard,
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
          ],
        ),
        if (subscription.message != null) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              subscription.message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.evolveColors.muted.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showProSuccessDialog() {
    showEvolveDialog<void>(
      context: context,
      builder: (dialogContext) => EvolveDialog(
        maxWidth: 420,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: proAccent.withValues(alpha: 0.1),
                  border: Border.all(color: proAccent.withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  size: 34,
                  color: proAccent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t.settingsPage.proWelcomeTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t.settingsPage.proActiveMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.evolveColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: proAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(t.settingsPage.proStartJourney),
                ),
              ),
            ],
          ),
        ),
      ),
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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected
              ? context.evolveAccent.withValues(alpha: 0.08)
              : context.evolveColors.panel.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? context.evolveAccent
                : context.evolveColors.border.withValues(alpha: 0.5),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: context.evolveAccent.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
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
                letterSpacing: -0.8,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 5),
              Text(detail!, style: _rowSubtitleStyle(context)),
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
      icon: LucideIcons.user,
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
      icon: LucideIcons.keyRound,
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
              Text(
                _error!,
                style: const TextStyle(color: EvolveColors.destructive),
              ),
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
    _SettingsSection.profile => LucideIcons.user,
    _SettingsSection.appearance => LucideIcons.settings,
    _SettingsSection.notifications => LucideIcons.bell,
    _SettingsSection.privacy => LucideIcons.shield,
    _SettingsSection.subscription => LucideIcons.sparkles,
  };
}
