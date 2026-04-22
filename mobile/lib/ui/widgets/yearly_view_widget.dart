import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/goal_provider.dart';

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

  void _goToPrev() {
    setState(() => _currentYear--);
    HapticFeedback.lightImpact();
  }

  void _goToNext() {
    setState(() => _currentYear++);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: AppTheme.glassPanelDecoration(radius: 14),
      child: Column(
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

          // Grid of months - Now responsive
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                return _MonthDensityWidget(
                  year: _currentYear,
                  month: index + 1,
                  label: _kMonthShort[index],
                );
              },
            ),
          ),
        ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(31, (dayIdx) {
                  final day = dayIdx + 1;
                  if (day > daysInMonth) {
                    return const SizedBox(width: 2);
                  }

                  final dateKey = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  final dayLogs = logs[dateKey] ?? {};
                  final isFuture = DateTime(year, month, day).isAfter(now);

                  // Calculate completion density
                  double completionPct = 0;
                  if (habits.isNotEmpty) {
                    final validHabits = habits.where((h) {
                      return h.startDate.compareTo(dateKey) <= 0 &&
                          (h.endDate == null || h.endDate!.compareTo(dateKey) >= 0);
                    }).toList();
                    
                    if (validHabits.isNotEmpty) {
                      final doneCount = validHabits.where((h) => dayLogs[h.id] == 'done').length;
                      completionPct = doneCount / validHabits.length;
                    }
                  }

                  Color barColor = AppColors.border.withValues(alpha: 0.3);
                  if (!isFuture) {
                    if (completionPct > 0) {
                      final hue = completionPct * 142.0;
                      barColor = HSLColor.fromAHSL(1.0, hue, 0.8, 0.5).toColor();
                    } else {
                      barColor = AppColors.border;
                    }
                  } else {
                     barColor = Colors.white.withValues(alpha: 0.05);
                  }

                  return Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
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
