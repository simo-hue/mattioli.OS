import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';

class PulsingSyncAnimation extends StatefulWidget {
  final double size;
  final Color? color;

  const PulsingSyncAnimation({
    super.key,
    this.size = 120,
    this.color,
  });

  @override
  State<PulsingSyncAnimation> createState() => _PulsingSyncAnimationState();
}

class _PulsingSyncAnimationState extends State<PulsingSyncAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _PulsingRingsPainter(
                  progress: _controller.value,
                  color: baseColor,
                ),
              );
            },
          ),
          // Center Icon with a slight glowing background
          Container(
            padding: EdgeInsets.all(widget.size * 0.15),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.appColors.card,
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              LucideIcons.arrowDownToLine,
              color: baseColor,
              size: widget.size * 0.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingRingsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulsingRingsPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw three staggered rings
    for (int i = 0; i < 3; i++) {
      // Offset the progress for each ring by 0.33
      final double ringProgress = (progress + (i * 0.33)) % 1.0;
      
      // We want it to start small and grow to maxRadius
      // We start the radius slightly larger than the center icon container
      final minRadius = maxRadius * 0.4;
      final radius = minRadius + (maxRadius - minRadius) * ringProgress;
      
      // Fade out as it expands
      // It stays opaque at first, then fades to 0 smoothly
      final opacity = math.max(0.0, 1.0 - (ringProgress * 1.5));
      final ringColor = color.withValues(alpha: opacity * 0.6); // Slightly darker rings

      final paint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
      
      // Also draw a very faint filled circle
      final fillPaint = Paint()
        ..color = ringColor.withValues(alpha: opacity * 0.15)
        ..style = PaintingStyle.fill;
        
      canvas.drawCircle(center, radius, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsingRingsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
