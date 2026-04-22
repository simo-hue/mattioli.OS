import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math' as math;

import '../../../core/theme.dart';
import '../../../models/macro_goal.dart';
import '../../../providers/macro_goals_provider.dart';

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

    final displayGoals = _selectedYear == 'all'
        ? allGoals
        : allGoals.where((g) => g.year == null || g.year.toString() == _selectedYear).toList();

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
                  color: AppColors.foreground,
                  letterSpacing: -0.5,
                ),
              ),
              _buildYearSelector(years),
            ],
          ),
          const SizedBox(height: 20),

          if (_selectedYear == 'all')
            ..._buildGlobalContent(allGoals)
          else
            ..._buildSingleYearContent(displayGoals)
        ],
      ),
    );
  }

  List<Widget> _buildSingleYearContent(List<MacroGoal> displayGoals) {
    final totalGoals = displayGoals.length;
    final completedGoals = displayGoals.where((g) => g.status == GoalStatus.completed).length;
    final successRate = totalGoals > 0 ? (completedGoals / totalGoals * 100).round() : 0;
    final trendPositive = successRate > 50;

    final Map<String, List<MacroGoal>> catMap = {};
    for (var g in displayGoals) {
      final key = g.categoryKey ?? 'altro';
      catMap.putIfAbsent(key, () => []).add(g);
    }
    String bestCategory = 'N/A';
    int bestCatRate = 0;
    catMap.forEach((key, list) {
      if (list.length >= 2) {
        final comp = list.where((g) => g.status == GoalStatus.completed).length;
        final rate = (comp / list.length * 100).round();
        if (rate > bestCatRate) {
          bestCatRate = rate;
          bestCategory = kDefaultCategories.firstWhere((c) => c.key == key, orElse: () => kDefaultCategories.first).label;
        }
      }
    });

    final Map<int, List<MacroGoal>> monthMap = {};
    for (var g in displayGoals.where((g) => g.month != null)) {
      monthMap.putIfAbsent(g.month!, () => []).add(g);
    }
    int bestMonthIdx = 0;
    int bestMonthRate = 0;
    monthMap.forEach((m, list) {
      if (list.isNotEmpty) {
        final comp = list.where((g) => g.status == GoalStatus.completed).length;
        final rate = (comp / list.length * 100).round();
        if (rate > bestMonthRate || (rate == bestMonthRate && comp > 0)) {
          bestMonthRate = rate;
          bestMonthIdx = m;
        }
      }
    });

    final monthsLabel = ['', 'gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];

    final Map<GoalType, List<MacroGoal>> typeMap = {};
    for (var g in displayGoals) {
      typeMap.putIfAbsent(g.type, () => []).add(g);
    }
    GoalType? bestType;
    int bestTypeRate = 0;
    typeMap.forEach((t, list) {
      if (list.length >= 2) {
        final comp = list.where((g) => g.status == GoalStatus.completed).length;
        final rate = (comp / list.length * 100).round();
        if (rate > bestTypeRate) {
          bestTypeRate = rate;
          bestType = t;
        }
      }
    });
    String bestTypeLabel = 'N/A';
    if (bestType != null) {
      switch (bestType!) {
        case GoalType.lifetime: bestTypeLabel = 'Lifetime'; break;
        case GoalType.annual: bestTypeLabel = 'Annuale'; break;
        case GoalType.quarterly: bestTypeLabel = 'Trimestrale'; break;
        case GoalType.monthly: bestTypeLabel = 'Mensile'; break;
        case GoalType.weekly: bestTypeLabel = 'Settimanale'; break;
      }
    }

    return [
      Row(
        children: [
          Expanded(child: _buildHighlightCard(title: 'Punto di Forza', value: bestCategory, subtitle: '$bestCatRate% di completamento', icon: LucideIcons.zap, color: const Color(0xFFA855F7))),
          const SizedBox(width: 12),
          Expanded(child: _buildHighlightCard(title: 'Mese Migliore', value: bestMonthIdx > 0 ? monthsLabel[bestMonthIdx] : 'Nessuno', subtitle: '$bestMonthRate% di successo', icon: LucideIcons.trophy, color: const Color(0xFFF59E0B))),
        ],
      ),
      const SizedBox(height: 12),
      _buildHighlightCard(title: 'Tipologia Efficace', value: bestTypeLabel, subtitle: '$bestTypeRate% di successo', icon: LucideIcons.brainCircuit, color: const Color(0xFF10B981), fullWidth: true),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _buildKpiCard('Totale', '$totalGoals', LucideIcons.target)),
          const SizedBox(width: 8),
          Expanded(child: _buildKpiCard('Completati', '$completedGoals', LucideIcons.circleCheck, color: const Color(0xFF34D399))),
          const SizedBox(width: 8),
          Expanded(child: _buildKpiCard('Successo', '$successRate%', LucideIcons.trophy, color: const Color(0xFFFBBF24))),
          const SizedBox(width: 8),
          Expanded(child: _buildKpiCard('Trend', trendPositive ? 'Crescita' : 'Calo', trendPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown, color: const Color(0xFF60A5FA))),
        ],
      ),
      const SizedBox(height: 24),
      _buildAreaChartCard(displayGoals),
      const SizedBox(height: 16),
      _buildCategoryRadarCard(displayGoals),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildQuarterlyBarCard(displayGoals)),
          const SizedBox(width: 12),
          Expanded(child: _buildMonthlyComposedCard(displayGoals)),
        ],
      ),
      const SizedBox(height: 16),
      _buildCategoryPieCard(displayGoals),
      const SizedBox(height: 48),
    ];
  }

  List<Widget> _buildGlobalContent(List<MacroGoal> goals) {
    if (goals.isEmpty) return [const Center(child: Text('Nessun obiettivo'))];

    final total = goals.length;
    final comp = goals.where((g) => g.status == GoalStatus.completed).length;
    final succ = total > 0 ? (comp / total * 100).round() : 0;
    
    final Map<int, List<MacroGoal>> yearMap = {};
    for (var g in goals.where((g) => g.year != null)) {
      yearMap.putIfAbsent(g.year!, () => []).add(g);
    }
    
    int bestYear = 0;
    int bestYearRate = 0;
    int mostProdYear = 0;
    int mostProdCount = 0;
    
    yearMap.forEach((y, list) {
      if (list.isNotEmpty) {
        final c = list.where((g) => g.status == GoalStatus.completed).length;
        final rate = (c / list.length * 100).round();
        if (rate > bestYearRate) { bestYearRate = rate; bestYear = y; }
        if (list.length > mostProdCount) { mostProdCount = list.length; mostProdYear = y; }
      }
    });

    final sortedYears = yearMap.keys.toList()..sort();

    return [
      Row(
        children: [
          Expanded(child: _buildHighlightCard(title: 'Totale Storico', value: '$total', subtitle: 'Obiettivi tracciati dal ${sortedYears.isNotEmpty ? sortedYears.first : '-'}', icon: LucideIcons.target, color: const Color(0xFF6366F1))),
          const SizedBox(width: 12),
          Expanded(child: _buildHighlightCard(title: 'Successo Globale', value: '$succ%', subtitle: '$comp obiettivi completati', icon: LucideIcons.trophy, color: const Color(0xFF10B981))),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _buildHighlightCard(title: 'Anno Migliore', value: bestYear > 0 ? '$bestYear' : 'N/A', subtitle: '$bestYearRate% completamento', icon: LucideIcons.calendar, color: const Color(0xFFD97706))),
          const SizedBox(width: 12),
          Expanded(child: _buildHighlightCard(title: 'Anno Più Produttivo', value: mostProdYear > 0 ? '$mostProdYear' : 'N/A', subtitle: '$mostProdCount obiettivi totali', icon: LucideIcons.activity, color: const Color(0xFF06B6D4))),
        ],
      ),
      const SizedBox(height: 24),
      
      _buildGlobalYearProgressionCard(goals, sortedYears),
      const SizedBox(height: 16),
      _buildCategoryRadarCard(goals), // Reusing radar for category performance
      const SizedBox(height: 16),
      _buildGlobalTypeDistCard(goals),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Expanded(child: _buildQuarterSeasonalityCard(goals)),
           const SizedBox(width: 12),
           Expanded(child: _buildGlobalMonthlyHistCard(goals)),
        ],
      ),
      const SizedBox(height: 16),
      _buildGlobalInterestEvolutionCard(goals, sortedYears),
      const SizedBox(height: 48),
    ];
  }

  // ─── Component Builders ───────────────────────────────────────────────────

  Widget _buildYearSelector(List<int> years) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.borderHover),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedYear,
          dropdownColor: AppColors.card,
          icon: Icon(LucideIcons.chevronDown, size: 14, color: AppColors.mutedForeground),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.foreground),
          onChanged: (v) {
            if (v != null) setState(() => _selectedYear = v);
          },
          items: [
            const DropdownMenuItem(value: 'all', child: Text('Tutti gli anni')),
            for (var y in years)
              DropdownMenuItem(value: '$y', child: Text('$y')),
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
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
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
              color: AppColors.foreground,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.mutedForeground,
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
        color: AppColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderHover),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedForeground, letterSpacing: -0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Icon(icon, size: 12, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 18, color: AppColors.foreground, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildCardBase({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderHover),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.card.withValues(alpha: 0.4),
            AppColors.card.withValues(alpha: 0.2),
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
              color: AppColors.foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.mutedForeground,
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

  Widget _buildAreaChartCard(List<MacroGoal> goals) {
    // Generate cumulative data per month (1-12)
    List<FlSpot> totalSpots = [];
    List<FlSpot> compSpots = [];
    
    int accTotal = 0;
    int accComp = 0;
    
    for (int m = 1; m <= 12; m++) {
      final monthly = goals.where((g) => g.month == m).toList();
      accTotal += monthly.length;
      accComp += monthly.where((g) => g.status == GoalStatus.completed).length;
      
      totalSpots.add(FlSpot(m.toDouble(), accTotal.toDouble()));
      compSpots.add(FlSpot(m.toDouble(), accComp.toDouble()));
    }

    final double maxY = math.max(10.0, accTotal.toDouble() * 1.2);

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
              getDrawingHorizontalLine: (value) => FlLine(color: AppColors.borderActive, strokeWidth: 1, dashArray: [4, 4]),
              getDrawingVerticalLine: (value) => FlLine(color: AppColors.borderActive, strokeWidth: 1, dashArray: [4, 4]),
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
                      child: Text(months[val.toInt() - 1], style: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedForeground)),
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
                    return Text(val.toInt().toString(), style: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedForeground));
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
                color: const Color(0xFF34D399), // Emerald
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: const Color(0xFF34D399).withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRadarCard(List<MacroGoal> goals) {
    if (goals.isEmpty) {
      return _buildCardBase(
        title: '🎯 Performance Categorie', subtitle: 'Tasso di successo',
        child: const SizedBox(height: 200, child: Center(child: Text('Nessun dato', style: TextStyle(color: Colors.white54)))),
      );
    }
    
    // Calculate rate per category
    final Map<GoalCategory, double> catRates = {};
    for (var cat in kDefaultCategories) {
      final catGoals = goals.where((g) => g.categoryKey == cat.key).toList();
      if (catGoals.isEmpty) continue;
      final comp = catGoals.where((g) => g.status == GoalStatus.completed).length;
      catRates[cat] = comp / catGoals.length * 100;
    }

    if (catRates.isEmpty) {
      return _buildCardBase(
        title: '🎯 Performance', subtitle: 'Tasso di successo',
        child: const SizedBox(height: 200, child: Center(child: Text('Dati non sufficienti', style: TextStyle(color: Colors.white54)))),
      );
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
                dataEntries: [
                  for (var cat in catRates.keys)
                    RadarEntry(value: catRates[cat]!),
                ],
              )
            ],
            radarBackgroundColor: Colors.transparent,
            borderData: FlBorderData(show: false),
            radarBorderData: BorderSide(color: AppColors.borderActive),
            tickBorderData: BorderSide(color: AppColors.borderActive, width: 0.5),
            getTitle: (index, angle) {
              final cats = catRates.keys.toList();
              return RadarChartTitle(
                text: cats[index].label,
                angle: 0,
                positionPercentageOffset: 0.1,
              );
            },
            titleTextStyle: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedForeground),
          ),
        ),
      ),
    );
  }

  Widget _buildQuarterlyBarCard(List<MacroGoal> goals) {
    if (goals.isEmpty) {
      return _buildCardBase(title: 'Attività Trim.', subtitle: 'Q1 - Q4', child: const SizedBox(height: 150));
    }
    
    // Extract totals and completed per quarter
    List<BarChartGroupData> groups = [];
    double maxY = 0;
    for (int q = 1; q <= 4; q++) {
      final qGoals = goals.where((g) => g.quarter == q).toList();
      final tot = qGoals.length.toDouble();
      final comp = qGoals.where((g) => g.status == GoalStatus.completed).length.toDouble();
      if (tot > maxY) maxY = tot;
      
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
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) => Text('Q${val.toInt()}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedForeground)),
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

  Widget _buildMonthlyComposedCard(List<MacroGoal> goals) {
    if (goals.isEmpty) {
      return _buildCardBase(title: 'Attività Mensile', subtitle: 'Totale/Completati', child: const SizedBox(height: 150));
    }

    List<BarChartGroupData> barGroups = [];
    double maxY = 0;
    
    for (int m = 1; m <= 12; m+=2) { // Show fewer columns to fit mobile
      final monthly = goals.where((g) => g.month == m).toList();
      final tot = monthly.length.toDouble();
      final comp = monthly.where((g) => g.status == GoalStatus.completed).length.toDouble();
      if (tot > maxY) maxY = tot;

      barGroups.add(
        BarChartGroupData(
          x: m,
          barRods: [
            BarChartRodData(toY: tot, color: const Color(0xFF6366F1), width: 6, borderRadius: BorderRadius.circular(1)),
            BarChartRodData(toY: comp, color: const Color(0xFFF97316), width: 6, borderRadius: BorderRadius.circular(1)), // Fake composed
          ],
        )
      );
    }

    const mLabel = ['', 'G', 'F', 'M', 'A', 'M', 'G', 'L', 'A', 'S', 'O', 'N', 'D'];

    return _buildCardBase(
      title: 'Mensile',
      subtitle: 'Completamenti',
      child: SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(show: false),
            titlesData: FlTitlesData(
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) => Text(mLabel[val.toInt()], style: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedForeground)),
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

  Widget _buildCategoryPieCard(List<MacroGoal> goals) {
    if (goals.isEmpty) {
       return _buildCardBase(title: 'Distribuzione', subtitle: '', child: const SizedBox(height: 200, child: Center(child: Text('Nessun dato', style: TextStyle(color: Colors.white54)))));
    }

    final Map<GoalCategory, int> map = {};
    for (var cat in kDefaultCategories) {
      final count = goals.where((g) => g.categoryKey == cat.key).length;
      if (count > 0) map[cat] = count;
    }

    if (map.isEmpty) return const SizedBox.shrink();

    // Sort by count desc
    final entries = map.entries.toList()..sort((a,b) => b.value.compareTo(a.value));

    List<PieChartSectionData> sections = [];
    for (var entry in entries) {
      sections.add(PieChartSectionData(
        value: entry.value.toDouble(),
        color: entry.key.color,
        title: '',
        radius: 26,
        badgeWidget: null,
      ));
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
                    Text('${goals.length}', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('obiettivi', style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedForeground)),
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
            children: entries.map((e) {
              final perc = (e.value / goals.length * 100).round();
              return Container(
                width: 150, // Fix width for grid likeness
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderHover),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: e.key.color)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.key.label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.foreground), maxLines: 1)),
                    Text('$perc%', style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedForeground)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalYearProgressionCard(List<MacroGoal> goals, List<int> sortedYears) {
    if (sortedYears.isEmpty) return const SizedBox();

    List<BarChartGroupData> groups = [];
    double maxTot = 0;

    for (int i = 0; i < sortedYears.length; i++) {
      final y = sortedYears[i];
      final yg = goals.where((g) => g.year == y).toList();
      final act = yg.where((g) => g.status == GoalStatus.active).length.toDouble();
      final fail = yg.where((g) => g.status == GoalStatus.failed).length.toDouble();
      final tot = yg.length.toDouble();
      if (tot > maxTot) maxTot = tot;

      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: tot,
            color: Colors.transparent,
            width: 16,
            borderRadius: BorderRadius.circular(4),
            rodStackItems: [
              BarChartRodStackItem(0, act, const Color(0xFF3B82F6)), // Attivi - Blue
              BarChartRodStackItem(act, act + fail, const Color(0xFFEF4444)), // Falliti - Red
              BarChartRodStackItem(act + fail, tot, const Color(0xFF10B981)), // Completati - Green
            ],
          )
        ],
      ));
    }

    return _buildCardBase(
      title: '📈 Progressione Annuale',
      subtitle: 'Confronto anno per anno del volume di obiettivi e completamenti',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(BarChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxTot / 4, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.borderActive, strokeWidth: 1, dashArray: [4, 4])),
              titlesData: FlTitlesData(
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedForeground)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, _) => Text(sortedYears.length > val.toInt() ? sortedYears[val.toInt()].toString() : '', style: GoogleFonts.inter(fontSize: 10, color: AppColors.mutedForeground)))),
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
          Text(i.label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedForeground)),
        ],
      )).toList(),
    );
  }

  Widget _buildGlobalTypeDistCard(List<MacroGoal> goals) {
    final Map<String, int> counts = {
      'Settimanale': goals.where((g) => g.type == GoalType.weekly).length,
      'Mensile': goals.where((g) => g.type == GoalType.monthly).length,
      'Trimestrale': goals.where((g) => g.type == GoalType.quarterly).length,
      'Annuale': goals.where((g) => g.type == GoalType.annual).length,
      'Lifetime': goals.where((g) => g.type == GoalType.lifetime).length,
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
              SizedBox(width: 85, child: Text(e.key, style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedForeground))),
              Expanded(
                child: Stack(
                  children: [
                    Container(height: 18, decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(4))),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: maxV == 0 ? 0 : e.value / maxV,
                      child: Container(height: 18, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)]), borderRadius: BorderRadius.circular(4))),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 30, child: Text('${e.value}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.foreground, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildQuarterSeasonalityCard(List<MacroGoal> goals) {
    List<BarChartGroupData> groups = [];
    double maxX = 0;
    for (int q = 1; q <= 4; q++) {
      final qg = goals.where((g) => g.quarter == q).toList();
      final act = qg.where((g)=>g.status==GoalStatus.active).length.toDouble();
      final fail = qg.where((g)=>g.status==GoalStatus.failed).length.toDouble();
      final tot = qg.length.toDouble();
      
      groups.add(BarChartGroupData(x: q, barRods: [
        BarChartRodData(
          toY: tot,
          color: Colors.transparent, 
          width: 12,
          rodStackItems: [
            BarChartRodStackItem(0, act, const Color(0xFF3B82F6)),
            BarChartRodStackItem(act, act+fail, const Color(0xFFD97706)),
            BarChartRodStackItem(act+fail, tot, const Color(0xFF10B981)),
          ]
        )
      ]));
      if (tot > maxX) maxX = tot;
    }
    return _buildCardBase(
      title: '🎂 Stagionalità',
      subtitle: 'Performance Trimestrale aggregata',
      child: Column(
        children: [
          SizedBox(height: 150, child: BarChart(BarChartData(
            gridData: FlGridData(show: false), borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: AxisTitles(), topTitles: AxisTitles(), leftTitles: AxisTitles(),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v,_) => Text('Q${v.toInt()}', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)))),
            ),
            barGroups: groups, maxY: math.max(5.0, maxX*1.2),
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

  Widget _buildGlobalMonthlyHistCard(List<MacroGoal> goals) {
    List<FlSpot> spots = [];
    for (int m = 1; m <= 12; m++) {
      final mg = goals.where((g) => g.month == m);
      if (mg.isNotEmpty) {
        spots.add(FlSpot(m.toDouble(), mg.where((g)=>g.status==GoalStatus.completed).length / mg.length * 100));
      } else {
         spots.add(FlSpot(m.toDouble(), 0));
      }
    }
    return _buildCardBase(
      title: '📈 Mensile (Storico)',
      subtitle: 'Successo medio per mese',
      child: SizedBox(height: 180, child: LineChart(LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.borderActive, strokeWidth: 0.5, dashArray: [4, 4])),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(), rightTitles: AxisTitles(),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 3, getTitlesWidget: (v, _) {
            const mLabel = ['', 'gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
            if (v < 1 || v > 12) return const SizedBox();
            return Text(mLabel[v.toInt()], style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground));
          })),
        ),
        minY: 0, maxY: 100, minX: 1, maxX: 12,
        lineBarsData: [LineChartBarData(
          spots: spots, color: const Color(0xFFEC4899),
          barWidth: 3, isCurved: true, 
          dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: const Color(0xFFEC4899), strokeWidth: 1, strokeColor: Colors.white)),
          belowBarData: BarAreaData(show: true, color: const Color(0xFFEC4899).withValues(alpha: 0.1)),
        )],
      ))),
    );
  }

  Widget _buildGlobalInterestEvolutionCard(List<MacroGoal> goals, List<int> sortedYears) {
    if (sortedYears.isEmpty) return const SizedBox();
    List<BarChartGroupData> groups = [];
    double maxY = 0;
    
    // Categories to show in evolution
    final categories = kDefaultCategories.take(6).toList();

    for (int i = 0; i < sortedYears.length; i++) {
        final yg = goals.where((g) => g.year == sortedYears[i]);
        if(yg.length > maxY) maxY = yg.length.toDouble();
        
        List<BarChartRodStackItem> stacks = [];
        double curr = 0;
        for (var c in categories) {
           double amt = yg.where((g)=>g.categoryKey==c.key).length.toDouble();
           if (amt>0) {
             stacks.add(BarChartRodStackItem(curr, curr+amt, c.color));
             curr += amt;
           }
        }
        groups.add(BarChartGroupData(x: i, barRods: [BarChartRodData(toY: yg.length.toDouble(), color: Colors.transparent, width: 24, borderRadius: BorderRadius.circular(2), rodStackItems: stacks)]));
    }
    return _buildCardBase(
      title: '📈 Evoluzione Interessi',
      subtitle: 'Composizione delle aree di focus negli anni',
      child: Column(
        children: [
          SizedBox(height: 220, child: BarChart(BarChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: math.max(1.0, maxY/4), getDrawingHorizontalLine: (v) => FlLine(color: AppColors.borderActive, strokeWidth: 0.5, dashArray: [4, 4])),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: AxisTitles(), topTitles: AxisTitles(), 
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v,_) => Text(sortedYears.length > v.toInt() ? sortedYears[v.toInt()].toString() : '', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)))),
            ),
            barGroups: groups, maxY: math.max(5.0, maxY*1.2),
          ))),
          const SizedBox(height: 16),
          _buildLegend(categories.map((c) => _LegendItem(c.label, c.color)).toList()),
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
