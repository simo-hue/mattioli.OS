import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/user_provider.dart';
import '../../i18n/translations.g.dart';

class LifeViewWidget extends ConsumerWidget {
  const LifeViewWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    final dobStr = userProfile.dateOfBirth;

    // NO FALLBACK BIRTH YEAR.
    //
    // This used to default to 2003, and the consequence was not a cosmetic one:
    // every number on this screen is derived from it, so a user who had never
    // entered a date of birth was shown a complete, plausible, entirely
    // fabricated life — months lived, current age, months remaining — with
    // nothing marking any of it as invented. Someone twice that age read their
    // own life back wrong.
    //
    // A missing date is not a number we are allowed to guess. Say so instead.
    final parsed = dobStr == null ? null : DateTime.tryParse(dobStr);
    // A date in the FUTURE is treated as absent too. It cannot be a birth date,
    // and every figure here is a subtraction from it — so it renders "-41 months
    // lived, age -4", which is the same class of nonsense as the invented 2003.
    // Not reachable through the picker; reachable through synced or imported
    // data, which is where a bad value actually comes from.
    final now = DateTime.now();
    final birthDate =
        parsed == null || parsed.isAfter(now) ? null : parsed;
    if (birthDate == null) return const _NeedsDateOfBirth();

    final int birthYear = birthDate.year;
    final int endYear = birthYear + 85;

    final int totalMonths = (endYear - birthYear + 1) * 12;
    final int livedMonths =
        (now.year - birthDate.year) * 12 + now.month - birthDate.month;
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
            context.t.habits.productiveLifeTitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(
                color: Colors.blue.withValues(alpha: 0.4),
                label: context.t.habits.preTracking,
              ),
              const SizedBox(width: 16),
              _LegendItem(
                color: const Color(0xFF10B981),
                label: context.t.habits.current,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats Block
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: context.appColors.card.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.appColors.border.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  value: '$livedMonths',
                  label: context.t.habits.monthsLived,
                ),
                _StatItem(value: '$age', label: context.t.habits.currentAge),
                _StatItem(
                  value: '$remainingMonths',
                  label: context.t.habits.remaining,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Life Grid - Responsive and optimized
          Expanded(
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Semantics(
                    label: context.t.a11y.lifeGridLabel(
                      lived: livedMonths,
                      total: totalMonths,
                    ),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _LifeGridPainter(
                        totalMonths: totalMonths,
                        livedMonths: livedMonths,
                        currentMonth: livedMonths,
                        accentColor: Theme.of(context).colorScheme.primary,
                        borderColor: context.appColors.border,
                        foregroundColor: context.appColors.foreground,
                      ),
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
              Text(
                context.t.habits.birth,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.mutedForeground.withValues(
                    alpha: 0.4,
                  ),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                context.t.habits.k85Years,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.mutedForeground.withValues(
                    alpha: 0.4,
                  ),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
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
          style: TextStyle(
            fontSize: 11,
            color: context.appColors.mutedForeground,
          ),
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

    final Paint preTrackingPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.2);
    final Paint livedPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.8);
    final Paint currentPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    final Paint currentStrokePaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Paint remainingPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.2);

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

/// Shown in place of the whole life grid when no date of birth is set.
///
/// Deliberately keeps the panel and its title, so the view still explains what
/// it IS — it simply declines to invent the one input it needs.
class _NeedsDateOfBirth extends StatelessWidget {
  const _NeedsDateOfBirth();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: AppTheme.glassPanelDecoration(context, radius: 14),
      child: Column(
        children: [
          Text(
            context.t.habits.productiveLifeTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.t.habits.lifeViewNeedsDob,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.45,
              color: context.appColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
