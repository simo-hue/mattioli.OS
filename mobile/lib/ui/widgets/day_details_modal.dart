import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/targets_config.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../core/streak_utils.dart';
import '../../core/verification_wiring.dart';
import '../../core/haptics.dart';
import 'habit_management_modal.dart';
import 'target_entry_sheet.dart';
import 'target_ring.dart';
import 'verification_rule_field.dart';
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
    final progress =
        TargetsConfig.enabled ? ref.watch(habitProgressProvider) : const {};
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final dayRecord = logs[dateKey] ?? {};
    final dateMidnight = DateTime(date.year, date.month, date.day);
    // Days an auto-verified habit couldn't be verified (drives the "?" state).
    final couldNotVerifyByGoal =
        ref.watch(couldNotVerifyDaysProvider).asData?.value ?? const {};

    // Habits scheduled on this date (active range AND this weekday). Off-day
    // habits are hidden here, not shown-and-uncompletable.
    final activeHabits = habits.where((h) => h.isScheduledOn(date)).toList();

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
                      // An unresolved auto-verification for this habit-day: no
                      // terminal status yet + a couldn't-verify marker.
                      final couldNotVerify = status == null &&
                          (couldNotVerifyByGoal[habit.id]
                                  ?.contains(dateMidnight) ??
                              false);

                      // A MANUAL quantitative target: the card shows a progress
                      // ring and opens the entry sheet instead of cycling a
                      // checkbox. Deliberately not `displayTarget` — a projected
                      // verification rule is measured, its value lives in
                      // goal_logs.value not goal_progress, so its ring would read
                      // empty; a verified habit keeps its checkbox + badge here.
                      final target = TargetsConfig.enabled &&
                              (habit.target?.isUserEnterable ?? false)
                          ? habit.target
                          : null;
                      final progressAmount =
                          (progress[dateKey]?[habit.id] as double?) ?? 0;
                      final TargetVerdict? verdict = target == null
                          ? null
                          : evaluateTarget(
                              target: target,
                              progress: progressAmount,
                              periodIsOver: periodIsOver(
                                  target.period, date, DateTime.now()),
                            );

                      // Signed streak via the shared, deterministic helper
                      // (same logic as cloud + Private Mode + the web app).
                      final streak = computeStreak(
                        habitId: habit.id,
                        date: date,
                        logs: logs,
                        startDate: habit.startDate,
                        frequencyDays: habit.frequencyDays,
                      );

                      return GoalLogCard(
                        habit: habit,
                        status: status,
                        streak: streak,
                        couldNotVerify: couldNotVerify,
                        target: target,
                        verdict: verdict,
                        progressAmount: progressAmount,
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

                          // A user-enterable target opens the progress entry
                          // sheet (increment / timer); a measured target's ring
                          // is filled by the verification pipeline, so it falls
                          // through to the normal resolve/toggle path.
                          if (target != null && target.isUserEnterable) {
                            TargetEntrySheet.show(
                              context,
                              habit: habit,
                              target: target,
                              date: date,
                            );
                            return;
                          }

                          ref
                              .read(habitLogsProvider.notifier)
                              .cycleStatus(date, habit.id);
                          // Manually resolving a verified habit clears its
                          // couldn't-verify marker in the store — refresh the
                          // "?" source so a later un-resolve doesn't resurrect a
                          // stale "?" from the cached provider.
                          if (habit.isVerified) {
                            ref.invalidate(couldNotVerifyDaysProvider);
                          }
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

  /// True when this is an auto-verified habit whose day couldn't be verified
  /// (D6): renders the "?" resolve affordance in place of the pending circle.
  final bool couldNotVerify;

  /// The habit's display target (own manual, or a projected rule). When set,
  /// the leading slot shows a progress ring + count instead of the status icon.
  final HabitTarget? target;
  final TargetVerdict? verdict;
  final double progressAmount;

  const GoalLogCard({
    super.key,
    required this.habit,
    required this.status,
    required this.streak,
    required this.onTap,
    this.couldNotVerify = false,
    this.target,
    this.verdict,
    this.progressAmount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
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
    } else if (couldNotVerify) {
      // Actionable "?" state — subtle primary tint (like an editable cell).
      cardColor = primary.withValues(alpha: 0.06);
      borderColor = primary.withValues(alpha: 0.3);
      iconBgColor = primary.withValues(alpha: 0.12);
      iconColor = primary;
    }

    // For a target habit the spoken status is the progress ("40 of 80"); the
    // ring carries the visual state, so the card's own colour stays neutral
    // while pending.
    final a11yStatus = target != null
        ? '${formatTargetAmount(progressAmount)} / '
            '${formatTargetAmount(target!.amount)}'
            '${targetUnitShortLabel(context.t, target!.unit).isEmpty ? '' : ' ${targetUnitShortLabel(context.t, target!.unit)}'}'
        : status == 'done'
        ? context.t.a11y.statusDone
        : status == 'missed'
        ? context.t.a11y.statusMissed
        : couldNotVerify
        ? context.t.verification.couldNotVerifyTapToResolve
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
              if (target != null && verdict != null)
                TargetRing(
                  target: target!,
                  verdict: verdict!,
                  size: 44,
                  strokeWidth: 4,
                  accent: habit.color,
                  child: Text(
                    formatTargetAmount(progressAmount),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: textColor,
                    ),
                  ),
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: couldNotVerify
                      ? Text(
                          '?',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: iconColor,
                            height: 1,
                          ),
                        )
                      : Icon(icon, color: iconColor, size: 20),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
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
                        if (habit.isVerified) ...[
                          const SizedBox(width: 8),
                          const VerificationBadge(),
                        ],
                      ],
                    ),
                    if (target != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${formatTargetAmount(progressAmount)} / '
                        '${formatTargetAmount(target!.amount)}'
                        '${targetUnitShortLabel(context.t, target!.unit).isEmpty ? '' : ' ${targetUnitShortLabel(context.t, target!.unit)}'}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.appColors.mutedForeground,
                        ),
                      ),
                    ] else if (couldNotVerify) ...[
                      const SizedBox(height: 2),
                      Text(
                        context.t.verification.couldNotVerifyTapToResolve,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.appColors.mutedForeground,
                        ),
                      ),
                    ],
                  ],
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
