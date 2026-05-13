import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';
import '../../../providers/goal_provider.dart';

class HabitPerformanceTabWidget extends ConsumerWidget {
  final String goalId;

  const HabitPerformanceTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(habitLogsProvider);
    
    final performance = _calculatePerformance(goalId, logs);
    
    Map<String, dynamic>? strongest;
    Map<String, dynamic>? weakest;
    
    final activeDays = performance.where((p) => p['total'] > 0).toList();
    
    if (activeDays.isNotEmpty) {
      strongest = activeDays.reduce((a, b) => a['pct'] > b['pct'] ? a : b);
      weakest = activeDays.reduce((a, b) => a['pct'] < b['pct'] ? a : b);
      
      // If all days have the same percentage and it's not 0, weakest might be equal to strongest.
      // Let's ensure they are different or handle it visually.
      if (strongest['pct'] == weakest['pct']) {
        weakest = null; // Don't show weakest if it's the same as strongest
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PerformanceChartCard(data: performance),
        const SizedBox(height: 12),
        if (strongest != null) _GiornoForteCard(data: strongest),
        const SizedBox(height: 12),
        if (weakest != null) _GiornoDeboleCard(data: weakest),
        const SizedBox(height: 16),
      ],
    );
  }
  
  List<Map<String, dynamic>> _calculatePerformance(String goalId, HabitLogsMap logs) {
    final daysOfWeek = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final doneCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    final totalCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    
    logs.forEach((dateStr, habits) {
      if (habits.containsKey(goalId)) {
        final date = DateTime.parse(dateStr);
        final weekday = date.weekday; // 1 = Monday, 7 = Sunday
        
        totalCounts[weekday] = totalCounts[weekday]! + 1;
        if (habits[goalId] == 'done') {
          doneCounts[weekday] = doneCounts[weekday]! + 1;
        }
      }
    });
    
    final List<Map<String, dynamic>> result = [];
    
    for (int i = 1; i <= 7; i++) {
      final total = totalCounts[i]!;
      final done = doneCounts[i]!;
      final pct = total > 0 ? (done / total * 100).round() : 0;
      
      result.add({
        'day': daysOfWeek[i - 1],
        'pct': pct,
        'done': done,
        'total': total,
      });
    }
    
    return result;
  }
}

class _PerformanceChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _PerformanceChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.translate('Performance per Giorno'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((d) => _buildBar(context, d['day'] as String, d['pct'] as int)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context, String day, int pct) {
    final screenHeight = MediaQuery.of(context).size.height;
    double height = screenHeight * 0.14; 
    if (height > 120) height = 120;
    if (height < 70) height = 70;

    final double fillHeight = height * (pct / 100.0);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          children: [
            Text(
              context.l10n.translate(day),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: context.appColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: height,
              decoration: BoxDecoration(
                color: context.appColors.muted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: fillHeight,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$pct%',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiornoForteCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GiornoForteCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(LucideIcons.trophy, size: 22, color: primaryColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.l10n.translate('Giorno più forte')}: ${context.l10n.translate(data['day'])}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${context.l10n.translate('Ben fatto! % di completamento').replaceFirst('done', data['pct'].toString())} (${data['done']}/${data['total']})',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: context.appColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GiornoDeboleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GiornoDeboleCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(LucideIcons.triangleAlert, size: 22, color: Color(0xFFEF4444)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.l10n.translate('Giorno più debole')}: ${context.l10n.translate(data['day'])}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${context.l10n.translate('Solo % di completamento').replaceFirst('done', data['pct'].toString())} (${data['done']}/${data['total']})',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: context.appColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
