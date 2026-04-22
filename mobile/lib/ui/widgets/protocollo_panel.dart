import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/goal_provider.dart';

/// "Protocollo" command panel matching the PWA sidebar card
class ProtocolloPanel extends ConsumerWidget {
  const ProtocolloPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivacy = ref.watch(privacyModeProvider);

    return Container(
      decoration: AppTheme.glassPanelDecoration(radius: 16),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row + toggles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Protocollo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: -0.4,
                          color: AppColors.foreground,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Esecuzione giornaliera.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
              // Privacy + AI toggles
              Row(
                children: [
                  _CompactToggle(
                    value: isPrivacy,
                    onChanged: (v) =>
                        ref.read(privacyModeProvider.notifier).state = v,
                  ),
                  const SizedBox(width: 8),
                  _CompactToggle(
                    value: false,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Divider
          Container(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),
          // Action buttons row
          Row(
            children: [
              _ActionButton(
                icon: LucideIcons.heartPulse,
                isHighlighted: true,
              ),
              const SizedBox(width: 8),
              _ActionButton(icon: LucideIcons.fileText),
              const SizedBox(width: 8),
              _ActionButton(icon: LucideIcons.settings),
              const SizedBox(width: 8),
              _ActionButton(icon: LucideIcons.download),
              const SizedBox(width: 8),
              _ActionButton(icon: LucideIcons.database),
              const Spacer(),
              _ActionButton(
                icon: LucideIcons.trash2,
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 22,
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary.withValues(alpha: 0.9)
              : AppColors.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: value ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color:
                    value ? AppColors.card : AppColors.mutedForeground,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final bool isHighlighted;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    this.isHighlighted = false,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor = AppColors.mutedForeground;
    Color bgColor = Colors.transparent;
    Color borderColor = AppColors.border;

    if (isHighlighted) {
      iconColor = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.05);
      borderColor = AppColors.primary.withValues(alpha: 0.25);
    } else if (isDestructive) {
      iconColor = const Color(0xFFEF4444);
      bgColor = const Color(0x1AEF4444);
      borderColor = const Color(0x33EF4444);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}
