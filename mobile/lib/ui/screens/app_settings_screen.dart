import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/settings_provider.dart';
import '../../core/haptics.dart';
import '../../core/openrouter_service.dart';
import '../../core/rtl.dart';
import '../../core/verification_config.dart';
import '../../core/verification_providers.dart';
import '../widgets/apple_health_form.dart';
import '../../i18n/translations.g.dart';
import '../widgets/pro_features_modal.dart';
import '../kit/evolve_color_picker.dart';
import '../kit/evolve_dialog.dart';
import '../kit/evolve_sheet.dart';
import '../kit/evolve_switch.dart';
import '../kit/evolve_section_header.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  static Route route() {
    // MaterialPageRoute so iOS gets the native Cupertino slide + edge-swipe-back
    // gesture for free (Android keeps its native Material transition).
    return MaterialPageRoute(builder: (context) => const AppSettingsScreen());
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
          icon: DirectionalIcon(
            LucideIcons.chevronLeft,
            LucideIcons.chevronRight,
            color: colors.foreground,
          ),
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
            _buildSectionHeader(context, context.t.settings.sections.calendar),
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
                })(),
                onTap: () {
                  ref.hapticLight();
                  showEvolveSheet<void>(
                    context: context,
                    title: context.t.settings.calendar.defaultView,
                    itemsBuilder: (sheetContext) => [
                      EvolveListSection(
                        children: [
                          EvolveListRow(
                            leading: EvolveIconTile(
                              icon: LucideIcons.calendarDays,
                              tint: context.appColors.mutedForeground,
                            ),
                            title: context.t.common.calendarView.month,
                            selected:
                                settings.defaultCalendarView == 'mese' ||
                                settings.defaultCalendarView == 'month',
                            onTap: () {
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(
                                    ref
                                        .read(settingsProvider)
                                        .copyWith(defaultCalendarView: 'mese'),
                                  );
                              Navigator.pop(sheetContext);
                            },
                          ),
                          EvolveListRow(
                            leading: EvolveIconTile(
                              icon: LucideIcons.calendarRange,
                              tint: context.appColors.mutedForeground,
                            ),
                            title: context.t.common.calendarView.week,
                            selected:
                                settings.defaultCalendarView == 'settimana' ||
                                settings.defaultCalendarView == 'week',
                            onTap: () {
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(
                                    ref
                                        .read(settingsProvider)
                                        .copyWith(
                                          defaultCalendarView: 'settimana',
                                        ),
                                  );
                              Navigator.pop(sheetContext);
                            },
                          ),
                          EvolveListRow(
                            leading: EvolveIconTile(
                              icon: LucideIcons.calendar,
                              tint: context.appColors.mutedForeground,
                            ),
                            title: context.t.common.calendarView.year,
                            selected:
                                settings.defaultCalendarView == 'anno' ||
                                settings.defaultCalendarView == 'year',
                            onTap: () {
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(
                                    ref
                                        .read(settingsProvider)
                                        .copyWith(defaultCalendarView: 'anno'),
                                  );
                              Navigator.pop(sheetContext);
                            },
                          ),
                          EvolveListRow(
                            leading: EvolveIconTile(
                              icon: LucideIcons.infinity,
                              tint: context.appColors.mutedForeground,
                            ),
                            title: context.t.common.calendarView.life,
                            selected: settings.defaultCalendarView == 'vita',
                            onTap: () {
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(
                                    ref
                                        .read(settingsProvider)
                                        .copyWith(defaultCalendarView: 'vita'),
                                  );
                              Navigator.pop(sheetContext);
                            },
                          ),
                        ],
                      ),
                    ],
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
            _buildSectionHeader(context, context.t.settings.sections.aiCoach),
            _buildSettingsCard(context, [
              _buildActionRow(
                context: context,
                icon: LucideIcons.keyRound,
                title: context.t.ai.apiKey.rowTitle,
                // Reports only whether a key exists — the key itself is never
                // rendered back out of the Keychain.
                trailingText:
                    ref.watch(openRouterApiKeyProvider).asData?.value != null
                    ? context.t.ai.apiKey.statusSet
                    : context.t.ai.apiKey.statusMissing,
                onTap: () {
                  ref.hapticLight();
                  _showApiKeySheet(context);
                },
              ),
            ]),
            const SizedBox(height: 32),
            // Apple Health (Guideline 2.5.1). Unconditional and permanent: it
            // renders whether or not permission was ever requested, whether or
            // not any habit uses it, and on devices with no Health data at all.
            // The only previous mention of Health lived three levels deep in the
            // habit modal behind an Auto-verify switch that defaults off, and
            // hid itself for good once tapped — identification that can
            // disappear is not identification. This is also the surface to point
            // a screen recording at: launch, Settings, Apple Health.
            if (VerificationConfig.healthKitEnabled) ...[
              _buildSectionHeader(
                context,
                context.t.settings.sections.appleHealth,
              ),
              _buildSettingsCard(context, [
                _buildActionRow(
                  context: context,
                  icon: LucideIcons.heartPulse,
                  title: context.t.health.rowTitle,
                  trailingText: _healthStatus(context, ref),
                  onTap: () {
                    ref.hapticLight();
                    _showAppleHealthSheet(context);
                  },
                ),
              ]),
              const SizedBox(height: 32),
            ],
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
    return EvolveSectionHeader(
      title,
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 12),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    // Grouped-inset card (kit look); EvolveListSection draws its own hairlines,
    // so drop the legacy manual `_buildDivider` spacers.
    return EvolveListSection(
      children: children.where((c) => c is! Divider).toList(),
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
          EvolveSwitch(value: value, onChanged: onChanged),
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
            DirectionalIcon(
              LucideIcons.chevronRight,
              LucideIcons.chevronLeft,
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

  /// Status for the Apple Health row.
  ///
  /// Deliberately never claims "connected". iOS does not report read-grant, so
  /// the honest signals are only: does this device have Health at all, and has
  /// the user been through the prompt. Saying "Connected" for someone who tapped
  /// Deny would be a lie the app cannot detect.
  String? _healthStatus(BuildContext context, WidgetRef ref) {
    final t = context.t.health;
    final available = ref.watch(healthDataAvailableProvider).asData?.value;
    if (available == false) return t.statusUnavailable;
    final requested = ref.watch(healthAuthRequestedTypesProvider);
    return requested.isEmpty ? t.statusNotConnected : t.statusConnected;
  }

  void _showAppleHealthSheet(BuildContext context) {
    showEvolveFormSheet<void>(
      context: context,
      // The app's own localized name for Health — see AppleHealthForm.
      title: context.t.health.appName,
      trailing: EvolveTextAction(
        label: context.t.common.actions.done,
        onPressed: () => Navigator.pop(context),
      ),
      builder: (sheetContext) => const AppleHealthForm(),
    );
  }

  void _showApiKeySheet(BuildContext context) {
    showEvolveFormSheet<void>(
      context: context,
      title: context.t.ai.apiKey.rowTitle,
      trailing: EvolveTextAction(
        label: context.t.common.actions.done,
        onPressed: () => Navigator.pop(context),
      ),
      builder: (sheetContext) => const _ApiKeyForm(),
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
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: context.appColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EvolveGrabber(),
            EvolveSheetTitle(context.t.settings.appearance.accentColor),
            const SizedBox(height: 8),
            Text(
              context.t.settings.appearance.accentColorSubtitle,
              style: TextStyle(
                color: context.appColors.mutedForeground,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: EvolveColorSwatchGrid(
                selected: currentColor,
                palette: [
                  for (final c in AppSettingsNotifier.premiumAccentColors.take(
                    3,
                  ))
                    (settings.themeMode == 'light' &&
                            c.toARGB32() == 0xFFFAFAFA)
                        ? const Color(0xFF09090B)
                        : c,
                ],
                customLocked: !settings.isPro,
                onChanged: (color) {
                  Navigator.pop(context); // close the accent selector sheet
                  _showValidationDialog(context, ref, color);
                },
                onCustomTap: () {
                  if (!settings.isPro) {
                    Navigator.pop(context);
                    ref.hapticHeavy();
                    ProFeaturesModal.show(context);
                  } else {
                    ref.hapticMedium();
                    _showFullColorPicker(context, ref, currentColor);
                  }
                },
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
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

    showEvolveSheet<void>(
      context: context,
      title: context.t.common.language,
      itemsBuilder: (sheetContext) {
        final options = <({String pref, String? subtitle})>[
          (
            pref: AppLanguagePreference.system,
            subtitle: context.t.settings.language.systemDescription,
          ),
          (pref: AppLanguagePreference.italian, subtitle: null),
          (pref: AppLanguagePreference.english, subtitle: null),
          (pref: AppLanguagePreference.spanish, subtitle: null),
          (pref: AppLanguagePreference.german, subtitle: null),
          (pref: AppLanguagePreference.arabic, subtitle: null),
        ];
        return [
          EvolveListSection(
            children: options.map((opt) {
              final isSelected =
                  AppLanguagePreference.normalize(opt.pref) ==
                  currentPreference;
              return EvolveListRow(
                leading: EvolveIconTile(
                  icon: opt.pref == AppLanguagePreference.system
                      ? LucideIcons.smartphone
                      : LucideIcons.languages,
                  tint: context.appColors.mutedForeground,
                ),
                title: _languagePreferenceLabel(context, opt.pref),
                subtitle: opt.subtitle,
                selected: isSelected,
                onTap: () {
                  if (!isSelected) {
                    Navigator.pop(sheetContext);
                    _applyLanguageWithAnimation(context, ref, opt.pref);
                  } else {
                    Navigator.pop(sheetContext);
                  }
                },
              );
            }).toList(),
          ),
        ];
      },
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

/// BYOK form: the user's own OpenRouter API key. The app ships no key, so this
/// is what makes the AI Coach work at all.
///
/// A stored key is NEVER read back into the field — the Settings row reports
/// that one exists, and saving simply overwrites it. That keeps the secret off
/// the screen (and out of any screenshot) while still allowing a replacement.
class _ApiKeyForm extends ConsumerStatefulWidget {
  const _ApiKeyForm();

  @override
  ConsumerState<_ApiKeyForm> createState() => _ApiKeyFormState();
}

class _ApiKeyFormState extends ConsumerState<_ApiKeyForm> {
  final TextEditingController _field = TextEditingController();
  bool _busy = false;
  bool _saveFailed = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _field.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    final saved = await ref
        .read(openRouterApiKeyProvider.notifier)
        .save(_field.text);
    if (!mounted) return;
    if (saved) {
      // Close on success: the Settings row behind the sheet flips to "Saved",
      // which is the confirmation.
      ref.hapticMedium();
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = false;
      _saveFailed = true;
    });
  }

  Future<void> _remove() async {
    final confirmed = await showEvolveConfirm(
      context: context,
      title: context.t.ai.apiKey.removeConfirmTitle,
      message: context.t.ai.apiKey.removeConfirmBody,
      confirmLabel: context.t.ai.apiKey.remove,
      isDestructive: true,
      ref: ref,
    );
    if (!confirmed || !mounted) return;
    await ref.read(openRouterApiKeyProvider.notifier).clear();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasKey = ref.watch(openRouterApiKeyProvider).asData?.value != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.ai.apiKey.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.45,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _field,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            style: GoogleFonts.inter(fontSize: 15, color: colors.foreground),
            decoration: InputDecoration(
              labelText: context.t.ai.apiKey.fieldLabel,
              hintText: context.t.ai.apiKey.hint,
            ),
            onSubmitted: (_) => _save(),
          ),
          if (_saveFailed) ...[
            const SizedBox(height: 10),
            Text(
              context.t.ai.apiKey.saveFailed,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(context.t.ai.apiKey.save),
            ),
          ),
          if (hasKey)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _remove,
                child: Text(
                  context.t.ai.apiKey.remove,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
