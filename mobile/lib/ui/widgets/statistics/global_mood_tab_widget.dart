import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';

class GlobalMoodTabWidget extends StatefulWidget {
  const GlobalMoodTabWidget({super.key});

  @override
  State<GlobalMoodTabWidget> createState() => _GlobalMoodTabWidgetState();
}

class _GlobalMoodTabWidgetState extends State<GlobalMoodTabWidget> {
  String _timeRange = '14gg';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        _buildMainChart(),
        const SizedBox(height: 24),
        _buildMoodSensitiveSection(),
        const SizedBox(height: 24),
        _buildResilientSection(),
        const SizedBox(height: 24),
        _buildSuggerimentiSection(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2), width: 0.5),
              ),
              child: const Icon(LucideIcons.chartLine, size: 20, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mood & Energy vs Productivity',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'Correlazione tra benessere e abitudini',
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
        const SizedBox(height: 20),
        _buildTimeSelector(),
      ],
    );
  }

  Widget _buildTimeSelector() {
    final ranges = ['7gg', '14gg', '30gg', 'Tutto'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: ranges.map((range) {
          final isSelected = _timeRange == range;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _timeRange = range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  range,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.background : AppColors.mutedForeground,
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
    return Container(
      height: 280,
      padding: const EdgeInsets.fromLTRB(10, 24, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == 50 || value == 100) {
                          return Text('${value.toInt()}%', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 9, fontWeight: FontWeight.w600));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == 5 || value == 10) {
                          return Text('${value.toInt()}', style: const TextStyle(color: AppColors.mutedForeground, fontSize: 10, fontWeight: FontWeight.w500));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2, // Show every 2nd date to avoid overlap on mobile
                      getTitlesWidget: (value, meta) {
                        final dates = ['08/04', '09/04', '11/04', '12/04', '13/04', '14/04', '15/04', '16/04', '17/04', '19/04', '20/04', '21/04', '22/04', '23/04'];
                        if (value.toInt() < dates.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Text(dates[value.toInt()], style: const TextStyle(color: AppColors.mutedForeground, fontSize: 9)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 13,
                minY: 0,
                maxY: 10,
                lineBarsData: [
                  // Habit Completion (Purple)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 0), FlSpot(1, 4), FlSpot(2, 5), FlSpot(3, 3), FlSpot(4, 7),
                      FlSpot(5, 8), FlSpot(6, 7), FlSpot(7, 6.5), FlSpot(8, 6.3), FlSpot(9, 4),
                      FlSpot(10, 7), FlSpot(11, 7.5), FlSpot(12, 9), FlSpot(13, 0),
                    ],
                    isCurved: true,

                    color: const Color(0xFF8B5CF6),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [const Color(0xFF8B5CF6).withValues(alpha: 0.15), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Mood (Green)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 7), FlSpot(1, 8), FlSpot(2, 3), FlSpot(3, 8), FlSpot(4, 8),
                      FlSpot(5, 9), FlSpot(6, 6), FlSpot(7, 8), FlSpot(8, 8), FlSpot(9, 9),
                      FlSpot(10, 9), FlSpot(11, 6), FlSpot(12, 9), FlSpot(13, 8),
                    ],
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                  // Energy (Orange/Yellow)
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 8), FlSpot(1, 8), FlSpot(2, 5), FlSpot(3, 5), FlSpot(4, 7),
                      FlSpot(5, 9), FlSpot(6, 4), FlSpot(7, 4), FlSpot(8, 9), FlSpot(9, 7),
                      FlSpot(10, 9), FlSpot(11, 7), FlSpot(12, 8), FlSpot(13, 9),
                    ],
                    isCurved: true,
                    color: const Color(0xFFF59E0B),
                    barWidth: 2,
                    dashArray: [5, 5],
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Productivity', const Color(0xFF8B5CF6)),
              _buildLegendItem('Mood', const Color(0xFF10B981)),
              _buildLegendItem('Energy', const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.mutedForeground, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMoodSensitiveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(LucideIcons.sparkles, size: 16, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text(
              'Mood',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.foreground),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Queste abitudini hanno bisogno di un buon mood per essere completate',
          style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 16),
        _buildMoodSensitiveCard('Sveglia', const Color(0xFFF97316), 25, 82, 57),
      ],
    );
  }

  Widget _buildMoodSensitiveCard(String title, Color color, int lowMoodRate, int highMoodRate, int drop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.foreground),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(LucideIcons.frown, size: 12, color: AppColors.mutedForeground),
                    const SizedBox(width: 4),
                    Text('$lowMoodRate% con mood basso', style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                    const SizedBox(width: 12),
                    Icon(LucideIcons.smile, size: 12, color: AppColors.mutedForeground),
                    const SizedBox(width: 4),
                    Text('$highMoodRate% con mood alto', style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Drop', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.mutedForeground)),
              Text('$drop%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF97316))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResilientSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(LucideIcons.shield, size: 16, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text(
              'Resilienti',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.foreground),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Queste abitudini vengono mantenute anche quando mood ed energia sono bassi',
          style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 16),
        _buildResilientCard('Caviglie', const Color(0xFF64748B), 100, 100),
        const SizedBox(height: 12),
        _buildResilientCard('No Phone in bagno', const Color(0xFF06B6D4), 90, 93),
        const SizedBox(height: 12),
        _buildResilientCard('Apparecchio', const Color(0xFFEC4899), 94, 80),
      ],
    );
  }

  Widget _buildResilientCard(String title, Color color, int moodStability, int energyStability) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.foreground),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(LucideIcons.smile, size: 11, color: AppColors.mutedForeground),
                    const SizedBox(width: 4),
                    Text('Mood: $moodStability%', style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                    const SizedBox(width: 10),
                    Icon(LucideIcons.zap, size: 11, color: AppColors.mutedForeground),
                    const SizedBox(width: 4),
                    Text('Energia: $energyStability%', style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: const [
              Icon(LucideIcons.trendingUp, size: 14, color: Color(0xFF10B981)),
              SizedBox(width: 4),
              Text(
                'Stabile',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggerimentiSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.lightbulb, size: 18, color: Color(0xFFFBBF24)),
              SizedBox(width: 8),
              Text(
                'Suggerimenti',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.foreground),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSuggerimentoItem('Pianifica le abitudini sensibili al mood nei momenti della giornata in cui ti senti meglio'),
          _buildSuggerimentoItem('Le abitudini resilienti sono ottime da mantenere anche nei giorni difficili'),
          _buildSuggerimentoItem('Monitora il tuo mood ed energia quotidianamente per ottenere insights più accurati'),
        ],
      ),
    );
  }

  Widget _buildSuggerimentoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
