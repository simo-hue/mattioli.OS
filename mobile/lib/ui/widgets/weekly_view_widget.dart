import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';

import '../../providers/goal_provider.dart';

const _kDays = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];
const _kMonths = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
  'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
];

class WeeklyViewWidget extends ConsumerStatefulWidget {
  const WeeklyViewWidget({super.key});

  @override
  ConsumerState<WeeklyViewWidget> createState() => _WeeklyViewWidgetState();
}

class _WeeklyViewWidgetState extends ConsumerState<WeeklyViewWidget> {
  late DateTime _currentWeekStart;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getStartOfWeek(DateTime.now());
  }

  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _goToPrev() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
    HapticFeedback.lightImpact();
  }

  void _goToNext() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    });
    HapticFeedback.lightImpact();
  }

  String _formatDateRange() {
    final end = _currentWeekStart.add(const Duration(days: 6));
    if (_currentWeekStart.month == end.month) {
      return '${_currentWeekStart.day} - ${end.day} ${_kMonths[_currentWeekStart.month - 1]}';
    }
    return '${_currentWeekStart.day} ${_kMonths[_currentWeekStart.month - 1].substring(0, 3)} - ${end.day} ${_kMonths[end.month - 1].substring(0, 3)}';
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    final isPrivacy = ref.watch(privacyModeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: AppTheme.glassPanelDecoration(radius: 14),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateRange(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                    letterSpacing: -0.5,
                  ),
                ),
                Row(
                  children: [
                    _NavButton(icon: Icons.chevron_left, onTap: _goToPrev),
                    const SizedBox(width: 8),
                    _NavButton(icon: Icons.chevron_right, onTap: _goToNext),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Days labels
          Row(
            children: List.generate(7, (index) {
              final dayDate = _currentWeekStart.add(Duration(days: index));
              final isToday = _dateKey(dayDate) == _dateKey(DateTime.now());

              return Expanded(
                child: Column(
                  children: [
                    Text(
                      _kDays[index],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isToday ? AppColors.mutedForeground : AppColors.mutedForeground.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: isToday
                          ? BoxDecoration(
                              color: AppColors.cardElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            )
                          : null,
                      child: Text(
                        '${dayDate.day}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                          color: isToday ? AppColors.foreground : AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Habit Stacks
          Column(
            children: [
              // We divide the habits into blocks to match the PWA look if needed, 
              // but for now let's just list them all.
              ...habits.asMap().entries.map((entry) {
                final habit = entry.value;

                return Column(
                  children: [
                    Row(
                      children: List.generate(7, (dayIdx) {
                        final dayDate = _currentWeekStart.add(Duration(days: dayIdx));
                        final dayKey = _dateKey(dayDate);
                        final status = logs[dayKey]?[habit.id];
                        final isFuture = dayDate.isAfter(DateTime.now());

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: _HabitCapsule(
                              color: habit.color,
                              status: status,
                              isFuture: isFuture,
                              isPrivacy: isPrivacy,
                              onTap: isFuture ? null : () {
                                ref.read(habitLogsProvider.notifier).toggle(dayDate, habit.id);
                                HapticFeedback.selectionClick();
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    // Optional spacing between groups
                    if (entry.key == 2 || entry.key == 6) const SizedBox(height: 12),
                  ],
                );
              })
            ],
          ),
        ],
      ),
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

class _HabitCapsule extends StatelessWidget {
  final Color color;
  final String? status;
  final bool isFuture;
  final bool isPrivacy;
  final VoidCallback? onTap;

  const _HabitCapsule({
    required this.color,
    this.status,
    required this.isFuture,
    required this.isPrivacy,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDone = status == 'done';
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 16,
        decoration: BoxDecoration(
          color: isDone 
              ? (isPrivacy ? AppColors.muted : color)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDone 
                ? (isPrivacy ? AppColors.border : color.withValues(alpha: 0.5))
                : AppColors.border.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: isDone && !isPrivacy
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: -1,
                  )
                ]
              : null,
        ),
      ),
    );
  }
}
