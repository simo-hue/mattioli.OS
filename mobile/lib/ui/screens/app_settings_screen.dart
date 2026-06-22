import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/settings_provider.dart';
import '../../core/haptics.dart';
import '../../i18n/translations.g.dart';
import '../widgets/pro_features_modal.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const AppSettingsScreen(),
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

    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: colors.foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.t.common.appSettings,
          style: TextStyle(
            color: colors.foreground,
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
              context.t.settings.sections.appearance,
            ),
            _buildSettingsCard(context, [
              _buildSwitchRow(
                context: context,
                icon: LucideIcons.moon,
                title: context.t.settings.appearance.darkMode,
                value: settings.themeMode == 'dark',
                onChanged: (val) {
                  final currentSettings = ref.read(settingsProvider);
                  notifier.updateSettings(
                    currentSettings.copyWith(themeMode: val ? 'dark' : 'light'),
                  );
                  ref.hapticLight();
                },
              ),
              _buildDivider(context),
              _buildActionRow(
                context: context,
                icon: LucideIcons.palette,
                title: context.t.settings.appearance.accentColor,
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: settings.accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: settings.accentColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  ref.hapticLight();
                  _showAccentColorPicker(context, ref, settings.accentColor);
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader(
              context,
              context.t.settings.sections.calendar,
            ),
            _buildSettingsCard(context, [
              _buildActionRow(
                context: context,
                icon: LucideIcons.calendar,
                title: context.t.settings.calendar.defaultView,
                trailingText: (() {
                  final v = settings.defaultCalendarView.toLowerCase();
                  if (v == 'week' || v == 'settimana') {
                    return context.t.common.calendarView.week;
                  }
                  if (v == 'month' || v == 'mese') {
                    return context.t.common.calendarView.month;
                  }
                  if (v == 'year' || v == 'anno') {
                    return context.t.common.calendarView.year;
                  }
                  if (v == 'vita') return context.t.common.calendarView.life;
                  return context.t.common.calendarView.week;
                })().toUpperCase(),
                onTap: () {
                  ref.hapticLight();
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Container(
                      decoration: BoxDecoration(
                        color: context.appColors.card,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        border: Border.all(color: context.appColors.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: context.appColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            context.t.settings.calendar.defaultView,
                            style: TextStyle(
                              color: context.appColors.foreground,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildViewOption(
                            context,
                            ref,
                            context.t.common.calendarView.month,
                            'mese',
                            settings.defaultCalendarView,
                          ),
                          _buildViewOption(
                            context,
                            ref,
                            context.t.common.calendarView.week,
                            'settimana',
                            settings.defaultCalendarView,
                          ),
                          _buildViewOption(
                            context,
                            ref,
                            context.t.common.calendarView.year,
                            'anno',
                            settings.defaultCalendarView,
                          ),
                          _buildViewOption(
                            context,
                            ref,
                            context.t.common.calendarView.life,
                            'vita',
                            settings.defaultCalendarView,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader(
              context,
              context.t.settings.sections.experience,
            ),
            _buildSettingsCard(context, [
              _buildSwitchRow(
                context: context,
                icon: LucideIcons.vibrate,
                title: context.t.settings.experience.hapticFeedback,
                value: settings.hapticFeedback,
                onChanged: (val) {
                  final currentSettings = ref.read(settingsProvider);
                  notifier.updateSettings(
                    currentSettings.copyWith(hapticFeedback: val),
                  );
                  if (val) ref.hapticMedium();
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader(
              context,
              context.t.settings.sections.unitsLanguage,
            ),
            _buildSettingsCard(context, [
              _buildActionRow(
                context: context,
                icon: LucideIcons.languages,
                title: context.t.settings.language.title,
                trailingText: _languagePreferenceLabel(
                  context,
                  settings.language,
                ),
                onTap: () {
                  ref.hapticLight();
                  _showLanguageSelector(context, ref, settings.language);
                },
              ),
              _buildDivider(context),
              _buildSwitchRow(
                context: context,
                icon: LucideIcons.clock,
                title: context.t.settings.units.timeFormat24h,
                value: settings.timeFormat24h,
                onChanged: (val) {
                  final currentSettings = ref.read(settingsProvider);
                  notifier.updateSettings(
                    currentSettings.copyWith(timeFormat24h: val),
                  );
                  ref.hapticLight();
                },
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: context.appColors.mutedForeground,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLocked = false,
    bool isComingSoon = false,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDisabled = isLocked || isComingSoon;

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
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: isDisabled
                            ? context.appColors.mutedForeground
                            : context.appColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
                    if (isComingSoon) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          context.t.settings.comingSoon,
                          style: GoogleFonts.inter(
                            color: primaryColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: context.appColors.mutedForeground.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 12,
                    ),
                  ),
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

  Widget _buildActionRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    Widget? trailing,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              child: Icon(icon, size: 18, color: primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: context.appColors.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText,
                style: GoogleFonts.inter(
                  color: context.appColors.mutedForeground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            trailing ?? const SizedBox.shrink(),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: context.appColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      indent: 60,
      endIndent: 16,
      color: context.appColors.border.withValues(alpha: 0.5),
    );
  }

  void _showAccentColorPicker(
    BuildContext context,
    WidgetRef ref,
    Color currentColor,
  ) {
    final settings = ref.read(settingsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: context.appColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.t.settings.appearance.accentColor,
              style: TextStyle(
                color: context.appColors.foreground,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.t.settings.appearance.accentColorSubtitle,
              style: TextStyle(
                color: context.appColors.mutedForeground,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 3 Presets
                ...AppSettingsNotifier.premiumAccentColors.take(3).map((c) {
                  final settings = ref.read(settingsProvider);
                  var color = c;
                  if (settings.themeMode == 'light' &&
                      color.toARGB32() == 0xFFFAFAFA) {
                    color = const Color(0xFF09090B);
                  }
                  final isSelected =
                      currentColor.toARGB32() == color.toARGB32();
                  return _buildColorOption(context, ref, color, isSelected);
                }),
                // Custom Color Picker Button
                GestureDetector(
                  onTap: () {
                    final settings = ref.read(settingsProvider);
                    if (!settings.isPro) {
                      Navigator.pop(
                        context,
                      ); // Close the accent color selector sheet
                      ref.hapticHeavy();
                      ProFeaturesModal.show(context);
                    } else {
                      HapticFeedback.mediumImpact();
                      _showFullColorPicker(context, ref, currentColor);
                    }
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: context.appColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: !settings.isPro
                            ? const Color(0xFFEAB308).withValues(alpha: 0.5)
                            : context.appColors.border,
                        width: 2,
                      ),
                      boxShadow: !settings.isPro
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFFEAB308,
                                ).withValues(alpha: 0.15),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      settings.isPro ? LucideIcons.plus : LucideIcons.lock,
                      color: settings.isPro
                          ? context.appColors.foreground
                          : const Color(0xFFEAB308),
                      size: settings.isPro ? 24 : 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(
    BuildContext context,
    WidgetRef ref,
    Color color,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        ref.hapticMedium();
        Navigator.pop(context); // Close bottom sheet
        _showValidationDialog(context, ref, color);
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? (color.computeLuminance() > 0.7
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.white)
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? Icon(
                LucideIcons.check,
                size: 24,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }

  void _showFullColorPicker(
    BuildContext parentContext,
    WidgetRef ref,
    Color currentColor,
  ) {
    final themeMode = ref.read(settingsProvider).themeMode;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        Color pickedColor = currentColor;
        return StatefulBuilder(
          builder: (context, setState) {
            final double luminance = pickedColor.computeLuminance();
            final bool isTooDark = themeMode == 'dark' && luminance < 0.15;

            return AlertDialog(
              backgroundColor: context.appColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isTooDark
                      ? context.appColors.destructive.withValues(alpha: 0.5)
                      : context.appColors.border,
                  width: isTooDark ? 2 : 1,
                ),
              ),
              title: Row(
                children: [
                  Text(context.t.settings.appearance.customColor),
                  const Spacer(),
                  if (isTooDark)
                    Icon(
                      LucideIcons.triangleAlert,
                      color: context.appColors.destructive,
                      size: 20,
                    ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SlidePicker(
                      pickerColor: pickedColor,
                      onColorChanged: (color) {
                        setState(() => pickedColor = color);
                      },
                      colorModel: ColorModel.rgb,
                      enableAlpha: false,
                      displayThumbColor: true,
                      showParams: true,
                    ),
                    if (isTooDark) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.appColors.destructive.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.info,
                              size: 16,
                              color: context.appColors.destructive,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.t.settings.appearance.colorTooDark,
                                style: TextStyle(
                                  color: context.appColors.destructive,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    context.t.common.actions.cancel,
                    style: TextStyle(color: context.appColors.mutedForeground),
                  ),
                ),
                ElevatedButton(
                  onPressed: isTooDark
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                          Navigator.of(parentContext).pop();
                          _showValidationDialog(
                            parentContext,
                            ref,
                            pickedColor,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTooDark
                        ? context.appColors.border
                        : Theme.of(dialogContext).colorScheme.primary,
                    foregroundColor: context.appColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(context.t.common.actions.verify),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showValidationDialog(
    BuildContext context,
    WidgetRef ref,
    Color testColor,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ValidationDialog(
        testColor: testColor,
        onConfirm: () {
          // SCENOGRAPHIC ANIMATION TRIGGER
          _applyColorWithAnimation(context, ref, testColor);
        },
      ),
    );
  }

  void _applyColorWithAnimation(
    BuildContext context,
    WidgetRef ref,
    Color newColor,
  ) {
    // We show a full screen overlay that fades in/out to create a "wow" transition
    final overlay = OverlayEntry(
      builder: (context) => _ScenographicTransition(color: newColor),
    );

    Overlay.of(context).insert(overlay);

    // Apply the color in the middle of the animation
    Future.delayed(const Duration(milliseconds: 400), () {
      ref.read(settingsProvider.notifier).setAccentColor(newColor);
    });

    // Remove overlay after animation
    Future.delayed(const Duration(milliseconds: 1200), () {
      overlay.remove();
      // Also close the settings bottom sheet if it was open (from presets)
      // Actually we are in a dialog here, so the bottom sheet of presets might still be there
      // Navigator.of(context).popUntil((route) => route.isFirst); // Too aggressive
    });
  }

  Widget _buildViewOption(
    BuildContext context,
    WidgetRef ref,
    String label,
    String value,
    String currentValue,
  ) {
    bool isSelected = value == currentValue;
    if (currentValue == 'week' && value == 'settimana') isSelected = true;
    if (currentValue == 'month' && value == 'mese') isSelected = true;
    if (currentValue == 'year' && value == 'anno') isSelected = true;

    final primaryColor = Theme.of(context).colorScheme.primary;
    return ListTile(
      onTap: () {
        ref
            .read(settingsProvider.notifier)
            .updateSettings(
              ref.read(settingsProvider).copyWith(defaultCalendarView: value),
            );
        ref.hapticMedium();
        Navigator.pop(context);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? primaryColor : context.appColors.foreground,
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: isSelected
          ? Icon(LucideIcons.check, color: primaryColor, size: 20)
          : null,
    );
  }

  String _languagePreferenceLabel(BuildContext context, String language) {
    switch (AppLanguagePreference.normalize(language)) {
      case AppLanguagePreference.italian:
        return context.t.settings.language.italian;
      case AppLanguagePreference.english:
        return context.t.settings.language.english;
      case AppLanguagePreference.spanish:
        return context.t.settings.language.spanish;
      case AppLanguagePreference.german:
        return context.t.settings.language.german;
      case AppLanguagePreference.arabic:
        return context.t.settings.language.arabic;
      case AppLanguagePreference.system:
      default:
        return context.t.settings.language.system;
    }
  }

  void _showLanguageSelector(
    BuildContext context,
    WidgetRef ref,
    String currentLanguage,
  ) {
    final currentPreference = AppLanguagePreference.normalize(currentLanguage);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.appColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.t.common.language,
              style: TextStyle(
                color: context.appColors.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            _buildLanguageOption(
              context,
              ref,
              AppLanguagePreference.system,
              currentPreference,
              subtitle: context.t.settings.language.systemDescription,
            ),
            _buildLanguageOption(
              context,
              ref,
              AppLanguagePreference.italian,
              currentPreference,
            ),
            _buildLanguageOption(
              context,
              ref,
              AppLanguagePreference.english,
              currentPreference,
            ),
            _buildLanguageOption(
              context,
              ref,
              AppLanguagePreference.spanish,
              currentPreference,
            ),
            _buildLanguageOption(
              context,
              ref,
              AppLanguagePreference.german,
              currentPreference,
            ),
            // Arabic is deferred until the RTL pass lands (see LOCALIZATION_PLAN.md).
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    WidgetRef ref,
    String language,
    String currentLanguage, {
    String? subtitle,
  }) {
    final isSelected =
        AppLanguagePreference.normalize(language) == currentLanguage;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return ListTile(
      onTap: () {
        if (!isSelected) {
          Navigator.pop(context);
          _applyLanguageWithAnimation(context, ref, language);
        } else {
          Navigator.pop(context);
        }
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(
        _languagePreferenceLabel(context, language),
        style: TextStyle(
          color: isSelected ? primaryColor : context.appColors.foreground,
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                color: context.appColors.mutedForeground,
                fontSize: 12,
              ),
            ),
      trailing: isSelected
          ? Icon(LucideIcons.check, color: primaryColor, size: 20)
          : null,
    );
  }

  void _applyLanguageWithAnimation(
    BuildContext context,
    WidgetRef ref,
    String newLanguage,
  ) {
    ref.hapticSuccess();

    final overlay = OverlayEntry(
      builder: (context) => _LanguageTransition(
        color: Theme.of(context).colorScheme.primary,
        language: _languagePreferenceLabel(context, newLanguage),
      ),
    );

    Overlay.of(context).insert(overlay);

    Future.delayed(const Duration(milliseconds: 400), () {
      final currentSettings = ref.read(settingsProvider);
      ref
          .read(settingsProvider.notifier)
          .updateSettings(currentSettings.copyWith(language: newLanguage));
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      overlay.remove();
    });
  }
}

class _ValidationDialog extends StatelessWidget {
  final Color testColor;
  final VoidCallback onConfirm;

  const _ValidationDialog({required this.testColor, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: testColor.withValues(alpha: 0.3), width: 2),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: testColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.eye, color: testColor, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            context.t.settings.appearance.verifyVisibility,
            style: TextStyle(
              color: context.appColors.foreground,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.t.settings.appearance.visibilityCheckPrompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appColors.mutedForeground.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: testColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: testColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  context.t.settings.confirmDialog.confirm,
                  style: TextStyle(
                    color: testColor.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.t.settings.confirmDialog.goBack,
              style: TextStyle(
                color: testColor.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenographicTransition extends StatefulWidget {
  final Color color;
  const _ScenographicTransition({required this.color});

  @override
  State<_ScenographicTransition> createState() =>
      _ScenographicTransitionState();
}

class _ScenographicTransitionState extends State<_ScenographicTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scale = Tween<double>(begin: 0.0, end: 5.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInCubic),
      ),
    );
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTransition extends StatefulWidget {
  final Color color;
  final String language;
  const _LanguageTransition({required this.color, required this.language});

  @override
  State<_LanguageTransition> createState() => _LanguageTransitionState();
}

class _LanguageTransitionState extends State<_LanguageTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scale = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInCubic),
      ),
    );
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.languages,
                    color: context.appColors.foreground,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.language.toUpperCase(),
                    style: TextStyle(
                      color: widget.color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
