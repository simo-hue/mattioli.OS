import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import '../../core/rtl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../../core/backup_import_service.dart';
import '../../core/import_merge_stats.dart';
import '../../providers/goal_provider.dart';
import '../../providers/macro_goals_provider.dart';
import '../../providers/macro_goal_categories_provider.dart';
import '../../providers/macro_goals_stats_provider.dart';
import '../../providers/mood_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/sync_refresh.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../core/data_mode.dart';
import '../../core/private_local_database.dart';
import '../../core/private_sync_service.dart';
import '../../core/notifications.dart';
import '../widgets/animations/pulsing_sync_animation.dart';
import 'icloud_sync_screen.dart';
import '../../providers/settings_provider.dart';
import '../../providers/consent_provider.dart';
import '../../core/haptics.dart';
import '../../core/app_logger.dart';
import '../../i18n/translations.g.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  static Route route() {
    // MaterialPageRoute so iOS gets the native Cupertino slide + edge-swipe-back
    // gesture for free (Android keeps its native Material transition).
    return MaterialPageRoute(
      builder: (context) => const PrivacySettingsScreen(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final consentState = ref.watch(consentProvider);
    final isPrivateMode =
        ref.watch(activeDataModeProvider) == AppDataMode.private;

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: context.appColors.background,
        elevation: 0,
        leading: IconButton(
          icon: DirectionalIcon(
            LucideIcons.chevronLeft,
            LucideIcons.chevronRight,
            color: context.appColors.foreground,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.t.common.privacySecurity,
          style: TextStyle(
            color: context.appColors.foreground,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, context.t.privacy.accessProtectionHeader),
            _buildSettingsCard(context, [
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.shield,
                title: context.t.privacy.biometricLock,
                subtitle: context.t.privacy.faceIdTouchId,
                value: settings.biometricLock,
                onChanged: (val) async {
                  if (val) {
                    final authenticated = await _authenticate(context);
                    if (authenticated) {
                      final currentSettings = ref.read(settingsProvider);
                      notifier.updateSettings(
                        currentSettings.copyWith(biometricLock: true),
                      );
                      ref.hapticLight();
                    }
                  } else {
                    final currentSettings = ref.read(settingsProvider);
                    notifier.updateSettings(
                      currentSettings.copyWith(biometricLock: false),
                    );
                    ref.hapticLight();
                  }
                },
              ),
              if (!isPrivateMode) ...[
                _buildDivider(context),
                _buildActionRow(
                  context: context,
                  icon: LucideIcons.keyRound,
                  title: context.t.privacy.changePassword,
                  onTap: () {
                    ref.hapticLight();
                    _showChangePasswordModal(context);
                  },
                ),
              ],
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader(context, context.t.privacy.dataManagementHeader),
            _buildSettingsCard(context, [
              if (!isPrivateMode) ...[
                _buildSwitchRow(
                  context: context,
                  ref: ref,
                  icon: LucideIcons.circleAlert,
                  title: context.t.privacy.sendCrashReports,
                  subtitle: context.t.privacy.sentryHelpSubtitle,
                  value: consentState.hasSentryConsent,
                  onChanged: (val) {
                    ref
                        .read(consentProvider.notifier)
                        .setConsent(
                          acceptedTerms: consentState.hasAcceptedTerms,
                          sentryConsent: val,
                          completed: consentState.hasCompletedOnboarding,
                        );
                    ref.hapticLight();
                  },
                ),
                _buildDivider(context),
              ],
              _buildActionRow(
                context: context,
                icon: LucideIcons.download,
                title: context.t.privacy.exportData,
                subtitle: context.t.privacy.jsonCsvFormat,
                onTap: () {
                  ref.hapticMedium();
                  _exportData(context, ref);
                },
              ),
              _buildDivider(context),
              _buildActionRow(
                context: context,
                icon: LucideIcons.upload,
                title: context.t.privacy.importData,
                subtitle: context.t.privacy.importDataSubtitle,
                onTap: () {
                  ref.hapticMedium();
                  _importData(context, ref);
                },
              ),
              if (isPrivateMode && Platform.isIOS) ...[
                _buildDivider(context),
                _buildActionRow(
                  context: context,
                  icon: LucideIcons.cloud,
                  title: context.t.icloudSync.title,
                  subtitle: context.t.icloudSync.entrySubtitle,
                  onTap: () {
                    ref.hapticLight();
                    Navigator.push(context, IcloudSyncScreen.route());
                  },
                ),
              ],
              _buildDivider(context),
              _buildActionRow(
                context: context,
                icon: LucideIcons.trash2,
                title: isPrivateMode
                    ? context.t.privacy.deletePrivateData
                    : context.t.privacy.deleteAccountData,
                titleColor: AppColors.destructive,
                onTap: () {
                  ref.hapticHeavy();
                  _showDeleteOrResetModal(context, ref);
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader(context, context.t.privacy.systemPermissionsHeader),
            _buildSettingsCard(context, [
              _buildActionRow(
                context: context,
                icon: LucideIcons.settings2,
                title: context.t.privacy.permissionsManagement,
                subtitle: context.t.privacy.permissionsSubtitle,
                onTap: () async {
                  ref.hapticLight();
                  await openAppSettings();
                },
              ),
            ]),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Future<bool> _authenticate(BuildContext context) async {
    final LocalAuthentication auth = LocalAuthentication();
    final String authReason = context.t.privacy.biometricAuthReason;
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) return false;

      return await auth.authenticate(
        localizedReason: authReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e, stack) {
      AppLogger.error('Biometric authentication error', e, stack);
      return false;
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: context.appColors.mutedForeground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.appColors.border,
      indent: 56,
    );
  }

  Widget _buildActionRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.appColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.appColors.border),
              ),
              child: Icon(icon, size: 18, color: titleColor ?? primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: titleColor ?? context.appColors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: context.appColors.mutedForeground.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const DirectionalIcon(
              LucideIcons.chevronRight,
              LucideIcons.chevronLeft,
              color: AppColors.mutedForeground,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLocked = false,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDisabled = isLocked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.appColors.border),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isDisabled
                  ? context.appColors.mutedForeground
                  : primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          color: isDisabled
                              ? context.appColors.mutedForeground
                              : context.appColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'PRO',
                          style: GoogleFonts.inter(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AppColors.mutedForeground.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: (val) =>
                  onChanged(val), // Always interactive to allow modal trigger
              activeTrackColor: primaryColor.withValues(alpha: 0.5),
              activeThumbColor: primaryColor,
              inactiveThumbColor: context.appColors.mutedForeground,
              inactiveTrackColor: context.appColors.border,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordModal(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool isLoading = false;
    String? errorMessage;
    bool isVerified = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.appColors.card.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: context.appColors.border.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t.privacy.changePassword,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVerified
                            ? context.t.privacy.enterNewPassword
                            : context.t.privacy.enterCurrentPassword,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: context.appColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (!isVerified) ...[
                        _buildPasswordField(
                          controller: currentPasswordController,
                          label: context.t.privacy.currentPassword,
                          context: context,
                        ),
                      ] else ...[
                        _buildPasswordField(
                          controller: newPasswordController,
                          label: context.t.privacy.newPassword,
                          context: context,
                        ),
                        const SizedBox(height: 16),

                        _buildPasswordField(
                          controller: confirmPasswordController,
                          label: context.t.privacy.confirmNewPassword,
                          context: context,
                        ),
                      ],

                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.destructive,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () => Navigator.pop(context),
                            child: Text(
                              context.t.common.actions.cancel,
                              style: GoogleFonts.inter(
                                color: context.appColors.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: isLoading
                                ? null
                                : () async {
                                    if (!isVerified) {
                                      final currentPwd =
                                          currentPasswordController.text;
                                      if (currentPwd.isEmpty) {
                                        setState(
                                          () => errorMessage = context.t.privacy.currentPasswordRequired,
                                        );
                                        return;
                                      }

                                      setState(() {
                                        isLoading = true;
                                        errorMessage = null;
                                      });

                                      try {
                                        final supabase =
                                            Supabase.instance.client;
                                        final email =
                                            supabase.auth.currentUser?.email;

                                        if (email == null) {
                                          throw Exception(
                                            context.t.privacy.userNotFound,
                                          );
                                        }

                                        await supabase.auth.signInWithPassword(
                                          email: email,
                                          password: currentPwd,
                                        );

                                        setState(() {
                                          isLoading = false;
                                          isVerified = true;
                                          errorMessage = null;
                                        });
                                      } catch (e) {
                                        setState(() {
                                          isLoading = false;
                                          errorMessage = context.t.privacy.currentPasswordIncorrect;
                                        });
                                      }
                                    } else {
                                      final newPwd = newPasswordController.text;
                                      final confirmPwd =
                                          confirmPasswordController.text;

                                      if (newPwd.isEmpty ||
                                          confirmPwd.isEmpty) {
                                        setState(
                                          () => errorMessage = context.t.privacy.allFieldsRequired,
                                        );
                                        return;
                                      }

                                      if (newPwd.length < 8) {
                                        setState(
                                          () => errorMessage = context.t.privacy.newPasswordMin8,
                                        );
                                        return;
                                      }

                                      if (newPwd != confirmPwd) {
                                        setState(
                                          () => errorMessage = context.t.privacy.passwordsDontMatch,
                                        );
                                        return;
                                      }

                                      setState(() {
                                        isLoading = true;
                                        errorMessage = null;
                                      });

                                      try {
                                        final supabase =
                                            Supabase.instance.client;

                                        await supabase.auth.updateUser(
                                          UserAttributes(password: newPwd),
                                        );

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                context.t.privacy.passwordUpdated,
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e, stack) {
                                        AppLogger.error(
                                          'Errore durante aggiornamento password',
                                          e,
                                          stack,
                                        );
                                        setState(() {
                                          isLoading = false;
                                          errorMessage = e
                                              .toString()
                                              .replaceAll('Exception: ', '');
                                        });
                                      }
                                    }
                                  },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      isVerified
                                          ? context.t.common.actions.save
                                          : context.t.common.actions.verify,
                                      style: GoogleFonts.inter(
                                        color:
                                            Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .computeLuminance() >
                                                0.5
                                            ? Colors.black
                                            : Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required BuildContext context,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: context.appColors.mutedForeground,
          fontSize: 14,
        ),
        floatingLabelStyle: TextStyle(
          color: Theme.of(context).colorScheme.primary,
        ),
        filled: true,
        fillColor: context.appColors.background.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: context.appColors.border.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
      style: TextStyle(
        color: context.appColors.foreground,
        fontFamily: 'Inter',
        fontSize: 14,
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      if (ref.read(activeDataModeProvider) == AppDataMode.private) {
        final shareText = context.t.privacy.exportedPrivateDataTitle;
        final data = await ref.read(privateLocalDatabaseProvider).exportData();
        final jsonString = const JsonEncoder.withIndent('  ').convert(data);
        final file = XFile.fromData(
          utf8.encode(jsonString),
          mimeType: 'application/json',
          name: 'evolve_private_export.json',
        );
        await SharePlus.instance.share(
          ShareParams(files: [file], text: shareText),
        );
        return;
      }

      final settings = ref.read(settingsProvider);
      final goals = ref.read(goalsProvider);
      final macroGoals = ref.read(macroGoalsProvider).goals;
      final habitLogs = ref.read(habitLogsProvider);
      final moods = ref.read(dailyMoodsProvider);
      final categories =
          ref.read(macroGoalCategoriesProvider).value ?? const [];
      final profile = ref.read(userProfileProvider);

      String colorToHex(Color c) =>
          '#${c.toARGB32().toRadixString(16).substring(2)}';

      // Construct JSON
      final data = {
        'exportDate': DateTime.now().toIso8601String(),
        'profile': {
          'firstName': profile.firstName,
          'lastName': profile.lastName,
          'email': profile.email,
          'dateOfBirth': profile.dateOfBirth,
        },
        'settings': {
          'themeMode': settings.themeMode,
          'accentColor':
              '#${settings.accentColor.toARGB32().toRadixString(16).substring(2)}',
          'defaultCalendarView': settings.defaultCalendarView,
          'hapticFeedback': settings.hapticFeedback,
          'language': settings.language,
          'timeFormat24h': settings.timeFormat24h,
          'aiSuggestions': settings.aiSuggestions,
          'isPro': settings.isPro,
          'focusMode': settings.focusMode,
          'milestones': settings.milestones,
          'deepWorkInsights': settings.deepWorkInsights,
          'habitReminders': settings.habitReminders,
          'goalDeadlines': settings.goalDeadlines,
          'aiInsights': settings.aiInsights,
          'weeklyReports': settings.weeklyReports,
          'eveningReview': settings.eveningReview,
          'biometricLock': settings.biometricLock,
          'morningBriefTime': settings.morningBriefTime,
          'eveningReviewTime': settings.eveningReviewTime,
        },
        'habits': goals.map((g) => g.toJson()).toList(),
        'habitLogs': habitLogs,
        'macroGoals': macroGoals.map((g) => g.toJson()).toList(),
        'macroGoalCategories': categories
            .map(
              (c) => {
                'id': c.key,
                'name': c.label,
                'color': colorToHex(c.color),
                if (c.archivedAt != null)
                  'archived_at': c.archivedAt!.toIso8601String(),
              },
            )
            .toList(),
        'dailyMoods': moods.map(
          (key, value) => MapEntry(key, {
            'id': value.id,
            'user_id': value.userId,
            'date': value.date,
            'mood_score': value.moodScore,
            'energy_score': value.energyScore,
          }),
        ),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final bytes = utf8.encode(jsonString);
      final file = XFile.fromData(
        bytes,
        mimeType: 'application/json',
        name: 'mattioli_os_export.json',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          text: context.t.privacy.exportedDataTitle,
        ),
      );
    } catch (e, stack) {
      AppLogger.error('Error exporting data', e, stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.t.privacy.errors.exportPrefix}$e')),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    // Tracks whether the blocking progress dialog is on the navigator stack, so
    // an error thrown BEFORE it opens (e.g. a bad file during preview) doesn't
    // pop the settings screen itself.
    var progressShown = false;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
      );

      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;

      final isPrivateMode = ref.read(activeDataModeProvider) == AppDataMode.private;
      final privateStore = ref.read(privateLocalDatabaseProvider);
      final supabase = isPrivateMode ? null : Supabase.instance.client;
      final importService = BackupImportService(privateStore, supabase);

      // 1. Preview
      final preview = await importService.parsePreview(path);

      if (!context.mounted) return;

      // 2. Ask for Replace/Merge
      bool replaceExisting = true;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: context.appColors.background,
                title: Text(
                  context.t.privacy.importPreviewTitle,
                  style: GoogleFonts.outfit(
                    color: context.appColors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t.privacy.importPreviewHabits(count: preview.habitsCount), style: TextStyle(color: context.appColors.foreground)),
                      Text(context.t.privacy.importPreviewLogs(count: preview.logsCount), style: TextStyle(color: context.appColors.foreground)),
                      Text(context.t.privacy.importPreviewMacroGoals(count: preview.macroGoalsCount), style: TextStyle(color: context.appColors.foreground)),
                      Text(context.t.privacy.importPreviewCategories(count: preview.categoriesCount), style: TextStyle(color: context.appColors.foreground)),
                      Text(context.t.privacy.importPreviewMoods(count: preview.moodsCount), style: TextStyle(color: context.appColors.foreground)),
                      if (preview.totalSkipped > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            context.t.privacy.importPreviewSkipped(
                                count: preview.totalSkipped),
                            style: const TextStyle(
                              color: AppColors.destructive,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      RadioListTile<bool>(
                        title: Text(context.t.privacy.importModeReplace, style: TextStyle(color: context.appColors.foreground)),
                        subtitle: Text(context.t.privacy.importModeReplaceDesc, style: TextStyle(color: context.appColors.mutedForeground, fontSize: 12)),
                        value: true,
                        groupValue: replaceExisting,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (val) => setState(() => replaceExisting = val!),
                      ),
                      RadioListTile<bool>(
                        title: Text(context.t.privacy.importModeMerge, style: TextStyle(color: context.appColors.foreground)),
                        subtitle: Text(context.t.privacy.importModeMergeDesc, style: TextStyle(color: context.appColors.mutedForeground, fontSize: 12)),
                        value: false,
                        groupValue: replaceExisting,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (val) => setState(() => replaceExisting = val!),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      context.t.common.actions.cancel,
                      style: TextStyle(color: context.appColors.mutedForeground),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    ),
                    child: Text(
                      context.t.privacy.importConfirm,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirm != true) return;
      if (!context.mounted) return;

      progressShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: context.appColors.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PulsingSyncAnimation(size: 140),
                  const SizedBox(height: 24),
                  Text(
                    context.t.privacy.importInProgress,
                    style: TextStyle(
                      color: context.appColors.foreground,
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t.privacy.importWaitMessage,
                    style: TextStyle(
                      color: context.appColors.mutedForeground,
                      fontFamily: 'Inter',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 3. Execute
      final importResult = await importService.executeImport(
        canonicalData: preview.canonicalData,
        replaceExisting: replaceExisting,
        isPrivateMode: isPrivateMode,
        skipped: preview.skipped,
      );

      // 4. Refresh Providers
      invalidatePrivateDataProviders(ref);

      // 5. Resync notifications after goals have had a moment to load from the DB
      Future.delayed(const Duration(seconds: 1), () {
        // Use a persistent container reference if we don't have context, or just read from the active ref
        try {
          ref.read(settingsProvider.notifier).syncNotifications();
        } catch (e) {
          AppLogger.error('Failed to sync notifications after import', e);
        }
      });

      if (context.mounted) {
        if (progressShown) {
          Navigator.pop(context); // Close progress
          progressShown = false;
        }

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ctx.appColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(LucideIcons.check, color: AppColors.success, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ctx.t.privacy.importCompletedTitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ctx.appColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  importResult.replaced
                      ? ctx.t.privacy.importSummaryReplaced
                      : ctx.t.privacy.importSummaryMerged,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: ctx.appColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow(ctx, LucideIcons.check, _mergeRowText(ctx, importResult, importResult.habits, ctx.t.privacy.importEntityHabits)),
                _buildSummaryRow(ctx, LucideIcons.history, _mergeRowText(ctx, importResult, importResult.logs, ctx.t.privacy.importEntityLogs)),
                _buildSummaryRow(ctx, LucideIcons.target, _mergeRowText(ctx, importResult, importResult.macroGoals, ctx.t.privacy.importEntityMacroGoals)),
                _buildSummaryRow(ctx, LucideIcons.folder, _mergeRowText(ctx, importResult, importResult.categories, ctx.t.privacy.importEntityCategories)),
                _buildSummaryRow(ctx, LucideIcons.smile, _mergeRowText(ctx, importResult, importResult.moods, ctx.t.privacy.importEntityMoods)),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.primary,
                  foregroundColor: Theme.of(ctx).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(ctx.t.privacy.importSummaryDone, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error('Import failed', e, stack);
      if (context.mounted) {
        if (progressShown) {
          Navigator.pop(context); // Close progress if open
          progressShown = false;
        }

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ctx.appColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(LucideIcons.info, color: AppColors.destructive, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ctx.t.privacy.importFailedTitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ctx.appColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              e.toString(),
              style: TextStyle(
                fontFamily: 'Inter',
                color: ctx.appColors.mutedForeground,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: ctx.appColors.card,
                  foregroundColor: ctx.appColors.foreground,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: ctx.appColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }
    }
  }

  /// One summary line. Replace mode shows a single total; merge mode breaks the
  /// outcome into added / updated / unchanged.
  String _mergeRowText(
    BuildContext context,
    ImportMergeStats stats,
    EntityMerge m,
    String label,
  ) {
    final t = context.t.privacy;
    final base = stats.replaced
        ? t.importRowReplace(count: m.total, label: label)
        : t.importRowMerge(
            label: label,
            added: m.added,
            updated: m.updated,
            unchanged: m.unchanged,
          );
    return m.skipped > 0
        ? '$base${t.importRowSkipped(count: m.skipped)}'
        : base;
  }

  Widget _buildSummaryRow(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              color: context.appColors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteOrResetModal(BuildContext context, WidgetRef ref) {
    final isPrivateMode =
        ref.read(activeDataModeProvider) == AppDataMode.private;
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.appColors.card.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.appColors.border.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPrivateMode
                        ? context.t.privacy.privateDataManagement
                        : context.t.privacy.accountDataManagement,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t.privacy.chooseOperation,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (isPrivateMode)
                    _buildOptionCard(
                      context: context,
                      icon: LucideIcons.trash2,
                      title: context.t.privacy.deletePrivateDataAction,
                      subtitle: context.t.privacy.privateDataDescription,
                      titleColor: AppColors.destructive,
                      onTap: () {
                        Navigator.pop(context);
                        _showConfirmationDialog(
                          context: context,
                          title: context.t.privacy.confirmPrivateDataDeletion,
                          message: context.t.privacy.confirmPrivateDataResetMessage,
                          isDestructive: true,
                          onConfirm: () async {
                            await _resetData(context, ref);
                          },
                        );
                      },
                    )
                  else ...[
                    _buildOptionCard(
                      context: context,
                      icon: LucideIcons.refreshCw,
                      title: context.t.privacy.resetData,
                      subtitle: context.t.privacy.resetDataDescription,
                      onTap: () {
                        Navigator.pop(context);
                        _showConfirmationDialog(
                          context: context,
                          title: context.t.privacy.confirmDataReset,
                          message: context.t.privacy.confirmResetMessage,
                          onConfirm: () async {
                            await _resetData(context, ref);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildOptionCard(
                      context: context,
                      icon: LucideIcons.trash2,
                      title: context.t.privacy.deleteAccount,
                      subtitle: context.t.privacy.deleteAccountDescription,
                      titleColor: AppColors.destructive,
                      onTap: () {
                        Navigator.pop(context);
                        _showConfirmationDialog(
                          context: context,
                          title: context.t.privacy.confirmAccountDeletion,
                          message: context.t.privacy.confirmDeleteAccountMessage,
                          isDestructive: true,
                          onConfirm: () async {
                            await _deleteAccount(context, ref);
                          },
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          context.t.common.actions.cancel,
                          style: GoogleFonts.inter(
                            color: context.appColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.appColors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (titleColor ?? context.appColors.foreground).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: titleColor ?? context.appColors.foreground,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? context.appColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            DirectionalIcon(
              LucideIcons.chevronRight,
              LucideIcons.chevronLeft,
              color: context.appColors.mutedForeground,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.appColors.card.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.appColors.border.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDestructive
                          ? AppColors.destructive
                          : context.appColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          context.t.common.actions.cancel,
                          style: GoogleFonts.inter(
                            color: context.appColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          onConfirm();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDestructive
                                ? AppColors.destructive
                                : Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            context.t.common.actions.confirm,
                            style: GoogleFonts.inter(
                              color: isDestructive
                                  ? Colors.white
                                  : (Theme.of(context).colorScheme.primary
                                                .computeLuminance() >
                                            0.5
                                        ? Colors.black
                                        : Colors.white),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _resetData(BuildContext context, WidgetRef ref) async {
    try {
      if (ref.read(activeDataModeProvider) == AppDataMode.private) {
        await NotificationService().cancelAll();
        // Wipe the iCloud zone + encryption keys when sync was on. Best-effort:
        // a failure here must never block the local data wipe below.
        try {
          await ref.read(privateSyncServiceProvider).requestFullReset();
        } catch (e, stack) {
          AppLogger.error('iCloud full reset failed during delete', e, stack);
        }
        await ref.read(privateLocalDatabaseProvider).deleteAllPrivateData();
        ref.invalidate(goalsProvider);
        ref.invalidate(habitLogsProvider);
        ref.invalidate(habitStatsProvider);
        ref.invalidate(habitAnalyticsProvider);
        ref.invalidate(globalCriticalDayProvider);
        ref.invalidate(globalTrendProvider);
        ref.invalidate(criticalHabitsProvider);
        ref.invalidate(bestHabitsProvider);
        ref.invalidate(habitPerformanceProvider);
        ref.invalidate(habitAlertsProvider);
        ref.invalidate(habitYearlyGridProvider);
        ref.invalidate(habitCorrelationsProvider);
        ref.invalidate(allHabitCorrelationsProvider);
        ref.invalidate(macroGoalsProvider);
        ref.invalidate(macroGoalCategoriesProvider);
        ref.invalidate(macroGoalsStatsProvider);
        ref.invalidate(dailyMoodsProvider);
        ref.invalidate(userProfileProvider);
        ref.invalidate(settingsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.t.privacy.privateDataDeletedSuccess,
              ),
            ),
          );
        }
        return;
      }

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Utente non trovato.');

      await supabase.from('goals').delete().eq('user_id', user.id);
      await supabase.from('long_term_goals').delete().eq('user_id', user.id);

      // Clear local state and cache
      ref.read(goalsProvider.notifier).clearAll();
      ref.read(habitLogsProvider.notifier).clearAll();
      ref.read(macroGoalsProvider.notifier).clearAll();
      ref.read(settingsProvider.notifier).resetToDefaults();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.privacy.dataResetSuccess,
            ),
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error('Errore durante reset dati', e, stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.t.privacy.errors.resetPrefix}$e')),
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Utente non trovato.');

      // Elimina l'utente e tutti i dati associati tramite RPC (security definer)
      await supabase.rpc('delete_user_account');

      await supabase.auth.signOut();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t.privacy.accountDeletedSuccess,
            ),
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error('Errore durante eliminazione account', e, stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.t.privacy.errors.deletePrefix}$e')),
        );
      }
    }
  }
}
