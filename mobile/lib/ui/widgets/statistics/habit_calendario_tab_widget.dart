import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';

class HabitCalendarioTabWidget extends StatelessWidget {
  final String goalId;

  const HabitCalendarioTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CalendarioAnnualeCard(),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _CalendarioAnnualeCard extends StatelessWidget {
  const _CalendarioAnnualeCard();

  @override
  Widget build(BuildContext context) {
    // Generate 365 mock days
    // Let's make the first 100 days have some pattern of green/red/dark, and the rest mostly dark
    final random = Random(42);
    final List<int> days = List.generate(365, (index) {
      if (index < 90) {
        // Active tracking period
        int r = random.nextInt(10);
        if (r < 6) return 1; // 60% completed
        if (r < 8) return 2; // 20% missed
        return 0; // 20% not tracked
      } else {
        return 0; // Not tracked
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendar, size: 20, color: context.appColors.foreground),
              SizedBox(width: 10),
            Text(
              context.l10n.translate('Calendario Annuale'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
              ),
            ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Using Wrap for responsive dots
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: days.map((status) {
              Color color;
              if (status == 1) {
                color = Theme.of(context).colorScheme.primary; // Completato (Dynamic Accent)
              } else if (status == 2) {
                color = const Color(0xFFEF4444); // Mancato (Red)
              } else {
                color = context.appColors.muted.withValues(alpha: 0.5); // Dynamic Grey
              }

              return Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // Legend
          Row(
            children: [
              _buildLegendItem(context, Theme.of(context).colorScheme.primary, context.l10n.translate('Completato')),
              const SizedBox(width: 16),
              _buildLegendItem(context, const Color(0xFFEF4444), context.l10n.translate('Mancato')),
              const SizedBox(width: 16),
              _buildLegendItem(context, context.appColors.muted.withValues(alpha: 0.5), context.l10n.translate('Non tracciato')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: context.appColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
