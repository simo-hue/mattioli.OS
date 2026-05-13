import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';
import '../../../providers/goal_provider.dart';
import '../../../models/goal.dart';

class HabitStats {
  final int currentStreak;
  final int bestStreak;
  final int completionRate;
  final int totalCompletions;
  final int totalActiveDays;
  final int missedDays;
  final List<int> trend30Days;

  HabitStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.completionRate,
    required this.totalCompletions,
    required this.totalActiveDays,
    required this.missedDays,
    required this.trend30Days,
  });
}

class HabitOverviewTabWidget extends ConsumerWidget {
  final String goalId;

  const HabitOverviewTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    
    final goal = goals.firstWhere((g) => g.id == goalId, orElse: () => Goal(id: '', title: '', color: Colors.blue, startDate: DateTime.now()));
    
    final stats = _calculateStats(goalId, logs, goal);
    final correlations = _calculateCorrelations(goalId, logs, goals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopStatsGrid(stats: stats),
        const SizedBox(height: 16),
        _TrendUltimi30Giorni(trend: stats.trend30Days),
        const SizedBox(height: 16),
        _CorrelazioniSection(goalId: goalId, correlations: correlations, currentGoalTitle: goal.title),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _TopStatsGrid extends StatelessWidget {
  final HabitStats stats;
  const _TopStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _StatCard(
          title: context.l10n.translate('SERIE ATTUALE'),
          value: '${stats.currentStreak}',
          subtitle: context.l10n.translate('giorni'),
          valueColor: const Color(0xFFEF4444), // Red
        ),
        _StatCard(
          title: context.l10n.translate('RECORD'),
          value: '${stats.bestStreak}',
          subtitle: context.l10n.translate('giorni'),
          valueColor: const Color(0xFFEAB308), // Yellow
        ),
        _StatCard(
          title: context.l10n.translate('COMPLETAMENTO'),
          value: '${stats.completionRate}%',
          subtitle: '${stats.totalCompletions}/${stats.totalActiveDays} ${context.l10n.translate('gg')}',
          valueColor: context.appColors.foreground,
        ),
        _StatCard(
          title: context.l10n.translate('MANCATI'),
          value: '${stats.missedDays}',
          subtitle: context.l10n.translate('giorni'),
          valueColor: const Color(0xFFEF4444), // Red
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color valueColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.appColors.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: context.appColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendUltimi30Giorni extends StatelessWidget {
  final List<int> trend;
  const _TrendUltimi30Giorni({required this.trend});

  @override
  Widget build(BuildContext context) {
    final List<int> statuses = trend;

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.translate('Trend Ultimi 30 Giorni'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: 30,
            itemBuilder: (context, index) {
              final status = statuses[index];
              Color color;
              if (status == 1) {
                color = Theme.of(context).colorScheme.primary; 
              } else if (status == 0) {
                color = const Color(0xFFFF0000); // Red
              } else {
                color = context.appColors.muted.withValues(alpha: 0.3); // Dynamic Grey
              }

              return Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(context.l10n.translate('Completato'), style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: context.appColors.mutedForeground)),
              const SizedBox(width: 16),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: context.appColors.muted.withValues(alpha: 0.3), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(context.l10n.translate('Non completato'), style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: context.appColors.mutedForeground)),
            ],
          )
        ],
      ),
    );
  }
}

class _CorrelazioniSection extends StatefulWidget {
  final String goalId;
  final List<Map<String, dynamic>> correlations;
  final String currentGoalTitle;
  const _CorrelazioniSection({required this.goalId, required this.correlations, required this.currentGoalTitle});

  @override
  State<_CorrelazioniSection> createState() => _CorrelazioniSectionState();
}

class _CorrelazioniSectionState extends State<_CorrelazioniSection> {
  late PageController _positiveController;
  late PageController _negativeController;
  int _positiveIndex = 0;
  int _negativeIndex = 0;

