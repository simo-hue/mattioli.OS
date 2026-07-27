import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/target_ring.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Create/edit control for a habit's quantitative target — the desktop twin of
/// mobile's `TargetField`. A closed list of preset chips ("Simple" + the four
/// catalog presets) plus, once a numeric preset is chosen, an amount stepper.
/// The four-axis model never reaches the user; each chip writes a fixed preset.
class TargetField extends StatelessWidget {
  const TargetField({
    super.key,
    required this.target,
    required this.onChanged,
    this.showNone = true,
  });

  final HabitTarget? target;
  final ValueChanged<HabitTarget?> onChanged;

  /// Whether to render the "Simple" (no-target) chip. The habit editor's
  /// tracking-mode picker owns the checkbox-vs-number choice, so it hides this
  /// chip (in Number mode the field only picks among numeric presets); every
  /// other use keeps it so a target can still be cleared inline.
  final bool showNone;

  TargetPreset? get _selectedPreset =>
      target == null ? null : TargetPresetCatalog.forTarget(target!);

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final selected = _selectedPreset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (showNone)
              _Chip(
                label: t.targets.none,
                selected: target == null,
                onTap: () => onChanged(null),
              ),
            for (final preset in TargetPresetCatalog.all)
              _Chip(
                label: _presetLabel(preset),
                selected: selected?.id == preset.id,
                onTap: () => onChanged(preset.targetWith(
                  amount: selected != null ? target!.amount : null,
                )),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          _AmountAndStep(
            preset: selected,
            target: target!,
            onChanged: onChanged,
          ),
          const SizedBox(height: 6),
          Text(
            _presetDescription(selected),
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
        ],
      ],
    );
  }
}

/// Amount + step entry — the desktop twin of mobile's `_AmountAndStep`, and
/// deliberately identical in behaviour: both numbers are typed, the `+`/`−`
/// buttons move by the CURRENT step (not `preset.defaultStep`, which would now
/// contradict both this field and the daily entry dialog), typing is never
/// corrected mid-keystroke, and values settle on blur/submit.
class _AmountAndStep extends StatefulWidget {
  const _AmountAndStep({
    required this.preset,
    required this.target,
    required this.onChanged,
  });

  final TargetPreset preset;
  final HabitTarget target;
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
    if (!_amountFocus.hasFocus && widget.target.amount != old.target.amount) {
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
    if (!_amountFocus.hasFocus) _commitAmount();
  }

  void _onStepFocusChange() {
    if (!_stepFocus.hasFocus) _commitStep();
  }

  void _commitAmount() {
    final typed = _typedAmount;
    final next =
        typed == null ? widget.target.amount : widget.preset.clampAmount(typed);
    _amount.text = formatTargetAmount(next);
    if (next != widget.target.amount) {
      widget.onChanged(widget.target.copyWith(amount: next));
    }
    setState(() {});
  }

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
    final colors = context.evolveColors;
    final unit = targetUnitShortLabel(widget.target.unit);
    final liveAmount = _typedAmount ?? widget.target.amount;
    final liveStep = _typedStep ?? widget.target.step;
    final allowDecimal =
        widget.preset.minAmount != widget.preset.minAmount.roundToDouble();

    final issues = validateHabitTarget(
      preset: widget.preset,
      amount: _typedAmount,
      step: _typedStep,
    );
    final ordered = [
      ...issues.where((i) => i.isBlocking),
      ...issues.where((i) => !i.isBlocking),
    ];

    void bump(double delta) {
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
              style: TextStyle(fontSize: 13, color: colors.muted),
            ),
            const Spacer(),
            _MiniStep(icon: Icons.remove, onTap: () => bump(-liveStep)),
            _NumberBox(
              controller: _amount,
              focusNode: _amountFocus,
              unit: unit,
              allowDecimal: allowDecimal,
              onSubmitted: _commitAmount,
              emphasised: true,
            ),
            _MiniStep(icon: Icons.add, onTap: () => bump(liveStep)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(t.targets.stepLabel,
                style: TextStyle(fontSize: 13, color: colors.muted)),
            const Spacer(),
            _NumberBox(
              controller: _step,
              focusNode: _stepFocus,
              unit: unit,
              allowDecimal: allowDecimal,
              onSubmitted: _commitStep,
              emphasised: false,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          t.targets.stepHint(
            step: unit.isEmpty
                ? formatTargetAmount(liveStep)
                : '${formatTargetAmount(liveStep)} $unit',
          ),
          style: TextStyle(fontSize: 12, color: colors.muted),
        ),
        for (final issue in ordered)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              targetIssueMessage(issue, amount: liveAmount, unit: unit),
              style: TextStyle(
                fontSize: 12,
                color: issue.isBlocking
                    ? EvolveColors.destructive
                    : kTargetWarningAmber,
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact numeric box. Digits only (plus a decimal separator where the preset
/// genuinely allows fractions), so letters cannot be typed at all.
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
    final colors = context.evolveColors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 84, maxWidth: 128),
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
          onSubmitted: (_) => onSubmitted(),
          style: TextStyle(
            fontSize: emphasised ? 16 : 14,
            fontWeight: emphasised ? FontWeight.w800 : FontWeight.w600,
            color: colors.foreground,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            suffixText: unit.isEmpty ? null : unit,
            suffixStyle: TextStyle(fontSize: 12, color: colors.muted),
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
    final colors = context.evolveColors;
    return Material(
      color: colors.panelSoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: colors.foreground),
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
    final colors = context.evolveColors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? colors.foreground : colors.panelSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? colors.foreground : colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? colors.panel : colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

String _presetLabel(TargetPreset preset) => switch (preset.id) {
      'count_daily' => t.targets.presets.countDaily.label,
      'duration_daily' => t.targets.presets.durationDaily.label,
      'limit_count_daily' => t.targets.presets.limitCountDaily.label,
      'limit_duration_daily' => t.targets.presets.limitDurationDaily.label,
      _ => preset.id,
    };

String _presetDescription(TargetPreset preset) => switch (preset.id) {
      'count_daily' => t.targets.presets.countDaily.description,
      'duration_daily' => t.targets.presets.durationDaily.description,
      'limit_count_daily' => t.targets.presets.limitCountDaily.description,
      'limit_duration_daily' => t.targets.presets.limitDurationDaily.description,
      _ => '',
    };


/// Localized message for a [TargetIssue] — the desktop twin of mobile's helper.
/// Shared with the save-time confirmation so a warning reads identically
/// wherever it appears.
String targetIssueMessage(
  TargetIssue issue, {
  required double amount,
  required String unit,
}) {
  String n(double v) =>
      unit.isEmpty ? formatTargetAmount(v) : '${formatTargetAmount(v)} $unit';
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
