import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';
import '../../../core/localization.dart';
import '../../../providers/goal_provider.dart';

class AlertData {
  final Map<String, dynamic> worstNegative;
  final List<Map<String, dynamic>> brokenStreaks;
  
  AlertData({required this.worstNegative, required this.brokenStreaks});
}

class HabitMiglioramentoTabWidget extends ConsumerWidget {
  final String goalId;

  const HabitMiglioramentoTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(habitLogsProvider);
    
    final alertData = _calculateAlerts(goalId, logs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SerieNegativaCard(data: alertData.worstNegative),
        const SizedBox(height: 16),
        _StreakInterrottiCard(streaks: alertData.brokenStreaks),
        const SizedBox(height: 16),
        const SizedBox(height: 32),
      ],
    );
  }
  
  AlertData _calculateAlerts(String goalId, HabitLogsMap logs) {
    final goalLogs = <DateTime, String>{};
    logs.forEach((dateStr, habits) {
      if (habits.containsKey(goalId)) {
        final date = DateTime.parse(dateStr);
        goalLogs[DateTime(date.year, date.month, date.day)] = habits[goalId]!;
      }
    });

    final sortedDates = goalLogs.keys.toList()..sort();
    
    // Variables for Worst Negative Streak
    int maxMissedStreak = 0;
    DateTime? worstStreakStartDate;
    int currentMissedStreak = 0;
    DateTime? currentMissedStreakStartDate;
    
    // Variables for Broken Streaks
    final brokenStreaks = <Map<String, dynamic>>[];
    int currentStreak = 0;
    
    for (final date in sortedDates) {
      final status = goalLogs[date];
      
      // 1. Worst Negative Streak Logic
      if (status == 'missed') {
        if (currentMissedStreak == 0) {
          currentMissedStreakStartDate = date;
        }
        currentMissedStreak++;
        if (currentMissedStreak > maxMissedStreak) {
          maxMissedStreak = currentMissedStreak;
          worstStreakStartDate = currentMissedStreakStartDate;
        }
      } else if (status == 'done') {
        currentMissedStreak = 0;
        currentMissedStreakStartDate = null;
      }
      
      // 2. Broken Streaks Logic
      if (status == 'done') {
        currentStreak++;
      } else if (status == 'missed') {
        if (currentStreak > 0) {
          brokenStreaks.add({
            'days': currentStreak,
            'date': date,
          });
          currentStreak = 0;
        }
      }
    }
    
    // Sort broken streaks by date descending
    brokenStreaks.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    
    return AlertData(
      worstNegative: {
        'days': maxMissedStreak,
        'startDate': worstStreakStartDate,
      },
      brokenStreaks: brokenStreaks.take(5).toList(),
    );
  }
}

class _SerieNegativaCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SerieNegativaCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final days = data['days'] as int;
    final startDate = data['startDate'] as DateTime?;
    
    String dateStr = '';
    if (startDate != null) {
      dateStr = '${context.l10n.translate('Iniziata il')} ${startDate.day} ${startDate.month} ${startDate.year}';
    }

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trendingDown, size: 20, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Text(
                context.l10n.translate('Serie Negativa Peggiore'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$days',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                  height: 1,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.translate('giorni consecutivi mancati'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: context.appColors.foreground,
                      ),
                    ),
                    if (startDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: context.appColors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakInterrottiCard extends StatelessWidget {
  final List<Map<String, dynamic>> streaks;
  const _StreakInterrottiCard({required this.streaks});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.translate('Streak Interrotti'),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 16),
          if (streaks.isEmpty)
            Text(
              context.l10n.translate('Nessun streak interrotto registrato'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: context.appColors.mutedForeground,
              ),
            )
          else
            ...streaks.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildStreakItem(context, s['days'] as int, s['date'] as DateTime),
                )),
        ],
      ),
    );
  }

  Widget _buildStreakItem(BuildContext context, int days, DateTime date) {
    final dateStr = '${date.day} ${date.month} ${date.year}';
    
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$days',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.translate('Streak di count giorni interrotto').replaceFirst('count', days.toString()),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: context.appColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
