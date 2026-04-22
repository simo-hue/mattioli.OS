import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../models/goal.dart';
import '../../../providers/goal_provider.dart';

class GlobalTrendTabWidget extends ConsumerStatefulWidget {
  const GlobalTrendTabWidget({super.key});

  @override
  ConsumerState<GlobalTrendTabWidget> createState() => _GlobalTrendTabWidgetState();
}

class _GlobalTrendTabWidgetState extends ConsumerState<GlobalTrendTabWidget> {
  String _chartTimeframe = 'Sett';
  String _comparisonTimeframe = 'Mese';

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTrendChartSection(),
        const SizedBox(height: 24),
        _buildComparisonSection(goals),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTrendChartSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassPanelDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trend',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                  letterSpacing: -0.5,
                ),
              ),
              _buildSmallTimeframeSelector(
                selected: _chartTimeframe,
                options: ['Sett', 'Mese', 'Anno', 'Tutto'],
                onSelect: (val) => setState(() => _chartTimeframe = val),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Smooth Area Chart
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: _SmoothAreaChartPainter(),
            ),
          ),
          const SizedBox(height: 16),
          // Day labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['gio', 'ven', 'sab', 'dom', 'lun', 'mar', 'mer'].map((d) {
              return Text(
                d,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonSection(List<Goal> goals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.trendingUp, size: 18, color: AppColors.foreground),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Confronto Temporale',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Analizza come stai andando rispetto al passato.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildSmallTimeframeSelector(
              selected: _comparisonTimeframe,
              options: ['Settimana', 'Mese', 'Anno'],
              onSelect: (val) => setState(() => _comparisonTimeframe = val),
              padding: 4,
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Grid of comparisons
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: goals.length,
          itemBuilder: (context, index) {
            final goal = goals[index];
            // Mock data based on goal ID
            final int current = 50 + (goal.id.hashCode % 45);
            final int previous = 40 + (goal.id.hashCode % 35);
            final int delta = current - previous;

            return _buildComparisonCard(goal, current, previous, delta);
          },
        ),
      ],
    );
  }

  Widget _buildComparisonCard(Goal goal, int current, int previous, int delta) {
    final bool isPositive = delta >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: goal.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  goal.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Precedente: $previous%',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$current%',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                    size: 10,
                    color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${isPositive ? '+' : ''}$delta%',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTimeframeSelector({
    required String selected,
    required List<String> options,
    required Function(String) onSelect,
    double padding = 2,
  }) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSel = selected == opt;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(opt);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSel ? AppColors.background : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                opt,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  color: isSel ? AppColors.foreground : AppColors.mutedForeground,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SmoothAreaChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Points for a smooth curve
    final points = [
      Offset(0, size.height * 0.4),
      Offset(size.width * 0.15, size.height * 0.5),
      Offset(size.width * 0.35, size.height * 0.8),
      Offset(size.width * 0.5, size.height * 0.7),
      Offset(size.width * 0.7, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.3),
      Offset(size.width, size.height * 0.6),
    ];

    path.moveTo(points[0].dx, points[0].dy);

    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    // Draw area
    final areaPath = Path.from(path);
    areaPath.lineTo(size.width, size.height);
    areaPath.lineTo(0, size.height);
    areaPath.close();
    canvas.drawPath(areaPath, areaPaint);

    // Draw line
    canvas.drawPath(path, paint);
    
    // Add some glow
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
