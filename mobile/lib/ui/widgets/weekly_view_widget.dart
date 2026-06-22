import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../providers/goal_provider.dart';
import 'day_details_modal.dart';
import '../../core/haptics.dart';
import '../../i18n/translations.g.dart';

class WeeklyViewWidget extends ConsumerStatefulWidget {
  const WeeklyViewWidget({super.key});

  @override
  ConsumerState<WeeklyViewWidget> createState() => _WeeklyViewWidgetState();
}

class _WeeklyViewWidgetState extends ConsumerState<WeeklyViewWidget> {
  late DateTime _currentWeekStart;
  int _slideDirection = 1; // 1 for next, -1 for prev

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
      _slideDirection = -1;
      _currentWeekStart = _currentWeekStart.subtract(const Duration(days: 7));
    });
    ref.hapticAction();
  }

  void _goToNext() {
    setState(() {
      _slideDirection = 1;
      _currentWeekStart = _currentWeekStart.add(const Duration(days: 7));
    });
    ref.hapticAction();
  }

  String _formatDateRange(BuildContext context) {
    final end = _currentWeekStart.add(const Duration(days: 6));
    final fullMonthFormatter = DateFormat.MMMM(LocaleSettings.currentLocale.languageCode);
    final shortMonthFormatter = DateFormat.MMM(LocaleSettings.currentLocale.languageCode);
    if (_currentWeekStart.month == end.month) {
      return '${_currentWeekStart.day} - ${end.day} ${fullMonthFormatter.format(_currentWeekStart)}';
    }
    return '${_currentWeekStart.day} ${shortMonthFormatter.format(_currentWeekStart)} - ${end.day} ${shortMonthFormatter.format(end)}';
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    final isPrivacy = ref.watch(privacyModeProvider);

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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: AppTheme.glassPanelDecoration(context, radius: 14),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutQuart,
          switchOutCurve: Curves.easeOutQuart,
          transitionBuilder: (child, animation) {
            final isIncoming =
                child.key == ValueKey(_dateKey(_currentWeekStart));

            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                // Perspective Fold Logic (3D Flip)
                final double rotation = isIncoming
                    ? (1.0 - animation.value) * (math.pi / 2) * _slideDirection
                    : animation.value * -(math.pi / 2) * _slideDirection;

                final alignment = isIncoming
                    ? (_slideDirection > 0
                          ? Alignment.centerRight
                          : Alignment.centerLeft)
                    : (_slideDirection > 0
                          ? Alignment.centerLeft
                          : Alignment.centerRight);

                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateY(rotation),
                  alignment: alignment,
                  child: Opacity(
                    opacity: animation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
          child: Column(
            key: ValueKey(_dateKey(_currentWeekStart)),
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDateRange(context),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.foreground,
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
                          DateFormat.E(
                            LocaleSettings.currentLocale.languageCode,
                          ).format(dayDate).toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isToday
                                ? context.appColors.mutedForeground
                                : context.appColors.mutedForeground.withValues(
                                    alpha: 0.5,
                                  ),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          decoration: isToday
                              ? BoxDecoration(
                                  color: context.appColors.card,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: context.appColors.border,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                )
                              : null,
                          child: Text(
                            '${dayDate.day}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: isToday
                                  ? context.appColors.foreground
                                  : context.appColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Habit Stacks - Scrollable if too many
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      ...habits.asMap().entries.map((entry) {
                        final habit = entry.value;

                        return Column(
                          children: [
                            Row(
                              children: List.generate(7, (dayIdx) {
                                final dayDate = _currentWeekStart.add(
                                  Duration(days: dayIdx),
                                );
                                final dayKey = _dateKey(dayDate);
                                final status = logs[dayKey]?[habit.id];
                                final isFuture = dayDate.isAfter(
                                  DateTime.now(),
                                );
                                final isActive = habit.isActiveOn(dayDate);

                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    child: Opacity(
                                      opacity: isActive ? 1.0 : 0.0,
                                      child: _HabitCapsule(
                                        status: status,
                                        isFuture: isFuture,
                                        isPrivacy: isPrivacy,
                                        onTap: (isFuture || !isActive)
                                            ? null
                                            : () {
                                                showModalBottomSheet(
                                                  context: context,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  isScrollControlled: true,
                                                  builder: (context) =>
                                                      DayDetailsModal(
                                                        date: dayDate,
                                                      ),
                                                );
                                                ref.hapticAction();
                                              },
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            // Optional spacing between groups
                            if (entry.key == 2 || entry.key == 6)
                              const SizedBox(height: 12),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
        child: Icon(icon, size: 20, color: context.appColors.foreground),
      ),
    );
  }
}

class _HabitCapsule extends StatelessWidget {
  final String? status;
  final bool isFuture;
  final bool isPrivacy;
  final VoidCallback? onTap;

  const _HabitCapsule({
    this.status,
    required this.isFuture,
    required this.isPrivacy,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDone = status == 'done';
    final bool isMissed = status == 'missed';

    Color capsuleColor = Colors.transparent;
    Color borderColor = context.appColors.border.withValues(alpha: 0.5);
    List<BoxShadow>? shadows;

    if (isDone) {
      capsuleColor = isPrivacy
          ? context.appColors.mutedForeground.withValues(alpha: 0.2)
          : context.appColors.primary;
      borderColor = isPrivacy
          ? context.appColors.border
          : context.appColors.primary.withValues(alpha: 0.5);
      if (!isPrivacy) {
        shadows = [
          BoxShadow(
            color: context.appColors.primary.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ];
      }
    } else if (isMissed) {
      capsuleColor = context.appColors.destructive.withValues(alpha: 0.2);
      borderColor = context.appColors.destructive.withValues(alpha: 0.5);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 16,
        decoration: BoxDecoration(
          color: capsuleColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: shadows,
        ),
      ),
    );
  }
}