  @override
  void initState() {
    super.initState();
    _positiveController = PageController(viewportFraction: 0.9);
    _negativeController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _positiveController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positiveCorrelations = widget.correlations.where((c) => c['percentage'] >= 50).toList();
    final negativeCorrelations = widget.correlations.where((c) => c['percentage'] < 50).toList();
    
    final displayPositives = positiveCorrelations.isNotEmpty ? positiveCorrelations.take(3).toList() : [];
    final displayNegatives = negativeCorrelations.isNotEmpty ? negativeCorrelations.take(3).toList() : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.l10n.translate('Correlazioni con')} "${widget.currentGoalTitle}"',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.appColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.translate('Come questa abitudine si relaziona con le altre'),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 24),

        // POSITIVE CORRELATIONS
        Row(
          children: [
            const Icon(LucideIcons.trendingUp, size: 16, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Correlazioni Positive'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: displayPositives.isEmpty 
            ? Center(child: Text(context.l10n.translate('Nessuna correlazione positiva significativa'), style: TextStyle(color: context.appColors.mutedForeground)))
            : PageView.builder(
                controller: _positiveController,
                itemCount: displayPositives.length,
                onPageChanged: (i) => setState(() => _positiveIndex = i),
                itemBuilder: (context, index) {
                  final c = displayPositives[index];
                  final goal = c['goal'] as Goal;
                  return _buildPaddedCard(
                    _CorrelazioneCard(
                      habitName: goal.title,
                      habitColor: goal.color,
                      strengthText: 'Forte (+${(c['percentage']/100).toStringAsFixed(2)})',
                      strengthColor: const Color(0xFF10B981),
                      subtitle: '${c['percentage']}% insieme',
                      description: 'Quando completi "${widget.currentGoalTitle}", hai una probabilità del ${c['percentage']}% di completare anche "${goal.title}".',
                      borderColor: const Color(0xFF10B981),
                    ),
                  );
                },
              ),
        ),
        const SizedBox(height: 12),
        if (displayPositives.isNotEmpty) _buildDots(displayPositives.length, _positiveIndex, const Color(0xFF10B981)),

        const SizedBox(height: 32),

        // NEGATIVE CORRELATIONS
        Row(
          children: [
            const Icon(LucideIcons.trendingDown, size: 16, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              context.l10n.translate('Correlazioni Negative'),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: displayNegatives.isEmpty 
            ? Center(child: Text(context.l10n.translate('Nessuna correlazione negativa significativa'), style: TextStyle(color: context.appColors.mutedForeground)))
            : PageView.builder(
                controller: _negativeController,
                itemCount: displayNegatives.length,
                onPageChanged: (i) => setState(() => _negativeIndex = i),
                itemBuilder: (context, index) {
                  final c = displayNegatives[index];
                  final goal = c['goal'] as Goal;
                  return _buildPaddedCard(
                    _CorrelazioneCard(
                      habitName: goal.title,
                      habitColor: goal.color,
                      strengthText: 'Debole (+${(c['percentage']/100).toStringAsFixed(2)})',
                      strengthColor: const Color(0xFFEF4444),
                      subtitle: '${c['percentage']}% insieme',
                      description: 'Quando completi "${widget.currentGoalTitle}", hai solo una probabilità del ${c['percentage']}% di completare anche "${goal.title}".',
                      borderColor: const Color(0xFFEF4444),
                    ),
                  );
                },
              ),
        ),
        const SizedBox(height: 12),
        if (displayNegatives.isNotEmpty) _buildDots(displayNegatives.length, _negativeIndex, const Color(0xFFEF4444)),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPaddedCard(Widget card) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: card,
    );
  }

  Widget _buildDots(int count, int current, Color color) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = current == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? color : context.appColors.mutedForeground.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

class _CorrelazioneCard extends StatelessWidget {
  final String habitName;
  final Color habitColor;
  final String strengthText;
  final Color strengthColor;
  final String subtitle;
  final String description;
  final Color borderColor;

  const _CorrelazioneCard({
    required this.habitName,
    required this.habitColor,
    required this.strengthText,
    required this.strengthColor,
    required this.subtitle,
    required this.description,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: habitColor, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  habitName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                strengthText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: strengthColor,
                ),
              ),
              const SizedBox(width: 6),
              Text('•', style: TextStyle(color: context.appColors.mutedForeground, fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: context.appColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: context.appColors.mutedForeground,
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

HabitStats _calculateStats(String goalId, HabitLogsMap logs, Goal goal) {
  final goalLogs = <DateTime, String>{};
  logs.forEach((dateStr, habits) {
    if (habits.containsKey(goalId)) {
      final date = DateTime.parse(dateStr);
      goalLogs[DateTime(date.year, date.month, date.day)] = habits[goalId]!;
    }
  });

  final today = DateTime.now();
  final todayNormalized = DateTime(today.year, today.month, today.day);

  final trend30Days = <int>[];
  for (int i = 29; i >= 0; i--) {
    final date = todayNormalized.subtract(Duration(days: i));
    final status = goalLogs[date];
    if (status == 'done') {
      trend30Days.add(1);
    } else if (status == 'missed') {
      trend30Days.add(0);
    } else {
      trend30Days.add(2);
    }
  }

  if (goalLogs.isEmpty) {
    return HabitStats(
      currentStreak: 0,
      bestStreak: 0,
      completionRate: 0,
      totalCompletions: 0,
      totalActiveDays: 0,
      missedDays: 0,
      trend30Days: trend30Days,
    );
  }

  final sortedDates = goalLogs.keys.toList()..sort();
  
  int currentStreak = 0;
  int bestStreak = 0;
  int tempStreak = 0;
  int missedDays = 0;
  int completedDays = 0;

  final startDate = goal.startDate;
  final daysSinceStart = todayNormalized.difference(DateTime(startDate.year, startDate.month, startDate.day)).inDays + 1;
  
  goalLogs.forEach((date, status) {
    if (status == 'done') {
      completedDays++;
    } else if (status == 'missed') {
      missedDays++;
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
      prevDate = date;
    } else if (status == 'missed') {
      tempStreak = 0;
      prevDate = null;
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
    } else if (!isDaily && !goal.frequencyDays!.contains(todayNormalized.weekday)) {
       if (yesterdayStatus == 'done') {
         currentStreak = checkStreak(yesterdayNormalized);
       }
    }
  }

  final int totalActiveDays = daysSinceStart > 0 ? daysSinceStart : 1;
  final completionRate = (completedDays / totalActiveDays * 100).round();

  return HabitStats(
    currentStreak: currentStreak,
    bestStreak: bestStreak,
    completionRate: completionRate,
    totalCompletions: completedDays,
    totalActiveDays: totalActiveDays,
    missedDays: missedDays,
    trend30Days: trend30Days,
  );
}

List<Map<String, dynamic>> _calculateCorrelations(String targetGoalId, HabitLogsMap logs, List<Goal> allGoals) {
  final targetLogs = <String, String>{};
  logs.forEach((date, habits) {
    if (habits.containsKey(targetGoalId)) {
      targetLogs[date] = habits[targetGoalId]!;
    }
  });

  final completedDates = targetLogs.entries
      .where((e) => e.value == 'done')
      .map((e) => e.key)
      .toList();

  if (completedDates.isEmpty) return [];

  final correlations = <Map<String, dynamic>>[];

  for (final otherGoal in allGoals) {
    if (otherGoal.id == targetGoalId) continue;

    int togetherCount = 0;
    
    for (final date in completedDates) {
      final otherStatus = logs[date]?[otherGoal.id];
      if (otherStatus == 'done') {
        togetherCount++;
      }
    }

    final percentage = (togetherCount / completedDates.length * 100).round();
    
    correlations.add({
      'goal': otherGoal,
      'percentage': percentage,
      'strength': percentage / 100.0,
      'togetherCount': togetherCount,
    });
  }

  correlations.sort((a, b) => (b['percentage'] as int).compareTo(a['percentage'] as int));

  return correlations;
}
