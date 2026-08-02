import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/performance_color.dart';
import '../../core/verification_wiring.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import 'day_details_modal.dart';
import '../../core/haptics.dart';
import '../../core/l10n_dynamic.dart';
import '../../core/rtl.dart';
import '../../i18n/translations.g.dart';
import '../../core/calendar_days.dart';

// Keys for localization
const _kDayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

class HabitCalendarWidget extends ConsumerStatefulWidget {
  const HabitCalendarWidget({super.key});

  @override
  ConsumerState<HabitCalendarWidget> createState() =>
      _HabitCalendarWidgetState();
}

class _HabitCalendarWidgetState extends ConsumerState<HabitCalendarWidget> {
  late PageController _pageController;
  static const int _basePage = 1200;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _basePage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
    final yesterday = shiftDays(today, -1);
    return date == today || date == yesterday;
  }

  void _goToPrev() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    ref.hapticAction();
  }

  void _goToNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    ref.hapticAction();
  }

  void _goToToday() {
    _pageController.animateToPage(
      _basePage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuart,
    );
    ref.hapticAction();
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    final isPrivacy = ref.watch(privacyModeProvider);
    final couldNotVerifyByGoal =
        ref.watch(couldNotVerifyDaysProvider).asData?.value ?? const {};

    return Container(
      decoration: AppTheme.glassPanelDecoration(context, radius: 14),
      child: PageView.builder(
        controller: _pageController,
        itemBuilder: (context, index) {
          final targetDate = DateTime(
            DateTime.now().year,
            DateTime.now().month + (index - _basePage),
            1,
          );
          
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double pageOffset = 0.0;
              if (_pageController.position.haveDimensions) {
                pageOffset = _pageController.page! - index;
              } else {
                pageOffset = (_basePage - index).toDouble();
              }
              
              final absOffset = pageOffset.abs();
              
              // Premium Parallax & Scale Effect
              final double scale = 1.0 - (absOffset * 0.05).clamp(0.0, 0.05);
              final double opacity = (1.0 - absOffset).clamp(0.0, 1.0);
              final double translation = pageOffset * 60; 
              
              return Transform.scale(
                scale: scale,
                child: Transform.translate(
                  offset: Offset(translation, 0),
                  child: Opacity(
                    opacity: opacity,
                    child: child,
                  ),
                ),
              );
            },
            child: _buildCalendarPage(
                targetDate, habits, logs, isPrivacy, couldNotVerifyByGoal),
          );
        },
      ),
    );
  }

  Widget _buildCalendarPage(DateTime date, List<Goal> habits, Map logs,
      bool isPrivacy, Map<String, Set<DateTime>> couldNotVerifyByGoal) {
    final year = date.year;
    final month = date.month;

    // First day of month, 0=Mon 6=Sun
    final int startDayOfWeek = DateTime(year, month, 1).weekday - 1; // Mon=0
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final totalSlots = startDayOfWeek + daysInMonth;
    final numRows = (totalSlots / 7).ceil();

    return Column(
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
                      context.t.common.months[month - 1],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.appColors.foreground,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Text(
                      '$year',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.appColors.mutedForeground,
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
                    icon: directionalIcon(
                      context,
                      LucideIcons.chevronLeft,
                      LucideIcons.chevronRight,
                    ),
                    onTap: _goToPrev,
                  ),
                  const SizedBox(width: 4),
                  _NavButton(
                    icon: directionalIcon(
                      context,
                      LucideIcons.chevronRight,
                      LucideIcons.chevronLeft,
                    ),
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
            children: _kDayKeys.map((key) {
              return Expanded(
                child: Center(
                  child: Text(
                    tWeekdayShort(context, key),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.mutedForeground,
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
                      return const Expanded(child: _EmptyCell(hasContent: false));
                    }

                    final dateKey = _dateKey(year, month, day);
                    final dayRecord = Map<String, String>.from(logs[dateKey] ?? {});
                    final future = _isFuture(year, month, day);
                    final today = _isToday(year, month, day);
                    final editableDay = _isYesterdayOrToday(year, month, day);

                    // Valid habits for this date
                    final dayDate = DateTime(year, month, day);
                    final validHabits = habits.where((h) => h.isScheduledOn(dayDate)).toList();

                    final totalHabits = validHabits.length;
                    final completedCount = validHabits
                        .where((h) => dayRecord[h.id] == 'done')
                        .length;
                    final missedCount = validHabits
                        .where((h) => dayRecord[h.id] == 'missed')
                        .length;
                    final hasActivity =
                        (completedCount + missedCount) > 0;

                    final double completionPct = totalHabits > 0
                        ? completedCount / totalHabits
                        : 0.0;

                    // Any auto-verified habit this day still unresolved (no
                    // terminal status + a couldn't-verify marker).
                    final couldNotVerify = !future &&
                        validHabits.any((h) =>
                            dayRecord[h.id] == null &&
                            (couldNotVerifyByGoal[h.id]?.contains(dayDate) ??
                                false));

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
                          isPrivacy: isPrivacy,
                          couldNotVerify: couldNotVerify,
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
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appColors.border, width: 1),
        ),
        child: Icon(icon, size: 18, color: context.appColors.foreground),
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
  final bool isPrivacy;
  final bool couldNotVerify;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.isEditableDay,
    required this.hasActivity,
    required this.completionPct,
    required this.isPrivacy,
    this.couldNotVerify = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color borderColor = Colors.transparent;

    if (hasActivity) {
      // Same red→green scale as the yearly bars via the shared helper. Tuned
      // for a faint tinted cell background (unchanged from before).
      bgColor = performanceColor(
        completionPct,
        saturation: 0.7,
        lightness: 0.1,
        alpha: 0.3,
      );
      borderColor = performanceColor(
        completionPct,
        saturation: 0.8,
        lightness: 0.4,
        alpha: 0.5,
      );
    }

    if (isEditableDay && !hasActivity) {
      bgColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.04);
      borderColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.25);
    }

    if (isToday && !hasActivity) {
      bgColor = context.appColors.foreground.withValues(alpha: 0.04);
      borderColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.4);
    }

    if (isFuture) {
      bgColor = null;
      borderColor = Colors.transparent;
    }

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
                        color: const HSLColor.fromAHSL(1.0, 142, 0.8, 0.4)
                            .toColor()
                            .withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 0,
                      )
                    ]
                  : null,
            ),
            // A single centered day number over the performance-colored cell —
            // the per-habit "dots" were removed (redundant with the color and
            // visually noisy). A corner "?" flags an unresolved auto-verification.
            child: Stack(
              children: [
                Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday
                          ? Theme.of(context).colorScheme.primary
                          : hasActivity
                              ? context.appColors.foreground
                              : context.appColors.mutedForeground,
                    ),
                    child: Text(
                      '$day',
                      style: isPrivacy
                          ? const TextStyle(color: Colors.transparent)
                          : null,
                    ),
                  ),
                ),
                if (couldNotVerify && !isPrivacy)
                  PositionedDirectional(
                    top: 3,
                    end: 3,
                    child: Container(
                      width: 12,
                      height: 12,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.appColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        '?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 8,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
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

