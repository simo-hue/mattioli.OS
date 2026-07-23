import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_kit.dart';
import 'verification_rule_field.dart';

/// The compound-habit builder (Q8): shown beneath the primary [VerificationRuleField]
/// once a HealthKit rule is chosen. Renders the "Any of these / All of these"
/// operator toggle, the additional-condition summary rows (each removable), and a
/// Pro-gated "+ Add condition" affordance that opens the [showAddConditionSheet].
/// Purely presentational — all state lives in the parent modal.
class CompoundConditionsField extends StatelessWidget {
  const CompoundConditionsField({
    super.key,
    required this.primaryRule,
    required this.additionalConditions,
    required this.join,
    required this.isPro,
    required this.onConditionsChanged,
    required this.onJoinChanged,
    required this.onNeedPro,
  });

  /// Condition #1 — the rule from the inline [VerificationRuleField] above.
  final VerificationRule primaryRule;

  /// Conditions 2..3.
  final List<VerificationRule> additionalConditions;
  final VerificationJoin join;
  final bool isPro;

  final ValueChanged<List<VerificationRule>> onConditionsChanged;
  final ValueChanged<VerificationJoin> onJoinChanged;

  /// A free user tapped "+ Add condition" — the parent shows the paywall.
  final VoidCallback onNeedPro;

  int get _total => 1 + additionalConditions.length;
  bool get _canAddMore => _total < kMaxVerificationConditions;

  /// HealthKit templates not already used by any condition (Q2: compound is
  /// HealthKit-only; a metric is never combined with itself).
  List<VerificationTemplate> _availableTemplates() {
    final used = {
      primaryRule.metricKey,
      for (final c in additionalConditions) c.metricKey,
    };
    return [
      for (final t in VerificationCatalog.all)
        if (t.isHealthKit && !used.contains(t.key)) t,
    ];
  }

  Future<void> _add(BuildContext context) async {
    if (!isPro) {
      onNeedPro();
      return;
    }
    final templates = _availableTemplates();
    if (templates.isEmpty) return;
    final rule = await showAddConditionSheet(context, templates: templates);
    if (rule != null) {
      onConditionsChanged([...additionalConditions, rule]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.t;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (additionalConditions.isNotEmpty) ...[
          const SizedBox(height: 12),
          EvolveSegmentedControl<VerificationJoin>(
            segments: {
              VerificationJoin.or: tr.verification.compound.anyOfThese,
              VerificationJoin.and: tr.verification.compound.allOfThese,
            },
            groupValue: join,
            onValueChanged: onJoinChanged,
          ),
          const SizedBox(height: 6),
          Text(
            join == VerificationJoin.or
                ? tr.verification.compound.anyHelper
                : tr.verification.compound.allHelper,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: context.appColors.mutedForeground),
          ),
          for (var i = 0; i < additionalConditions.length; i++)
            _ConditionRow(
              rule: additionalConditions[i],
              onRemove: () =>
                  onConditionsChanged([...additionalConditions]..removeAt(i)),
            ),
        ],
        if (_canAddMore && _availableTemplates().isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(tr.verification.compound.addCondition),
              onPressed: () => _add(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// One removable summary row for an additional condition ("≥ 30 min Exercise ✕").
class _ConditionRow extends StatelessWidget {
  const _ConditionRow({required this.rule, required this.onRemove});

  final VerificationRule rule;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsetsDirectional.only(start: 12, top: 2, bottom: 2),
        decoration: BoxDecoration(
          color: context.appColors.muted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                verificationRuleSummary(context.t, rule),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              tooltip: context.t.common.actions.delete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet that configures one additional HealthKit condition — the
/// existing [VerificationRuleField] picker + threshold stepper, minus the enable
/// switch. Returns the picked [VerificationRule], or null if dismissed.
Future<VerificationRule?> showAddConditionSheet(
  BuildContext context, {
  required List<VerificationTemplate> templates,
}) {
  return showModalBottomSheet<VerificationRule>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _AddConditionSheet(templates: templates),
    ),
  );
}

class _AddConditionSheet extends StatefulWidget {
  const _AddConditionSheet({required this.templates});

  final List<VerificationTemplate> templates;

  @override
  State<_AddConditionSheet> createState() => _AddConditionSheetState();
}

class _AddConditionSheetState extends State<_AddConditionSheet> {
  late VerificationRule _rule;

  @override
  void initState() {
    super.initState();
    final t = widget.templates.first;
    _rule = t.ruleWith(t.defaultThreshold);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.t;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr.verification.compound.addSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                child: VerificationRuleField(
                  rule: _rule,
                  showSwitch: false,
                  templates: widget.templates,
                  onChanged: (r) {
                    if (r != null) setState(() => _rule = r);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            EvolveButton(
              label: tr.verification.compound.add,
              onPressed: () => Navigator.of(context).pop(_rule),
            ),
          ],
        ),
      ),
    );
  }
}
