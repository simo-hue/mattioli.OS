import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../../core/rtl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../../core/backup_import_service.dart';
import '../kit/evolve_dialog.dart';
import '../kit/evolve_toast.dart';
import '../kit/evolve_switch.dart';
import '../kit/evolve_section_header.dart';
import '../kit/evolve_sheet.dart';
import '../kit/evolve_button.dart';
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
import '../../core/openrouter_service.dart';
import '../../core/secure_storage_utils.dart';
import '../widgets/animations/pulsing_sync_animation.dart';
import 'icloud_sync_screen.dart';
import '../../providers/settings_provider.dart';
import '../widgets/biometric_lock_gate.dart';
import '../../providers/consent_provider.dart';
import '../../core/haptics.dart';
import '../../core/app_logger.dart';
import '../../i18n/translations.g.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const PrivacySettingsScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
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
                    // The biometric prompt is a system overlay during which the
                    // user can background or pop the screen, disposing this
                    // ConsumerWidget. Bail before reading `ref` on a dead tree.
                    if (!context.mounted) return;
                    if (authenticated) {
                      // The user just authenticated to enable the lock, so count
                      // it as this session's unlock — the app-wide lock gate must
                      // not immediately prompt again. Set this BEFORE enabling so
                      // the gate never observes an armed-but-unauthenticated state.
                      ref.read(biometricUnlockedProvider.notifier).set(true);
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
    return EvolveSectionHeader(
      title,
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 12),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return EvolveListSection(
      children: children.where((c) => c is! Divider).toList(),
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
          EvolveSwitch(value: value, onChanged: onChanged),
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

    showEvolveFormSheet<void>(
      context: context,
      title: context.t.privacy.changePassword,
      leading: EvolveTextAction(
        label: context.t.common.actions.cancel,
        onPressed: () => Navigator.pop(context),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> onSubmit() async {
              if (!isVerified) {
                final currentPwd = currentPasswordController.text;
                if (currentPwd.isEmpty) {
                  setState(
                    () => errorMessage =
                        context.t.privacy.currentPasswordRequired,
                  );
                  return;
                }
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                try {
                  final supabase = Supabase.instance.client;
                  final email = supabase.auth.currentUser?.email;
                  if (email == null) {
                    throw Exception(context.t.privacy.userNotFound);
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
                final confirmPwd = confirmPasswordController.text;
                if (newPwd.isEmpty || confirmPwd.isEmpty) {
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
                  final supabase = Supabase.instance.client;
                  await supabase.auth.updateUser(
                    UserAttributes(password: newPwd),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    showEvolveToast(
                      context,
                      message: context.t.privacy.passwordUpdated,
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
                    errorMessage = e.toString().replaceAll('Exception: ', '');
                  });
                }
              }
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        color: context.appColors.destructive,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  EvolveButton(
                    label: isVerified
                        ? context.t.common.actions.save
                        : context.t.common.actions.verify,
                    loading: isLoading,
                    onPressed: onSubmit,
                  ),
                ],
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

      // Read before the awaits below: the share text is the last use of
      // `context` in this branch and would otherwise cross an async gap.
      final shareText = context.t.privacy.exportedDataTitle;
      final settings = ref.read(settingsProvider);
      // habits / macro goals / moods are no longer read from the in-memory
      // providers: their models carry no `updated_at`, which is what silently
      // broke Merge re-imports. They come from the tables below instead.
      // Categories stay — the importer matches them by NAME and never consults a
      // timestamp, so serialising them is lossless.
      final categories =
          ref.read(macroGoalCategoriesProvider).value ?? const [];
      final profile = ref.read(userProfileProvider);

      // Read the logs from the table, NOT from habitLogsProvider. That map is
      // `{date: {goalId: status}}` built from a `id, goal_id, date, status`
      // select whose fold also drops the id (goal_provider.dart), so `value`,
      // `streak`, `notes` and the timestamps can never reach it — exporting it
      // hands the user a file that nulls every logged quantity (steps/minutes/
      // reps, incl. HealthKit-measured ones) and zeroes every streak on restore,
      // while reporting success. Emitting full rows as a LIST also routes the
      // file through normalizeBackup's lossless branch instead of its lossy
      // legacy-Map branch.
      //
      // `select()` names no columns on purpose: an explicit list would silently
      // drop whatever it omits, and the deployed table may legitimately run
      // ahead of the checked-in snapshot. (`streak` was the concrete case; it is
      // now declared in schema.sql.)
      //
      // Paged for the reason kGoalLogsSyncPageSize documents: a single
      // unbounded PostgREST select is capped by the project's db-max-rows and
      // would truncate a long history with no error. The id tiebreaker keeps the
      // order total across pages.
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Utente non trovato.');

      // Paged raw-table read. Everything the import side merges by
      // last-write-wins MUST come through here rather than through a model's
      // `toJson()`: those emit no `updated_at`, and `incomingWins` treats a null
      // incoming timestamp as OLDEST, so a Merge import skipped every row whose
      // id already existed — i.e. a same-account restore was a silent no-op for
      // habits, macro goals and moods, while logs and progress (raw rows, real
      // timestamps) merged normally. The result was a habit reverted to Checkbox
      // still owning its goal_progress numbers, reported as "unchanged".
      Future<List<Map<String, dynamic>>> fetchAllRows(String table) async {
        final all = <Map<String, dynamic>>[];
        for (var offset = 0; ; offset += kGoalLogsSyncPageSize) {
          final page = await supabase
              .from(table)
              .select()
              .eq('user_id', userId)
              .order('id', ascending: true)
              .range(offset, offset + kGoalLogsSyncPageSize - 1);
          final rows = List<Map<String, dynamic>>.from(page);
          all.addAll(rows);
          if (rows.length < kGoalLogsSyncPageSize) break;
        }
        return all;
      }

      final habitLogs = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += kGoalLogsSyncPageSize) {
        final page = await supabase
            .from('goal_logs')
            .select()
            .eq('user_id', userId)
            .order('date', ascending: true)
            .order('id', ascending: true)
            .range(offset, offset + kGoalLogsSyncPageSize - 1);
        final rows = List<Map<String, dynamic>>.from(page);
        habitLogs.addAll(rows);
        if (rows.length < kGoalLogsSyncPageSize) break;
      }

      // Same treatment for the three entities that were being serialised from
      // in-memory models. `daily_moods` becomes a LIST of rows; normalizeBackup
      // accepts both shapes and its list branch is the one that reads
      // created_at/updated_at.
      final habitRows = await fetchAllRows('goals');
      final macroGoalRows = await fetchAllRows('long_term_goals');
      final moodRows = await fetchAllRows('daily_moods');

      // Quantitative-target daily numbers ride in the backup under 'habitProgress'
      // (the key the import side already reads) so a Replace-import can't wipe
      // goal_progress by finding an empty keep-set. Degrades to empty if the table
      // isn't there yet — the v9 migration lands before the targets flag flips, so
      // a pre-migration export still succeeds instead of failing whole.
      final habitProgress = <Map<String, dynamic>>[];
      try {
        for (var offset = 0; ; offset += kGoalLogsSyncPageSize) {
          final page = await supabase
              .from('goal_progress')
              .select()
              .eq('user_id', userId)
              .order('date', ascending: true)
              .order('id', ascending: true)
              .range(offset, offset + kGoalLogsSyncPageSize - 1);
          final rows = List<Map<String, dynamic>>.from(page);
          habitProgress.addAll(rows);
          if (rows.length < kGoalLogsSyncPageSize) break;
        }
      } catch (e, stack) {
        AppLogger.error(
            '[Export] goal_progress read skipped (pre-migration?)', e, stack);
      }

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
        'habits': habitRows,
        'habitLogs': habitLogs,
        'habitProgress': habitProgress,
        'macroGoals': macroGoalRows,
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
        'dailyMoods': moodRows,
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
          text: shareText,
        ),
      );
    } catch (e, stack) {
      AppLogger.error('Error exporting data', e, stack);
      if (context.mounted) {
        showEvolveToast(
          context,
          message: '${context.t.privacy.errors.exportPrefix}$e',
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

      // Private-mode import needs the encrypted local DB to open. If its key is
      // unreadable (after moving to a new device or a change to the app's
      // signing that rotated the Keychain access group) the DB is LOCKED and
      // every write throws PrivateDatabaseLockedException. Detect it up front
      // and offer an explicit reset-and-import — the old local data is
      // unrecoverable (its key is gone), but the backup imports onto a fresh key.
      if (isPrivateMode && await privateStore.isDatabaseLocked()) {
        if (!context.mounted) return;
        final recover = await showEvolveConfirm(
          context: context,
          title: context.t.privacy.importLockedTitle,
          message: context.t.privacy.importLockedMessage,
          confirmLabel: context.t.privacy.importLockedResetButton,
          isDestructive: true,
          ref: ref,
        );
        if (!recover) return;
        if (!context.mounted) return;
        await privateStore.resetLockedDatabase();
      }

      // 1. Preview
      final preview = await importService.parsePreview(path);

      if (!context.mounted) return;

      // 2. Ask for Replace/Merge. Default to the NON-destructive Merge: Replace
      // wipes every existing record not in the backup, so it must be an explicit
      // opt-in, never the pre-selected one-tap default.
      bool replaceExisting = false;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: context.appColors.background,
                title: Text(
                  context.t.privacy.importPreviewTitle,
                  style: GoogleFonts.inter(
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
                      // Merge first (the safe, default choice); Replace below and
                      // marked destructive so it can't be tapped by reflex.
                      // Flutter 3.32 deprecated per-tile groupValue/onChanged in
                      // favour of a RadioGroup ancestor holding the selection.
                      RadioGroup<bool>(
                        groupValue: replaceExisting,
                        onChanged: (val) => setState(() => replaceExisting = val!),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RadioListTile<bool>(
                              title: Text(context.t.privacy.importModeMerge, style: TextStyle(color: context.appColors.foreground)),
                              subtitle: Text(context.t.privacy.importModeMergeDesc, style: TextStyle(color: context.appColors.mutedForeground, fontSize: 12)),
                              value: false,
                              activeColor: Theme.of(context).colorScheme.primary,
                            ),
                            RadioListTile<bool>(
                              title: Text(context.t.privacy.importModeReplace, style: const TextStyle(color: AppColors.destructive)),
                              subtitle: Text(context.t.privacy.importModeReplaceDesc, style: TextStyle(color: context.appColors.mutedForeground, fontSize: 12)),
                              value: true,
                              activeColor: AppColors.destructive,
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

      // Replace is destructive: it deletes every existing record not in the
      // backup. Require a second, explicit confirmation that names the loss with
      // a real count (the logs currently loaded in memory, both modes), so a
      // stale/partial backup can't silently wipe a full history.
      if (replaceExisting) {
        final logCount = ref
            .read(habitLogsProvider)
            .values
            .fold<int>(0, (sum, day) => sum + day.length);
        final proceed = await showEvolveConfirm(
          context: context,
          title: context.t.privacy.importReplaceConfirmTitle,
          message: context.t.privacy.importReplaceConfirmMessage(count: logCount),
          confirmLabel: context.t.privacy.importReplaceConfirmButton,
          isDestructive: true,
          ref: ref,
        );
        if (!proceed) return;
        if (!context.mounted) return;
      }

      progressShown = true;
      // Deliberately not awaited: this is a blocking progress dialog shown while
      // the import runs underneath it, and it is popped further down. Awaiting
      // here would stall the import until the user dismissed it.
      unawaited(showDialog(
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
      ));

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

        await showEvolveAlert(
          context: context,
          title: context.t.privacy.importCompletedTitle,
          dismissLabel: context.t.privacy.importSummaryDone,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                importResult.replaced
                    ? context.t.privacy.importSummaryReplaced
                    : context.t.privacy.importSummaryMerged,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.appColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(context, LucideIcons.check, _mergeRowText(context, importResult, importResult.habits, context.t.privacy.importEntityHabits)),
              _buildSummaryRow(context, LucideIcons.history, _mergeRowText(context, importResult, importResult.logs, context.t.privacy.importEntityLogs)),
              _buildSummaryRow(context, LucideIcons.target, _mergeRowText(context, importResult, importResult.macroGoals, context.t.privacy.importEntityMacroGoals)),
              _buildSummaryRow(context, LucideIcons.folder, _mergeRowText(context, importResult, importResult.categories, context.t.privacy.importEntityCategories)),
              _buildSummaryRow(context, LucideIcons.smile, _mergeRowText(context, importResult, importResult.moods, context.t.privacy.importEntityMoods)),
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

        await showEvolveAlert(
          context: context,
          title: context.t.privacy.importFailedTitle,
          message: e.toString(),
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
      // The host CupertinoAlertDialog is fixed-width (~270pt) by iOS design, so
      // the summary text must wrap rather than clip. Top-align the icon and let
      // the text take the remaining width with Expanded so long rows flow onto
      // multiple lines instead of being cut off at the dialog edge.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon,
                size: 16, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
                color: context.appColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteOrResetModal(BuildContext context, WidgetRef ref) {
    final isPrivateMode =
        ref.read(activeDataModeProvider) == AppDataMode.private;
    showEvolveSheet<void>(
      context: context,
      title: isPrivateMode
          ? context.t.privacy.privateDataManagement
          : context.t.privacy.accountDataManagement,
      itemsBuilder: (sheetContext) => [
        EvolveListSection(
          children: [
            if (isPrivateMode)
              EvolveListRow(
                leading: EvolveIconTile(
                  icon: LucideIcons.trash2,
                  tint: context.appColors.destructive,
                ),
                title: context.t.privacy.deletePrivateDataAction,
                subtitle: context.t.privacy.privateDataDescription,
                titleColor: context.appColors.destructive,
                onTap: () {
                  Navigator.pop(sheetContext);
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
              EvolveListRow(
                leading: EvolveIconTile(
                  icon: LucideIcons.refreshCw,
                  tint: Theme.of(context).colorScheme.primary,
                ),
                title: context.t.privacy.resetData,
                subtitle: context.t.privacy.resetDataDescription,
                onTap: () {
                  Navigator.pop(sheetContext);
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
              EvolveListRow(
                leading: EvolveIconTile(
                  icon: LucideIcons.trash2,
                  tint: context.appColors.destructive,
                ),
                title: context.t.privacy.deleteAccount,
                subtitle: context.t.privacy.deleteAccountDescription,
                titleColor: context.appColors.destructive,
                onTap: () {
                  Navigator.pop(sheetContext);
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
          ],
        ),
      ],
    );
  }

  

  void _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    showEvolveConfirm(
      context: context,
      title: title,
      message: message,
      isDestructive: isDestructive,
    ).then((confirmed) {
      if (confirmed) onConfirm();
    });
  }

  Future<void> _resetData(BuildContext context, WidgetRef ref) async {
    try {
      if (ref.read(activeDataModeProvider) == AppDataMode.private) {
        final privateStore = ref.read(privateLocalDatabaseProvider);

        // Locked-DB recovery: if the encrypted DB can't be unlocked (its key is
        // gone), the row-wipe below can't even open it — every step would throw
        // PrivateDatabaseLockedException. Fall back to a file-level reset so
        // "delete private data" still recovers a locked device for a user with
        // no backup to import.
        //
        // resetLockedDatabase now RETAINS the encrypted file (renamed aside,
        // with its key parked) — right for a recovery, wrong here: this action
        // promises irreversible deletion, and the database may be perfectly
        // intact (a wrong key also reads as locked). Destroy the retained copy
        // immediately, or the app keeps a full copy of the data it just said it
        // had deleted.
        if (await privateStore.isDatabaseLocked()) {
          await NotificationService().cancelAll();
          await privateStore.resetLockedDatabase();
          await privateStore.deleteLockedAsideCopy();
          invalidatePrivateDataProviders(ref);
          if (context.mounted) {
            showEvolveToast(
              context,
              message: context.t.privacy.privateDataDeletedSuccess,
            );
          }
          return;
        }

        await NotificationService().cancelAll();
        // Wipe the iCloud zone + encryption keys when sync was on. Best-effort:
        // a failure here must never block the local data wipe below.
        try {
          await ref.read(privateSyncServiceProvider).requestFullReset();
        } catch (e, stack) {
          AppLogger.error('iCloud full reset failed during delete', e, stack);
        }
        await privateStore.deleteAllPrivateData();
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
          showEvolveToast(
            context,
            message: context.t.privacy.privateDataDeletedSuccess,
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

      // The analytics providers are keepAlive'd and depend on nothing this reset
      // changes (the user id is the same), so without an explicit invalidate they
      // keep serving pre-reset statistics for habits that no longer exist. In
      // cloud mode each re-reads Supabase, which the deletes above already
      // emptied, so they recompute correctly.
      //
      // Only the DERIVED providers belong here. invalidatePrivateDataProviders
      // must NOT be used in this branch: it also invalidates the notifiers
      // cleared just above, and their cloud build() re-seeds from
      // initialGoalsProvider / initialLogsProvider — overrideWithValue blobs
      // frozen at cold start (main.dart), so they still hold the pre-reset data
      // and would resurrect exactly what was deleted. The private branch can use
      // the helper because its build() re-reads the emptied local DB instead.
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
      ref.invalidate(macroGoalsStatsProvider);

      if (context.mounted) {
        showEvolveToast(
          context,
          message: context.t.privacy.dataResetSuccess,
        );
      }
    } catch (e, stack) {
      AppLogger.error('Errore durante reset dati', e, stack);
      if (context.mounted) {
        showEvolveToast(
          context,
          message: '${context.t.privacy.errors.resetPrefix}$e',
        );
      }
    }
  }

  /// Revokes the Sign in with Apple grant bound to this account, as Apple asks
  /// apps offering SIWA to do when the account is deleted.
  ///
  /// Apple's `authorizationCode` is single-use and expires in ~5 minutes, so it
  /// cannot be captured at sign-in and kept for a deletion that happens months
  /// later; re-running the credential request mints a fresh one seconds before
  /// it is exchanged. Exchanging and revoking it both need the team's .p8
  /// signing key, which must never ship inside the app — hence the edge
  /// function, which the caller's own JWT authenticates against.
  ///
  /// Returns false when the grant could not be revoked. The caller must still
  /// delete: a user asking to be erased is never trapped by an Apple-side step
  /// failing (or by them dismissing the credential sheet).
  Future<bool> _revokeAppleToken(User user) async {
    final hasAppleIdentity =
        user.identities?.any((identity) => identity.provider == 'apple') ??
        false;
    if (!Platform.isIOS || !hasAppleIdentity) return true;

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [],
      );
      await Supabase.instance.client.functions.invoke(
        'revoke-apple-token',
        body: {'authorization_code': credential.authorizationCode},
      );
      return true;
    } catch (e, stack) {
      AppLogger.error('Apple token revocation failed', e, stack);
      return false;
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Utente non trovato.');

      // Revoke before the RPC: the edge function authenticates as this user, and
      // once auth.users is gone there is no session left to authorize it with.
      final appleRevoked = await _revokeAppleToken(user);

      // Elimina l'utente e tutti i dati associati tramite RPC (security definer)
      await supabase.rpc('delete_user_account');

      // The cloud row is gone; drop the on-device mirror of it too, or the
      // habits and history the user just erased outlive the account in the
      // keychain (which survives even an uninstall). Same teardown as the
      // Supabase branch of _resetData, plus the cache-owner marker: deletion is
      // permanent, so unlike a transient logout there is nothing to keep. The
      // marker must go or the next account's empty first sync is refused as
      // cross-account contamination and this account's cache is served to them
      // at cold start.
      try {
        await NotificationService().cancelAll();
        ref.read(goalsProvider.notifier).clearAll();
        ref.read(habitLogsProvider.notifier).clearAll();
        ref.read(macroGoalsProvider.notifier).clearAll();
        ref.read(settingsProvider.notifier).resetToDefaults();
        await SecureStorageUtils.delete(kCacheOwnerKey);
      } finally {
        // The BYOK OpenRouter key is a Keychain secret that, like the cache
        // marker, survives even an uninstall — so this permanent erasure must
        // purge it too, or the next user of a shared/resold device inherits it
        // and spends this account's OpenRouter credits. It runs in the finally so
        // a throw from any teardown step above can't skip it, and is guarded so
        // its own failure can't abort the sign-out that frees the user. Same
        // mechanism as the Settings "remove key" action.
        try {
          await ref.read(openRouterApiKeyProvider.notifier).clear();
        } catch (e, stack) {
          AppLogger.error(
            'BYOK key purge failed during account deletion',
            e,
            stack,
          );
        }
      }

      // Report before signing out: signOut redirects to /login and disposes this
      // screen, so a toast deferred past it would never reach a live context.
      if (context.mounted) {
        showEvolveToast(
          context,
          message: appleRevoked
              ? context.t.privacy.accountDeletedSuccess
              : context.t.privacy.accountDeletedAppleRevokeFailed,
          kind: appleRevoked ? EvolveToastKind.neutral : EvolveToastKind.error,
          duration: Duration(seconds: appleRevoked ? 2 : 6),
        );
      }

      await supabase.auth.signOut();
    } catch (e, stack) {
      AppLogger.error('Errore durante eliminazione account', e, stack);
      if (context.mounted) {
        showEvolveToast(
          context,
          message: '${context.t.privacy.errors.deletePrefix}$e',
        );
      }
    }
  }
}
