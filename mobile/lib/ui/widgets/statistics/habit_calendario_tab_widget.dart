import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';
import '../../../providers/goal_provider.dart';
import '../../../models/goal.dart';

class HabitCalendarioTabWidget extends ConsumerWidget {
  final String goalId;

  const HabitCalendarioTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(habitLogsProvider);
    final goals = ref.watch(goalsProvider);
    final goal = goals.firstWhere((g) => g.id == goalId, orElse: () => Goal(id: '', title: '', color: Colors.blue, startDate: DateTime.now()));
    
    final days = _calculateYearlyData(goalId, logs, goal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CalendarioAnnualeCard(days: days),
        const SizedBox(height: 32),
      ],
    );
  }
  
  List<int> _calculateYearlyData(String goalId, HabitLogsMap logs, Goal goal) {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    
    final List<int> days = [];
    
    for (int i = 364; i >= 0; i--) {
      final date = todayNormalized.subtract(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      final dayLogs = logs[dateStr];
      if (dayLogs != null && dayLogs.containsKey(goalId)) {
        final status = dayLogs[goalId];
        if (status == 'done') {
          days.add(1);
        } else if (status == 'missed') {
          days.add(2);
        } else {
          days.add(0);
        }
      } else {
        days.add(0); // Not tracked or before start date
      }
    }
    return days;
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendar, size: 20, color: context.appColors.foreground),
              const SizedBox(width: 10),
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
          
          Wrap(
            spacing: 6,
            runSpacing: 6,
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
          
          Row(
            children: [
              _buildLegendItem(context, const Color(0xFF10B981), context.l10n.translate('Completato')),
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
