import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';

class GlobalMoodTabWidget extends StatefulWidget {
  const GlobalMoodTabWidget({super.key});

  @override
  State<GlobalMoodTabWidget> createState() => _GlobalMoodTabWidgetState();
}

class _GlobalMoodTabWidgetState extends State<GlobalMoodTabWidget> {
  String _timeRange = 'time_range_14d';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildMainChart(),
        const SizedBox(height: 24),
        const _MoodSensitiveSection(),
        const SizedBox(height: 24),
        const _ResilientHabitsSection(),
        const SizedBox(height: 24),
        const _CorrelazioneMoodSection(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.translate('Mood & Energia'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.appColors.foreground,
          ),
        ),
        Text(
          context.l10n.translate('Analisi del benessere psicofisico.'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: context.appColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    final options = [
      {'key': 'time_range_14d', 'label': '14D'},
      {'key': 'time_range_30d', 'label': '30D'},
      {'key': 'time_range_90d', 'label': '90D'},
    ];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Row(
        children: options.map((opt) {
          final isSelected = _timeRange == opt['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _timeRange = opt['key']!;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected 
                      ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))] 
                      : null,
                ),
                child: Text(
                  opt['label']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? context.appColors.background : context.appColors.mutedForeground,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainChart() {
    final List<FlSpot> moodSpots;
    final List<FlSpot> energySpots;
    final double maxX;
    final double interval;

    switch (_timeRange) {
      case 'time_range_30d':
        moodSpots = List.generate(30, (i) => FlSpot(i.toDouble(), 60 + (i % 7) * 4.0 + (i % 3) * 2.0));
        energySpots = List.generate(30, (i) => FlSpot(i.toDouble(), 50 + (i % 5) * 6.0 + (i % 4) * 3.0));
        maxX = 29;
        interval = 5;
        break;
      case 'time_range_90d':
        moodSpots = List.generate(90, (i) => FlSpot(i.toDouble(), 65 + (i % 10) * 2.0 + (i % 4) * 1.0));
        energySpots = List.generate(90, (i) => FlSpot(i.toDouble(), 55 + (i % 12) * 2.5 + (i % 3) * 1.5));
        maxX = 89;
        interval = 15;
        break;
      case 'time_range_14d':
      default:
        moodSpots = [
          const FlSpot(0, 65), const FlSpot(1, 45), const FlSpot(2, 75), const FlSpot(3, 85),
          const FlSpot(4, 70), const FlSpot(5, 90), const FlSpot(6, 80), const FlSpot(7, 85),
          const FlSpot(8, 60), const FlSpot(9, 70), const FlSpot(10, 80), const FlSpot(11, 75),
          const FlSpot(12, 90), const FlSpot(13, 85),
        ];
        energySpots = [
          const FlSpot(0, 70), const FlSpot(1, 60), const FlSpot(2, 55), const FlSpot(3, 65),
          const FlSpot(4, 80), const FlSpot(5, 75), const FlSpot(6, 85), const FlSpot(7, 70),
          const FlSpot(8, 75), const FlSpot(9, 65), const FlSpot(10, 60), const FlSpot(11, 80),
          const FlSpot(12, 85), const FlSpot(13, 75),
        ];
        maxX = 13;
        interval = 2;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassPanelDecoration(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeRangeSelector(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildChartLegendItem(context.l10n.translate('Mood'), const Color(0xFFFBBF24)),
              _buildChartLegendItem(context.l10n.translate('Energia'), const Color(0xFF06B6D4)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: context.appColors.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _timeRange == 'time_range_14d' 
                                ? '${value.toInt() + 1} set'
                                : '${value.toInt() + 1} mag',
                            style: TextStyle(
                              color: context.appColors.mutedForeground,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: TextStyle(
                            color: context.appColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        );
                      },
                      reservedSize: 42,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: moodSpots,
                    isCurved: true,
                    color: const Color(0xFFFBBF24),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.05),
                    ),
                  ),
                  LineChartBarData(
                    spots: energySpots,
                    isCurved: true,
                    color: const Color(0xFF06B6D4),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.05),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => context.appColors.card.withValues(alpha: 0.9),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final isMood = barSpot.barIndex == 0;
                        return LineTooltipItem(
                          '${isMood ? 'Mood' : 'Energia'}: ${barSpot.y.toInt()}%',
                          TextStyle(
                            color: isMood ? const Color(0xFFFBBF24) : const Color(0xFF06B6D4),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 350),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.appColors.foreground,
          ),
        ),
      ],
    );
  }
}

class _MoodSensitiveSection extends StatelessWidget {
  const _MoodSensitiveSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.translate('Abitudini Sensibili al Mood'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.appColors.foreground,
          ),
        ),
        const SizedBox(height: 12),
        _buildSensitiveItem(context, 'Meditazione', 82, const Color(0xFF8B5CF6)),
        _buildSensitiveItem(context, 'Journaling', 75, const Color(0xFFEC4899)),
        _buildSensitiveItem(context, 'Studio', 68, const Color(0xFF3B82F6)),
      ],
    );
  }

  Widget _buildSensitiveItem(BuildContext context, String name, int sensitivity, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appColors.border),
        ),
        child: Row(
          children: [
            Container(width: 4, height: 24, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: context.appColors.foreground)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('${context.l10n.translate('Sensibilità')}: ', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: context.appColors.mutedForeground)),
                      Text('$sensitivity%', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: context.appColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

class _ResilientHabitsSection extends StatelessWidget {
  const _ResilientHabitsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.translate('Abitudini Resilienti'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.appColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Abitudini che mantieni anche quando il mood è basso.'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildResilientCard(context, 'Fitness', 94, const Color(0xFF10B981)),
            const SizedBox(width: 12),
            _buildResilientCard(context, 'Alimentazione', 88, const Color(0xFFF59E0B)),
          ],
        ),
      ],
    );
  }

  Widget _buildResilientCard(BuildContext context, String name, int resilience, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(name, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: context.appColors.foreground), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 12),
            Text('$resilience%', style: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w900, color: color)),
            Text(context.l10n.translate('Resilienza'), style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: context.appColors.mutedForeground)),
          ],
        ),
      ),
    );
  }
}

