import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/target_ring.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The desktop progress-entry surface for a quantitative habit-day: a big ring
/// and a −/+ stepper that persists each change live via
/// `DashboardController.setHabitProgressForDay` (which re-derives the verdict).
///
/// Keyboard-first, as desktop should be: ↑/+ increment, ↓/− decrement. Those
/// keys do NOT collide with the habit pages' ←/→ period paging (which is what
/// the recon flagged), and the dialog captures focus so the stepper owns them
/// while open. Real increment/decrement Semantics are attached too — the habit
/// rows themselves have none, so this is the accessible entry point.
class TargetEntryDialog extends ConsumerStatefulWidget {
  const TargetEntryDialog({
    super.key,
    required this.habit,
    required this.target,
    required this.date,
  });

  final DashboardHabit habit;
  final HabitTarget target;
  final DateTime date;

  static Future<void> show(
    BuildContext context, {
    required DashboardHabit habit,
    required HabitTarget target,
    required DateTime date,
  }) {
    return showEvolveDialog<void>(
      context: context,
      builder: (_) =>
          TargetEntryDialog(habit: habit, target: target, date: date),
    );
  }

  @override
  ConsumerState<TargetEntryDialog> createState() => _TargetEntryDialogState();
}

class _TargetEntryDialogState extends ConsumerState<TargetEntryDialog> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  double get _progress =>
      ref.read(dashboardControllerProvider).habitProgressFor(
            widget.habit.id,
            widget.date,
          ) ??
      0;

  Future<void> _set(double amount) => ref
      .read(dashboardControllerProvider.notifier)
      .setHabitProgressForDay(widget.habit.id, widget.date, amount);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.numpadAdd) {
      _set(progressAfterIncrement(widget.target, _progress));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _set(progressAfterDecrement(widget.target, _progress));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final progress = ref.watch(dashboardControllerProvider
        .select((s) => s.habitProgressFor(widget.habit.id, widget.date) ?? 0));
    final over = periodIsOver(widget.target.period, widget.date, DateTime.now());
    final verdict = evaluateTarget(
        target: widget.target, progress: progress, periodIsOver: over);
    final unit = targetUnitShortLabel(widget.target.unit);
    final amountText = formatTargetAmount(progress);
    final targetText = formatTargetAmount(widget.target.amount);

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: EvolveAlertDialog(
        maxWidth: 340,
        title: Text(widget.habit.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            TargetRing(
              target: widget.target,
              verdict: verdict,
              size: 116,
              strokeWidth: 9,
              accent: widget.habit.color,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: colors.foreground,
                    ),
                  ),
                  Text(
                    unit.isEmpty ? '/ $targetText' : '/ $targetText $unit',
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              container: true,
              value: unit.isEmpty
                  ? '$amountText / $targetText'
                  : '$amountText / $targetText $unit',
              increasedValue: formatTargetAmount(
                  progressAfterIncrement(widget.target, progress)),
              decreasedValue: formatTargetAmount(
                  progressAfterDecrement(widget.target, progress)),
              onIncrease: () =>
                  _set(progressAfterIncrement(widget.target, progress)),
              onDecrease: () =>
                  _set(progressAfterDecrement(widget.target, progress)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepButton(
                    icon: LucideIcons.minus,
                    onPressed: progress <= 0
                        ? null
                        : () => _set(
                            progressAfterDecrement(widget.target, progress)),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    '+${formatTargetAmount(widget.target.step)}'
                    '${unit.isEmpty ? '' : ' $unit'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.muted,
                    ),
                  ),
                  const SizedBox(width: 18),
                  _StepButton(
                    icon: LucideIcons.plus,
                    emphasized: true,
                    accent: widget.habit.color,
                    onPressed: () =>
                        _set(progressAfterIncrement(widget.target, progress)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.actions.done),
          ),
        ],
      ),
    );
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
    final colors = context.evolveColors;
    final disabled = onPressed == null;
    final bg = emphasized ? (accent ?? colors.foreground) : colors.panelSoft;
    final fg = emphasized
        ? (bg.computeLuminance() > 0.5 ? Colors.black : Colors.white)
        : colors.foreground;
    return ExcludeSemantics(
      child: Opacity(
        opacity: disabled ? 0.35 : 1,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, color: fg, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
