import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../i18n/translations.g.dart';
import '../target_ring.dart';

/// A habit the user can link a macro goal to (its daily `goal_progress` then
/// feeds the goal's progress bar). Kept a plain value object so the field can be
/// widget-tested without wiring the goals provider.
class MacroHabitOption {
  const MacroHabitOption({required this.id, required this.title});

  final String id;
  final String title;
}

/// The numeric target chosen for a macro goal, or `null` for a plain boolean
/// goal. [linkedGoalId] null ⇒ manual entry, else the habit feeding it.
class MacroTargetDraft {
  const MacroTargetDraft({
    required this.amount,
    required this.unit,
    this.linkedGoalId,
  });

  final double amount;
  final TargetUnit unit;
  final String? linkedGoalId;

  MacroTargetDraft copyWith({
    double? amount,
    TargetUnit? unit,
    String? linkedGoalId,
    bool clearLink = false,
  }) => MacroTargetDraft(
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    linkedGoalId: clearLink ? null : (linkedGoalId ?? this.linkedGoalId),
  );
}

/// Create/edit control for a macro goal's optional NUMERIC target: a unit chip
/// row ("None" + each [TargetUnit]), an amount field, and a "track with a habit"
/// picker (Manual + the user's habits). Emits a [MacroTargetDraft] (or null for
/// a plain boolean goal) via [onChanged]. The four-axis target model never
/// reaches the user — this is a "reach the amount" (atLeast) target only.
///
/// The widget is NOT flag-gated itself; its call sites gate inclusion behind
/// [MacroTargetsConfig.enabled] so the field can be exercised in tests
/// independently of the compile-time flag (mirrors habit `TargetField`).
class MacroTargetField extends StatefulWidget {
  const MacroTargetField({
    super.key,
    required this.value,
    required this.habits,
    required this.onChanged,
  });

  final MacroTargetDraft? value;
  final List<MacroHabitOption> habits;
  final ValueChanged<MacroTargetDraft?> onChanged;

  @override
  State<MacroTargetField> createState() => _MacroTargetFieldState();
}

class _MacroTargetFieldState extends State<MacroTargetField> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    final amount = widget.value?.amount;
    _amountController = TextEditingController(
      text: amount == null ? '' : formatTargetAmount(amount),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectUnit(TargetUnit unit) {
    final current = widget.value;
    if (current == null) {
      final typed = double.tryParse(_amountController.text.replaceAll(',', '.'));
      final amount = (typed == null || typed <= 0) ? 1.0 : typed;
      if (_amountController.text.isEmpty) {
        _amountController.text = formatTargetAmount(amount);
      }
      widget.onChanged(MacroTargetDraft(amount: amount, unit: unit));
    } else {
      widget.onChanged(current.copyWith(unit: unit));
    }
  }

  void _onAmountChanged(String text) {
    final current = widget.value;
    if (current == null) return;
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    if (parsed == null) return; // keep the last valid amount
    widget.onChanged(current.copyWith(amount: parsed));
  }

  String _unitLabel(Translations t, TargetUnit unit) => unit == TargetUnit.count
      ? t.macroTargets.unitCount
      : targetUnitShortLabel(t, unit);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = context.t;
    final draft = widget.value;
    final unitShort =
        draft == null ? '' : targetUnitShortLabel(t, draft.unit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.macroTargets.sectionTitle,
          style: TextStyle(fontFamily: 'Inter', 
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
            _Chip(
              label: t.macroTargets.none,
              selected: draft == null,
              onTap: () => widget.onChanged(null),
            ),
            for (final unit in TargetUnit.values)
              _Chip(
                label: _unitLabel(t, unit),
                selected: draft?.unit == unit,
                onTap: () => _selectUnit(unit),
              ),
          ],
        ),
        if (draft != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                t.macroTargets.amountLabel,
                style: TextStyle(fontFamily: 'Inter', 
                  fontSize: 14,
                  color: colors.mutedForeground,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.right,
                  onChanged: _onAmountChanged,
                  style: TextStyle(fontFamily: 'Inter', 
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.foreground,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                ),
              ),
              if (unitShort.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  unitShort,
                  style: TextStyle(fontFamily: 'Inter', 
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.foreground,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            t.macroTargets.linkLabel,
            style: TextStyle(fontFamily: 'Inter', 
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                label: t.macroTargets.manual,
                selected: draft.linkedGoalId == null,
                onTap: () =>
                    widget.onChanged(draft.copyWith(clearLink: true)),
              ),
              for (final habit in widget.habits)
                _Chip(
                  label: habit.title,
                  selected: draft.linkedGoalId == habit.id,
                  onTap: () =>
                      widget.onChanged(draft.copyWith(linkedGoalId: habit.id)),
                ),
            ],
          ),
        ],
      ],
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
            style: TextStyle(fontFamily: 'Inter', 
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
