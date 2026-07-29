import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_kit.dart';

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

/// Formats a threshold for display in [localeCode]'s own conventions — grouping
/// and decimal separators both, so 10000 reads "10,000" in English but "10.000"
/// in Italian and German, and 0.5 reads "0,5" rather than "0.5". Previously this
/// hardcoded "," as the group separator for every language, which was invisible
/// while rule summaries only appeared in the editor and wrong everywhere else.
///
/// [localeCode] defaults to the app's current locale, for the widget call sites
/// that format outside `build` and so cannot reach an inherited [Translations].
/// [verificationRuleSummary] passes it explicitly, keeping that helper pure and
/// testable against any locale.
///
/// Safe for the editable threshold field even though it inserts separators: for
/// an integer metric [_VerificationRuleFieldState._parse] strips every non-digit,
/// and focusing the field swaps this form for [_editThreshold]'s plain digits
/// before the user can type over it.
String _formatThreshold(double value, {String? localeCode}) {
  final code = localeCode ?? LocaleSettings.currentLocale.languageCode;
  final isWhole = value == value.roundToDouble();
  final format = NumberFormat.decimalPattern(code)
    ..minimumFractionDigits = isWhole ? 0 : 1
    ..maximumFractionDigits = isWhole ? 0 : 1;
  return format.format(value);
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
///
/// Set [includeMetricLabel] false for the threshold alone ("≥ 10,000") — used
/// where the metric is already named by its surroundings, so repeating it would
/// only cost width. See [habitVerificationLabel].
String verificationRuleSummary(
  Translations t,
  VerificationRule rule, {
  bool includeMetricLabel = true,
}) {
  final comparator =
      rule.comparator == VerificationComparator.atLeast ? '≥' : '≤';
  final number = _formatThreshold(
    rule.threshold,
    localeCode: t.$meta.locale.languageCode,
  );
  final unit = verificationUnitSuffix(t, rule.unit);
  final amount = unit.isEmpty ? number : '$number $unit';
  if (!includeMetricLabel) return '$comparator $amount';
  return '$comparator $amount ${verificationTemplateLabel(t, rule.metricKey)}';
}

/// The one-line label describing what an auto-verified habit is measured
/// against, as shown beneath the habit's name.
///
/// A single rule reads as its summary ("≥ 30 min Workout"), except that the
/// metric label is dropped when it merely echoes [habitTitle] ("Workout /
/// ≥ 30 min Workout"). That echo is the COMMON case, not an edge one: creating a
/// rule auto-fills the habit name from this very label, so most auto-verified
/// habits are named after their metric until the user renames them. The
/// comparison is a plain locale-bound string match — create a habit in Italian,
/// switch the app to English, and it misses, yielding the full summary. That
/// degrades toward more information, never toward a wrong or empty line, which
/// is why no persisted flag backs it.
///
/// A compound habit reads as its join plus condition count ("All 2
/// conditions"), because two or three full summaries never fit one row. A null
/// join means "any", matching how the engine reads it (`verification_wiring`
/// coerces a null join to [VerificationJoin.or]) — the label must never claim a
/// stricter rule than the one actually evaluated.
///
/// Empty for a manual habit, so callers can render nothing without a null check.
String habitVerificationLabel(
  Translations t, {
  required List<VerificationRule> conditions,
  required VerificationJoin? join,
  required String habitTitle,
}) {
  if (conditions.isEmpty) return '';
  if (conditions.length > 1) {
    return join == VerificationJoin.and
        ? t.verification.compound.summaryAll(count: conditions.length)
        : t.verification.compound.summaryAny(count: conditions.length);
  }
  final rule = conditions.first;
  final echoesTitle =
      verificationTemplateLabel(t, rule.metricKey).trim().toLowerCase() ==
          habitTitle.trim().toLowerCase();
  return verificationRuleSummary(t, rule, includeMetricLabel: !echoesTitle);
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

/// The quiet second line marking a habit as auto-verified, shown directly under
/// the habit's name: a shield plus the rule the habit is measured against
/// ("≥ 30 min"), or — when a day's verification couldn't be determined — the
/// actionable "not verified" prompt.
///
/// It replaced an inline pill that shared row 1 with the habit name. The pill was
/// laid out at its intrinsic width (~180pt for the Italian "Verificato
/// automaticamente"), leaving the name so little room it broke mid-word; giving
/// the name the whole of row 1 and the marker its own row fixes that while also
/// making space for something more useful than a generic label.
///
/// Always exactly ONE row: every variant is `maxLines: 1` with an ellipsis, so a
/// card carrying this line keeps the same height in every state and the list
/// doesn't jump when a day resolves. The line stays muted while the card is
/// pending / done / missed — the rule is metadata, not status, and a green
/// "≥ 30 min" would read as "you did 30 min" — and takes the accent colour only
/// in the couldn't-verify state, where the line IS the actionable status.
///
/// Takes the rule pieces rather than a `Goal` so this file stays free of a
/// `models/` dependency and the label logic can be unit-tested without one.
/// Renders nothing when there are no conditions and [couldNotVerify] is false.
class VerificationLine extends StatelessWidget {
  const VerificationLine({
    super.key,
    required this.conditions,
    required this.join,
    required this.habitTitle,
    this.couldNotVerify = false,
    this.ruleInEffect = true,
  });

  final List<VerificationRule> conditions;
  final VerificationJoin? join;
  final String habitTitle;

  /// True for a habit-day whose auto-verification is unresolved (D6). Swaps the
  /// line's content for the resolve prompt instead of adding a second row.
  final bool couldNotVerify;

  /// Whether [conditions] is the rule that actually governed the day being shown
  /// (`Goal.verificationRuleAppliesOn`). False on a day that predates a rule edit,
  /// where naming a threshold would misreport what the day was judged against —
  /// the line falls back to the generic "auto-verified", which cannot be wrong.
  /// Callers with no particular day in view leave this true.
  final bool ruleInEffect;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final accent = Theme.of(context).colorScheme.primary;
    final label = couldNotVerify
        ? t.verification.couldNotVerifyShort
        : !ruleInEffect
            ? (conditions.isEmpty ? '' : t.verification.autoVerified)
            : habitVerificationLabel(
                t,
                conditions: conditions,
                join: join,
                habitTitle: habitTitle,
              );
    if (label.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          couldNotVerify ? LucideIcons.shieldAlert : LucideIcons.shieldCheck,
          size: 12,
          color: accent,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: couldNotVerify
                  ? accent
                  : context.appColors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}

/// Whether [t]'s threshold is meaningfully fractional (e.g. distance in 0.5 km,
/// sleep in 0.5 h steps) — decides whether the typed field accepts a decimal
/// point and whether a typed value is rounded to a whole number.
bool _templateAllowsDecimal(VerificationTemplate tmpl) =>
    tmpl.step != tmpl.step.roundToDouble();

class _DoneKeyboardAccessory extends StatefulWidget {
  final VoidCallback onDone;
  const _DoneKeyboardAccessory({required this.onDone});

  @override
  State<_DoneKeyboardAccessory> createState() => _DoneKeyboardAccessoryState();
}

class _DoneKeyboardAccessoryState extends State<_DoneKeyboardAccessory> with WidgetsBindingObserver {
  double _bottom = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = View.of(context);
    final bottom = view.viewInsets.bottom / view.devicePixelRatio;
    if (_bottom != bottom) {
      setState(() {
        _bottom = bottom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bottom == 0) return const SizedBox.shrink();
    return Positioned(
      bottom: _bottom,
      left: 0,
      right: 0,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onPressed: widget.onDone,
              child: Text(
                context.t.common.actions.done,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain, separator-free text for *editing* a threshold (e.g. "10000", "7.5"),
/// as opposed to [_formatThreshold]'s display form ("10,000") which is nicer to
/// read but awkward to type over.
String _editThreshold(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);

/// A self-contained control for a habit's auto-verification rule (D5): a switch
/// to enable it, a template chooser, and a threshold picker. The threshold can
/// be nudged with the +/− steppers *or* typed in directly — the centre value is
/// an editable numeric field, clamped to the template's range on commit. Emits a
/// [VerificationRule] (or null for a manual habit) via [onChanged].
class VerificationRuleField extends StatefulWidget {
  const VerificationRuleField({
    super.key,
    required this.rule,
    required this.onChanged,
    this.templates = VerificationCatalog.all,
    this.showSwitch = true,
  });

  final VerificationRule? rule;
  final ValueChanged<VerificationRule?> onChanged;

  /// Whether to show the "Auto-verify" enable switch. False inside the compound
  /// "add a condition" sheet, where the control is just a metric picker +
  /// threshold stepper for an always-present condition.
  final bool showSwitch;

  /// The templates the user may choose from — pass a provider-filtered subset
  /// (e.g. HealthKit-only) so disabled providers aren't offered. Defaults to all.
  final List<VerificationTemplate> templates;

  @override
  State<VerificationRuleField> createState() => _VerificationRuleFieldState();
}

class _VerificationRuleFieldState extends State<VerificationRuleField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    final r = widget.rule;
    if (r != null) _controller.text = _formatThreshold(r.threshold);
  }

  @override
  void didUpdateWidget(covariant VerificationRuleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in sync when the value changes from *outside* the field —
    // a +/− tap, a template switch, an edit reset — but never overwrite what the
    // user is actively typing.
    final r = widget.rule;
    if (r == null || _focusNode.hasFocus) return;
    final desired = _formatThreshold(r.threshold);
    if (_controller.text != desired) _controller.text = desired;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _hideOverlay();
    super.dispose();
  }

  VerificationTemplate get _currentTemplate =>
      widget.rule?.template ??
      (widget.templates.isNotEmpty
          ? widget.templates.first
          : VerificationCatalog.steps);

  void _toggle(bool on) {
    if (!on || widget.templates.isEmpty) {
      widget.onChanged(null);
      return;
    }
    final first = widget.templates.first;
    widget.onChanged(first.ruleWith(first.defaultThreshold));
  }

  void _selectTemplate(VerificationTemplate template) {
    widget.onChanged(template.ruleWith(template.defaultThreshold));
  }

  void _step(int direction) {
    final r = widget.rule;
    if (r == null) return;
    final t = _currentTemplate;
    widget.onChanged(r.copyWith(
      threshold: t.clampThreshold(r.threshold + direction * t.step),
    ));
  }

  /// Parses the raw field text into a threshold value, or null when it isn't a
  /// number yet (empty / mid-typing) so the user can keep going. Rounds to a
  /// whole number for count/integer metrics; honours a decimal point for the
  /// fractional ones (distance, sleep).
  double? _parse(String text) {
    final allowsDecimal = _templateAllowsDecimal(_currentTemplate);
    var s = text.trim();
    // Accept a comma as the decimal separator (it/de keyboards) for fractional
    // metrics; strip any non-digit for integer ones.
    s = allowsDecimal
        ? s.replaceAll(',', '.')
        : s.replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty) return null;
    final v = double.tryParse(s);
    if (v == null) return null;
    return allowsDecimal ? v : v.roundToDouble();
  }

  void _onType(String text) {
    final r = widget.rule;
    if (r == null) return;
    final parsed = _parse(text);
    if (parsed == null) return; // empty / not-a-number yet — don't emit
    final clamped = _currentTemplate.clampThreshold(parsed);
    if (clamped != r.threshold) {
      widget.onChanged(r.copyWith(threshold: clamped));
    }
  }

  void _onFocusChange() {
    final r = widget.rule;
    if (r == null) return;
    if (_focusNode.hasFocus) {
      _showOverlay();
      // Entering edit mode: swap the pretty "10,000" for a plain "10000" and
      // select it, so the first keystroke replaces the whole value.
      final edit = _editThreshold(r.threshold);
      _controller.value = TextEditingValue(
        text: edit,
        selection: TextSelection(baseOffset: 0, extentOffset: edit.length),
      );
    } else {
      _hideOverlay();
      // Leaving edit mode: clamp whatever was typed into range, re-format, and
      // commit the final value.
      final value =
          _currentTemplate.clampThreshold(_parse(_controller.text) ?? r.threshold);
      _controller.text = _formatThreshold(value);
      if (value != r.threshold) widget.onChanged(r.copyWith(threshold: value));
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(
      builder: (context) => _DoneKeyboardAccessory(onDone: () => _focusNode.unfocus()),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// "1,000–100,000" (plus a unit token) — the accepted range, shown under the
  /// field so a typed value that gets clamped isn't a surprise.
  String _rangeHint(Translations t, VerificationTemplate tmpl) {
    final unit = verificationUnitSuffix(t, tmpl.unit);
    final locale = t.$meta.locale.languageCode;
    final range = '${_formatThreshold(tmpl.minThreshold, localeCode: locale)}'
        '–${_formatThreshold(tmpl.maxThreshold, localeCode: locale)}';
    return unit.isEmpty ? range : '$range $unit';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rule;
    final theme = Theme.of(context);
    final tr = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showSwitch)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr.verification.autoVerify,
                  style: theme.textTheme.titleSmall),
              CupertinoSwitch(value: r != null, onChanged: _toggle),
            ],
          ),
        if (r != null) ...[
          const SizedBox(height: 4),
          // Templates grouped into labelled sections (Activity / Mindfulness /
          // Sleep / Screen Time) for a scannable, organized picker.
          for (final group in groupTemplatesByCategory(widget.templates)) ...[
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
          if (r.isScreenTime) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: EvolveSegmentedControl<VerificationComparator>(
                segments: {
                  VerificationComparator.atLeast: tr.verification.comparatorAtLeast,
                  VerificationComparator.atMost: tr.verification.comparatorAtMost,
                },
                groupValue: r.comparator,
                onValueChanged: (c) => widget.onChanged(r.copyWith(comparator: c)),
              ),
            ),
          ],
          // Threshold: −/+ steppers flanking a directly-editable number. The
          // comparator and unit sit inline as read-only context; the metric name
          // is already shown by the selected chip above.
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      r.comparator == VerificationComparator.atLeast
                          ? '≥'
                          : '≤',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        key: const Key('verify_threshold_input'),
                        controller: _controller,
                        focusNode: _focusNode,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: _templateAllowsDecimal(_currentTemplate),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            _templateAllowsDecimal(_currentTemplate)
                                ? RegExp(r'[0-9.,]')
                                : RegExp(r'[0-9]'),
                          ),
                        ],
                        style: theme.textTheme.titleMedium,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                        onTapOutside: (_) => _focusNode.unfocus(),
                        onChanged: _onType,
                        onSubmitted: (_) => _focusNode.unfocus(),
                      ),
                    ),
                    if (verificationUnitSuffix(tr, r.unit).isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        verificationUnitSuffix(tr, r.unit),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ],
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
          Center(
            child: Text(
              _rangeHint(tr, _currentTemplate),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
