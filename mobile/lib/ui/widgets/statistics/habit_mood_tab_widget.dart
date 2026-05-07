import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';
import 'dart:ui' as ui;

class HabitMoodTabWidget extends StatelessWidget {
  final String goalId;

  const HabitMoodTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopMetricsGrid(),
        const SizedBox(height: 12),
        _ResilienteBadge(),
        const SizedBox(height: 24),
        _CompletatoVsMancatoCard(),
        const SizedBox(height: 16),
        _PerformancePerLivelloCard(),
        const SizedBox(height: 16),
        _FooterInfo(),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _TopMetricsGrid extends StatelessWidget {
  const _TopMetricsGrid();

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
        _MetricCard(title: context.l10n.translate('Correlazione Mood'), value: '-20%', subtitle: context.l10n.translate('none')),
        _MetricCard(title: context.l10n.translate('Correlazione Energia'), value: '-6%', subtitle: context.l10n.translate('none')),
        _MetricCard(title: context.l10n.translate('Mood Medio (✓)'), value: '6.1', subtitle: context.l10n.translate('su 10'), isRed: true),
        _MetricCard(title: context.l10n.translate('Energia Media (✓)'), value: '6.7', subtitle: context.l10n.translate('su 10'), isRed: true),
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
              color: isRed ? const Color(0xFFEF4444) : context.appColors.foreground,
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
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.activity, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            context.l10n.translate('Resiliente'),
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
  const _CompletatoVsMancatoCard();

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
            context.l10n.translate('Completato vs Mancato'),
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
                    Text('10', style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
                    Text('6', style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
                    Text('3', style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
                    Text('0', style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
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
                        children: List.generate(4, (index) => _buildGridLine(context)),
                      ),
                      // Bars
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: _buildBarGroup(context, context.l10n.translate('Completato'), 6.0, 6.7)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildBarGroup(context, context.l10n.translate('Mancato'), 7.0, 7.0)),
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
              _buildLegendItem(context, const Color(0xFF10B981), context.l10n.translate('Umore')),
              const SizedBox(width: 16),
              _buildLegendItem(context, const Color(0xFFF59E0B), context.l10n.translate('Energia')),
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

  Widget _buildBarGroup(BuildContext context, String label, double moodValue, double energiaValue) {
    // max is 10
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
                  heightFactor: moodPct,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FractionallySizedBox(
                  heightFactor: energiaPct,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
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
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: color, // In the screenshot the text color matches the legend square
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PerformancePerLivelloCard extends StatelessWidget {
  const _PerformancePerLivelloCard();

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
            context.l10n.translate('Performance per Livello'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.translate('Basso (1-4) • Medio (5-7) • Alto (8-10)'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: context.appColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                // Y Axis
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('100%', style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
                    Text('75%', style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
                    Text('50%', style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
                    Text('25%', style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
                    Text('0%', style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
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
                        children: List.generate(5, (index) => _buildGridLine(context)),
                      ),
                      // Line Chart Custom Paint
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _LineChartPainter(
                            moodColor: const Color(0xFF10B981),
                            backgroundColor: context.appColors.background,
                          ),
                        ),
                      ),
                      // X Axis Labels
                      Positioned(
                        bottom: -16, // Move below the chart
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(context.l10n.translate('Basso'), style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
                            Text(context.l10n.translate('Medio'), style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
                            Text(context.l10n.translate('Alto'), style: TextStyle(fontSize: 10, color: context.appColors.mutedForeground)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLineLegendItem(const Color(0xFF10B981), context.l10n.translate('Con Mood'), false),
              const SizedBox(width: 16),
              _buildLineLegendItem(const Color(0xFFF59E0B), context.l10n.translate('Con Energia'), true),
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

  Widget _buildLineLegendItem(Color color, String label, bool isDashed) {
    return Row(
      children: [
        Icon(
          isDashed ? LucideIcons.unfoldHorizontal : LucideIcons.moveHorizontal, 
          size: 14, 
          color: color
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final Color moodColor;
  final Color backgroundColor;
  _LineChartPainter({required this.moodColor, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Values from 0.0 to 1.0 representing percentage
    // Mood (Teal): 75%, 62%, 48%
    // Energia (Orange): 68%, 64%, 54%
    final List<double> moodPts = [0.75, 0.62, 0.48];
    final List<double> energiaPts = [0.68, 0.64, 0.54];

    final double width = size.width;
    final double height = size.height;

    // Draw Mood Line
    final moodPaint = Paint()
      ..color = moodColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final moodPath = Path();
    for (int i = 0; i < moodPts.length; i++) {
      double x = (width / 2) * i;
      double y = height - (height * moodPts[i]);
      if (i == 0) {
        moodPath.moveTo(x, y);
      } else {
        moodPath.lineTo(x, y);
      }
    }
    canvas.drawPath(moodPath, moodPaint);

    // Draw Energia Dashed Line
    final energiaPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final energiaPath = Path();
    for (int i = 0; i < energiaPts.length; i++) {
      double x = (width / 2) * i;
      double y = height - (height * energiaPts[i]);
      if (i == 0) {
        energiaPath.moveTo(x, y);
      } else {
        energiaPath.lineTo(x, y);
      }
    }
    _drawDashedPath(canvas, energiaPath, energiaPaint);

    // Draw points
    final dotPaintFill = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 3; i++) {
      double x = (width / 2) * i;
      double my = height - (height * moodPts[i]);
      double ey = height - (height * energiaPts[i]);

      final moodDotStroke = Paint()
        ..color = moodColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(x, my), 4, dotPaintFill);
      canvas.drawCircle(Offset(x, my), 4, moodDotStroke);

      final energiaDotStroke = Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(x, ey), 4, dotPaintFill);
      canvas.drawCircle(Offset(x, ey), 4, energiaDotStroke);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dashWidth = 5.0;
    const double dashSpace = 4.0;
    double distance = 0.0;
    bool draw = true;

    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final double length = draw ? dashWidth : dashSpace;
        if (draw) {
          canvas.drawPath(
            pathMetric.extractPath(distance, distance + length),
            paint,
          );
        }
        distance += length;
        draw = !draw;
      }
      distance = 0.0;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FooterInfo extends StatelessWidget {
  const _FooterInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Text(
        context.l10n.translate('Analisi basata su count giorni con dati mood/energia (done completati, missed mancati)')
            .replaceFirst('count', '76')
            .replaceFirst('done', '46')
            .replaceFirst('missed', '30'),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: context.appColors.mutedForeground,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
