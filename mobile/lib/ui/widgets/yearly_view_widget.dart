import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/goal_provider.dart';
import '../../core/haptics.dart';

const _kMonthShort = [
  'GEN', 'FEB', 'MAR', 'APR', 'MAG', 'GIU',
  'LUG', 'AGO', 'SET', 'OTT', 'NOV', 'DIC',
];

class YearlyViewWidget extends ConsumerStatefulWidget {
  const YearlyViewWidget({super.key});

  @override
  ConsumerState<YearlyViewWidget> createState() => _YearlyViewWidgetState();
}

class _YearlyViewWidgetState extends ConsumerState<YearlyViewWidget> {
  int _currentYear = DateTime.now().year;
  int _slideDirection = 1; // 1 for next, -1 for prev

  void _goToPrev() {
    setState(() {
      _slideDirection = -1;
      _currentYear--;
    });
    HapticFeedback.lightImpact();
  }

  void _goToNext() {
    setState(() {
      _slideDirection = 1;
      _currentYear++;
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        const threshold = 200;
        if (details.primaryVelocity! > threshold) {
          _goToPrev();
        } else if (details.primaryVelocity! < -threshold) {
          _goToNext();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: AppTheme.glassPanelDecoration(radius: 14),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0.1 * _slideDirection, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Column(
            key: ValueKey('$_currentYear'),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavButton(icon: Icons.chevron_left, onTap: _goToPrev),
                  Text(
                    '$_currentYear',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _NavButton(icon: Icons.chevron_right, onTap: _goToNext),
                ],
              ),
              const SizedBox(height: 20),
    
              // Grid of months - Now perfectly responsive to fit 6 rows
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const double crossAxisSpacing = 16;
                    const double mainAxisSpacing = 16;
                    final double cellWidth = (constraints.maxWidth - crossAxisSpacing) / 2;
                    final double cellHeight = (constraints.maxHeight - (mainAxisSpacing * 5)) / 6;
                    final double aspectRatio = cellWidth / cellHeight;
    
                    return GridView.builder(
                      physics: const NeverScrollableScrollPhysics(), // Fits perfectly, no scroll needed
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: crossAxisSpacing,
                        mainAxisSpacing: mainAxisSpacing,
                        childAspectRatio: aspectRatio > 0 ? aspectRatio : 2.2,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        return _MonthDensityWidget(
                          year: _currentYear,
                          month: index + 1,
                          label: _kMonthShort[index],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

  }
}

class _MonthDensityWidget extends ConsumerWidget {
  final int year;
  final int month;
  final String label;

  const _MonthDensityWidget({
    required this.year,
    required this.month,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final now = DateTime.now();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 34,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: RepaintBoundary(
            child: CustomPaint(
              size: const Size(double.infinity, 32),
              painter: _MonthBarsPainter(
                year: year,
                month: month,
                daysInMonth: daysInMonth,
                habits: habits,
                logs: logs,
                now: now,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthBarsPainter extends CustomPainter {
  final int year;
  final int month;
  final int daysInMonth;
  final List<dynamic> habits;
  final Map<String, dynamic> logs;
  final DateTime now;

  _MonthBarsPainter({
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.habits,
    required this.logs,
    required this.now,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double barSpacing = 1.5;
    final double totalSpacing = barSpacing * 30;
    final double barWidth = (size.width - totalSpacing) / 31;
    
    final Paint futurePaint = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final Paint emptyPaint = Paint()..color = AppColors.border.withValues(alpha: 0.2);

    for (int dayIdx = 0; dayIdx < 31; dayIdx++) {
      final day = dayIdx + 1;
      if (day > daysInMonth) break;

      final double x = dayIdx * (barWidth + barSpacing);
      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, size.height),
        const Radius.circular(1),
      );

      final dateKey = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final isFuture = DateTime(year, month, day).isAfter(now);

      if (isFuture) {
        canvas.drawRRect(rect, futurePaint);
        continue;
      }

      final dayLogs = logs[dateKey] ?? {};
      double completionPct = 0;

      if (habits.isNotEmpty) {
        final validHabits = habits.where((h) {
          // Simplified check for painter
          return true; 
        }).toList();
        
        if (validHabits.isNotEmpty) {
          final doneCount = validHabits.where((h) => dayLogs[h.id] == 'done').length;
          completionPct = doneCount / validHabits.length;
        }
      }

      if (completionPct > 0) {
        final hue = completionPct * 140.0; // Greenish
        final Paint barPaint = Paint()
          ..color = HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
        canvas.drawRRect(rect, barPaint);
      } else {
        canvas.drawRRect(rect, emptyPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MonthBarsPainter oldDelegate) {
    return oldDelegate.year != year || 
           oldDelegate.month != month || 
           oldDelegate.logs != logs;
  }
}


class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 20, color: AppColors.foreground),
      ),
    );
  }
}
