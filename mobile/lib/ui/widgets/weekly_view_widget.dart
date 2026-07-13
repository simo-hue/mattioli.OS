import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../providers/goal_provider.dart';
import '../../models/goal.dart';
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
  int _slideDirection = 1;

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

  List<double> _calculateDailyCompletion(List<Goal> habits, Map<String, dynamic> logs) {
    List<double> completion = List.filled(7, 0.0);
    
    for (int i = 0; i < 7; i++) {
      final dayDate = _currentWeekStart.add(Duration(days: i));
      if (dayDate.isAfter(DateTime.now())) {
        completion[i] = -1.0; 
        continue;
      }
      
      final dayKey = _dateKey(dayDate);
      int activeCount = 0;
      int doneCount = 0;
      
      for (final habit in habits) {
        if (habit.isActiveOn(dayDate)) {
          activeCount++;
          if (logs[dayKey]?[habit.id] == 'done') {
            doneCount++;
          }
        }
      }
      
      if (activeCount == 0) {
        completion[i] = 0.0;
      } else {
        completion[i] = (doneCount / activeCount) * 100;
      }
    }
    return completion;
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    final isPrivacy = ref.watch(privacyModeProvider);
    
    final completionData = _calculateDailyCompletion(habits, logs);

    // Compute summary
    double bestPercent = -1.0;
    int bestIndex = -1;
    double worstPercent = 101.0;
    int worstIndex = -1;
    double totalPercent = 0.0;
    int pastDaysCount = 0;

    for (int i = 0; i < 7; i++) {
      if (completionData[i] >= 0) {
        pastDaysCount++;
        totalPercent += completionData[i];
        if (completionData[i] > bestPercent) {
          bestPercent = completionData[i];
          bestIndex = i;
        }
        if (completionData[i] < worstPercent) {
          worstPercent = completionData[i];
          worstIndex = i;
        }
      }
    }

    String summaryText = "";
    if (isPrivacy) {
      summaryText = "Privacy Mode";
    } else if (pastDaysCount > 0) {
      final bestDayName = DateFormat.E(LocaleSettings.currentLocale.languageCode)
          .format(_currentWeekStart.add(Duration(days: bestIndex)))
          .toUpperCase();
      final worstDayName = DateFormat.E(LocaleSettings.currentLocale.languageCode)
          .format(_currentWeekStart.add(Duration(days: worstIndex)))
          .toUpperCase();
      final avgPercent = (totalPercent / pastDaysCount).round();
      summaryText = "Best: $bestDayName ${bestPercent.round()}%  •  Worst: $worstDayName ${worstPercent.round()}%  •  Avg: $avgPercent%";
    } else {
      summaryText = "No data for this week yet";
    }

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
            final isIncoming = child.key == ValueKey(_dateKey(_currentWeekStart));
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final double rotation = isIncoming
                    ? (1.0 - animation.value) * (math.pi / 2) * _slideDirection
                    : animation.value * -(math.pi / 2) * _slideDirection;
                final alignment = isIncoming
                    ? (_slideDirection > 0 ? Alignment.centerRight : Alignment.centerLeft)
                    : (_slideDirection > 0 ? Alignment.centerLeft : Alignment.centerRight);

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
              
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: RadarChart(
                    RadarChartData(
                      dataSets: [
                        RadarDataSet(
                          fillColor: isPrivacy 
                              ? context.appColors.mutedForeground.withValues(alpha: 0.2) 
                              : context.appColors.primary.withValues(alpha: 0.2),
                          borderColor: isPrivacy 
                              ? context.appColors.mutedForeground 
                              : context.appColors.primary.withValues(alpha: 0.8),
                          entryRadius: 4,
                          dataEntries: completionData.map((val) => RadarEntry(value: val < 0 ? 0 : val)).toList(),
                          borderWidth: 2,
                        ),
                      ],
                      radarBackgroundColor: Colors.transparent,
                      borderData: FlBorderData(show: false),
                      radarBorderData: const BorderSide(color: Colors.transparent),
                      titlePositionPercentageOffset: 0.15,
                      titleTextStyle: TextStyle(color: context.appColors.mutedForeground, fontSize: 12),
                      getTitle: (index, angle) {
                        final dayDate = _currentWeekStart.add(Duration(days: index));
                        return RadarChartTitle(
                          text: DateFormat.E(LocaleSettings.currentLocale.languageCode).format(dayDate).toUpperCase(),
                          angle: 0,
                        );
                      },
                      tickCount: 4,
                      ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 10),
                      tickBorderData: BorderSide(color: context.appColors.border.withValues(alpha: 0.5), width: 1),
                      gridBorderData: BorderSide(color: context.appColors.border.withValues(alpha: 0.5), width: 1),
                      radarShape: RadarShape.polygon,
                      radarTouchData: RadarTouchData(
                        touchCallback: (FlTouchEvent event, RadarTouchResponse? response) {
                          if (!event.isInterestedForInteractions || response == null || response.touchedSpot == null) {
                            return;
                          }
                          if (event is FlTapUpEvent) {
                            final index = response.touchedSpot!.touchedRadarEntryIndex;
                            final dayDate = _currentWeekStart.add(Duration(days: index));
                            if (!dayDate.isAfter(DateTime.now())) {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => DayDetailsModal(date: dayDate),
                              );
                              ref.hapticAction();
                            }
                          }
                        },
                      ),
                    ),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              // Summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  summaryText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPrivacy ? Colors.transparent : context.appColors.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
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