class _CorrelazioneMoodSection extends StatelessWidget {
  const _CorrelazioneMoodSection();

  @override
  Widget build(BuildContext context) {
    // Mocking some data for the cards
    final low = 15;
    final high = 85;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.translate('Analisi di Correlazione'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _MoodStatMini(label: 'MOOD BASSO', value: '$low%', icon: LucideIcons.frown),
              const SizedBox(width: 24),
              _MoodStatMini(label: 'MOOD ALTO', value: '$high%', icon: LucideIcons.smile),
            ],
          ),
          const SizedBox(height: 24),
          _buildCorrelationRow(context, 'Fitness', 42, 78),
          _buildCorrelationRow(context, 'Meditazione', 35, 82),
          _buildCorrelationRow(context, 'Journaling', 40, 75),
        ],
      ),
    );
  }

  Widget _buildCorrelationRow(BuildContext context, String name, int lowVal, int highVal) {
    final mood = 80;
    final energy = 75;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: context.appColors.foreground)),
              Row(
                children: [
                  _MoodStatMini(label: 'MOOD', value: '$mood%', icon: LucideIcons.smile, small: true),
                  const SizedBox(width: 12),
                  _MoodStatMini(label: 'ENERGIA', value: '$energy%', icon: LucideIcons.zap, small: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(height: 6, decoration: BoxDecoration(color: context.appColors.border.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(widthFactor: highVal / 100, child: Container(height: 6, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(3)))),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodStatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool small;

  const _MoodStatMini({required this.label, required this.value, required this.icon, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: small ? 7 : 8, fontWeight: FontWeight.w800, color: context.appColors.mutedForeground, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(icon, size: small ? 10 : 12, color: context.appColors.mutedForeground),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: small ? 12 : 14, fontWeight: FontWeight.w900, color: context.appColors.foreground)),
          ],
        ),
      ],
    );
  }
}
