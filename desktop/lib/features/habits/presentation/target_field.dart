import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/target_ring.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';

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
          _AmountRow(
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

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.preset,
    required this.target,
    required this.onChanged,
  });

  final TargetPreset preset;
  final HabitTarget target;
  final ValueChanged<HabitTarget?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final unit = targetUnitShortLabel(target.unit);
    final step = preset.defaultStep;

    void bump(double delta) =>
        onChanged(target.copyWith(amount: preset.clampAmount(target.amount + delta)));

    return Row(
      children: [
        Text(
          preset.direction == TargetDirection.atMost
              ? t.targets.atMostLabel
              : t.targets.atLeastLabel,
          style: TextStyle(fontSize: 13, color: colors.muted),
        ),
        const Spacer(),
        _MiniStep(icon: Icons.remove, onTap: () => bump(-step)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            unit.isEmpty
                ? formatTargetAmount(target.amount)
                : '${formatTargetAmount(target.amount)} $unit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.foreground,
            ),
          ),
        ),
        _MiniStep(icon: Icons.add, onTap: () => bump(step)),
      ],
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
