import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../i18n/translations.g.dart';
import 'target_ring.dart';

/// Creation/edit control for a habit's quantitative target.
///
/// A closed list of presets ("Simple" checkbox + the four catalog presets) plus,
/// once a numeric preset is chosen, an amount stepper (and a per-tap step for
/// counters). The four-axis model never reaches the user — each chip writes a
/// fixed preset — matching how `VerificationRuleField` hides the rule internals.
/// Emits a [HabitTarget] (or null for "Simple") via [onChanged].
class TargetField extends ConsumerWidget {
  const TargetField({
    super.key,
    required this.target,
    required this.onChanged,
    this.showNone = true,
  });

  final HabitTarget? target;
  final ValueChanged<HabitTarget?> onChanged;

  /// Whether to offer the leading "Simple" (no-target) chip. False when the
  /// caller already models the no-target choice elsewhere (the tracking-mode
  /// picker's Checkbox segment), so Number mode always carries a numeric preset.
  final bool showNone;

  TargetPreset? get _selectedPreset =>
      target == null ? null : TargetPresetCatalog.forTarget(target!);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final t = context.t;
    final selected = _selectedPreset;
    void haptic() => ref.hapticLight();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.targets.sectionTitle,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (showNone)
              _Chip(
                label: t.targets.none,
                selected: target == null,
                onTap: () {
                  haptic();
                  onChanged(null);
                },
              ),
            for (final preset in TargetPresetCatalog.all)
              _Chip(
                label: _presetLabel(t, preset),
                selected: selected?.id == preset.id,
                onTap: () {
                  haptic();
                  onChanged(preset.targetWith(
                    // Preserve the amount when switching between presets, else
                    // fall back to the preset default.
                    amount: selected != null ? target!.amount : null,
                  ));
                },
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 14),
          _AmountAndStep(
            preset: selected,
            target: target!,
            haptic: haptic,
            onChanged: onChanged,
          ),
          const SizedBox(height: 6),
          Text(
            _presetDescription(t, selected),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: colors.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}

/// Amount + step entry for a numeric target.
///
/// Both numbers are typed directly — reaching 100 push-ups by tapping `+` a
/// hundred times was the whole reason this replaced a read-only display. The
/// `+`/`−` buttons remain for quick nudges, and they move by the CURRENT step,
/// which is what makes the Step field self-explanatory: type 20, and every tap
/// jumps 20. (They previously moved by `preset.defaultStep`, which would now
/// contradict both this field and the daily entry sheet.)
///
/// Typing is never corrected mid-keystroke — you cannot type "100" without
/// passing through "1" and "10". Values settle on blur/submit: empty reverts,
/// out-of-range snaps to the nearest allowed value, and the reason is shown.
/// Warnings (from `validateHabitTarget`) appear live but never block.
class _AmountAndStep extends StatefulWidget {
  const _AmountAndStep({
    required this.preset,
    required this.target,
    required this.haptic,
    required this.onChanged,
  });

  final TargetPreset preset;
  final HabitTarget target;
  final VoidCallback haptic;
  final ValueChanged<HabitTarget?> onChanged;

  @override
  State<_AmountAndStep> createState() => _AmountAndStepState();
}

class _AmountAndStepState extends State<_AmountAndStep> {
  late final TextEditingController _amount;
  late final TextEditingController _step;
  late final FocusNode _amountFocus;
  late final FocusNode _stepFocus;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: formatTargetAmount(widget.target.amount));
    _step = TextEditingController(text: formatTargetAmount(widget.target.step));
    _amountFocus = FocusNode()..addListener(_onAmountFocusChange);
    _stepFocus = FocusNode()..addListener(_onStepFocusChange);
  }

  @override
  void didUpdateWidget(_AmountAndStep old) {
    super.didUpdateWidget(old);
    // Re-seed from the model when it changes underneath us (a +/- tap, or the
    // user picking a different preset) — but never while the field has focus,
    // or we would overwrite what is being typed.
    if (!_amountFocus.hasFocus &&
        widget.target.amount != old.target.amount) {
      _amount.text = formatTargetAmount(widget.target.amount);
    }
    if (!_stepFocus.hasFocus && widget.target.step != old.target.step) {
      _step.text = formatTargetAmount(widget.target.step);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _step.dispose();
    _amountFocus.dispose();
    _stepFocus.dispose();
    super.dispose();
  }

  double? get _typedAmount => double.tryParse(_amount.text.replaceAll(',', '.'));
  double? get _typedStep => double.tryParse(_step.text.replaceAll(',', '.'));

  void _onAmountFocusChange() {
    if (_amountFocus.hasFocus) return;
    _commitAmount();
  }

  void _onStepFocusChange() {
    if (_stepFocus.hasFocus) return;
    _commitStep();
  }

  /// Settles the amount: empty reverts to the stored value rather than becoming
  /// zero (clearing a field is not a request to set 0), anything else clamps
  /// into the preset's range.
  void _commitAmount() {
    final typed = _typedAmount;
    final next = typed == null
        ? widget.target.amount
        : widget.preset.clampAmount(typed);
    _amount.text = formatTargetAmount(next);
    if (next != widget.target.amount) {
      widget.onChanged(widget.target.copyWith(amount: next));
    }
    setState(() {});
  }

  /// Settles the step. A step larger than the amount collapses to the amount —
  /// one tap completes the day, which is legitimate — and a zero/empty step
  /// reverts, because an inert `+` button is never what was meant.
  void _commitStep() {
    final typed = _typedStep;
    var next = (typed == null || typed <= 0) ? widget.target.step : typed;
    if (next > widget.target.amount) next = widget.target.amount;
    _step.text = formatTargetAmount(next);
    if (next != widget.target.step) {
      widget.onChanged(widget.target.copyWith(step: next));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = context.t;
    final unit = targetUnitShortLabel(t, widget.target.unit);
    // Live values, so the hint and the warnings track what is being typed
    // rather than what was last committed.
    final liveAmount = _typedAmount ?? widget.target.amount;
    final liveStep = _typedStep ?? widget.target.step;

    final issues = validateHabitTarget(
      preset: widget.preset,
      amount: _typedAmount,
      step: _typedStep,
    );
    final blocking = issues.where((i) => i.isBlocking).toList();
    final warnings = issues.where((i) => !i.isBlocking).toList();

    void bump(double delta) {
      widget.haptic();
      final next = widget.preset.clampAmount(liveAmount + delta);
      _amount.text = formatTargetAmount(next);
      widget.onChanged(widget.target.copyWith(amount: next));
      setState(() {});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.preset.direction == TargetDirection.atMost
                  ? t.targets.atMostLabel
                  : t.targets.atLeastLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: colors.mutedForeground,
              ),
            ),
            const Spacer(),
            _MiniStep(icon: Icons.remove, onTap: () => bump(-liveStep)),
            _NumberBox(
              controller: _amount,
              focusNode: _amountFocus,
              unit: unit,
              allowDecimal: widget.preset.minAmount != widget.preset.minAmount.roundToDouble(),
              onSubmitted: _commitAmount,
              emphasised: true,
            ),
            _MiniStep(icon: Icons.add, onTap: () => bump(liveStep)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              t.targets.stepLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: colors.mutedForeground,
              ),
            ),
            const Spacer(),
            _NumberBox(
              controller: _step,
              focusNode: _stepFocus,
              unit: unit,
              allowDecimal: widget.preset.minAmount != widget.preset.minAmount.roundToDouble(),
              onSubmitted: _commitStep,
              emphasised: false,
            ),
          ],
        ),
        const SizedBox(height: 6),
        // The hint is what makes the Step field explain itself: it names, in
        // words, exactly what the + button above will now do.
        Text(
          t.targets.stepHint(
            step: unit.isEmpty
                ? formatTargetAmount(liveStep)
                : '${formatTargetAmount(liveStep)} $unit',
          ),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: colors.mutedForeground,
          ),
        ),
        for (final issue in [...blocking, ...warnings])
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              targetIssueMessage(t, issue, amount: liveAmount, unit: unit),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: issue.isBlocking ? colors.destructive : kTargetWarningAmber,
              ),
            ),
          ),
      ],
    );
  }
}

