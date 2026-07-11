import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../core/streak_utils.dart';
import '../../core/haptics.dart';
import 'habit_management_modal.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_toast.dart';
import '../kit/evolve_button.dart';
import '../kit/evolve_sheet.dart';

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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: EvolveGrabber()),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.MMMMd(
                      LocaleSettings.currentLocale.languageCode,
                    ).format(date),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.appColors.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    context.t.habits.yourProgressForToday,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(LucideIcons.x, color: context.appColors.mutedForeground),
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
                          color: context.appColors.mutedForeground.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.t.habits.noHabit,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.t.habits.thereAreNoHabitsForThis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: context.appColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 24),
                        EvolveButton(
                          label: context.t.habits.createHabit,
                          icon: LucideIcons.plus,
                          expand: false,
                          onPressed: () {
                            Navigator.pop(context); // Close details modal
                            HabitManagementModal.show(context);
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: activeHabits.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final habit = activeHabits[index];
                      final status = dayRecord[habit.id];

                      // Signed streak via the shared, deterministic helper
                      // (same logic as cloud + Private Mode + the web app).
                      final streak = computeStreak(
                        habitId: habit.id,
                        date: date,
                        logs: logs,
                        startDate: habit.startDate,
                      );

                      return GoalLogCard(
                        habit: habit,
                        status: status,
                        streak: streak,
                        onTap: () {
                          final today = DateTime(
                            DateTime.now().year,
                            DateTime.now().month,
                            DateTime.now().day,
                          );
                          final yesterday = today.subtract(
                            const Duration(days: 1),
                          );
                          final dateMidnight = DateTime(
                            date.year,
                            date.month,
                            date.day,
                          );

                          if (dateMidnight.isBefore(yesterday)) {
                            ref.hapticMedium();
                            showEvolveToast(
                              context,
                              message:
                                  context.t.habits.youCanOnlyEditTodayAnd,
                              kind: EvolveToastKind.error,
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
    Color cardColor = context.appColors.card;
    Color borderColor = context.appColors.border;
    Color textColor = context.appColors.foreground;
    Color iconBgColor = context.appColors.muted;
    IconData icon = LucideIcons.circle;
    Color iconColor = context.appColors.mutedForeground;
    bool hasStrikethrough = false;

    if (status == 'done') {
      cardColor = context.appColors.success.withValues(alpha: 0.15);
      borderColor = context.appColors.success.withValues(alpha: 0.4);
      textColor = context.appColors.success;
      iconBgColor = context.appColors.success.withValues(alpha: 0.2);
      iconColor = context.appColors.success;
      icon = LucideIcons.check;
    } else if (status == 'missed') {
      cardColor = const Color(
        0xFF450A0A,
      ).withValues(alpha: 0.2); // Very dark red
      borderColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
      textColor = context.appColors.mutedForeground;
      iconBgColor = const Color(0xFF450A0A).withValues(alpha: 0.4);
      iconColor = const Color(0xFFEF4444);
      icon = LucideIcons.x;
      hasStrikethrough = true;
    }

    final a11yStatus = status == 'done'
        ? context.t.a11y.statusDone
        : status == 'missed'
        ? context.t.a11y.statusMissed
        : context.t.a11y.statusPending;

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${habit.title}, $a11yStatus',
      hint: context.t.a11y.toggleHint,
      child: GestureDetector(
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
                    decoration: hasStrikethrough
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: const Color(
                      0xFFEF4444,
                    ).withValues(alpha: 0.5),
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
    Color bgColor = context.appColors.muted;
    Color textColor = context.appColors.mutedForeground;
    IconData icon = LucideIcons.flame;
    Color iconColor = const Color(0xFFF97316); // Orange

    if (isMissed) {
      bgColor = const Color(0xFF450A0A).withValues(alpha: 0.5);
      textColor = const Color(0xFFEF4444);
      icon = LucideIcons.heartCrack;
      iconColor = const Color(0xFFEF4444);
    } else if (isDone) {
      bgColor = context.appColors.success.withValues(alpha: 0.2);
      textColor = context.appColors.success;
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
