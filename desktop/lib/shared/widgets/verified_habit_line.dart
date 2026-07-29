import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Display helpers for a habit's verification rule, mirroring mobile's
/// `verification_rule_field.dart` so the same habit is worded identically on both
/// platforms. Deliberate duplication: the two apps have separate slang
/// `Translations` types, so a shared package could not take one.
///
/// macOS never verifies anything — these are read-only.

/// The localized name of the metric behind [key], or [key] itself if this build
/// doesn't know it (a rule written by a newer iPhone).
String verificationTemplateLabel(String key) => switch (key) {
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
String verificationUnitSuffix(VerificationUnit unit) => switch (unit) {
      VerificationUnit.count => '',
      VerificationUnit.minutes => t.verification.units.minutes,
      VerificationUnit.hours => t.verification.units.hours,
      VerificationUnit.kilocalories => t.verification.units.kilocalories,
      VerificationUnit.kilometers => t.verification.units.kilometers,
    };

/// Formats a threshold in the locale's own conventions — grouping and decimal
/// separators both, so 10000 reads "10,000" in English but "10.000" in Italian
/// and German, and 0.5 reads "0,5" rather than "0.5".
///
/// The locale comes from the `Translations` instance actually supplying the
/// surrounding words, NOT from `LocaleSettings.currentLocale`. Those are two
/// different sources of truth: slang flips `currentLocale` before a deferred
/// locale finishes loading and falls back to the base translations meanwhile, so
/// reading the setting could pair German grouping with English words. Same
/// reason mobile threads its locale through explicitly.
String _formatThreshold(double value) {
  final isWhole = value == value.roundToDouble();
  final format = NumberFormat.decimalPattern(t.$meta.locale.languageCode)
    ..minimumFractionDigits = isWhole ? 0 : 1
    ..maximumFractionDigits = isWhole ? 0 : 1;
  return format.format(value);
}

/// Human summary of a rule, e.g. "≥ 10,000 Steps" or "≤ 120 min Screen time".
/// Set [includeMetricLabel] false for the threshold alone.
String verificationRuleSummary(
  VerificationRule rule, {
  bool includeMetricLabel = true,
}) {
  final comparator =
      rule.comparator == VerificationComparator.atLeast ? '≥' : '≤';
  final number = _formatThreshold(rule.threshold);
  final unit = verificationUnitSuffix(rule.unit);
  final amount = unit.isEmpty ? number : '$number $unit';
  if (!includeMetricLabel) return '$comparator $amount';
  return '$comparator $amount ${verificationTemplateLabel(rule.metricKey)}';
}

/// The one-line label describing what an auto-verified habit is measured
/// against. Mirrors mobile's `habitVerificationLabel` decision for decision:
///
/// A single rule reads as its summary, minus the metric label when that merely
/// echoes [habitTitle] — the common case, because creating a rule on iPhone
/// auto-fills the habit name from this very label. A compound habit reads as its
/// join plus condition count, since two or three summaries never fit one row; a
/// null join means "any", matching how the iPhone's engine coerces it, so the
/// label can never claim a stricter rule than the one actually evaluated.
///
/// Empty for a manual habit, so callers can render nothing without a null check.
String habitVerificationLabel({
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
  final echoesTitle = verificationTemplateLabel(rule.metricKey)
          .trim()
          .toLowerCase() ==
      habitTitle.trim().toLowerCase();
  return verificationRuleSummary(rule, includeMetricLabel: !echoesTitle);
}

/// The quiet line marking a habit as auto-verified from the user's iPhone
/// (HealthKit / Screen Time), shown directly under the habit's name: a shield
/// plus the rule the habit is measured against ("≥ 30 min").
///
/// Replaced a `VerifiedHabitBadge` pill that sat inline with the habit name. On
/// mobile that arrangement starved the name of width until it broke mid-word;
/// the pill's short "Verified" label hid the problem here, but naming the rule
/// would have reproduced it exactly, so both platforms now give the name its own
/// full-width row and the marker its own.
///
/// One row always — `maxLines: 1` + ellipsis. macOS has no verification engine,
/// so unlike mobile there is no unresolved-day variant. Gate the caller on
/// `habit.verificationRule != null`.
///
/// Requires an [Overlay] ancestor, because the tooltip does — fine under
/// `MaterialApp`, but it will assert in a bare test harness or an overlay-less
/// route. Note also that while the tooltip is showing, the label text exists
/// twice in the tree (row + overlay), so a hover-then-`findsOneWidget` assertion
/// would fail.
class VerifiedHabitLine extends StatelessWidget {
  const VerifiedHabitLine({
    super.key,
    required this.conditions,
    required this.join,
    required this.habitTitle,
    this.ruleInEffect = true,
  });

  final List<VerificationRule> conditions;
  final VerificationJoin? join;
  final String habitTitle;

  /// Whether [conditions] is the rule that governed the day on screen. False on
  /// a day predating a rule edit (rule edits apply forward only), where naming a
  /// threshold would misreport what the day was judged against — the line falls
  /// back to the generic "auto-verified", which cannot be wrong. Callers with no
  /// particular day in view leave this true.
  final bool ruleInEffect;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final label = ruleInEffect
        ? habitVerificationLabel(
            conditions: conditions,
            join: join,
            habitTitle: habitTitle,
          )
        : (conditions.isEmpty ? '' : t.verification.autoVerified);
    if (label.isEmpty) return const SizedBox.shrink();

    // The pill this replaced carried a tooltip, and on macOS hover is the norm —
    // keep one, because a single ellipsized line is otherwise a dead end when the
    // rule doesn't fit. The tooltip repeats the full label rather than the old
    // generic word, so it is the thing the truncation hid.
    return Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.shieldCheck, size: 11, color: context.evolveAccent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: colors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
