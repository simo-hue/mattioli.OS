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
      decoration: AppTheme.glassPanelDecoration(radius: 14),
      child: Column(
        children: [
          // Title
          const Text(
            'La Mia Vita Produttiva',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$birthYear - $endYear • ${totalMonths.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} mesi',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: Colors.blue.withValues(alpha: 0.4), label: 'Pre-tracking'),
              const SizedBox(width: 16),
              const _LegendItem(color: AppColors.success, label: 'Attuale'),
            ],
          ),
          const SizedBox(height: 24),

          // Stats Block
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
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
              Text('nascita', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedForeground.withValues(alpha: 0.4), letterSpacing: 0.5)),
              Text('orizzonte (85 anni)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedForeground.withValues(alpha: 0.4), letterSpacing: 0.5)),
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
          style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
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
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedForeground,
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

  _LifeGridPainter({
    required this.totalMonths,
    required this.livedMonths,
    required this.currentMonth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double dotSize = 4.0;
    const double spacing = 4.0;
    final int dotsPerRow = (size.width / (dotSize + spacing)).floor();
    
    final Paint preTrackingPaint = Paint()..color = Colors.blue.withValues(alpha: 0.2);
    final Paint livedPaint = Paint()..color = AppColors.success.withValues(alpha: 0.8);
    final Paint currentPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.fill;
    final Paint currentStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Paint remainingPaint = Paint()..color = AppColors.border.withValues(alpha: 0.2);

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
