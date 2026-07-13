import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Display helpers for a verification template/rule — English fallbacks. i18n of
/// these labels is a documented follow-up (see TO_SIMO_DO); the whole field is
/// dark behind VerificationConfig until then.
String verificationTemplateLabel(String key) => switch (key) {
      'steps' => 'Steps',
      'exercise_minutes' => 'Exercise minutes',
      'active_energy' => 'Active energy',
      'stand_hours' => 'Stand hours',
      'distance' => 'Distance',
      'mindful_minutes' => 'Mindful minutes',
      'sleep_hours' => 'Sleep hours',
      'workout' => 'Workout',
      'screen_time_total' => 'Screen time',
      _ => key,
    };

String verificationUnitSuffix(VerificationUnit unit) => switch (unit) {
      VerificationUnit.count => '',
      VerificationUnit.minutes => ' min',
      VerificationUnit.hours => ' h',
      VerificationUnit.kilocalories => ' kcal',
      VerificationUnit.kilometers => ' km',
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

/// Human summary of a rule, e.g. "≥ 10,000 Steps" or "≤ 120 min Screen time".
String verificationRuleSummary(VerificationRule rule) {
  final comparator = rule.comparator == VerificationComparator.atLeast ? '≥' : '≤';
  final amount = '${_formatThreshold(rule.threshold, rule.unit)}'
      '${verificationUnitSuffix(rule.unit)}';
  return '$comparator $amount ${verificationTemplateLabel(rule.metricKey)}';
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
      message: "Couldn't verify — tap to resolve",
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
      message: 'Auto-verified',
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
  });

  final VerificationRule? rule;
  final ValueChanged<VerificationRule?> onChanged;

  VerificationTemplate get _currentTemplate =>
      rule?.template ?? VerificationCatalog.steps;

  void _toggle(bool on) {
    onChanged(on ? VerificationCatalog.steps.ruleWith(
        VerificationCatalog.steps.defaultThreshold) : null);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Auto-verify', style: theme.textTheme.titleSmall),
            CupertinoSwitch(value: r != null, onChanged: _toggle),
          ],
        ),
        if (r != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in VerificationCatalog.all)
                ChoiceChip(
                  label: Text(verificationTemplateLabel(t.key)),
                  selected: t.key == r.metricKey,
                  onSelected: (_) => _selectTemplate(t),
                ),
            ],
          ),
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
                  verificationRuleSummary(r),
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
                'Needs an Apple Watch to auto-verify',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}
