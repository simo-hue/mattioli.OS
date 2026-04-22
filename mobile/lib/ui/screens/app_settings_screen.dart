import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../core/theme.dart';
import '../../providers/settings_provider.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const AppSettingsScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Impostazioni App',
          style: TextStyle(
            color: AppColors.foreground,
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
            _buildSectionHeader('ASPETTO & VISUAL'),
            _buildSettingsCard([
              _buildSwitchRow(
                icon: LucideIcons.moon,
                title: 'Modalità Scura',
                value: settings.themeMode == 'dark',
                onChanged: (val) {
                  notifier.updateSettings(settings.copyWith(themeMode: val ? 'dark' : 'light'));
                  HapticFeedback.lightImpact();
                },
              ),
              _buildDivider(),
              _buildSwitchRow(
                icon: LucideIcons.sparkles,
                title: 'Effetti Trasparenza',
                value: settings.glassEffects,
                onChanged: (val) {
                  notifier.updateSettings(settings.copyWith(glassEffects: val));
                  HapticFeedback.lightImpact();
                },
              ),
              _buildDivider(),
              _buildActionRow(
                icon: LucideIcons.palette,
                title: 'Colore Accento',
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: settings.accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: settings.accentColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showAccentColorPicker(context, ref, settings.accentColor);
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader('CALENDARIO & DASHBOARD'),
            _buildSettingsCard([
              _buildActionRow(
                icon: LucideIcons.calendar,
                title: 'Vista Predefinita',
                trailingText: settings.defaultCalendarView.toUpperCase(),
                onTap: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Scegli Vista Predefinita',
                            style: TextStyle(
                              color: AppColors.foreground,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildViewOption(context, ref, 'Giorno', 'giorno', settings.defaultCalendarView),
                          _buildViewOption(context, ref, 'Settimana', 'settimana', settings.defaultCalendarView),
                          _buildViewOption(context, ref, 'Anno', 'anno', settings.defaultCalendarView),
                          _buildViewOption(context, ref, 'Vita', 'vita', settings.defaultCalendarView),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  );
                },
              ),
              _buildDivider(),
              _buildSwitchRow(
                icon: LucideIcons.calendarDays,
                title: 'Inizia di Lunedì',
                value: settings.startWeekOnMonday,
                onChanged: (val) {
                  notifier.updateSettings(settings.copyWith(startWeekOnMonday: val));
                  HapticFeedback.lightImpact();
                },
              ),
              _buildDivider(),
              _buildSwitchRow(
                icon: LucideIcons.calendarRange,
                title: 'Mostra Weekend',
                value: settings.showWeekend,
                onChanged: (val) {
                  notifier.updateSettings(settings.copyWith(showWeekend: val));
                  HapticFeedback.lightImpact();
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader('ESPERIENZA UTENTE'),
            _buildSettingsCard([
              _buildSwitchRow(
                icon: LucideIcons.vibrate,
                title: 'Feedback Aptico',
                value: settings.hapticFeedback,
                onChanged: (val) {
                  notifier.updateSettings(settings.copyWith(hapticFeedback: val));
                  if (val) HapticFeedback.mediumImpact();
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader('UNITÀ E LINGUA'),
            _buildSettingsCard([
              _buildActionRow(
                icon: LucideIcons.languages,
                title: 'Lingua',
                trailingText: settings.language,
                onTap: () {
                  HapticFeedback.lightImpact();
                },
              ),
              _buildDivider(),
              _buildSwitchRow(
                icon: LucideIcons.clock,
                title: 'Formato 24h',
                value: settings.timeFormat24h,
                onChanged: (val) {
                  notifier.updateSettings(settings.copyWith(timeFormat24h: val));
                  HapticFeedback.lightImpact();
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader('AI & SISTEMA'),
            _buildSettingsCard([
              _buildSwitchRow(
                icon: LucideIcons.brainCircuit,
                title: 'Suggerimenti AI',
                subtitle: 'Analisi intelligente delle abitudini',
                value: settings.aiSuggestions,
                isLocked: !settings.isPro,
                onChanged: (val) {
                  if (settings.isPro) {
                    notifier.updateSettings(settings.copyWith(aiSuggestions: val));
                    HapticFeedback.lightImpact();
                  } else {
                    HapticFeedback.heavyImpact();
                    // Show PRO promo or similar
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Questa funzione è disponibile solo per utenti PRO'),
                        backgroundColor: Colors.amber,
                      ),
                    );
                  }
                },
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.mutedForeground,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLocked = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 18, color: isLocked ? AppColors.mutedForeground : AppColors.primary),
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
                      style: TextStyle(
                        color: isLocked ? AppColors.mutedForeground : AppColors.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isLocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.mutedForeground.withValues(alpha: 0.7),
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
              onChanged: onChanged,
              activeTrackColor: AppColors.success.withValues(alpha: 0.5),
              activeColor: AppColors.success,
              inactiveThumbColor: AppColors.mutedForeground,
              inactiveTrackColor: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String title,
    Widget? trailing,
    String? trailingText,
    required VoidCallback onTap,
  }) {
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
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText,
                style: const TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            trailing ?? const SizedBox.shrink(),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 60,
      endIndent: 16,
      color: AppColors.border.withValues(alpha: 0.5),
    );
  }

  void _showAccentColorPicker(BuildContext context, WidgetRef ref, Color currentColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Colore Accento',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scegli una tonalità premium o creane una tua',
              style: TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 3 Presets
                ...AppSettingsNotifier.premiumAccentColors.take(3).map((color) {
                  final isSelected = currentColor == color;
                  return _buildColorOption(context, ref, color, isSelected);
                }),
                // Custom Color Picker Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showFullColorPicker(context, ref, currentColor);
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: const Icon(LucideIcons.plus, color: AppColors.foreground),
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

  Widget _buildColorOption(BuildContext context, WidgetRef ref, Color color, bool isSelected) {
    return GestureDetector(
      onTap: () {
        ref.read(settingsProvider.notifier).setAccentColor(color);
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(LucideIcons.check, size: 24, color: Colors.black)
            : null,
      ),
    );
  }

  void _showFullColorPicker(BuildContext context, WidgetRef ref, Color currentColor) {
    Color pickedColor = currentColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Colore Personalizzato'),
        content: SingleChildScrollView(
          child: SlidePicker(
            pickerColor: currentColor,
            onColorChanged: (color) => pickedColor = color,
            colorModel: ColorModel.rgb,
            enableAlpha: false,
            displayThumbColor: true,
            showParams: true,
            showLabel: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla', style: TextStyle(color: AppColors.mutedForeground)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setAccentColor(pickedColor);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close bottom sheet
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Widget _buildViewOption(
    BuildContext context,
    WidgetRef ref,
    String label,
    String value,
    String currentValue,
  ) {
    final isSelected = value == currentValue;
    return ListTile(
      onTap: () {
        ref.read(settingsProvider.notifier).updateSettings(
              ref.read(settingsProvider).copyWith(defaultCalendarView: value),
            );
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.foreground,
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: isSelected
          ? const Icon(LucideIcons.check, color: AppColors.primary, size: 20)
          : null,
    );
  }
}
