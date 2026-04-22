import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';

class HabitPerformanceTabWidget extends StatelessWidget {
  final String goalId;

  const HabitPerformanceTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _PerformanceChartCard(),
        SizedBox(height: 12),
        _GiornoForteCard(),
        SizedBox(height: 12),
        _GiornoDeboleCard(),
        SizedBox(height: 16),
      ],
    );
  }
}

class _PerformanceChartCard extends StatelessWidget {
  const _PerformanceChartCard();

  @override
  Widget build(BuildContext context) {
    final data = [
      {'day': 'Lun', 'pct': 56},
      {'day': 'Mar', 'pct': 67},
      {'day': 'Mer', 'pct': 56},
      {'day': 'Gio', 'pct': 53},
      {'day': 'Ven', 'pct': 53},
      {'day': 'Sab', 'pct': 53},
      {'day': 'Dom', 'pct': 47},
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
          const Text(
            'Performance per Giorno',
            style: TextStyle(
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
              day,
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
                  color: const Color(0xFFF59E0B), // Orange color
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(LucideIcons.trophy, size: 22, color: Color(0xFF10B981)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Giorno più forte: Mar',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ben 67% di completamento (12/18)',
                  style: TextStyle(
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
              children: const [
                Text(
                  'Giorno più debole: Dom',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Solo 47% di completamento (8/17)',
                  style: TextStyle(
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
