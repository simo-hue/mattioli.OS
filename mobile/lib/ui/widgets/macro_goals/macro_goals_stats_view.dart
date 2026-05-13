import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math' as math;

import '../../../core/theme.dart';
import '../../../models/macro_goal.dart';
import '../../../providers/macro_goals_provider.dart';
import '../../../providers/macro_goals_stats_provider.dart';
import '../../../providers/macro_goal_categories_provider.dart';

class MacroGoalsStatsView extends ConsumerStatefulWidget {
  const MacroGoalsStatsView({super.key});

  @override
  ConsumerState<MacroGoalsStatsView> createState() => _MacroGoalsStatsViewState();
}

class _MacroGoalsStatsViewState extends ConsumerState<MacroGoalsStatsView> {
  String _selectedYear = 'all';

  @override
  Widget build(BuildContext context) {
    final allGoals = ref.watch(macroGoalsProvider).goals;

    // Distinct years for dropdown
    final years = allGoals
        .map((g) => g.year)
        .whereType<int>()
        .toSet()
        .toList()
        ..sort((a, b) => b.compareTo(a));

    if (!years.contains(DateTime.now().year)) {
      years.insert(0, DateTime.now().year);
    }

    final statsAsync = ref.watch(macroGoalsStatsProvider(_selectedYear));

    return statsAsync.when(
      data: (stats) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Year Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Performance',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.appColors.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _buildYearSelector(years),
                ],
              ),
              const SizedBox(height: 20),

              if (_selectedYear == 'all')
                ..._buildGlobalContent(stats)
              else
                ..._buildSingleYearContent(stats)
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => SizedBox(
        height: 300,
        child: Center(
          child: Text(
            'Errore: $err',
            style: TextStyle(color: context.appColors.mutedForeground),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSingleYearContent(Map<String, dynamic> stats) {
    final categories = ref.watch(macroGoalCategoriesProvider).value ?? [];
    final totalGoals = stats['total_goals'] as int? ?? 0;
    final completedGoals = stats['completed_goals'] as int? ?? 0;
    final successRate = stats['success_rate'] as int? ?? 0;
    final trendPositive = successRate > 50;

    final bestCategoryKey = stats['best_category'] as String?;
    String bestCategory = 'N/A';
    try {
      bestCategory = categories.firstWhere((c) => c.key == bestCategoryKey).label;
    } catch (_) {
      bestCategory = categoryLabel(bestCategoryKey) ?? 'N/A';
    }
    final bestCatRate = stats['best_category_rate'] as int? ?? 0;

    final bestMonthIdx = stats['best_month'] as int?;
    final bestMonthRate = stats['best_month_rate'] as int? ?? 0;

    final monthsLabel = ['', 'gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];

    final bestTypeStr = stats['best_type'] as String?;
    String bestTypeLabel = 'N/A';
    if (bestTypeStr != null) {
      switch (bestTypeStr) {
        case 'lifetime': bestTypeLabel = 'Lifetime'; break;
        case 'annual': bestTypeLabel = 'Annuale'; break;
        case 'quarterly': bestTypeLabel = 'Trimestrale'; break;
        case 'monthly': bestTypeLabel = 'Mensile'; break;
        case 'weekly': bestTypeLabel = 'Settimanale'; break;
      }
    }
    final bestTypeRate = stats['best_type_rate'] as int? ?? 0;

    return [
      Row(
        children: [
          Expanded(child: _buildHighlightCard(title: 'Punto di Forza', value: bestCategory, subtitle: '$bestCatRate% di completamento', icon: LucideIcons.zap, color: const Color(0xFFA855F7))),
          const SizedBox(width: 12),
          Expanded(child: _buildHighlightCard(title: 'Mese Migliore', value: (bestMonthIdx != null && bestMonthIdx > 0) ? monthsLabel[bestMonthIdx] : 'Nessuno', subtitle: '$bestMonthRate% di successo', icon: LucideIcons.trophy, color: const Color(0xFFF59E0B))),
        ],
      ),
      const SizedBox(height: 12),
      _buildHighlightCard(title: 'Tipologia Efficace', value: bestTypeLabel, subtitle: '$bestTypeRate% di successo', icon: LucideIcons.brainCircuit, color: Theme.of(context).colorScheme.primary, fullWidth: true),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _buildKpiCard('Totale', '$totalGoals', LucideIcons.target)),
          const SizedBox(width: 8),
          Expanded(child: _buildKpiCard('Completati', '$completedGoals', LucideIcons.circleCheck, color: const Color(0xFF10B981))),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _buildKpiCard('Successo', '$successRate%', LucideIcons.trophy, color: const Color(0xFFFBBF24))),
          const SizedBox(width: 8),
          Expanded(child: _buildKpiCard('Trend', trendPositive ? 'Crescita' : 'Calo', trendPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown, color: const Color(0xFF60A5FA))),
        ],
      ),
      const SizedBox(height: 24),
      _buildAreaChartCard(stats['cumulative_monthly'] as List<dynamic>? ?? []),
      const SizedBox(height: 16),
      _buildCategoryRadarCard(stats['category_rates'] as List<dynamic>? ?? []),
      const SizedBox(height: 16),
      _buildQuarterlyBarCard(stats['quarterly_activity'] as List<dynamic>? ?? []),
      const SizedBox(height: 16),
      _buildMonthlyComposedCard(stats['monthly_composed'] as List<dynamic>? ?? []),
      const SizedBox(height: 16),
      _buildCategoryPieCard(stats['category_distribution'] as List<dynamic>? ?? [], categories),
      const SizedBox(height: 48),
    ];
  }