/// A compact numeric text box. Digits only (plus a decimal separator where the
/// preset genuinely allows fractions, e.g. the 0.5 coffee minimum), so there is
/// no way to type letters at all.
class _NumberBox extends StatelessWidget {
  const _NumberBox({
    required this.controller,
    required this.focusNode,
    required this.unit,
    required this.allowDecimal,
    required this.onSubmitted,
    required this.emphasised,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String unit;
  final bool allowDecimal;
  final VoidCallback onSubmitted;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 76, maxWidth: 118),
      child: IntrinsicWidth(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              allowDecimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
            ),
          ],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmitted(),
          onTapOutside: (_) => focusNode.unfocus(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: emphasised ? 18 : 15,
            fontWeight: emphasised ? FontWeight.w800 : FontWeight.w600,
            color: colors.foreground,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: colors.background.withValues(alpha: 0.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            suffixText: unit.isEmpty ? null : unit,
            suffixStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: colors.mutedForeground,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStep extends StatelessWidget {
  const _MiniStep({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.muted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: colors.foreground),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? colors.foreground : colors.muted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.foreground : colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? colors.background : colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

String _presetLabel(Translations t, TargetPreset preset) => switch (preset.id) {
      'count_daily' => t.targets.presets.countDaily.label,
      'duration_daily' => t.targets.presets.durationDaily.label,
      'limit_count_daily' => t.targets.presets.limitCountDaily.label,
      'limit_duration_daily' => t.targets.presets.limitDurationDaily.label,
      _ => preset.id,
    };

String _presetDescription(Translations t, TargetPreset preset) =>
    switch (preset.id) {
      'count_daily' => t.targets.presets.countDaily.description,
      'duration_daily' => t.targets.presets.durationDaily.description,
      'limit_count_daily' => t.targets.presets.limitCountDaily.description,
      'limit_duration_daily' => t.targets.presets.limitDurationDaily.description,
      _ => '',
    };


/// Localized message for a [TargetIssue]. Kept beside the field so the package
/// stays i18n-free, and shared with the save-time confirmation so a warning is
/// worded identically wherever it appears.
String targetIssueMessage(
  Translations t,
  TargetIssue issue, {
  required double amount,
  required String unit,
}) {
  String n(double v) => unit.isEmpty
      ? formatTargetAmount(v)
      : '${formatTargetAmount(v)} $unit';
  switch (issue.kind) {
    case TargetIssueKind.amountOutOfRange:
      return t.targets.rangeError(
        min: formatTargetAmount(issue.lowerBound ?? 0),
        max: formatTargetAmount(issue.upperBound ?? 0),
      );
    case TargetIssueKind.stepNotPositive:
      return t.targets.stepPositiveError;
    case TargetIssueKind.stepExceedsAmount:
      return t.targets.stepExceedsWarning;
    case TargetIssueKind.amountNotDivisibleByStep:
      final above = n(issue.upperBound ?? 0);
      return issue.lowerBound == null
          ? t.targets.notDivisibleWarningNoBelow(amount: n(amount), above: above)
          : t.targets.notDivisibleWarning(
              amount: n(amount),
              below: n(issue.lowerBound!),
              above: above,
            );
    case TargetIssueKind.tooManyTaps:
      return t.targets.tooManyTapsWarning(taps: '${issue.taps ?? 0}');
  }
}
