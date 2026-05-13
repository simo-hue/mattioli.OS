import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/localization.dart';
import '../../../providers/goal_provider.dart';
import '../../../models/goal.dart';

class GlobalHabitsTabWidget extends ConsumerStatefulWidget {
  const GlobalHabitsTabWidget({super.key});

  @override
  ConsumerState<GlobalHabitsTabWidget> createState() => _GlobalHabitsTabWidgetState();
}

class _GlobalHabitsTabWidgetState extends ConsumerState<GlobalHabitsTabWidget> {
  String _sortBy = 'rate';

  List<Map<String, dynamic>> _calculateHabits(List<Goal> goals, HabitLogsMap logs) {
    return goals.map((goal) => _calculateHabitStats(goal, logs)).toList();
  }

  List<Map<String, dynamic>> _getSortedHabits(List<Map<String, dynamic>> habits) {
    final sorted = List<Map<String, dynamic>>.from(habits);
    sorted.sort((a, b) {
      switch (_sortBy) {
        case 'rate':
          return (b['rate'] as int).compareTo(a['rate'] as int);
        case 'best_streak_label':
          return (b['best'] as int).compareTo(a['best'] as int);
        case 'worst_streak_label':
          return (b['worst'] as int).compareTo(a['worst'] as int);
        case 'current_streak_label':
          return (b['serie'] as int).compareTo(a['serie'] as int);
        case 'first_name':
          return (a['name'] as String).compareTo(b['name'] as String);
        default:
          return 0;
      }
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    final habits = _calculateHabits(goals, logs);
    final sortedHabits = _getSortedHabits(habits);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.translate('Dettagli Abitudini'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
              ),
            ),
            _buildSortDropdown(),
          ],
        ),
        const SizedBox(height: 20),
        sortedHabits.isEmpty
          ? Center(child: Text(context.l10n.translate('Nessuna abitudine trovata'), style: TextStyle(color: context.appColors.mutedForeground)))
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedHabits.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _HabitDetailCard(habit: sortedHabits[index]);
              },
            ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSortDropdown() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showSortPicker();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.appColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.appColors.foreground.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getSortIcon(_sortBy), size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate(_sortBy).replaceAll('_', ' '),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appColors.foreground,
              ),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronDown, size: 12, color: context.appColors.mutedForeground.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  void _showSortPicker() {
    final options = [
      (val: 'rate', icon: LucideIcons.trendingUp),
      (val: 'best_streak_label', icon: LucideIcons.trophy),
      (val: 'worst_streak_label', icon: LucideIcons.trendingDown),
      (val: 'current_streak_label', icon: LucideIcons.flame),
      (val: 'first_name', icon: LucideIcons.list),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  context.l10n.translate('Ordina per'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.mutedForeground,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),

            ...options.map((opt) {
              final isSel = _sortBy == opt.val;
              final primaryColor = Theme.of(context).colorScheme.primary;
              return ListTile(
                leading: Icon(
                  opt.icon, 
                  size: 20, 
                  color: isSel ? primaryColor : context.appColors.mutedForeground.withValues(alpha: 0.6)
                ),
                title: Text(
                  context.l10n.translate(opt.val).replaceAll('_', ' '),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? context.appColors.foreground : context.appColors.mutedForeground,
                  ),
                ),
                trailing: isSel ? Icon(LucideIcons.check, color: primaryColor, size: 20) : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _sortBy = opt.val);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }


  IconData _getSortIcon(String sort) {
    switch (sort) {
      case 'rate': return LucideIcons.trendingUp;
      case 'best_streak_label': return LucideIcons.trophy;
      case 'worst_streak_label': return LucideIcons.trendingDown;
      case 'current_streak_label': return LucideIcons.flame;
      case 'first_name': return LucideIcons.list;
      default: return LucideIcons.trendingUp;
    }
  }

}

class _HabitDetailCard extends StatelessWidget {
  final Map<String, dynamic> habit;

  const _HabitDetailCard({required this.habit});

  @override
  Widget build(BuildContext context) {
    final Color habitColor = habit['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Row(
        children: [
          // Habit Icon/Dot
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.appColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.appColors.border, width: 1),
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: habitColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: habitColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name and small progress bar
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit['name'] as String,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.foreground,
                  ),
                ),

                const SizedBox(height: 6),
                Container(
                  width: 60,
                  height: 3,
                  decoration: BoxDecoration(
                    color: context.appColors.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (habit['rate'] as int) / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: habitColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Stats
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatColumn(context, 'BEST', '${habit['best']}gg', icon: LucideIcons.trophy, iconColor: const Color(0xFFEAB308)),
                _buildStatColumn(context, 'WORST', '${habit['worst']}gg', icon: LucideIcons.trendingDown, iconColor: const Color(0xFFEF4444)),
                _buildStatColumn(context, 'SERIE', '${habit['serie']}gg'),
                _buildStatColumn(context, 'RATE', '${habit['rate']}%', isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String label, String value, {IconData? icon, Color? iconColor, bool isBold = false}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 10, color: iconColor ?? context.appColors.mutedForeground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: context.appColors.mutedForeground,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: label == 'WORST' ? const Color(0xFFEF4444) : context.appColors.foreground,
          ),
        ),
      ],
    );
  }
}

