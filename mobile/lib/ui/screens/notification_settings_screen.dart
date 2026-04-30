import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/settings_provider.dart';
import '../../core/haptics.dart';
import '../../core/notifications.dart';
import '../../core/localization.dart';
import '../widgets/pro_features_modal.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const NotificationSettingsScreen(),
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
        title: Text(
          context.l10n.translate('Notifiche'),
          style: const TextStyle(
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
            _buildSectionHeader('PROMEMORIA OPERATIVI'),
            _buildSettingsCard([
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.calendarCheck,
                title: context.l10n.translate('Promemoria Abitudini'),
                subtitle: context.l10n.translate('Morning Brief'),
                value: settings.habitReminders,
                onChanged: (val) {
                  if (val) NotificationService().requestPermissions();
                  final currentSettings = ref.read(settingsProvider);
                  notifier.updateSettings(currentSettings.copyWith(habitReminders: val));
                  ref.hapticLight();
                },
              ),
              _buildDivider(),
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.bellRing,
                title: context.l10n.translate('Review Serale'),
                subtitle: context.l10n.translate('Review Serale'),
                value: settings.eveningReview,
                onChanged: (val) {
                  if (val) NotificationService().requestPermissions();
                  final currentSettings = ref.read(settingsProvider);
                  notifier.updateSettings(currentSettings.copyWith(eveningReview: val));
                  ref.hapticLight();
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader('OBIETTIVI & PERFORMANCE'),
            _buildSettingsCard([
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.timer,
                title: context.l10n.translate('Scadenze Obiettivi'),
                subtitle: context.l10n.translate('Scadenze Obiettivi'),
                value: settings.goalDeadlines,
                onChanged: (val) {
                  final currentSettings = ref.read(settingsProvider);
                  notifier.updateSettings(currentSettings.copyWith(goalDeadlines: val));
                  ref.hapticLight();
                },
              ),
              _buildDivider(),
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.trophy,
                title: context.l10n.translate('Milestones'),
                subtitle: context.l10n.translate('Milestones'),
                value: settings.milestones,
                onChanged: (val) {
                  final currentSettings = ref.read(settingsProvider);
                  notifier.updateSettings(currentSettings.copyWith(milestones: val));
                  ref.hapticLight();
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader('INTELLIGENZA ARTIFICIALE'),
            _buildSettingsCard([
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.brainCircuit,
                title: context.l10n.translate('Insight AI'),
                subtitle: context.l10n.translate('Analisi intelligente delle abitudini'),
                value: settings.aiInsights,
                isLocked: !settings.isPro,
                onChanged: (val) {
                  if (settings.isPro) {
                    final currentSettings = ref.read(settingsProvider);
                    notifier.updateSettings(currentSettings.copyWith(aiInsights: val));
                    ref.hapticLight();
                  } else {
                    ref.hapticHeavy();
                    ProFeaturesModal.show(context);
                  }
                },
              ),
              _buildDivider(),
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.zap,
                title: context.l10n.translate('Deep Work Insights'),
                subtitle: context.l10n.translate('Deep Work Insights'),
                value: settings.deepWorkInsights,
                isLocked: !settings.isPro,
                onChanged: (val) {
                  if (settings.isPro) {
                    final currentSettings = ref.read(settingsProvider);
                    notifier.updateSettings(currentSettings.copyWith(deepWorkInsights: val));
                    ref.hapticLight();
                  } else {
                    ref.hapticHeavy();
                    ProFeaturesModal.show(context);
                  }
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader('GESTIONE SISTEMA'),
            _buildSettingsCard([
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.chartBar,
                title: context.l10n.translate('Resoconti Settimanali'),
                subtitle: context.l10n.translate('Resoconti Settimanali'),
                value: settings.weeklyReports,
                isLocked: !settings.isPro,
                onChanged: (val) {
                  if (settings.isPro) {
                    final currentSettings = ref.read(settingsProvider);
                    notifier.updateSettings(currentSettings.copyWith(weeklyReports: val));
                    ref.hapticLight();
                  } else {
                    ref.hapticHeavy();
                    ProFeaturesModal.show(context);
                  }
                },
              ),
              _buildDivider(),
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.moonStar,
                title: context.l10n.translate('Modalità Focus'),
                subtitle: context.l10n.translate('Modalità Focus'),
                value: settings.focusMode,
                isLocked: !settings.isPro,
                onChanged: (val) {
                  if (settings.isPro) {
                    final currentSettings = ref.read(settingsProvider);
                    notifier.updateSettings(currentSettings.copyWith(focusMode: val));
                    ref.hapticLight();
                  } else {
                    ref.hapticHeavy();
                    ProFeaturesModal.show(context);
                  }
                },
              ),
            ]),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: AppColors.mutedForeground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.border,
      indent: 56,
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
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 18, color: isDisabled ? AppColors.mutedForeground : primaryColor),
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
                          color: isDisabled ? AppColors.mutedForeground : AppColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
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
              onChanged: (val) => onChanged(val), // Always interactive to allow modal trigger
              activeTrackColor: primaryColor.withValues(alpha: 0.5),
              activeThumbColor: primaryColor,
              inactiveThumbColor: AppColors.mutedForeground,
              inactiveTrackColor: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}
