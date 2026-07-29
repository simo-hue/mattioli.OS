import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/ui/widgets/verification_rule_field.dart';
import 'package:mattioli_os/core/theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps [child] in the TranslationProvider the verification widgets now need
/// for `context.t` (localized labels/tooltips).
Widget _app(Widget child) => ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(theme: AppTheme.lightTheme(null), home: Scaffold(body: child)),
      ),
    );

class _Harness extends StatefulWidget {
  const _Harness(this.initial);
  final VerificationRule? initial;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late VerificationRule? rule = widget.initial;
  @override
  Widget build(BuildContext context) => VerificationRuleField(
        rule: rule,
        onChanged: (r) => setState(() => rule = r),
      );
}

/// Like [_Harness] but forwards every emitted rule to [onChanged] (so a test can
/// assert the exact value) while still re-rendering with it. Not self-wrapped —
/// pass it through [_app].
class _Recorder extends StatefulWidget {
  const _Recorder({required this.initial, required this.onChanged});
  final VerificationRule? initial;
  final ValueChanged<VerificationRule?> onChanged;
  @override
  State<_Recorder> createState() => _RecorderState();
}

class _RecorderState extends State<_Recorder> {
  late VerificationRule? rule = widget.initial;
  @override
  Widget build(BuildContext context) => VerificationRuleField(
        rule: rule,
        onChanged: (r) {
          widget.onChanged(r);
          setState(() => rule = r);
        },
      );
}

/// The current text shown in the editable threshold field.
String _thresholdText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('verify_threshold_input')))
    .controller!
    .text;

