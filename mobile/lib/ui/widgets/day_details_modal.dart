import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../core/haptics.dart';
import 'habit_management_modal.dart';
import '../../core/localization.dart';

const _kMonths = [
  'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
  'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
];

class DayDetailsModal extends ConsumerWidget {
  final DateTime date;

  const DayDetailsModal({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(goalsProvider);
    final logs = ref.watch(habitLogsProvider);
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final dayRecord = logs[dateKey] ?? {};

    // Filter habits active on this date
    final activeHabits = habits.where((h) => h.isActiveOn(date)).toList();

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.background,
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
            child: activeHabits.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Icon(
                          LucideIcons.clipboardList,
                          size: 64,
                          color: AppColors.mutedForeground.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nessuna abitudine',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Non ci sono abitudini per questo giorno.\nInizia a crearne una!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context); // Close details modal
                            HabitManagementModal.show(context);
                          },
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: Text(context.l10n.translate('Crea Abitudine')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: activeHabits.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final habit = activeHabits[index];
                      final status = dayRecord[habit.id];

                      // Calculate streak
                      int streak = 0;
                      DateTime checkDate = date;
                      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                      
                      bool isNegative = false;
                      while (true) {
                        final dk = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
                        final dl = logs[dk] ?? {};
                        final s = dl[habit.id];
                        
                        if (s == 'done') {
                          if (isNegative) break;
                          streak++;
                        } else if (s == 'missed') {
                          if (streak > 0) break;
                          isNegative = true;
                          streak--;
                        } else {
                          if (habit.isActiveOn(checkDate)) {
                            final checkDateMidnight = DateTime(checkDate.year, checkDate.month, checkDate.day);
                            if (checkDateMidnight.isBefore(today)) {
                              break;
                            }
                          }
                        }
                        
                        // Condizione di uscita per evitare loop infiniti!
                        final startMidnight = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);
                        final checkDateMidnight = DateTime(checkDate.year, checkDate.month, checkDate.day);
                        if (checkDateMidnight.isBefore(startMidnight)) {
                          break;
                        }
                        
                        checkDate = checkDate.subtract(const Duration(days: 1));
                      }

                      return GoalLogCard(
                        habit: habit,
                        status: status,
                        streak: streak,
                        onTap: () {
                          final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                          final yesterday = today.subtract(const Duration(days: 1));
                          final dateMidnight = DateTime(date.year, date.month, date.day);
                          
                          if (dateMidnight.isBefore(yesterday)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.translate('Puoi modificare solo oggi e ieri!')),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          
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

class GoalLogCard extends ConsumerWidget {
  final Goal habit;
  final String? status; // 'done', 'missed', or null
  final int streak;
  final VoidCallback onTap;

  const GoalLogCard({
    super.key,
    required this.habit,
    required this.status,
    required this.streak,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color cardColor = AppColors.card;
    Color borderColor = AppColors.border;
    Color textColor = AppColors.foreground;
    Color iconBgColor = AppColors.muted;
    IconData icon = LucideIcons.circle;
    Color iconColor = AppColors.mutedForeground;
    bool hasStrikethrough = false;



    if (status == 'done') {
      cardColor = AppColors.success.withValues(alpha: 0.15); 
      borderColor = AppColors.success.withValues(alpha: 0.4);
      textColor = AppColors.success;
      iconBgColor = AppColors.success.withValues(alpha: 0.2);
      iconColor = AppColors.success;
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
        ref.hapticLight();
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
            StreakBadge(
              streak: streak,
              isMissed: status == 'missed',
              isDone: status == 'done',
            ),
          ],
        ),
      ),
    );
  }
}

class StreakBadge extends StatelessWidget {
  final int streak;
  final bool isMissed;
  final bool isDone;

  const StreakBadge({
    super.key,
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
      bgColor = AppColors.success.withValues(alpha: 0.2);
      textColor = AppColors.success;
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
