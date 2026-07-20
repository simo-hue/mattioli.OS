import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/data_mode.dart';
import '../../core/openrouter_service.dart';
import '../../providers/mood_provider.dart';
import '../../providers/settings_provider.dart';
import '../screens/ai_chat_screen.dart';
import 'daily_check_in_modal.dart';
import 'habit_management_modal.dart';
import 'pro_features_modal.dart';
import '../../i18n/translations.g.dart';
import '../../core/haptics.dart';

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
    // Detect whether today's mood has been logged
    final moods = ref.watch(dailyMoodsProvider);
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final hasLoggedToday = moods.containsKey(dateKey);

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
                showPulse: !hasLoggedToday,
                showCheckBadge: hasLoggedToday,
                onTap: () => DailyCheckInModal.show(context),
              ),
            ),
            const SizedBox(width: 12),
            // AI Chat Tile
            Expanded(
              flex: 2,
              child: Builder(builder: (context) {
                // Gate: free cloud users without a BYOK key see the paywall.
                // Private mode always passes (no paywall there — it has no
                // account and BYOK is the only path). Pro users pass (Standard
                // mode). Free users with a BYOK key pass (BYOK mode). Everyone
                // else is a free cloud user whose every send would 403.
                final isPrivate = ref.watch(activeDataModeProvider).isPrivate;
                final isPro = ref.watch(settingsProvider).isPro;
                final hasKey = ref.watch(openRouterApiKeyProvider).asData?.value != null;
                final needsPaywall = !isPrivate && !isPro && !hasKey;

                return _ActionTile(
                  key: aiChatKey,
                  icon: LucideIcons.sparkles,
                  label: context.t.habits.aiChat,
                  subtitle: context.t.common.goals,
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    if (needsPaywall) {
                      ProFeaturesModal.show(context);
                    } else {
                      Navigator.push(context, AIChatScreen.route());
                    }
                  },
                );
              }),
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

class _ActionTile extends ConsumerStatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool showPulse;
  final bool showCheckBadge;

  const _ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.showPulse = false,
    this.showCheckBadge = false,
  });

  @override
  ConsumerState<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends ConsumerState<_ActionTile>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.showPulse) {
      _startPulse();
    }
  }

  @override
  void didUpdateWidget(covariant _ActionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showPulse && !oldWidget.showPulse) {
      _startPulse();
    } else if (!widget.showPulse && oldWidget.showPulse) {
      _stopPulse();
    }
  }

  void _startPulse() {
    _pulseController?.dispose();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController!,
      curve: Curves.easeInOut,
    );
    _pulseController!.repeat(reverse: true);
  }

  void _stopPulse() {
    _pulseController?.stop();
    _pulseController?.dispose();
    _pulseController = null;
    _pulseAnimation = null;
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget tile = _buildTileContent(context);

    // Wrap with animated glow when pulsing
    if (widget.showPulse && _pulseAnimation != null) {
      tile = AnimatedBuilder(
        animation: _pulseAnimation!,
        builder: (context, child) {
          final value = _pulseAnimation!.value;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: value * 0.40),
                  blurRadius: value * 16,
                  spreadRadius: value * 3,
                ),
              ],
            ),
            child: child,
          );
        },
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildTileContent(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ref.hapticLight();
        widget.onTap();
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
                      widget.color.withValues(alpha: 0.15),
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
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: widget.color,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.foreground,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: context.appColors.mutedForeground
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Green checkmark badge when mood is logged
            if (widget.showCheckBadge)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
