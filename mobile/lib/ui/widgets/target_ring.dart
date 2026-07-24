import 'dart:math' as math;

import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../i18n/translations.g.dart';

/// A circular progress indicator for a quantitative habit-day.
///
/// Fills to [verdict.fraction] and is coloured by [TargetVerdict.outcome], NOT
/// by fullness — for a LIMIT habit a full ring means the allowance is spent
/// (trouble), so a filling limit ring is drawn amber and a breached one red,
/// while a reach-it ring fills toward the habit's own colour and turns green on
/// completion. This is the one place that mapping lives, so every surface that
/// shows a ring reads the same.
class TargetRing extends StatelessWidget {
  const TargetRing({
    super.key,
    required this.target,
    required this.verdict,
    this.size = 44,
    this.strokeWidth = 4,
    this.accent,
    this.child,
  });

  final HabitTarget target;
  final TargetVerdict verdict;
  final double size;
  final double strokeWidth;

  /// The habit's own colour, used as the in-progress fill for a reach-it target.
  /// Defaults to the theme primary.
  final Color? accent;

  /// Optional centre content (e.g. an icon or a compact count).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accentColor = accent ?? colors.primary;
    const limitAmber = Color(0xFFF59E0B);
    const missRed = Color(0xFFEF4444);

    final Color fillColor = switch (verdict.outcome) {
      TargetOutcome.met => colors.success,
      TargetOutcome.breached => missRed,
      TargetOutcome.unmet => missRed,
      TargetOutcome.unknown => colors.mutedForeground,
      TargetOutcome.pending =>
        target.isLimit ? limitAmber : accentColor,
    };

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: verdict.fraction,
          fillColor: fillColor,
          trackColor: colors.muted,
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
    // Start at 12 o'clock and sweep clockwise.
    canvas.drawArc(rect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// Formats a target amount for display, trimming a trailing `.0` so `5.0`
/// reads `5` while `0.5` stays `0.5`. Deliberately plain `toString`-based (the
/// repo has no locale-aware NumberFormat yet — see task #8); the unit is shown
/// abbreviated beside it so plurals never arise.
String formatTargetAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toString();
}

/// Short, plural-free unit suffix for a target. `count` has none (the number
/// stands alone — "80", not "80 counts"). Kept beside the ring so no full
/// pluralization is ever needed (task #8 note).
String targetUnitShortLabel(Translations t, TargetUnit unit) => switch (unit) {
      TargetUnit.count => '',
      TargetUnit.minutes => t.targets.units.min,
      TargetUnit.hours => t.targets.units.hour,
      TargetUnit.kilocalories => t.targets.units.kcal,
      TargetUnit.kilometers => t.targets.units.km,
    };