  List<Widget> _buildGlobalContent(Map<String, dynamic> stats) {
    final categories = ref.watch(macroGoalCategoriesProvider).value ?? [];
    final total = stats['total_goals'] as int? ?? 0;
    final comp = stats['completed_goals'] as int? ?? 0;
    final succ = total > 0 ? (comp / total * 100).round() : 0;
    
    final bestYear = stats['best_year'] as int?;
    final bestYearRate = stats['best_year_rate'] as int? ?? 0;
    final mostProdYear = stats['most_productive_year'] as int?;
    final mostProdCount = stats['most_productive_count'] as int? ?? 0;

    final yearProgression = stats['year_progression'] as List<dynamic>? ?? [];
    List<int> sortedYears = [];
    for (var item in yearProgression) {
      if (item is Map<String, dynamic>) {
        final y = item['year'] as int?;
        if (y != null) sortedYears.add(y);
      }
    }
    sortedYears.sort();

    return [
      Row(
        children: [
          Expanded(child: _buildHighlightCard(title: 'Totale Storico', value: '$total', subtitle: 'dal ${sortedYears.isNotEmpty ? sortedYears.first : '-'}', icon: LucideIcons.target, color: const Color(0xFF6366F1))),
          const SizedBox(width: 12),
          Expanded(child: _buildHighlightCard(title: 'Successo Globale', value: '$succ%', subtitle: '$comp obiettivi completati', icon: LucideIcons.trophy, color: const Color(0xFF10B981))),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _buildHighlightCard(title: 'Anno Migliore', value: bestYear != null ? '$bestYear' : 'N/A', subtitle: '$bestYearRate% completamento', icon: LucideIcons.calendar, color: const Color(0xFFD97706))),
          const SizedBox(width: 12),
          Expanded(child: _buildHighlightCard(title: 'Anno Più Produttivo', value: mostProdYear != null ? '$mostProdYear' : 'N/A', subtitle: '$mostProdCount obiettivi totali', icon: LucideIcons.activity, color: const Color(0xFF06B6D4))),
        ],
      ),
      const SizedBox(height: 24),
      
      _buildGlobalYearProgressionCard(yearProgression),
      const SizedBox(height: 16),
      _buildCategoryRadarCard(stats['category_performance'] as List<dynamic>? ?? []), 
      const SizedBox(height: 16),
      _buildGlobalTypeDistCard(stats['type_distribution'] as Map<String, dynamic>? ?? {}),
      const SizedBox(height: 16),
      _buildQuarterSeasonalityCard(stats['seasonality'] as List<dynamic>? ?? []),
      const SizedBox(height: 16),
      _buildGlobalMonthlyHistCard(stats['monthly_history'] as List<dynamic>? ?? []),
      const SizedBox(height: 16),
      _buildGlobalInterestEvolutionCard(stats['interest_evolution'] as List<dynamic>? ?? [], categories),
      const SizedBox(height: 48),
    ];
  }

  // ─── Component Builders ───────────────────────────────────────────────────

  Widget _buildYearSelector(List<int> years) {
    String displayLabel = _selectedYear == 'all' ? 'Tutti gli anni' : _selectedYear;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showYearPicker(years);
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.appColors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendar, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              displayLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appColors.foreground,
              ),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronDown, size: 14, color: context.appColors.mutedForeground),
          ],
        ),
      ),
    );
  }

  void _showYearPicker(List<int> years) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  'SELEZIONA ANNO', 
                  style: TextStyle(
                    fontFamily: 'Inter', 
                    fontWeight: FontWeight.w800, 
                    color: context.appColors.mutedForeground, 
                    fontSize: 10,
                    letterSpacing: 1.2,
                  )
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                LucideIcons.calendarRange,
                size: 20,
                color: _selectedYear == 'all' ? primaryColor : context.appColors.mutedForeground.withValues(alpha: 0.6),
              ),
              title: Text(
                'Tutti gli anni',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: _selectedYear == 'all' ? FontWeight.w700 : FontWeight.w500,
                  color: _selectedYear == 'all' ? context.appColors.foreground : context.appColors.mutedForeground,
                ),
              ),
              trailing: _selectedYear == 'all' ? Icon(LucideIcons.check, color: primaryColor, size: 20) : null,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedYear = 'all');
                Navigator.pop(context);
              },
            ),
            ...years.map((y) {
              final isSel = _selectedYear == '$y';
              return ListTile(
                leading: Icon(
                  LucideIcons.calendar,
                  size: 20,
                  color: isSel ? primaryColor : context.appColors.mutedForeground.withValues(alpha: 0.6),
                ),
                title: Text(
                  '$y',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? context.appColors.foreground : context.appColors.mutedForeground,
                  ),
                ),
                trailing: isSel ? Icon(LucideIcons.check, color: primaryColor, size: 20) : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedYear = '$y');
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  Widget _buildHighlightCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 12, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              color: context.appColors.foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: context.appColors.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, {Color color = AppColors.foreground}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: GoogleFonts.inter(fontSize: 11, color: context.appColors.mutedForeground, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Icon(icon, size: 12, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 18, color: context.appColors.foreground, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildCardBase({required String title, required String subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.appColors.card.withValues(alpha: 0.4),
            context.appColors.card.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 17,
              color: context.appColors.foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: context.appColors.mutedForeground,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  // ─── Chart Widgets ────────────────────────────────────────────────────────

  Widget _buildAreaChartCard(List<dynamic> stats) {
    List<FlSpot> totalSpots = [];
    List<FlSpot> compSpots = [];
    
    double maxTotal = 0;

    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final m = item['month'] as int?;
        final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
        final comp = (item['completed'] as num?)?.toDouble() ?? 0.0;
        
        if (m != null) {
          totalSpots.add(FlSpot(m.toDouble(), tot));
          compSpots.add(FlSpot(m.toDouble(), comp));
          if (tot > maxTotal) maxTotal = tot;
        }
      }
    }

    final double maxY = math.max(10.0, maxTotal * 1.2);

    return _buildCardBase(
      title: '🚀 Velocità di Esecuzione (Cumulativa)',
      subtitle: 'Confronto tra obiettivi pianificati e completati nel tempo',
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: maxY / 4,
              verticalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(color: context.appColors.border.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
              getDrawingVerticalLine: (value) => FlLine(color: context.appColors.border.withValues(alpha: 0.5), strokeWidth: 1, dashArray: [4, 4]),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (val, meta) {
                    const months = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
                    if (val < 1 || val > 12) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(months[val.toInt() - 1], style: GoogleFonts.inter(fontSize: 10, color: context.appColors.mutedForeground)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: maxY / 4,
                  reservedSize: 36,
                  getTitlesWidget: (val, meta) {
                    return Text(val.toInt().toString(), style: GoogleFonts.inter(fontSize: 10, color: context.appColors.mutedForeground));
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 1,
            maxX: 12,
            minY: 0,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: totalSpots,
                isCurved: true,
                color: const Color(0xFF818CF8), // Indigo
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                ),
              ),
              LineChartBarData(
                spots: compSpots,
                isCurved: true,
                color: const Color(0xFF10B981),
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRadarCard(List<dynamic> stats) {
    final categories = ref.watch(macroGoalCategoriesProvider).value ?? [];
    if (stats.isEmpty) {
      return _buildCardBase(
        title: '🎯 Performance Categorie', subtitle: 'Tasso di successo',
        child: SizedBox(height: 200, child: Center(child: Text('Nessun dato', style: TextStyle(color: context.appColors.mutedForeground)))),
      );
    }
    
    if (stats.length < 3) {
      return _buildCardBase(
        title: '🎯 Performance Categorie', subtitle: 'Tasso di successo',
        child: SizedBox(height: 200, child: Center(child: Text('Dati insufficienti (servono almeno 3 categorie)', style: TextStyle(color: context.appColors.mutedForeground)))),
      );
    }

    List<RadarEntry> entries = [];
    List<String> labels = [];
    
    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final catKey = item['category'] as String?;
        final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
        String label = 'N/A';
        try {
          label = categories.firstWhere((c) => c.key == catKey).label;
        } catch (_) {
          label = categoryLabel(catKey) ?? 'N/A';
        }
        
        entries.add(RadarEntry(value: rate));
        labels.add(label);
      }
    }

    return _buildCardBase(
      title: '🎯 Performance Categorie',
      subtitle: 'Tasso di successo per categoria',
      child: SizedBox(
        height: 240,
        child: RadarChart(
          RadarChartData(
            tickCount: 3,
            dataSets: [
              RadarDataSet(
                fillColor: const Color(0xFF06B6D4).withValues(alpha: 0.2), // Cyan
                borderColor: const Color(0xFF06B6D4),
                entryRadius: 0,
                dataEntries: entries,
              )
            ],
            radarBackgroundColor: Colors.transparent,
            borderData: FlBorderData(show: false),
            radarBorderData: BorderSide(color: context.appColors.border),
            tickBorderData: BorderSide(color: context.appColors.border, width: 0.5),
            ticksTextStyle: const TextStyle(color: Colors.transparent),
            getTitle: (index, angle) {
              if (index < labels.length) {
                return RadarChartTitle(
                  text: labels[index],
                  angle: 0,
                  positionPercentageOffset: 0.1,
                );
              }
              return const RadarChartTitle(text: '');
            },
            titleTextStyle: GoogleFonts.inter(fontSize: 10, color: context.appColors.mutedForeground),
          ),
        ),
      ),
    );
  }

  Widget _buildQuarterlyBarCard(List<dynamic> stats) {
    if (stats.isEmpty) {
      return _buildCardBase(
        title: 'Attività Trim.',
        subtitle: 'Q1 - Q4',
        child: SizedBox(
          height: 150,
          child: Center(
            child: Text(
              'Nessun dato',
              style: TextStyle(color: context.appColors.mutedForeground),
            ),
          ),
        ),
      );
    }
    
    // Extract totals and completed per quarter
    List<BarChartGroupData> groups = [];
    double maxY = 0;
    
    // Create a map for quick lookup
    final Map<int, Map<String, dynamic>> dataMap = {};
    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final q = item['quarter'] as int?;
        if (q != null) {
          dataMap[q] = item;
          final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
          if (tot > maxY) maxY = tot;
        }
      }
    }

    for (int q = 1; q <= 4; q++) {
      final item = dataMap[q];
      final tot = (item?['total'] as num?)?.toDouble() ?? 0.0;
      final comp = (item?['completed'] as num?)?.toDouble() ?? 0.0;
      
      groups.add(
        BarChartGroupData(
          x: q,
          barRods: [
            BarChartRodData(toY: tot, color: const Color(0xFFD97706), width: 10, borderRadius: BorderRadius.circular(2)),
            BarChartRodData(toY: comp, color: const Color(0xFF10B981), width: 10, borderRadius: BorderRadius.circular(2)),
          ],
        ),
      );
    }

    return _buildCardBase(
      title: 'Attività Trim.',
      subtitle: 'In Q1-Q4',
      child: SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) => Text('Q${val.toInt()}', style: GoogleFonts.inter(fontSize: 10, color: context.appColors.mutedForeground)),
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            maxY: math.max(5.0, maxY * 1.2),
            barGroups: groups,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyComposedCard(List<dynamic> stats) {
    if (stats.isEmpty) {
      return _buildCardBase(title: 'Attività Mensile', subtitle: 'Totale/Completati', child: const SizedBox(height: 150));
    }

    List<BarChartGroupData> barGroups = [];
    double maxY = 0;
    
    // Create a map for quick lookup
    final Map<int, Map<String, dynamic>> dataMap = {};
    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final m = item['month'] as int?;
        if (m != null) {
          dataMap[m] = item;
          final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
          if (tot > maxY) maxY = tot;
        }
      }
    }

    for (int m = 1; m <= 12; m+=2) { // Show fewer columns to fit mobile
      final item = dataMap[m];
      final tot = (item?['total'] as num?)?.toDouble() ?? 0.0;
      final comp = (item?['completed'] as num?)?.toDouble() ?? 0.0;

      barGroups.add(
        BarChartGroupData(
          x: m,
          barRods: [
            BarChartRodData(
              toY: tot, 
              color: Colors.transparent, 
              width: 10, 
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: math.max(5.0, maxY * 1.2),
                color: context.appColors.border.withValues(alpha: 0.1),
              ),
              rodStackItems: [
                if (comp > 0) BarChartRodStackItem(0, comp, Theme.of(context).colorScheme.primary),
                if (tot > comp) BarChartRodStackItem(comp, tot, const Color(0xFF6366F1).withValues(alpha: 0.6)),
              ],
            ),
          ],
        )
      );
    }

    const mLabel = ['', 'G', 'F', 'M', 'A', 'M', 'G', 'L', 'A', 'S', 'O', 'N', 'D'];

    return _buildCardBase(
      title: 'Completamenti',
      subtitle: 'Mensili',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => context.appColors.card,
                tooltipRoundedRadius: 12,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final m = group.x.toInt();
                  final item = dataMap[m];
                  final tot = (item?['total'] as num?)?.toInt() ?? 0;
                  final comp = (item?['completed'] as num?)?.toInt() ?? 0;
                  const months = ['', 'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];
                  return BarTooltipItem(
                    '${months[m]}\n',
                    GoogleFonts.inter(color: context.appColors.foreground, fontWeight: FontWeight.bold, fontSize: 13),
                    children: [
                      TextSpan(text: 'Totali: $tot\n', style: GoogleFonts.inter(color: const Color(0xFF6366F1), fontSize: 10)),
                      TextSpan(text: 'Completati: $comp', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.primary, fontSize: 10)),
                    ],
                  );
                },
              ),
            ),
            gridData: FlGridData(
              show: true, 
              drawVerticalLine: false, 
              horizontalInterval: math.max(1.0, maxY / 4), 
              getDrawingHorizontalLine: (v) => FlLine(color: context.appColors.border.withValues(alpha: 0.2), strokeWidth: 1, dashArray: [4, 4]),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true, 
                  reservedSize: 30, 
                  getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: GoogleFonts.inter(fontSize: 10, color: context.appColors.mutedForeground)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    final index = val.toInt();
                    if (index < 1 || index >= mLabel.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(mLabel[index], style: GoogleFonts.inter(fontSize: 10, color: context.appColors.mutedForeground, fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            maxY: math.max(5.0, maxY * 1.2),
            barGroups: barGroups,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPieCard(List<dynamic> stats, List<GoalCategory> categories) {
    if (stats.isEmpty) {
       return _buildCardBase(title: 'Distribuzione', subtitle: '', child: SizedBox(height: 200, child: Center(child: Text('Nessun dato', style: TextStyle(color: context.appColors.mutedForeground)))));
    }

    List<PieChartSectionData> sections = [];
    int totalCount = 0;
    
    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final count = (item['count'] as num?)?.toInt() ?? 0;
        totalCount += count;
      }
    }

    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final catKey = item['category'] as String?;
        final count = (item['count'] as num?)?.toDouble() ?? 0.0;
        
        Color? color;
        try {
          color = categories.firstWhere((c) => c.key == catKey).color;
        } catch (_) {
          color = categoryColor(catKey) ?? Colors.grey;
        }
        
        sections.add(PieChartSectionData(
          value: count,
          color: color,
          title: '',
          radius: 26,
          badgeWidget: null,
        ));
      }
    }

    return _buildCardBase(
      title: '🎯 Distribuzione Categorie',
      subtitle: 'Ripartizione degli obiettivi per area di focus',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 65,
                    sectionsSpace: 4,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$totalCount', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: context.appColors.foreground)),
                    Text('obiettivi', style: GoogleFonts.inter(fontSize: 12, color: context.appColors.mutedForeground)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Legend grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stats.map((item) {
              if (item is! Map<String, dynamic>) return const SizedBox.shrink();
              final catKey = item['category'] as String?;
              final count = (item['count'] as num?)?.toInt() ?? 0;
              Color? color;
              String label = 'N/A';
              try {
                final c = categories.firstWhere((c) => c.key == catKey);
                color = c.color;
                label = c.label;
              } catch (_) {
                color = categoryColor(catKey) ?? Colors.grey;
                label = categoryLabel(catKey) ?? 'N/A';
              }
              final perc = totalCount > 0 ? (count / totalCount * 100).round() : 0;
              
              return Container(
                width: 150, // Fix width for grid likeness
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.appColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.appColors.border),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: context.appColors.foreground), maxLines: 1)),
                    Text('$perc%', style: GoogleFonts.inter(fontSize: 12, color: context.appColors.mutedForeground)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalYearProgressionCard(List<dynamic> stats) {
    if (stats.isEmpty) return const SizedBox();

    List<BarChartGroupData> groups = [];
    double maxTot = 0;
    
    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
        if (tot > maxTot) maxTot = tot;
      }
    }

    for (int i = 0; i < stats.length; i++) {
      final item = stats[i];
      if (item is Map<String, dynamic>) {
        final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
        final act = (item['active'] as num?)?.toDouble() ?? 0.0;
        final fail = (item['failed'] as num?)?.toDouble() ?? 0.0;
        final comp = (item['completed'] as num?)?.toDouble() ?? 0.0;

        groups.add(BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: tot,
              color: Colors.transparent,
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: math.max(10, maxTot * 1.2),
                color: context.appColors.border.withValues(alpha: 0.1),
              ),
              rodStackItems: [
                if (act > 0) BarChartRodStackItem(0, act, const Color(0xFF3B82F6)), // Attivi - Blue
                if (fail > 0) BarChartRodStackItem(act, act + fail, const Color(0xFFEF4444)), // Falliti - Red
                if (comp > 0) BarChartRodStackItem(act + fail, act + fail + comp, const Color(0xFF10B981)), // Completati - Dynamic Accent
              ],
            )
          ],
        ));
      }
    }

    return _buildCardBase(
      title: '📈 Progressione Annuale',
      subtitle: 'Confronto anno per anno del volume di obiettivi e completamenti',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(BarChartData(
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => context.appColors.card,
                  tooltipRoundedRadius: 12,
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tooltipMargin: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final index = group.x.toInt();
                    if (index >= stats.length) return null;
                    final item = stats[index] as Map<String, dynamic>;
                    final y = item['year'] as int?;
                    final act = item['active'] as int? ?? 0;
                    final fail = item['failed'] as int? ?? 0;
                    final comp = item['completed'] as int? ?? 0;
                    return BarTooltipItem(
                      '$y\n',
                      GoogleFonts.inter(color: context.appColors.foreground, fontWeight: FontWeight.bold, fontSize: 13),
                      children: [
                        TextSpan(text: 'Attivi: $act\n', style: GoogleFonts.inter(color: const Color(0xFF3B82F6), fontSize: 11)),
                        TextSpan(text: 'Falliti: $fail\n', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11)),
                        TextSpan(text: 'Completati: $comp', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11)),
                      ],
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                show: true, 
                drawVerticalLine: false, 
                horizontalInterval: math.max(1.0, maxTot / 4), 
                getDrawingHorizontalLine: (v) => FlLine(color: context.appColors.border.withValues(alpha: 0.3), strokeWidth: 1, dashArray: [4, 4]),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, 
                    reservedSize: 32, 
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(v.toInt().toString(), style: GoogleFonts.inter(fontSize: 10, color: context.appColors.mutedForeground)),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true, 
                    getTitlesWidget: (val, _) {
                      final index = val.toInt();
                      if (index < 0 || index >= stats.length) return const SizedBox.shrink();
                      final item = stats[index] as Map<String, dynamic>;
                      final y = item['year'] as int?;
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(y?.toString() ?? '', style: GoogleFonts.inter(fontSize: 10, color: context.appColors.mutedForeground, fontWeight: FontWeight.w600)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              maxY: math.max(10.0, maxTot * 1.2),
              barGroups: groups,
              alignment: BarChartAlignment.spaceAround,
            )),
          ),
          const SizedBox(height: 16),
          _buildLegend([
            _LegendItem('Attivi', const Color(0xFF3B82F6)),
            _LegendItem('Falliti', const Color(0xFFEF4444)),
            _LegendItem('Completati', const Color(0xFF10B981)),
          ]),
        ],
      ),
    );
  }

  Widget _buildLegend(List<_LegendItem> items) {
    return Wrap(
      spacing: 16,
      alignment: WrapAlignment.center,
      children: items.map((i) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: i.color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text(i.label, style: GoogleFonts.inter(fontSize: 12, color: context.appColors.mutedForeground)),
        ],
      )).toList(),
    );
  }

  Widget _buildGlobalTypeDistCard(Map<String, dynamic> stats) {
    final Map<String, int> counts = {
      'Settimanale': (stats['weekly'] as num?)?.toInt() ?? 0,
      'Mensile': (stats['monthly'] as num?)?.toInt() ?? 0,
      'Trimestrale': (stats['quarterly'] as num?)?.toInt() ?? 0,
      'Annuale': (stats['annual'] as num?)?.toInt() ?? 0,
      'Lifetime': (stats['lifetime'] as num?)?.toInt() ?? 0,
    };
    int maxV = counts.values.fold(0, (p, c) => math.max(p, c));
    return _buildCardBase(
      title: '🔮 Distribuzione Tipologie',
      subtitle: 'Ripartizione degli obiettivi per orizzonte temporale',
      child: Column(
        children: counts.entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(width: 85, child: Text(e.key, style: GoogleFonts.inter(fontSize: 12, color: context.appColors.mutedForeground))),
              Expanded(
                child: Stack(
                  children: [
                    Container(height: 18, decoration: BoxDecoration(color: context.appColors.card, borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: maxV == 0 ? 0 : e.value / maxV,
                      child: Container(
                        height: 18, 
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                            ],
                          ), 
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 30, child: Text('${e.value}', style: GoogleFonts.inter(fontSize: 12, color: context.appColors.foreground, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildQuarterSeasonalityCard(List<dynamic> stats) {
    List<BarChartGroupData> groups = [];
    double maxX = 0;
    
    // Create a map for quick lookup
    final Map<int, Map<String, dynamic>> dataMap = {};
    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final q = item['quarter'] as int?;
        if (q != null) {
          dataMap[q] = item;
          final tot = (item['total'] as num?)?.toDouble() ?? 0.0;
          if (tot > maxX) maxX = tot;
        }
      }
    }

    for (int q = 1; q <= 4; q++) {
      final item = dataMap[q];
      final tot = (item?['total'] as num?)?.toDouble() ?? 0.0;
      final act = (item?['active'] as num?)?.toDouble() ?? 0.0;
      final fail = (item?['failed'] as num?)?.toDouble() ?? 0.0;
      final comp = (item?['completed'] as num?)?.toDouble() ?? 0.0;
      
      groups.add(BarChartGroupData(x: q, barRods: [
        BarChartRodData(
          toY: tot,
          color: Colors.transparent, 
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: math.max(5.0, maxX * 1.2),
            color: context.appColors.border.withValues(alpha: 0.1),
          ),
          rodStackItems: [
            if (act > 0) BarChartRodStackItem(0, act, const Color(0xFF3B82F6)),
            if (fail > 0) BarChartRodStackItem(act, act + fail, const Color(0xFFD97706)),
            if (comp > 0) BarChartRodStackItem(act + fail, act + fail + comp, const Color(0xFF10B981)),
          ]
        )
      ]));
    }
    return _buildCardBase(
      title: '🎂 Stagionalità',
      subtitle: 'Performance Trimestrale aggregata',
      child: Column(
        children: [
          SizedBox(height: 150, child: BarChart(BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => context.appColors.card,
                tooltipRoundedRadius: 12,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final q = group.x.toInt();
                  final item = dataMap[q];
                  final act = (item?['active'] as num?)?.toInt() ?? 0;
                  final fail = (item?['failed'] as num?)?.toInt() ?? 0;
                  final comp = (item?['completed'] as num?)?.toInt() ?? 0;
                  return BarTooltipItem(
                    'Trimestre $q\n',
                    GoogleFonts.inter(color: context.appColors.foreground, fontWeight: FontWeight.bold, fontSize: 13),
                    children: [
                      TextSpan(text: 'Attivi: $act\n', style: GoogleFonts.inter(color: const Color(0xFF3B82F6), fontSize: 10)),
                      TextSpan(text: 'Falliti: $fail\n', style: GoogleFonts.inter(color: const Color(0xFFD97706), fontSize: 10)),
                      TextSpan(text: 'Completati: $comp', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 10)),
                    ],
                  );
                },
              ),
            ),
            gridData: FlGridData(
              show: true, 
              drawVerticalLine: false, 
              horizontalInterval: math.max(1.0, maxX / 4), 
              getDrawingHorizontalLine: (v) => FlLine(color: context.appColors.border.withValues(alpha: 0.2), strokeWidth: 1, dashArray: [4, 4]),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(), 
              topTitles: const AxisTitles(), 
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v,_) {
                final index = v.toInt();
                if (index < 1 || index > 4) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Q$index', style: GoogleFonts.inter(fontSize: 10, color: context.appColors.mutedForeground, fontWeight: FontWeight.w600)),
                );
              })),
            ),
            barGroups: groups, 
            maxY: math.max(5.0, maxX * 1.2),
          ))),
          const SizedBox(height: 12),
          _buildLegend([
            _LegendItem('Attivi', const Color(0xFF3B82F6)),
            _LegendItem('Falliti', const Color(0xFFD97706)),
            _LegendItem('Compl.', const Color(0xFF10B981)),
          ]),
        ],
      ),
    );
  }

  Widget _buildGlobalMonthlyHistCard(List<dynamic> stats) {
    List<FlSpot> spots = [];
    
    // Create a map for quick lookup
    final Map<int, double> dataMap = {};
    for (var item in stats) {
      if (item is Map<String, dynamic>) {
        final m = item['month'] as int?;
        final rate = (item['rate'] as num?)?.toDouble() ?? 0.0;
        if (m != null) {
          dataMap[m] = rate;
        }
      }
    }

    for (int m = 1; m <= 12; m++) {
      final rate = dataMap[m] ?? 0.0;
      spots.add(FlSpot(m.toDouble(), rate));
    }

    return _buildCardBase(
      title: '📈 Mensile (Storico)',
      subtitle: 'Successo medio per mese',
      child: SizedBox(height: 180, child: LineChart(LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.appColors.card,
            tooltipRoundedRadius: 10,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((s) {
                const months = ['', 'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre'];
                return LineTooltipItem(
                  '${months[s.x.toInt()]}\n',
                  GoogleFonts.inter(color: context.appColors.mutedForeground, fontSize: 10),
                  children: [
                    TextSpan(
                      text: '${s.y.round()}% successo',
                      style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true, 
          drawVerticalLine: false, 
          getDrawingHorizontalLine: (v) => FlLine(color: context.appColors.border.withValues(alpha: 0.2), strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(), 
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, 
              reservedSize: 34, 
              getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: GoogleFonts.inter(fontSize: 9, color: context.appColors.mutedForeground)),
            ),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 3, getTitlesWidget: (v, _) {
            const mLabel = ['', 'gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
            final idx = v.toInt();
            if (idx < 1 || idx > 12) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(mLabel[idx], style: GoogleFonts.inter(fontSize: 9, color: context.appColors.mutedForeground, fontWeight: FontWeight.w600)),
            );
          })),
        ),
        minY: 0, maxY: 100, minX: 1, maxX: 12,
        lineBarsData: [LineChartBarData(
          spots: spots, 
          color: const Color(0xFF10B981),
          barWidth: 3, 
          isCurved: true, 
          curveSmoothness: 0.35,
          preventCurveOverShooting: true,
          dotData: FlDotData(
            show: true, 
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4, 
              color: const Color(0xFF10B981), 
              strokeWidth: 2, 
              strokeColor: context.appColors.card,
            ),
          ),
          belowBarData: BarAreaData(
            show: true, 
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.0),
              ],
            ),
          ),
        )],
      ))),
    );
  }

  Widget _buildGlobalInterestEvolutionCard(List<dynamic> stats, List<GoalCategory> categories) {
    if (stats.isEmpty) return const SizedBox();
    List<BarChartGroupData> groups = [];
    double maxY = 0;
    
    // Categories to show in evolution
    final limitedCategories = categories.take(6).toList();

    for (int i = 0; i < stats.length; i++) {
        final item = stats[i];
        if (item is! Map<String, dynamic>) continue;
        
        final cats = item['categories'] as Map<String, dynamic>? ?? {};
        
        double totalForYear = 0;
        List<BarChartRodStackItem> stacks = [];
        double curr = 0;
        
        for (var c in limitedCategories) {
           final count = (cats[c.key] as num?)?.toDouble() ?? 0.0;
           totalForYear += count;
           if (count > 0) {
             stacks.add(BarChartRodStackItem(curr, curr + count, c.color));
             curr += count;
           }
        }
        
        if (totalForYear > maxY) maxY = totalForYear;
        
        groups.add(BarChartGroupData(
          x: i, 
          barRods: [
            BarChartRodData(
              toY: totalForYear, 
              color: Colors.transparent, 
              width: 20, 
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: math.max(5.0, maxY * 1.2),
                color: AppColors.borderHover.withValues(alpha: 0.1),
              ),
              rodStackItems: stacks,
            )
          ],
        ));
    }
    
    // Update backDrawRodData with the final maxY
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final rod = g.barRods.first;
      groups[i] = BarChartGroupData(
        x: g.x,
        barRods: [
          BarChartRodData(
            toY: rod.toY,
            color: rod.color,
            width: rod.width,
            borderRadius: rod.borderRadius,
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: math.max(5.0, maxY * 1.2),
              color: AppColors.borderHover.withValues(alpha: 0.1),
            ),
            rodStackItems: rod.rodStackItems,
          )
        ],
      );
    }

    return _buildCardBase(
      title: '📈 Evoluzione Interessi',
      subtitle: 'Composizione delle aree di focus negli anni',
      child: Column(
        children: [
          SizedBox(height: 240, child: BarChart(BarChartData(
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => context.appColors.card,
                tooltipRoundedRadius: 12,
                tooltipPadding: const EdgeInsets.all(12),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final index = group.x.toInt();
                  if (index >= stats.length) return null;
                  final item = stats[index] as Map<String, dynamic>;
                  final y = item['year'] as int?;
                  final cats = item['categories'] as Map<String, dynamic>? ?? {};
                  
                  List<TextSpan> categorySpans = [];
                  for (var c in limitedCategories) {
                    final count = (cats[c.key] as num?)?.toInt() ?? 0;
                    if (count > 0) {
                      categorySpans.add(TextSpan(
                        text: '${c.label}: $count\n',
                        style: GoogleFonts.inter(color: c.color, fontSize: 10, fontWeight: FontWeight.w500),
                      ));
                    }
                  }

                  return BarTooltipItem(
                    '$y\n',
                    GoogleFonts.inter(color: context.appColors.foreground, fontWeight: FontWeight.bold, fontSize: 14),
                    children: categorySpans,
                  );
                },
              ),
            ),
            gridData: FlGridData(
              show: true, 
              drawVerticalLine: false, 
              horizontalInterval: math.max(1.0, maxY / 4), 
              getDrawingHorizontalLine: (v) => FlLine(color: context.appColors.border.withValues(alpha: 0.2), strokeWidth: 1, dashArray: [4, 4]),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(), 
              topTitles: const AxisTitles(), 
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true, 
                  reservedSize: 30, 
                  getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: GoogleFonts.inter(fontSize: 10, color: context.appColors.mutedForeground)),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true, 
                  getTitlesWidget: (v,_) {
                    final index = v.toInt();
                    if (index < 0 || index >= stats.length) return const SizedBox.shrink();
                    final item = stats[index] as Map<String, dynamic>;
                    final y = item['year'] as int?;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(y?.toString() ?? '', style: GoogleFonts.inter(fontSize: 10, color: context.appColors.mutedForeground, fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              ),
            ),
            barGroups: groups, 
            maxY: math.max(5.0, maxY * 1.2),
          ))),
          const SizedBox(height: 16),
          _buildLegend(limitedCategories.map((c) => _LegendItem(c.label, c.color)).toList()),
        ],
      ),
    );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  _LegendItem(this.label, this.color);
}
