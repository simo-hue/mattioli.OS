import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
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
  });

  final HabitTarget? target;
  final ValueChanged<HabitTarget?> onChanged;

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
          _AmountRow(
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

class _AmountRow extends StatelessWidget {
  const _AmountRow({
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
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = context.t;
    final unit = targetUnitShortLabel(t, target.unit);
    final step = preset.defaultStep;

    void bump(double delta) {
      haptic();
      final next = preset.clampAmount(target.amount + delta);
      onChanged(target.copyWith(amount: next));
    }

    return Row(
      children: [
        Text(
          preset.direction == TargetDirection.atMost
              ? t.targets.atMostLabel
              : t.targets.atLeastLabel,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: colors.mutedForeground,
          ),
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
              fontFamily: 'Inter',
              fontSize: 18,
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
