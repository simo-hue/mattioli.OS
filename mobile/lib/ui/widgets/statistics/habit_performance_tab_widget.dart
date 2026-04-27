import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';

class HabitPerformanceTabWidget extends StatelessWidget {
  final String goalId;

  const HabitPerformanceTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PerformanceChartCard(),
        const SizedBox(height: 12),
        const _GiornoForteCard(),
        const SizedBox(height: 12),
        const _GiornoDeboleCard(),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PerformanceChartCard extends StatelessWidget {
  const _PerformanceChartCard();

  @override
  Widget build(BuildContext context) {
    final data = [
      {'day': 'mon', 'pct': 56},
      {'day': 'tue', 'pct': 67},
      {'day': 'wed', 'pct': 56},
      {'day': 'thu', 'pct': 53},
      {'day': 'fri', 'pct': 53},
      {'day': 'sat', 'pct': 53},
      {'day': 'sun', 'pct': 47},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.translate('performance_per_day'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
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
    // Dynamic height based on screen size, clamped for safety
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
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF18181B), // Dark background for the uncompleted part
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: fillHeight,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary, // Dynamic accent color
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$pct%',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiornoForteCard extends StatelessWidget {
  const _GiornoForteCard();

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
                  '${context.l10n.translate('strongest_day_label')}: ${context.l10n.translate('tue')}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${context.l10n.translate('well_done_completion').replaceFirst('done', '67')} (12/18)',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.mutedForeground,
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
  const _GiornoDeboleCard();

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
                  '${context.l10n.translate('weakest_day_label')}: ${context.l10n.translate('sun')}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${context.l10n.translate('only_completion').replaceFirst('done', '47')} (8/17)',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.mutedForeground,
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