Map<String, dynamic> _calculateHabitStats(Goal goal, HabitLogsMap logs) {
  final goalLogs = <DateTime, String>{};
  logs.forEach((dateStr, habits) {
    if (habits.containsKey(goal.id)) {
      final date = DateTime.parse(dateStr);
      goalLogs[DateTime(date.year, date.month, date.day)] = habits[goal.id]!;
    }
  });

  if (goalLogs.isEmpty) {
    return {
      'name': goal.title,
      'color': goal.color,
      'best': 0,
      'worst': 0,
      'serie': 0,
      'rate': 0,
    };
  }

  final sortedDates = goalLogs.keys.toList()..sort();
  
  int currentStreak = 0;
  int bestStreak = 0;
  int worstStreak = 0;
  int tempStreak = 0;
  int tempMissedStreak = 0;
  int completedDays = 0;

  final today = DateTime.now();
  final todayNormalized = DateTime(today.year, today.month, today.day);
  final startDate = goal.startDate;
  final daysSinceStart = todayNormalized.difference(DateTime(startDate.year, startDate.month, startDate.day)).inDays + 1;

  goalLogs.forEach((date, status) {
    if (status == 'done') {
      completedDays++;
    }
  });

  final isDaily = goal.frequencyDays == null || goal.frequencyDays!.isEmpty;

  DateTime? prevDate;
  for (final date in sortedDates) {
    final status = goalLogs[date];
    if (status == 'done') {
      if (prevDate == null) {
        tempStreak = 1;
      } else {
        final diff = date.difference(prevDate).inDays;
        if (isDaily) {
          if (diff == 1) {
            tempStreak++;
          } else {
            tempStreak = 1;
          }
        } else {
          bool broken = false;
          for (int i = 1; i < diff; i++) {
            final checkDate = prevDate.add(Duration(days: i));
            if (goal.frequencyDays!.contains(checkDate.weekday)) {
              broken = true;
              break;
            }
          }
          if (broken) {
            tempStreak = 1;
          } else {
            tempStreak++;
          }
        }
      }
      if (tempStreak > bestStreak) {
        bestStreak = tempStreak;
      }
      tempMissedStreak = 0;
      prevDate = date;
    } else if (status == 'missed') {
      tempStreak = 0;
      if (prevDate == null) {
        tempMissedStreak = 1;
      } else {
        final diff = date.difference(prevDate).inDays;
        if (isDaily) {
          if (diff == 1) {
            tempMissedStreak++;
          } else {
            tempMissedStreak = 1;
          }
        } else {
          if (goal.frequencyDays!.contains(date.weekday)) {
            tempMissedStreak++;
          }
        }
      }
      if (tempMissedStreak > worstStreak) {
        worstStreak = tempMissedStreak;
      }
      prevDate = date;
    }
  }

  final yesterdayNormalized = todayNormalized.subtract(const Duration(days: 1));

  int checkStreak(DateTime startCheckDate) {
    int streak = 0;
    DateTime checkDate = startCheckDate;
    while (true) {
      final status = goalLogs[checkDate];
      if (status == 'done') {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (status == 'missed') {
        break;
      } else {
        if (!isDaily && !goal.frequencyDays!.contains(checkDate.weekday)) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }
        break; 
      }
    }
    return streak;
  }

  final todayStatus = goalLogs[todayNormalized];
  if (todayStatus == 'done') {
    currentStreak = checkStreak(todayNormalized);
  } else {
    final yesterdayStatus = goalLogs[yesterdayNormalized];
    if (yesterdayStatus == 'done') {
      currentStreak = checkStreak(yesterdayNormalized);
    }
  }

  final int totalActiveDays = daysSinceStart > 0 ? daysSinceStart : 1;
  final rate = (completedDays / totalActiveDays * 100).round();

  return {
    'name': goal.title,
    'color': goal.color,
    'best': bestStreak,
    'worst': worstStreak,
    'serie': currentStreak,
    'rate': rate,
  };
}
