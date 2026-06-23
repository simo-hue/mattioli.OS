import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/settings_provider.dart';
import '../screens/ai_chat_screen.dart';
import 'daily_check_in_modal.dart';
import 'habit_management_modal.dart';
import 'pro_features_modal.dart';
import '../../i18n/translations.g.dart';

/// "Protocollo" command panel matching the PWA sidebar card
class ProtocolloPanel extends ConsumerWidget {
  final GlobalKey? checkInKey;
  final GlobalKey? aiChatKey;
  final GlobalKey? manageHabitsKey;

  const ProtocolloPanel({
    super.key,
    this.checkInKey,
    this.aiChatKey,
    this.manageHabitsKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PROTOCOLLO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: context.appColors.mutedForeground.withValues(alpha: 0.8),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.appColors.border.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            // Daily Mood Tile (Large)
            Expanded(
              flex: 3,
              child: _ActionTile(
                key: checkInKey,
                icon: LucideIcons.heartPulse,
                label: context.t.habits.dailyCheckIn,
                subtitle: context.t.habits.mood,
                color: const Color(0xFFEF4444),
                onTap: () => DailyCheckInModal.show(context),
              ),
            ),
            const SizedBox(width: 12),
            // AI Chat Tile
            Expanded(
              flex: 2,
              child: _ActionTile(
                key: aiChatKey,
                icon: LucideIcons.sparkles,
                label: context.t.habits.aiChat,
                subtitle: context.t.common.goals,
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  final settings = ref.read(settingsProvider);
                  if (settings.isPro) {
                    Navigator.push(context, AIChatScreen.route());
                  } else {
                    ProFeaturesModal.show(context);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            // Settings Tile
            Expanded(
              flex: 2,
              child: _ActionTile(
                key: manageHabitsKey,
                icon: LucideIcons.listTodo,
                label: context.t.habits.manager,
                subtitle: context.t.common.habits,
                color: Theme.of(context).colorScheme.primary,
                onTap: () => HabitManagementModal.show(context),
              ),
            ),

          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: context.appColors.card.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.appColors.border.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Subtle gradient glow in the corner
            PositionedDirectional(
              top: -20,
              end: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: color,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.foreground,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: context.appColors.mutedForeground.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
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
