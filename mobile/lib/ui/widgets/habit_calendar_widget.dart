import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import 'day_details_modal.dart';
import '../../core/haptics.dart';

const _kDays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
const _kMonths = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
  'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
];

class HabitCalendarWidget extends ConsumerStatefulWidget {
  const HabitCalendarWidget({super.key});

  @override
  ConsumerState<HabitCalendarWidget> createState() =>
      _HabitCalendarWidgetState();
}

class _HabitCalendarWidgetState extends ConsumerState<HabitCalendarWidget> {
  late DateTime _currentDate;
  int _slideDirection = 1; // 1 for next, -1 for prev

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
  }

  String _dateKey(int year, int month, int day) =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  bool _isToday(int year, int month, int day) {
    final now = DateTime.now();
    return now.year == year && now.month == month && now.day == day;
  }

  bool _isFuture(int year, int month, int day) {
    final date = DateTime(year, month, day);
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return date.isAfter(todayStart);
  }

  bool _isYesterdayOrToday(int year, int month, int day) {
    final date = DateTime(year, month, day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    return date == today || date == yesterday;
  }

  void _goToPrev() {
    setState(() {
      _slideDirection = -1;
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
    });
    ref.hapticAction();
  }

  void _goToNext() {
    setState(() {
      _slideDirection = 1;
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
    });
    ref.hapticAction();
  }

  void _goToToday() {
    setState(() {
      _currentDate = DateTime.now();
    });
    ref.hapticAction();
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    final isPrivacy = ref.watch(privacyModeProvider);

    final year = _currentDate.year;
    final month = _currentDate.month;

    // First day of month, 0=Mon 6=Sun
    int startDayOfWeek = DateTime(year, month, 1).weekday - 1; // Mon=0
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final totalSlots = startDayOfWeek + daysInMonth;
    final numRows = (totalSlots / 7).ceil();

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
        decoration: AppTheme.glassPanelDecoration(radius: 14),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            final offset = animation.status == AnimationStatus.completed
                ? Offset.zero
                : Offset(0.1 * _slideDirection, 0);
            
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
            key: ValueKey('${_currentDate.year}-${_currentDate.month}'),
            children: [
              // Calendar header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Month + Year
                    GestureDetector(
                      onTap: _goToToday,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _kMonths[month - 1],
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.foreground,
                              letterSpacing: -0.8,
                            ),
                          ),
                          Text(
                            '$year',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.mutedForeground,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Navigation buttons
                    Row(
                      children: [
                        _NavButton(
                          icon: LucideIcons.chevronLeft,
                          onTap: _goToPrev,
                        ),
                        const SizedBox(width: 4),
                        _NavButton(
                          icon: LucideIcons.chevronRight,
                          onTap: _goToNext,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
    
              // Day labels row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: _kDays.map((d) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
    
              const SizedBox(height: 4),
    
              // Calendar grid - Now responsive
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: Column(
                    children: List.generate(numRows, (row) {
                      return Row(
                        children: List.generate(7, (col) {
                          final slot = row * 7 + col;
                          final day = slot - startDayOfWeek + 1;
    
                          if (day < 1 || day > daysInMonth) {
                            return Expanded(child: _EmptyCell(hasContent: false));
                          }
    
                          final dateKey = _dateKey(year, month, day);
                          final dayRecord = logs[dateKey] ?? {};
                          final future = _isFuture(year, month, day);
                          final today = _isToday(year, month, day);
                          final editableDay = _isYesterdayOrToday(year, month, day);
    
                          // Valid habits for this date
                          final validHabits = habits.where((h) {
                            return h.startDate.compareTo(dateKey) <= 0 &&
                                (h.endDate == null || h.endDate!.compareTo(dateKey) >= 0);
                          }).toList();
    
                          final totalHabits = validHabits.length;
                          final completedCount = validHabits
                              .where((h) => dayRecord[h.id] == 'done')
                              .length;
                          final missedCount = validHabits
                              .where((h) => dayRecord[h.id] == 'missed')
                              .length;
                          final hasActivity =
                              (completedCount + missedCount) > 0;
    
                          double completionPct = totalHabits > 0
                              ? completedCount / totalHabits
                              : 0.0;
    
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: _DayCell(
                                day: day,
                                isToday: today,
                                isFuture: future,
                                isEditableDay: editableDay,
                                hasActivity: hasActivity,
                                completionPct: completionPct,
                                validHabits: validHabits,
                                dayRecord: dayRecord,
                                isPrivacy: isPrivacy,
                                  onTap: future
                                      ? null
                                      : () => _showDayDetails(DateTime(year, month, day)),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

  }

  void _showDayDetails(DateTime date) {
    ref.hapticAction();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DayDetailsModal(date: date);
      },
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Icon(icon, size: 18, color: AppColors.foreground),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  final bool hasContent;
  const _EmptyCell({required this.hasContent});

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(aspectRatio: 0.85, child: SizedBox.shrink());
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool isFuture;
  final bool isEditableDay;
  final bool hasActivity;
  final double completionPct;
  final List<Goal> validHabits;
  final Map<String, String> dayRecord;
  final bool isPrivacy;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.isEditableDay,
    required this.hasActivity,
    required this.completionPct,
    required this.validHabits,
    required this.dayRecord,
    required this.isPrivacy,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Compute dynamic color from completion % (0=red hue 0°, 1=green hue 142°)
    Color? bgColor;
    Color borderColor = AppColors.borderSubtle;

    if (hasActivity) {
      final hue = completionPct * 142.0; // 0..142
      bgColor = HSLColor.fromAHSL(1.0, hue, 0.7, 0.1)
          .toColor()
          .withValues(alpha: 0.3);
      borderColor =
          HSLColor.fromAHSL(1.0, hue, 0.8, 0.4).toColor().withValues(alpha: 0.5);
    }

    if (isEditableDay && !hasActivity) {
      bgColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.04);
      borderColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.25);
    }

    if (isToday && !hasActivity) {
      bgColor = Colors.white.withValues(alpha: 0.04);
      borderColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.4);
    }

    if (isFuture) {
      bgColor = null;
      borderColor = Colors.transparent;
    }

    final dotsToShow = validHabits
        .where((h) => dayRecord[h.id] == 'done')
        .take(8)
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isFuture ? 0.28 : 1.0,
        child: AspectRatio(
          aspectRatio: 0.85,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: hasActivity && completionPct == 1.0
                  ? [
                      BoxShadow(
                        color: HSLColor.fromAHSL(1.0, 142, 0.8, 0.4)
                            .toColor()
                            .withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 0,
                      )
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                // Day number
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday
                        ? Theme.of(context).colorScheme.primary
                        : hasActivity
                            ? AppColors.foreground
                            : AppColors.mutedForeground,
                  ),
                  child: Text(
                    '$day',
                    style: isPrivacy
                        ? const TextStyle(color: Colors.transparent)
                        : null,
                  ),
                ),

                const SizedBox(height: 2),

                // Habit dots
                if (dotsToShow.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 2,
                      runSpacing: 2,
                      children: dotsToShow.map((h) {
                        return Opacity(
                          opacity: isPrivacy ? 0.2 : 1.0,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: h.color,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

