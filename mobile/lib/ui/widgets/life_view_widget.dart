import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';

class LifeViewWidget extends ConsumerWidget {
  const LifeViewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock data based on screenshot
    const int birthYear = 2003;
    const int endYear = 2088;
    final now = DateTime.now();
    
    final int totalMonths = (endYear - birthYear + 1) * 12;
    final int livedMonths = (now.year - birthYear) * 12 + now.month;
    final int remainingMonths = totalMonths - livedMonths;
    final int age = (livedMonths / 12).floor();

    // The screenshot shows a grid of dots.
    // Usually these are grouped by year (12 dots per row).
    // Let's try 24 dots per row to keep it compact and look like the screenshot.

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: AppTheme.glassPanelDecoration(context, radius: 14),
      child: Column(
        children: [
          // Title
          Text(
            'La Mia Vita Produttiva',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$birthYear - $endYear • ${totalMonths.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} mesi',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: context.appColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: Colors.blue.withValues(alpha: 0.4), label: 'Pre-tracking'),
              const SizedBox(width: 16),
              _LegendItem(color: const Color(0xFF10B981), label: 'Attuale'),
            ],
          ),
          const SizedBox(height: 24),

          // Stats Block
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: context.appColors.card.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(value: '$livedMonths', label: 'MESI VISSUTI'),
                _StatItem(value: '$age', label: 'ETÀ ATTUALE'),
                _StatItem(value: '$remainingMonths', label: 'RIMANENTI'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Life Grid - Responsive and optimized
          Expanded(
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _LifeGridPainter(
                      totalMonths: totalMonths,
                      livedMonths: livedMonths,
                      currentMonth: livedMonths,
                      accentColor: Theme.of(context).colorScheme.primary,
                      borderColor: context.appColors.border,
                      foregroundColor: context.appColors.foreground,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('nascita', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.appColors.mutedForeground.withValues(alpha: 0.4), letterSpacing: 0.5)),
              Text('orizzonte (85 anni)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.appColors.mutedForeground.withValues(alpha: 0.4), letterSpacing: 0.5)),
            ],
          )

        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
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
          style: TextStyle(fontSize: 11, color: context.appColors.mutedForeground),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.appColors.foreground,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: context.appColors.mutedForeground,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _LifeGridPainter extends CustomPainter {
  final int totalMonths;
  final int livedMonths;
  final int currentMonth;
  final Color accentColor;
  final Color borderColor;
  final Color foregroundColor;

  _LifeGridPainter({
    required this.totalMonths,
    required this.livedMonths,
    required this.currentMonth,
    required this.accentColor,
    required this.borderColor,
    required this.foregroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double dotSize = 4.0;
    const double spacing = 4.0;
    final int dotsPerRow = (size.width / (dotSize + spacing)).floor();
    
    final Paint preTrackingPaint = Paint()..color = Colors.blue.withValues(alpha: 0.2);
    final Paint livedPaint = Paint()..color = accentColor.withValues(alpha: 0.8);
    final Paint currentPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    final Paint currentStrokePaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Paint remainingPaint = Paint()..color = borderColor.withValues(alpha: 0.2);

    for (int i = 0; i < totalMonths; i++) {
      final int row = i ~/ dotsPerRow;
      final int col = i % dotsPerRow;

      final double x = col * (dotSize + spacing) + dotSize / 2;
      final double y = row * (dotSize + spacing) + dotSize / 2;

      Paint paint;
      if (i < livedMonths - 5) {
        paint = preTrackingPaint;
      } else if (i < livedMonths) {
        paint = livedPaint;
      } else {
        paint = remainingPaint;
      }

      if (i == currentMonth - 1) {
        canvas.drawCircle(Offset(x, y), dotSize / 2 + 2, currentStrokePaint);
        canvas.drawCircle(Offset(x, y), dotSize / 2, currentPaint);
      } else {
        canvas.drawCircle(Offset(x, y), dotSize / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
