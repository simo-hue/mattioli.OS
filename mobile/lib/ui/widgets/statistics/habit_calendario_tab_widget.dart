import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';
import '../../../providers/goal_provider.dart';

class HabitCalendarioTabWidget extends ConsumerWidget {
  final String goalId;

  const HabitCalendarioTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gridAsync = ref.watch(habitYearlyGridProvider(goalId));
    
    return gridAsync.when(
      data: (days) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CalendarioAnnualeCard(days: days),
            const SizedBox(height: 16),
            _CalendarioStatsCard(days: days),
            const SizedBox(height: 32),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => SizedBox(
        height: 200,
        child: Center(child: Text('Error: $err', style: TextStyle(color: context.appColors.mutedForeground))),
      ),
    );
  }
}

class _CalendarioAnnualeCard extends StatelessWidget {
  final List<int> days;
  const _CalendarioAnnualeCard({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendar, size: 16, color: context.appColors.foreground),
              const SizedBox(width: 8),
              Text(
                context.l10n.translate('Calendario Annuale'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              // Calcola il numero di colonne in base alla larghezza disponibile
              // per mantenere i pallini di dimensione circa 9-10px con 3px di spazio
              final columns = (availableWidth / 12).floor().clamp(20, 50);
              
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
                childAspectRatio: 1.0,
                children: days.map((status) {
                  Color color;
                  if (status == 1) {
                    color = const Color(0xFF10B981); // Verde per completato
                  } else if (status == 2) {
                    color = const Color(0xFFEF4444); // Mancato (Red)
                  } else {
                    color = context.appColors.muted.withValues(alpha: 0.5); // Dynamic Grey
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              _buildLegendItem(context, const Color(0xFF10B981), context.l10n.translate('Completato')),
              const SizedBox(width: 12),
              _buildLegendItem(context, const Color(0xFFEF4444), context.l10n.translate('Mancato')),
              const SizedBox(width: 12),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            color: context.appColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _CalendarioStatsCard extends StatelessWidget {
  final List<int> days;
  const _CalendarioStatsCard({required this.days});

  @override
  Widget build(BuildContext context) {
    final completed = days.where((status) => status == 1).length;
    final missed = days.where((status) => status == 2).length;
    final totalTracked = completed + missed;
    final rate = totalTracked > 0 ? (completed / totalTracked * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(context, '$completed', context.l10n.translate('Completati'), const Color(0xFF10B981)),
          _buildStatItem(context, '$missed', context.l10n.translate('Mancati'), const Color(0xFFEF4444)),
          _buildStatItem(context, '$rate%', context.l10n.translate('Tasso'), Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
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

