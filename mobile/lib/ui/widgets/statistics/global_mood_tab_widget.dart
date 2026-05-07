import 'package:flutter/material.dart';
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
        const SizedBox(height: 20),
        _buildMainChart(),
        const SizedBox(height: 24),
        const _MoodSensitiveSection(),
        const SizedBox(height: 24),
        const _ResilientHabitsSection(),
        const SizedBox(height: 24),
        const _MoodSuggestionsSection(),
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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), width: 0.5),
              ),
              child: Icon(LucideIcons.activity, size: 20, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.translate('Wellness vs Output'),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: context.appColors.foreground,
                      letterSpacing: -0.8,
                    ),
                  ),
                  Text(
                    context.l10n.translate('Correlazione tra benessere e abitudini'),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: context.appColors.mutedForeground,
                      fontWeight: FontWeight.w500,
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
    final ranges = ['time_range_7d', 'time_range_14d', 'time_range_30d', 'timeframe_all'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Row(
        children: ranges.map((range) {
          final isSelected = _timeRange == range;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _timeRange = range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.l10n.translate(range == 'time_range_7d' ? '7gg' : range == 'time_range_14d' ? '14gg' : range == 'time_range_30d' ? '30gg' : 'Tutto'),
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
    final List<FlSpot> outputSpots;
    final List<FlSpot> moodSpots;
    final List<FlSpot> energySpots;
    final List<String> dates;
    final double maxX;

    switch (_timeRange) {
      case 'time_range_7d':
        outputSpots = const [FlSpot(0, 4), FlSpot(1, 7), FlSpot(2, 6.5), FlSpot(3, 4), FlSpot(4, 7), FlSpot(5, 7.5), FlSpot(6, 9)];
        moodSpots = const [FlSpot(0, 6), FlSpot(1, 8), FlSpot(2, 8), FlSpot(3, 9), FlSpot(4, 9), FlSpot(5, 6), FlSpot(6, 9)];
        energySpots = const [FlSpot(0, 4), FlSpot(1, 9), FlSpot(2, 7), FlSpot(3, 9), FlSpot(4, 7), FlSpot(5, 8), FlSpot(6, 9)];
        dates = ['17/04', '18/04', '19/04', '20/04', '21/04', '22/04', '23/04'];
        maxX = 6;
        break;
      case 'time_range_30d':
        outputSpots = List.generate(30, (i) => FlSpot(i.toDouble(), (i % 7 + 3).toDouble()));
        moodSpots = List.generate(30, (i) => FlSpot(i.toDouble(), (i % 5 + 5).toDouble()));
        energySpots = List.generate(30, (i) => FlSpot(i.toDouble(), (i % 4 + 6).toDouble()));
        dates = List.generate(30, (i) => '${(i + 1).toString().padLeft(2, '0')}/04');
        maxX = 29;
        break;
      case 'timeframe_all':
        outputSpots = List.generate(60, (i) => FlSpot(i.toDouble(), (i % 10 + 1).toDouble()));
        moodSpots = List.generate(60, (i) => FlSpot(i.toDouble(), (i % 8 + 3).toDouble()));
        energySpots = List.generate(60, (i) => FlSpot(i.toDouble(), (i % 6 + 4).toDouble()));
        dates = List.generate(60, (i) => '${(i % 30 + 1).toString().padLeft(2, '0')}/0${i < 30 ? 3 : 4}');
        maxX = 59;
        break;
      case 'time_range_14d':
      default:
        outputSpots = const [
          FlSpot(0, 0), FlSpot(1, 4), FlSpot(2, 5), FlSpot(3, 3), FlSpot(4, 7),
          FlSpot(5, 8), FlSpot(6, 7), FlSpot(7, 6.5), FlSpot(8, 6.3), FlSpot(9, 4),
          FlSpot(10, 7), FlSpot(11, 7.5), FlSpot(12, 9), FlSpot(13, 0),
        ];
        moodSpots = const [
          FlSpot(0, 7), FlSpot(1, 8), FlSpot(2, 3), FlSpot(3, 8), FlSpot(4, 8),
          FlSpot(5, 9), FlSpot(6, 6), FlSpot(7, 8), FlSpot(8, 8), FlSpot(9, 9),
          FlSpot(10, 9), FlSpot(11, 6), FlSpot(12, 9), FlSpot(13, 8),
        ];
        energySpots = const [
          FlSpot(0, 8), FlSpot(1, 8), FlSpot(2, 5), FlSpot(3, 5), FlSpot(4, 7),
          FlSpot(5, 9), FlSpot(6, 4), FlSpot(7, 4), FlSpot(8, 9), FlSpot(9, 7),
          FlSpot(10, 9), FlSpot(11, 7), FlSpot(12, 8), FlSpot(13, 9),
        ];
        dates = ['08/04', '09/04', '11/04', '12/04', '13/04', '14/04', '15/04', '16/04', '17/04', '19/04', '20/04', '21/04', '22/04', '23/04'];
        maxX = 13;
        break;
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(16, 24, 20, 16),
      decoration: AppTheme.glassPanelDecoration(context, radius: 24),
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: context.appColors.border.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: context.appColors.mutedForeground,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: _timeRange == 'time_range_7d' ? 1 : _timeRange == 'timeframe_all' ? 10 : 3,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < dates.length && value.toInt() >= 0) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              dates[value.toInt()],
                              style: TextStyle(
                                color: context.appColors.mutedForeground,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: 10,
                lineBarsData: [
                  // Habit Completion (Output)
                  LineChartBarData(
                    spots: outputSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Mood
                  LineChartBarData(
                    spots: moodSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF10B981), // Emerald for Mood
                    barWidth: 2,
                    dotData: FlDotData(
                      show: _timeRange == 'time_range_7d' || _timeRange == 'time_range_14d',
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 2,
                        color: Colors.white,
                        strokeWidth: 1.5,
                        strokeColor: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                  // Energy
                  LineChartBarData(
                    spots: energySpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFFF59E0B),
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: FlDotData(
                      show: _timeRange == 'time_range_7d' || _timeRange == 'time_range_14d',
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 2,
                        color: Colors.white,
                        strokeWidth: 1.5,
                        strokeColor: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => context.appColors.card.withValues(alpha: 0.9),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final flSpot = barSpot;
                        return LineTooltipItem(
                          '${flSpot.y.toStringAsFixed(1)}',
                          TextStyle(color: context.appColors.foreground, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 350),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(context.l10n.translate('Output'), Theme.of(context).colorScheme.primary),
              const SizedBox(width: 20),
              _buildLegendItem(context.l10n.translate('Umore'), const Color(0xFF10B981)),
              const SizedBox(width: 20),
              _buildLegendItem(context.l10n.translate('Energia'), const Color(0xFFF59E0B)),
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
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: context.appColors.mutedForeground, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ],
    );
  }
}

class _MoodSensitiveSection extends StatefulWidget {
  const _MoodSensitiveSection();

  @override
  State<_MoodSensitiveSection> createState() => _MoodSensitiveSectionState();
}

class _MoodSensitiveSectionState extends State<_MoodSensitiveSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      _MoodSensitiveCard(title: 'Sveglia', low: 25, high: 82, drop: 57, color: const Color(0xFFF97316)),
      _MoodSensitiveCard(title: 'Palestra', low: 30, high: 90, drop: 60, color: Theme.of(context).colorScheme.primary),
      _MoodSensitiveCard(title: 'Studio', low: 45, high: 85, drop: 40, color: const Color(0xFFEAB308)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.sparkles, size: 16, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Sensibili al Mood'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Richiedono un buon mood per essere completate.'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cards[index],
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive 
                      ? const Color(0xFFF59E0B)
                      : context.appColors.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MoodSensitiveCard extends StatelessWidget {
  final String title;
  final int low;
  final int high;
  final int drop;
  final Color color;

  const _MoodSensitiveCard({
    required this.title,
    required this.low,
    required this.high,
    required this.drop,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w700, color: context.appColors.foreground)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('DROP', style: TextStyle(fontFamily: 'Inter', fontSize: 8, fontWeight: FontWeight.w800, color: context.appColors.mutedForeground, letterSpacing: 0.5)),
                  Text('$drop%', style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFF97316))),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MoodStatMini(label: 'MOOD BASSO', value: '$low%', icon: LucideIcons.frown),
              _MoodStatMini(label: 'MOOD ALTO', value: '$high%', icon: LucideIcons.smile),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResilientHabitsSection extends StatefulWidget {
  const _ResilientHabitsSection();

  @override
  State<_ResilientHabitsSection> createState() => _ResilientHabitsSectionState();
}

class _ResilientHabitsSectionState extends State<_ResilientHabitsSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      _ResilientCard(title: 'Caviglie', mood: 100, energy: 100, color: const Color(0xFF64748B)),
      const _ResilientCard(title: 'No Phone in bagno', mood: 90, energy: 93, color: Color(0xFF06B6D4)),
      const _ResilientCard(title: 'Apparecchio', mood: 94, energy: 80, color: Color(0xFFEC4899)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.shieldCheck, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Resilienti'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Mantenute anche con mood ed energia bassi.'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cards[index],
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive 
                      ? Theme.of(context).colorScheme.primary 
                      : context.appColors.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ResilientCard extends StatelessWidget {
  final String title;
  final int mood;
  final int energy;
  final Color color;

  const _ResilientCard({
    required this.title,
    required this.mood,
    required this.energy,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: context.appColors.foreground)),
                ],
              ),
              Row(
                children: [
                  Icon(LucideIcons.trendingUp, size: 12, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(context.l10n.translate('STABILE'), style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MoodStatMini(label: 'MOOD', value: '$mood%', icon: LucideIcons.smile, small: true),
              _MoodStatMini(label: 'ENERGIA', value: '$energy%', icon: LucideIcons.zap, small: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodSuggestionsSection extends StatefulWidget {
  const _MoodSuggestionsSection();

  @override
  State<_MoodSuggestionsSection> createState() => _MoodSuggestionsSectionState();
}

class _MoodSuggestionsSectionState extends State<_MoodSuggestionsSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [
      _MoodSuggestionCard(
        icon: LucideIcons.calendarHeart,
        color: const Color(0xFFF97316),
        title: 'Pianificazione Strategica',
        desc: 'Pianifica le abitudini sensibili al mood nei momenti in cui solitamente ti senti meglio.',
      ),
      _MoodSuggestionCard(
        icon: LucideIcons.shieldCheck,
        color: Theme.of(context).colorScheme.primary,
        title: 'Ancore di Stabilità',
        desc: 'Usa le abitudini resilienti come ancore nei giorni in cui mood ed energia sono bassi.',
      ),
      _MoodSuggestionCard(
        icon: LucideIcons.activity,
        color: const Color(0xFF06B6D4),
        title: 'Monitoraggio Attivo',
        desc: 'Continua a monitorare mood ed energia per ottenere insight sempre più accurati.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.lightbulb, size: 16, color: Color(0xFFFBBF24)),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Suggerimenti'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Consigli basati sul tuo benessere.'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cards[index],
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive 
                      ? const Color(0xFFFBBF24)
                      : context.appColors.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MoodSuggestionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;

  const _MoodSuggestionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: context.appColors.foreground), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: context.appColors.mutedForeground, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
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
