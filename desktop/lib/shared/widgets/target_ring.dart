import 'dart:math' as math;

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';

/// Circular progress indicator for a quantitative habit-day — the desktop twin
/// of the mobile `TargetRing`, kept visually and semantically identical so "60
/// of 80" looks the same on both platforms.
///
/// Coloured by [TargetVerdict.outcome], not fullness: a filling limit ring is
/// amber (allowance being spent), a breached one red, and a reach-it ring fills
/// toward the habit's own colour and turns green on completion.
class TargetRing extends StatelessWidget {
  const TargetRing({
    super.key,
    required this.target,
    required this.verdict,
    this.size = 22,
    this.strokeWidth = 2.5,
    this.accent,
    this.child,
  });

  final HabitTarget target;
  final TargetVerdict verdict;
  final double size;
  final double strokeWidth;
  final Color? accent;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final accentColor = accent ?? colors.foreground;
    const limitAmber = kTargetWarningAmber;

    final Color fillColor = switch (verdict.outcome) {
      TargetOutcome.met => EvolveColors.success,
      TargetOutcome.breached => EvolveColors.destructive,
      TargetOutcome.unmet => EvolveColors.destructive,
      TargetOutcome.unknown => colors.muted,
      TargetOutcome.pending => target.isLimit ? limitAmber : accentColor,
    };

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: verdict.fraction,
          fillColor: fillColor,
          trackColor: colors.border,
          strokeWidth: strokeWidth,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.fillColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double fraction;
  final Color fillColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (fraction <= 0) return;
    final sweep = 2 * math.pi * fraction.clamp(0.0, 1.0);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = fillColor;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// Trims a trailing `.0` so `5.0` reads `5` while `0.5` stays `0.5`. No
/// locale-aware NumberFormat in the repo yet (task #8); the unit is shown
/// abbreviated beside it so plurals never arise.
/// The amber this feature uses for "not wrong, but watch out" — a filling limit
/// ring, and a warning under the amount/step fields. One definition so the two
/// surfaces cannot drift into different shades of caution.
const Color kTargetWarningAmber = Color(0xFFF59E0B);

String formatTargetAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

/// Short, plural-free unit suffix. `count` has none (the number stands alone).
String targetUnitShortLabel(TargetUnit unit) => switch (unit) {
      TargetUnit.count => '',
      TargetUnit.minutes => t.targets.units.min,
      TargetUnit.hours => t.targets.units.hour,
      TargetUnit.kilocalories => t.targets.units.kcal,
      TargetUnit.kilometers => t.targets.units.km,
    };
