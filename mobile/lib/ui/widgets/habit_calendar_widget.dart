import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';

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
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
    });
  }

  void _goToNext() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      _currentDate = DateTime.now();
    });
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

    return Container(
      decoration: AppTheme.glassPanelDecoration(radius: 14),
      child: Column(
        children: [
          // Calendar header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Prev button
                _NavButton(
                  icon: Icons.chevron_left,
                  onTap: _goToPrev,
                ),
                // Month + Year + Today button
                GestureDetector(
                  onTap: _goToToday,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${_kMonths[month - 1]} ',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                            letterSpacing: -0.3,
                          ),
                        ),
                        TextSpan(
                          text: '$year',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: AppColors.mutedForeground,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _NavButton(
                  icon: Icons.chevron_right,
                  onTap: _goToNext,
                ),
              ],
            ),
          ),

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
    );
  }

  void _showDayDetails(DateTime date) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _DayDetailsModal(date: date);
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppColors.mutedForeground),
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
      bgColor = AppColors.primary.withValues(alpha: 0.04);
      borderColor = AppColors.primary.withValues(alpha: 0.25);
    }

    if (isToday && !hasActivity) {
      bgColor = Colors.white.withValues(alpha: 0.04);
      borderColor = AppColors.primary.withValues(alpha: 0.4);
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
                        ? AppColors.primary
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

class _DayDetailsModal extends ConsumerWidget {
  final DateTime date;

  const _DayDetailsModal({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final dayRecord = logs[dateKey] ?? {};

    // Filter habits active on this date
    final activeHabits = habits.where((h) {
      return h.startDate.compareTo(dateKey) <= 0 &&
          (h.endDate == null || h.endDate!.compareTo(dateKey) >= 0);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${date.day} ${_kMonths[date.month - 1]}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'I tuoi progressi per oggi',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.mutedForeground),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: activeHabits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final habit = activeHabits[index];
                final status = dayRecord[habit.id];

                return _GoalLogCard(
                  habit: habit,
                  status: status,
                  onTap: () {
                    ref
                        .read(habitLogsProvider.notifier)
                        .cycleStatus(date, habit.id);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _GoalLogCard extends StatelessWidget {
  final Goal habit;
  final String? status; // 'done', 'missed', or null
  final VoidCallback onTap;

  const _GoalLogCard({
    required this.habit,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color cardColor = AppColors.card;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.foreground;
    Color iconBgColor = AppColors.muted;
    IconData icon = LucideIcons.circle;
    Color iconColor = AppColors.mutedForeground;
    bool hasStrikethrough = false;
    
    // Mock streak
    final int mockStreak = 7 - (habit.id.hashCode % 5);

    if (status == 'done') {
      cardColor = const Color(0xFF064E3B).withValues(alpha: 0.2); // Very dark green
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
      textColor = const Color(0xFF10B981);
      iconBgColor = const Color(0xFF064E3B).withValues(alpha: 0.4);
      iconColor = const Color(0xFF10B981);
      icon = LucideIcons.check;
    } else if (status == 'missed') {
      cardColor = const Color(0xFF450A0A).withValues(alpha: 0.2); // Very dark red
      borderColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
      textColor = AppColors.mutedForeground;
      iconBgColor = const Color(0xFF450A0A).withValues(alpha: 0.4);
      iconColor = const Color(0xFFEF4444);
      icon = LucideIcons.x;
      hasStrikethrough = true;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                habit.title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  decoration: hasStrikethrough ? TextDecoration.lineThrough : null,
                  decorationColor: const Color(0xFFEF4444).withValues(alpha: 0.5),
                  decorationThickness: 2,
                ),
              ),
            ),
            _StreakBadge(
              streak: mockStreak,
              isMissed: status == 'missed',
              isDone: status == 'done',
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  final bool isMissed;
  final bool isDone;

  const _StreakBadge({
    required this.streak,
    this.isMissed = false,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppColors.muted;
    Color textColor = AppColors.mutedForeground;
    IconData icon = LucideIcons.flame;
    Color iconColor = const Color(0xFFF97316); // Orange

    if (isMissed) {
      bgColor = const Color(0xFF450A0A).withValues(alpha: 0.5);
      textColor = const Color(0xFFEF4444);
      icon = LucideIcons.heartCrack;
      iconColor = const Color(0xFFEF4444);
    } else if (isDone) {
      bgColor = const Color(0xFF064E3B).withValues(alpha: 0.5);
      textColor = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
