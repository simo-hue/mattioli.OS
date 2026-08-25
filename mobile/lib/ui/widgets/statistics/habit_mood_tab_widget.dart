import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../providers/mood_provider.dart';
import '../../../i18n/translations.g.dart';

class HabitMoodTabWidget extends ConsumerWidget {
  final String goalId;

  const HabitMoodTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final correlations = ref.watch(moodCorrelationProvider);
    final correlation = correlations.firstWhere(
      (c) => c.goalId == goalId,
      orElse: () => MoodCorrelation(
        goalId: goalId,
        lowMoodPct: 0,
        highMoodPct: 0,
        sensitivity: 0,
        resilience: 0,
        avgMoodDone: 0.0,
        avgEnergyDone: 0.0,
        avgMoodMissed: 0.0,
        avgEnergyMissed: 0.0,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopMetricsGrid(correlation: correlation),
        const SizedBox(height: 12),
        if (correlation.resilience > 50) const _ResilienteBadge(),
        const SizedBox(height: 24),
        _CompletatoVsMancatoCard(correlation: correlation),
        const SizedBox(height: 16),
        _PerformancePerLivelloCard(correlation: correlation),
        const SizedBox(height: 16),
        const _FooterInfo(),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _TopMetricsGrid extends StatelessWidget {
  final MoodCorrelation correlation;

  const _TopMetricsGrid({required this.correlation});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: [
        _MetricCard(
          title: context.t.statistics.moodCorrelation,
          value: '${correlation.sensitivity}%',
          subtitle: correlation.sensitivity > 10
              ? context.t.statistics.positive
              : context.t.statistics.neutral,
        ),
        _MetricCard(
          title: context.t.statistics.resilience,
          value: '${correlation.resilience}%',
          subtitle: correlation.resilience > 50
              ? context.t.statistics.high
              : context.t.statistics.low,
        ),
        _MetricCard(
          title: context.t.statistics.avgMood,
          value: correlation.avgMoodDone.toStringAsFixed(1),
          subtitle: context.t.statistics.onCompletedDays,
          isRed: correlation.avgMoodDone < 4,
        ),
        _MetricCard(
          title: context.t.statistics.avgEnergy,
          value: correlation.avgEnergyDone.toStringAsFixed(1),
          subtitle: context.t.statistics.onCompletedDays,
          isRed: correlation.avgEnergyDone < 4,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final bool isRed;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    this.isRed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: context.appColors.mutedForeground,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isRed
                  ? const Color(0xFFEF4444)
                  : context.appColors.foreground,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: context.appColors.mutedForeground,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ResilienteBadge extends StatelessWidget {
  const _ResilienteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.activity,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            context.t.statistics.resilient,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletatoVsMancatoCard extends StatelessWidget {
  final MoodCorrelation correlation;

  const _CompletatoVsMancatoCard({required this.correlation});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.statistics.completedVsMissed,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                // Y Axis
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '10',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.appColors.mutedForeground,
                      ),
                    ),
                    Text(
                      '5',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.appColors.mutedForeground,
                      ),
                    ),
                    Text(
                      '0',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.appColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Chart Area
                Expanded(
                  child: Stack(
                    children: [
                      // Grid lines
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          3,
                          (index) => _buildGridLine(context),
                        ),
                      ),
                      // Bars
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildBarGroup(
                              context,
                              context.t.statistics.completed2,
                              correlation.avgMoodDone,
                              correlation.avgEnergyDone,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildBarGroup(
                              context,
                              context.t.statistics.missed2,
                              correlation.avgMoodMissed,
                              correlation.avgEnergyMissed,
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
          const SizedBox(height: 24),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                context,
                const Color(0xFF10B981),
                context.t.statistics.mood2,
              ),
              const SizedBox(width: 16),
              _buildLegendItem(
                context,
                const Color(0xFFF59E0B),
                context.t.statistics.energy,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridLine(BuildContext context) {
    return Container(
      height: 1,
      width: double.infinity,
      color: context.appColors.border.withValues(alpha: 0.5),
    );
  }

  Widget _buildBarGroup(
    BuildContext context,
    String label,
    double moodValue,
    double energiaValue,
  ) {
    // Mood/energy averages are on a 0–10 scale.
    final double moodPct = moodValue / 10.0;
    final double energiaPct = energiaValue / 10.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: FractionallySizedBox(
                  heightFactor: moodPct.clamp(0.0, 1.0),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FractionallySizedBox(
                  heightFactor: energiaPct.clamp(0.0, 1.0),
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: context.appColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: color),
        ),
      ],
    );
  }
}

class _PerformancePerLivelloCard extends StatelessWidget {
  final MoodCorrelation correlation;

  const _PerformancePerLivelloCard({required this.correlation});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.statistics.performancePerLevel,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 20),
          _buildLevelRow(
            context,
            context.t.statistics.withHighMood,
            correlation.highMoodPct,
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          _buildLevelRow(
            context,
            context.t.statistics.withLowMood,
            correlation.lowMoodPct,
            const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelRow(
    BuildContext context,
    String label,
    int percentage,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: context.appColors.foreground,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: context.appColors.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percentage / 100,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FooterInfo extends StatelessWidget {
  const _FooterInfo();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.t.statistics.moodEnergyAnalysis,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        color: context.appColors.mutedForeground,
      ),
      textAlign: TextAlign.center,
    );
  }
}
