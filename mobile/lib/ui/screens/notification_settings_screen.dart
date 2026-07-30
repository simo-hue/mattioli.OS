import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/settings_provider.dart';
import '../../core/haptics.dart';
import '../../core/notifications.dart';
import '../../core/time_formatting.dart';
import '../../core/rtl.dart';
import '../../core/verification_config.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_switch.dart';
import '../kit/evolve_section_header.dart';
import '../kit/evolve_sheet.dart';
import '../kit/evolve_route.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static Route route() =>
      evolveRoute((context) => const NotificationSettingsScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: context.appColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            directionalIcon(
              context,
              LucideIcons.chevronLeft,
              LucideIcons.chevronRight,
            ),
            color: context.appColors.foreground,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.t.common.notifications,
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
            // Focus Mode comes FIRST, above every other switch, because it
            // overrides all of them: `_runNotificationSync` cancels everything
            // and returns early while it is on. macOS has always had this toggle
            // and syncs the value, so before this row existed the Mac could
            // permanently silence the iPhone with no visible cause and no way to
            // undo it on the phone. A person whose reminders stopped opens this
            // screen — the switch that explains it has to be the first thing
            // they see, not buried under the switches it is suppressing.
            _buildSectionHeader(context, context.t.notifications.focusHeader),
            _buildSettingsCard(context, [
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.moonStar,
                title: context.t.notifications.focusMode,
                // The sync note is part of the subtitle, not a footnote: this
                // switch is a SYNCED setting, so turning it on here also
                // silences the Mac (and vice versa). Saying so is what makes the
                // cross-device silence explainable rather than a mystery.
                subtitle: '${context.t.notifications.focusModeSubtitle} '
                    '${context.t.notifications.focusModeSyncNote}',
                value: settings.focusMode,
                onChanged: (val) {
                  final currentSettings = ref.read(settingsProvider);
                  notifier.updateSettings(
                    currentSettings.copyWith(focusMode: val),
                  );
                  ref.hapticLight();
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader(
              context,
              context.t.notifications.operationalRemindersHeader,
            ),
            _buildSettingsCard(context, [
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.calendarCheck,
                title: context.t.notifications.habitReminders,
                subtitle: context.t.notifications.morningBrief,
                value: settings.habitReminders,
                onChanged: (val) {
                  if (val) NotificationService().requestPermissions();
                  final currentSettings = ref.read(settingsProvider);
                  notifier.updateSettings(
                    currentSettings.copyWith(habitReminders: val),
                  );
                  ref.hapticLight();
                },
              ),
              if (settings.habitReminders)
                _buildTimePickerRow(
                  context: context,
                  title: context.t.notifications.morningBriefTime,
                  time: AppTimeFormatting.formatStoredTime(
                    settings.morningBriefTime,
                    use24hFormat: settings.timeFormat24h,
                  ),
                  onTap: () {
                    _showAppleStyleTimePicker(
                      context: context,
                      initialTime: settings.morningBriefTime,
                      use24hFormat: settings.timeFormat24h,
                      onTimeSelected: (timeStr) {
                        final currentSettings = ref.read(settingsProvider);
                        notifier.updateSettings(
                          currentSettings.copyWith(morningBriefTime: timeStr),
                        );
                        ref.hapticLight();
                      },
                    );
                  },
                ),
              _buildDivider(context),
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.bellRing,
                title: context.t.notifications.eveningReview,
                subtitle: context.t.notifications.eveningReview,
                value: settings.eveningReview,
                onChanged: (val) {
                  if (val) NotificationService().requestPermissions();
                  final currentSettings = ref.read(settingsProvider);
                  notifier.updateSettings(
                    currentSettings.copyWith(eveningReview: val),
                  );
                  ref.hapticLight();
                },
              ),
              if (settings.eveningReview)
                _buildTimePickerRow(
                  context: context,
                  title: context.t.notifications.eveningReviewTime,
                  time: AppTimeFormatting.formatStoredTime(
                    settings.eveningReviewTime,
                    use24hFormat: settings.timeFormat24h,
                  ),
                  onTap: () {
                    _showAppleStyleTimePicker(
                      context: context,
                      initialTime: settings.eveningReviewTime,
                      use24hFormat: settings.timeFormat24h,
                      onTimeSelected: (timeStr) {
                        final currentSettings = ref.read(settingsProvider);
                        notifier.updateSettings(
                          currentSettings.copyWith(eveningReviewTime: timeStr),
                        );
                        ref.hapticLight();
                      },
                    );
                  },
                ),
            ]),
            // Auto-verified habits (D11). Only shown when the feature is live;
            // nudges default on, celebration + failure summary are opt-in.
            if (VerificationConfig.enabled) ...[
              const SizedBox(height: 32),
              _buildSectionHeader(
                context,
                context.t.notifications.verificationHeader,
              ),
              _buildSettingsCard(context, [
                _buildSwitchRow(
                  context: context,
                  ref: ref,
                  icon: LucideIcons.badgeCheck,
                  title: context.t.notifications.verificationNudges,
                  subtitle: context.t.notifications.verificationNudgesSubtitle,
                  value: settings.verificationNudges,
                  onChanged: (val) {
                    if (val) NotificationService().requestPermissions();
                    final current = ref.read(settingsProvider);
                    notifier.updateSettings(
                      current.copyWith(verificationNudges: val),
                    );
                    ref.hapticLight();
                  },
                ),
                _buildDivider(context),
                _buildSwitchRow(
                  context: context,
                  ref: ref,
                  icon: LucideIcons.partyPopper,
                  title: context.t.notifications.verificationCelebrations,
                  subtitle:
                      context.t.notifications.verificationCelebrationsSubtitle,
                  value: settings.verificationCelebrations,
                  onChanged: (val) {
                    if (val) NotificationService().requestPermissions();
                    final current = ref.read(settingsProvider);
                    notifier.updateSettings(
                      current.copyWith(verificationCelebrations: val),
                    );
                    ref.hapticLight();
                  },
                ),
                _buildDivider(context),
                _buildSwitchRow(
                  context: context,
                  ref: ref,
                  icon: LucideIcons.triangleAlert,
                  title: context.t.notifications.verificationFailureSummary,
                  subtitle: context
                      .t.notifications.verificationFailureSummarySubtitle,
                  value: settings.verificationFailureSummary,
                  onChanged: (val) {
                    if (val) NotificationService().requestPermissions();
                    final current = ref.read(settingsProvider);
                    notifier.updateSettings(
                      current.copyWith(verificationFailureSummary: val),
                    );
                    ref.hapticLight();
                  },
                ),
              ]),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
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

  Widget _buildTimePickerRow({
    required BuildContext context,
    required String title,
    required String time,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        bottom: 12,
        top: 4,
      ),
      child: Row(
        children: [
          const SizedBox(width: 54), // Allinea con il testo dello switch row
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: context.appColors.mutedForeground,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.appColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.appColors.border),
              ),
              child: Text(
                time,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
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

  void _showAppleStyleTimePicker({
    required BuildContext context,
    required String initialTime,
    required bool use24hFormat,
    required Function(String) onTimeSelected,
  }) {
    final initialDateTime = AppTimeFormatting.dateTimeForToday(initialTime);

    String selectedTime = initialTime;

    showEvolveFormSheet<void>(
      context: context,
      title: context.t.notifications.selectTime,
      leading: EvolveTextAction(
        label: context.t.common.actions.cancel,
        onPressed: () => Navigator.pop(context),
      ),
      trailing: EvolveTextAction(
        label: context.t.common.actions.done,
        emphasized: true,
        onPressed: () {
          onTimeSelected(selectedTime);
          Navigator.pop(context);
        },
      ),
      builder: (sheetContext) => SizedBox(
        height: 216,
        child: CupertinoTheme(
          data: CupertinoThemeData(
            brightness: Theme.of(context).brightness,
            textTheme: CupertinoTextThemeData(
              dateTimePickerTextStyle: GoogleFonts.inter(
                color: context.appColors.foreground,
                fontSize: 20,
              ),
            ),
          ),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: use24hFormat,
            initialDateTime: initialDateTime,
            onDateTimeChanged: (DateTime newDateTime) {
              selectedTime = AppTimeFormatting.serializeDateTime(
                newDateTime,
              );
            },
          ),
        ),
      ),
    );
  }
}