void main() {
  final t = AppLocale.en.buildSync();

  group('verificationRuleSummary', () {
    test('formats HealthKit and Screen Time rules', () {
      expect(
        verificationRuleSummary(t, VerificationCatalog.steps.ruleWith(10000)),
        '≥ 10,000 Steps',
      );
      expect(
        verificationRuleSummary(
            t, VerificationCatalog.screenTimeTotal.ruleWith(120)),
        '≤ 120 min Total device usage',
      );
      expect(
        verificationRuleSummary(t, VerificationCatalog.sleepHours.ruleWith(8)),
        '≥ 8 h Sleep hours',
      );
    });
  });

  group('verificationRuleSummary number formatting', () {
    // Non-base locales are deferred, so they have to be built asynchronously —
    // `buildSync` throws "Deferred library not loaded" for anything but `en`.
    test('groups thousands in the locale\'s own convention', () async {
      // Italian and German group with "." — this used to hardcode "," for every
      // language, which was wrong everywhere but English.
      expect(
        verificationRuleSummary(
            await AppLocale.it.build(), VerificationCatalog.steps.ruleWith(10000)),
        '≥ 10.000 Passi',
      );
      expect(
        verificationRuleSummary(
            await AppLocale.de.build(), VerificationCatalog.steps.ruleWith(10000)),
        startsWith('≥ 10.000 '),
      );
    });

    test('a fractional threshold uses the locale decimal separator', () async {
      expect(
        verificationRuleSummary(
            await AppLocale.it.build(), VerificationCatalog.distance.ruleWith(2.5)),
        startsWith('≥ 2,5 '),
      );
      expect(
        verificationRuleSummary(t, VerificationCatalog.distance.ruleWith(2.5)),
        startsWith('≥ 2.5 '),
      );
    });

    test('no decimal-capable template can reach a grouped threshold', () {
      // Guards a latent 1000x data loss. `_formatThreshold` now groups for EVERY
      // unit, but `_parse` only strips separators for INTEGER templates; for a
      // decimal-capable one it just maps "," to ".". So an Italian "1.500" would
      // parse as 1.5 on blur. Unreachable today only because every fractional
      // template maxes out below 1,000 — this pins that assumption so raising a
      // range fails here instead of silently dividing a user's threshold.
      final decimalCapable = VerificationCatalog.all
          .where((t) => t.step != t.step.roundToDouble())
          .toList();
      expect(decimalCapable, isNotEmpty, reason: 'sanity: distance, sleep_hours');
      for (final tmpl in decimalCapable) {
        expect(tmpl.maxThreshold, lessThan(1000),
            reason: '${tmpl.key} can now reach a grouped number; make _parse '
                'locale-aware before raising this range');
      }
    });

    test('omits the metric label when asked', () {
      expect(
        verificationRuleSummary(t, VerificationCatalog.steps.ruleWith(10000),
            includeMetricLabel: false),
        '≥ 10,000',
      );
    });
  });

  group('habitVerificationLabel', () {
    VerificationRule steps(double n) => VerificationCatalog.steps.ruleWith(n);

    test('drops the metric label when it only echoes the habit name', () {
      // The common case: creating a rule auto-fills the name from this label.
      expect(
        habitVerificationLabel(t,
            conditions: [steps(10000)], join: null, habitTitle: 'Steps'),
        '≥ 10,000',
      );
    });

    test('the echo check ignores case and surrounding whitespace', () {
      expect(
        habitVerificationLabel(t,
            conditions: [steps(10000)], join: null, habitTitle: '  steps '),
        '≥ 10,000',
      );
    });

    test('keeps the metric label when the habit is named something else', () {
      expect(
        habitVerificationLabel(t,
            conditions: [steps(10000)], join: null, habitTitle: 'Morning walk'),
        '≥ 10,000 Steps',
      );
    });

    test('a compound habit reads as its join and condition count', () {
      expect(
        habitVerificationLabel(
          t,
          conditions: [steps(8000), VerificationCatalog.workout.ruleWith(30)],
          join: VerificationJoin.and,
          habitTitle: 'Full training',
        ),
        'All 2 conditions',
      );
      expect(
        habitVerificationLabel(
          t,
          conditions: [
            steps(8000),
            VerificationCatalog.workout.ruleWith(30),
            VerificationCatalog.standHours.ruleWith(10),
          ],
          join: VerificationJoin.or,
          habitTitle: 'Movement',
        ),
        'Any of 3 conditions',
      );
    });

    test('a compound with no join reads as "any", like the engine treats it', () {
      // verification_wiring coerces a null join to OR before evaluating, so the
      // label must not claim a stricter rule than the one actually run.
      expect(
        habitVerificationLabel(
          t,
          conditions: [steps(8000), VerificationCatalog.workout.ruleWith(30)],
          join: null,
          habitTitle: 'Movement',
        ),
        'Any of 2 conditions',
      );
    });

    test('a manual habit has no label', () {
      expect(
        habitVerificationLabel(t,
            conditions: const [], join: null, habitTitle: 'Read'),
        '',
      );
    });
  });

  group('groupTemplatesByCategory', () {
    test('groups in category order, preserves within-group order', () {
      final groups = groupTemplatesByCategory(VerificationCatalog.all);
      expect(groups.map((g) => g.key), [
        VerificationCategory.activity,
        VerificationCategory.mindfulness,
        VerificationCategory.sleep,
        VerificationCategory.screenTime,
      ]);
      expect(groups.first.value.map((t) => t.key), [
        'steps',
        'exercise_minutes',
        'active_energy',
        'stand_hours',
        'distance',
        'workout',
      ]);
    });

    test('a HealthKit-only subset omits the empty Screen Time group', () {
      final hk = VerificationCatalog.all.where((t) => t.isHealthKit).toList();
      final groups = groupTemplatesByCategory(hk);
      expect(groups.map((g) => g.key),
          isNot(contains(VerificationCategory.screenTime)));
    });
  });

  group('VerificationRuleField', () {
    testWidgets('renders localized category section headers', (tester) async {
      await tester
          .pumpWidget(_app(_Harness(VerificationCatalog.steps.ruleWith(10000))));
      await tester.pumpAndSettle();
      expect(find.text('ACTIVITY'), findsOneWidget);
      expect(find.text('SLEEP'), findsOneWidget);
      expect(find.text('SCREEN TIME'), findsOneWidget);
    });

    testWidgets('manual by default — switch off, no template chips',
        (tester) async {
      await tester.pumpWidget(_app(const _Harness(null)));
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
        isFalse,
      );
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('toggling on emits the default steps rule', (tester) async {
      await tester.pumpWidget(_app(const _Harness(null)));
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(_thresholdText(tester), '10,000');
      expect(find.text('≥'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(10));
    });

    testWidgets('selecting a template switches the rule + its default',
        (tester) async {
      await tester.pumpWidget(_app(_Harness(VerificationCatalog.steps.ruleWith(10000))));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Total device usage'));
      await tester.pumpAndSettle();
      expect(_thresholdText(tester), '120');
      expect(find.text('≤'), findsOneWidget);
      expect(find.text('min'), findsOneWidget);
    });

    testWidgets('stepper increments the threshold by the template step',
        (tester) async {
      await tester.pumpWidget(_app(_Harness(VerificationCatalog.steps.ruleWith(10000))));
      await tester.tap(find.byKey(const Key('verify_threshold_up')));
      await tester.pumpAndSettle();
      expect(_thresholdText(tester), '10,100');
    });

    testWidgets('typing a specific number sets that threshold', (tester) async {
      VerificationRule? emitted;
      await tester.pumpWidget(_app(_Recorder(
        initial: VerificationCatalog.steps.ruleWith(10000),
        onChanged: (r) => emitted = r,
      )));
      await tester.enterText(
          find.byKey(const Key('verify_threshold_input')), '8000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(emitted?.threshold, 8000);
      expect(_thresholdText(tester), '8,000'); // re-formatted on commit
    });

    testWidgets('a typed out-of-range number is clamped on commit',
        (tester) async {
      VerificationRule? emitted;
      await tester.pumpWidget(_app(_Recorder(
        initial: VerificationCatalog.steps.ruleWith(10000),
        onChanged: (r) => emitted = r,
      )));
      await tester.enterText(
          find.byKey(const Key('verify_threshold_input')), '9999999');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(emitted?.threshold, VerificationCatalog.steps.maxThreshold);
      expect(_thresholdText(tester), '1,000,000');
    });

    testWidgets('a fractional metric accepts a decimal value', (tester) async {
      VerificationRule? emitted;
      await tester.pumpWidget(_app(_Recorder(
        initial: VerificationCatalog.distance.ruleWith(5),
        onChanged: (r) => emitted = r,
      )));
      await tester.enterText(
          find.byKey(const Key('verify_threshold_input')), '7.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(emitted?.threshold, 7.5);
      expect(_thresholdText(tester), '7.5');
      expect(find.text('km'), findsOneWidget);
    });

    testWidgets('down stepper is disabled at the minimum threshold',
        (tester) async {
      await tester.pumpWidget(_app(_Harness(VerificationCatalog.steps
          .ruleWith(VerificationCatalog.steps.minThreshold))));
      final down = tester.widget<IconButton>(
          find.byKey(const Key('verify_threshold_down')));
      expect(down.onPressed, isNull);
    });

    testWidgets('Watch-dependent templates show the warning', (tester) async {
      await tester
          .pumpWidget(_app(_Harness(VerificationCatalog.standHours.ruleWith(12))));
      expect(find.text('Needs an Apple Watch to auto-verify'), findsOneWidget);
    });
  });

  group('VerificationLine', () {
    testWidgets('shows a shield and the rule it is measured against',
        (tester) async {
      await tester.pumpWidget(_app(VerificationLine(
        conditions: [VerificationCatalog.steps.ruleWith(10000)],
        join: null,
        habitTitle: 'Morning walk',
      )));

      expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
      expect(find.text('≥ 10,000 Steps'), findsOneWidget);
    });

    testWidgets('swaps to the alert variant when the day is unresolved',
        (tester) async {
      await tester.pumpWidget(_app(VerificationLine(
        conditions: [VerificationCatalog.steps.ruleWith(10000)],
        join: null,
        habitTitle: 'Morning walk',
        couldNotVerify: true,
      )));

      expect(find.byIcon(LucideIcons.shieldAlert), findsOneWidget);
      expect(find.text('Not verified — tap'), findsOneWidget);
      // Never both: the card's height has to stay constant across states.
      expect(find.text('≥ 10,000 Steps'), findsNothing);
      expect(find.byIcon(LucideIcons.shieldCheck), findsNothing);
    });

    testWidgets('renders nothing for a habit with no conditions',
        (tester) async {
      await tester.pumpWidget(_app(const VerificationLine(
        conditions: [],
        join: null,
        habitTitle: 'Read',
      )));

      expect(find.byIcon(LucideIcons.shieldCheck), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('keeps to one line when the label cannot fit', (tester) async {
      // The Italian screen-time label is the longest combination the line can
      // be asked to render; it must ellipsize, never wrap into a second row.
      await tester.pumpWidget(_app(SizedBox(
        width: 120,
        child: VerificationLine(
          conditions: [VerificationCatalog.screenTimeTotal.ruleWith(120)],
          join: null,
          habitTitle: 'Detox',
        ),
      )));

      final text = tester.widget<Text>(find.text('≤ 120 min Total device usage'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('CouldNotVerifyChip shows "?" and is tappable', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_app(CouldNotVerifyChip(onTap: () => tapped++)));
    expect(find.text('?'), findsOneWidget);
    await tester.tap(find.byType(CouldNotVerifyChip));
    expect(tapped, 1);
  });
}
