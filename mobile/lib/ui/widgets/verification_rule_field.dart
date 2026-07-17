import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../i18n/translations.g.dart';

/// Display helpers for a verification template/rule. Localized via slang — the
/// [Translations] instance is passed in so the pure helpers stay testable
/// (`AppLocale.en.buildSync()`) and usable outside a widget.
String verificationTemplateLabel(Translations t, String key) => switch (key) {
      'steps' => t.verification.templates.steps,
      'exercise_minutes' => t.verification.templates.exerciseMinutes,
      'active_energy' => t.verification.templates.activeEnergy,
      'stand_hours' => t.verification.templates.standHours,
      'distance' => t.verification.templates.distance,
      'mindful_minutes' => t.verification.templates.mindfulMinutes,
      'sleep_hours' => t.verification.templates.sleepHours,
      'workout' => t.verification.templates.workout,
      'screen_time_total' => t.verification.templates.screenTimeTotal,
      'screen_time_apps' => t.verification.templates.screenTimeApps,
      _ => key,
    };

/// The unit token for [unit] (e.g. "min", "h"), or empty for a plain count.
String verificationUnitSuffix(Translations t, VerificationUnit unit) =>
    switch (unit) {
      VerificationUnit.count => '',
      VerificationUnit.minutes => t.verification.units.minutes,
      VerificationUnit.hours => t.verification.units.hours,
      VerificationUnit.kilocalories => t.verification.units.kilocalories,
      VerificationUnit.kilometers => t.verification.units.kilometers,
    };

String _formatThreshold(double value, VerificationUnit unit) {
  final isWhole = value == value.roundToDouble();
  final number = isWhole
      ? value.round().toString()
      : value.toStringAsFixed(1);
  // Thousands separators for plain counts (e.g. 10,000 steps).
  if (unit == VerificationUnit.count && isWhole) {
    final digits = value.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
  return number;
}

/// Localized header for a template [category] (Activity / Mindfulness / …).
String verificationCategoryLabel(Translations t, VerificationCategory c) =>
    switch (c) {
      VerificationCategory.activity => t.verification.categories.activity,
      VerificationCategory.mindfulness => t.verification.categories.mindfulness,
      VerificationCategory.sleep => t.verification.categories.sleep,
      VerificationCategory.screenTime => t.verification.categories.screenTime,
    };

/// Groups [templates] by [VerificationCategory] in enum-declaration order,
/// preserving each template's order within its group and omitting empty groups.
/// Pure so the "organized into sections" layout is testable.
List<MapEntry<VerificationCategory, List<VerificationTemplate>>>
    groupTemplatesByCategory(List<VerificationTemplate> templates) {
  final byCategory = <VerificationCategory, List<VerificationTemplate>>{};
  for (final t in templates) {
    (byCategory[t.category] ??= <VerificationTemplate>[]).add(t);
  }
  return [
    for (final c in VerificationCategory.values)
      if (byCategory[c] != null) MapEntry(c, byCategory[c]!),
  ];
}

/// Human summary of a rule, e.g. "≥ 10,000 Steps" or "≤ 120 min Screen time".
String verificationRuleSummary(Translations t, VerificationRule rule) {
  final comparator =
      rule.comparator == VerificationComparator.atLeast ? '≥' : '≤';
  final number = _formatThreshold(rule.threshold, rule.unit);
  final unit = verificationUnitSuffix(t, rule.unit);
  final amount = unit.isEmpty ? number : '$number $unit';
  return '$comparator $amount ${verificationTemplateLabel(t, rule.metricKey)}';
}

/// A "?" indicator for a day whose auto-verification couldn't be determined
/// (D6) — permission off, no data, or the extension never fired. Tappable so the
/// user can resolve the day by hand. Ready to drop into the habit calendar's day
/// cells (that wiring is a follow-up — see DOCUMENTATION).
class CouldNotVerifyChip extends StatelessWidget {
  const CouldNotVerifyChip({super.key, this.onTap, this.size = 18});

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Tooltip(
      message: context.t.verification.couldNotVerifyTapToResolve,
      child: InkResponse(
        onTap: onTap,
        radius: size,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Text(
            '?',
            style: TextStyle(fontSize: size * 0.66, color: color, height: 1),
          ),
        ),
      ),
    );
  }
}

/// A small "auto-verified" indicator shown on verified habits.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({super.key, this.size = 15});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.t.verification.autoVerified,
      child: Icon(
        Icons.verified,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// A self-contained control for a habit's auto-verification rule (D5): a switch
/// to enable it, a template chooser, and a clamped threshold stepper. Emits a
/// [VerificationRule] (or null for a manual habit) via [onChanged].
class VerificationRuleField extends StatelessWidget {
  const VerificationRuleField({
    super.key,
    required this.rule,
    required this.onChanged,
    this.templates = VerificationCatalog.all,
  });

  final VerificationRule? rule;
  final ValueChanged<VerificationRule?> onChanged;

  /// The templates the user may choose from — pass a provider-filtered subset
  /// (e.g. HealthKit-only) so disabled providers aren't offered. Defaults to all.
  final List<VerificationTemplate> templates;

  VerificationTemplate get _currentTemplate =>
      rule?.template ??
      (templates.isNotEmpty ? templates.first : VerificationCatalog.steps);

  void _toggle(bool on) {
    if (!on || templates.isEmpty) {
      onChanged(null);
      return;
    }
    final first = templates.first;
    onChanged(first.ruleWith(first.defaultThreshold));
  }

  void _selectTemplate(VerificationTemplate template) {
    onChanged(template.ruleWith(template.defaultThreshold));
  }

  void _step(int direction) {
    final r = rule;
    if (r == null) return;
    final t = _currentTemplate;
    onChanged(r.copyWith(
      threshold: t.clampThreshold(r.threshold + direction * t.step),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = rule;
    final theme = Theme.of(context);
    final tr = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(tr.verification.autoVerify, style: theme.textTheme.titleSmall),
            CupertinoSwitch(value: r != null, onChanged: _toggle),
          ],
        ),
        if (r != null) ...[
          const SizedBox(height: 4),
          // Templates grouped into labelled sections (Activity / Mindfulness /
          // Sleep / Screen Time) for a scannable, organized picker.
          for (final group in groupTemplatesByCategory(templates)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                verificationCategoryLabel(tr, group.key).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final template in group.value)
                  ChoiceChip(
                    label: Text(verificationTemplateLabel(tr, template.key)),
                    selected: template.key == r.metricKey,
                    onSelected: (_) => _selectTemplate(template),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                key: const Key('verify_threshold_down'),
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: r.threshold <= _currentTemplate.minThreshold
                    ? null
                    : () => _step(-1),
              ),
              Expanded(
                child: Text(
                  verificationRuleSummary(tr, r),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const Key('verify_threshold_up'),
                icon: const Icon(Icons.add_circle_outline),
                onPressed: r.threshold >= _currentTemplate.maxThreshold
                    ? null
                    : () => _step(1),
              ),
            ],
          ),
          if (_currentTemplate.requiresWatch)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tr.verification.needsAppleWatch,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}
