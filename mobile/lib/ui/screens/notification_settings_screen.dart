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
import '../../i18n/translations.g.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const NotificationSettingsScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        var tween = Tween(
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

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: context.appColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.chevronLeft,
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
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

  Widget _buildTimePickerRow({
    required BuildContext context,
    required String title,
    required String time,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
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

  void _showAppleStyleTimePicker({
    required BuildContext context,
    required String initialTime,
    required bool use24hFormat,
    required Function(String) onTimeSelected,
  }) {
    final initialDateTime = AppTimeFormatting.dateTimeForToday(initialTime);

    String selectedTime = initialTime;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext modalContext) {
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: context.appColors.border.withValues(alpha: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(modalContext),
                        child: Text(
                          context.t.common.actions.cancel,
                          style: GoogleFonts.inter(
                            color: context.appColors.mutedForeground,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        context.t.notifications.selectTime,
                        style: GoogleFonts.inter(
                          color: context.appColors.foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          onTimeSelected(selectedTime);
                          Navigator.pop(modalContext);
                        },
                        child: Text(
                          context.t.common.actions.done,
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.appColors.border),
                Expanded(
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
              ],
            ),
          ),
        );
      },
    );
  }
}
