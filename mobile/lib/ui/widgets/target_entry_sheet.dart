import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../i18n/translations.g.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../kit/evolve_sheet.dart';
import 'target_ring.dart';

/// The progress-entry sheet for a quantitative habit-day: a big ring, a −/+
/// stepper by the target's step, and a live number. Every change persists
/// immediately through [HabitProgressNotifier.setProgress] (which also re-derives
/// the day's verdict), so the sheet holds no draft state to commit — closing it
/// is not a save.
///
/// The stepper carries real accessibility semantics (`onIncrease`/`onDecrease` +
/// a spoken value), unlike the day-card it is opened from, whose
/// `excludeSemantics: true` would swallow a nested control.
class TargetEntrySheet extends ConsumerWidget {
  const TargetEntrySheet({
    super.key,
    required this.habit,
    required this.target,
    required this.date,
  });

  final Goal habit;
  final HabitTarget target;
  final DateTime date;

  static Future<void> show(
    BuildContext context, {
    required Goal habit,
    required HabitTarget target,
    required DateTime date,
  }) {
    return showEvolveFormSheet<void>(
      context: context,
      title: habit.title,
      builder: (_) => TargetEntrySheet(habit: habit, target: target, date: date),
    );
  }

  String get _dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _set(WidgetRef ref, double amount) async {
    ref.hapticLight();
    await ref.read(habitProgressProvider.notifier).setProgress(
          dateKey: _dateKey,
          goalId: habit.id,
          amount: amount,
          target: target,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final progress = ref.watch(habitProgressProvider)[_dateKey]?[habit.id] ?? 0;
    final over = periodIsOver(target.period, date, DateTime.now());
    final verdict =
        evaluateTarget(target: target, progress: progress, periodIsOver: over);
    final unit = targetUnitShortLabel(context.t, target.unit);
    final amountText = formatTargetAmount(progress);
    final targetText = formatTargetAmount(target.amount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TargetRing(
            target: target,
            verdict: verdict,
            size: 132,
            strokeWidth: 10,
            accent: habit.color,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: colors.foreground,
                  ),
                ),
                Text(
                  unit.isEmpty ? '/ $targetText' : '/ $targetText $unit',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusLine(context, verdict, over),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          Semantics(
            container: true,
            value: unit.isEmpty
                ? '$amountText / $targetText'
                : '$amountText / $targetText $unit',
            increasedValue: formatTargetAmount(
                progressAfterIncrement(target, progress)),
            decreasedValue: formatTargetAmount(
                progressAfterDecrement(target, progress)),
            onIncrease: () =>
                _set(ref, progressAfterIncrement(target, progress)),
            onDecrease: () =>
                _set(ref, progressAfterDecrement(target, progress)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepButton(
                  icon: LucideIcons.minus,
                  onPressed: progress <= 0
                      ? null
                      : () => _set(
                          ref, progressAfterDecrement(target, progress)),
                ),
                const SizedBox(width: 20),
                Text(
                  '+${formatTargetAmount(target.step)}${unit.isEmpty ? '' : ' $unit'}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(width: 20),
                _StepButton(
                  icon: LucideIcons.plus,
                  emphasized: true,
                  accent: habit.color,
                  onPressed: () =>
                      _set(ref, progressAfterIncrement(target, progress)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLine(BuildContext context, TargetVerdict verdict, bool over) {
    final t = context.t;
    return switch (verdict.outcome) {
      TargetOutcome.met => t.a11y.statusDone,
      TargetOutcome.breached => t.targets.entry.overLimit,
      TargetOutcome.unmet => t.a11y.statusMissed,
      TargetOutcome.pending =>
        target.isLimit ? t.targets.entry.withinLimit : t.targets.entry.keepGoing,
      TargetOutcome.unknown => t.a11y.statusPending,
    };
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
    this.accent,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasized;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final disabled = onPressed == null;
    final bg = emphasized
        ? (accent ?? colors.primary)
        : colors.muted;
    final fg = emphasized
        ? _onAccent(accent ?? colors.primary)
        : colors.foreground;
    return Semantics(
      // The Row already exposes onIncrease/onDecrease; keep the two big buttons
      // tappable for sighted users but out of the a11y tree to avoid a double
      // announcement.
      excludeSemantics: true,
      child: Opacity(
        opacity: disabled ? 0.35 : 1,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 60,
              height: 60,
              child: Icon(icon, color: fg, size: 26),
            ),
          ),
        ),
      ),
    );
  }

  /// Black or white for legible contrast on [bg].
  Color _onAccent(Color bg) =>
      bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
