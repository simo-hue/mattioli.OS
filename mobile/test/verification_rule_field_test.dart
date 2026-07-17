import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/ui/widgets/verification_rule_field.dart';

/// Wraps [child] in the TranslationProvider the verification widgets now need
/// for `context.t` (localized labels/tooltips).
Widget _app(Widget child) => TranslationProvider(
      child: MaterialApp(home: Scaffold(body: child)),
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
  Widget build(BuildContext context) => _app(
        VerificationRuleField(
          rule: rule,
          onChanged: (r) => setState(() => rule = r),
        ),
      );
}

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
          .pumpWidget(_Harness(VerificationCatalog.steps.ruleWith(10000)));
      await tester.pumpAndSettle();
      expect(find.text('ACTIVITY'), findsOneWidget);
      expect(find.text('SLEEP'), findsOneWidget);
      expect(find.text('SCREEN TIME'), findsOneWidget);
    });

    testWidgets('manual by default — switch off, no template chips',
        (tester) async {
      await tester.pumpWidget(const _Harness(null));
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
        isFalse,
      );
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('toggling on emits the default steps rule', (tester) async {
      await tester.pumpWidget(const _Harness(null));
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(find.text('≥ 10,000 Steps'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(10));
    });

    testWidgets('selecting a template switches the rule + its default',
        (tester) async {
      await tester.pumpWidget(_Harness(VerificationCatalog.steps.ruleWith(10000)));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Total device usage'));
      await tester.pumpAndSettle();
      expect(find.text('≤ 120 min Total device usage'), findsOneWidget);
    });

    testWidgets('stepper increments the threshold by the template step',
        (tester) async {
      await tester.pumpWidget(_Harness(VerificationCatalog.steps.ruleWith(10000)));
      await tester.tap(find.byKey(const Key('verify_threshold_up')));
      await tester.pumpAndSettle();
      expect(find.text('≥ 10,500 Steps'), findsOneWidget);
    });

    testWidgets('down stepper is disabled at the minimum threshold',
        (tester) async {
      await tester.pumpWidget(_Harness(VerificationCatalog.steps
          .ruleWith(VerificationCatalog.steps.minThreshold)));
      final down = tester.widget<IconButton>(
          find.byKey(const Key('verify_threshold_down')));
      expect(down.onPressed, isNull);
    });

    testWidgets('Watch-dependent templates show the warning', (tester) async {
      await tester
          .pumpWidget(_Harness(VerificationCatalog.standHours.ruleWith(12)));
      expect(find.text('Needs an Apple Watch to auto-verify'), findsOneWidget);
    });
  });

  testWidgets('VerificationBadge renders a verified indicator', (tester) async {
    await tester.pumpWidget(_app(const VerificationBadge()));
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('CouldNotVerifyChip shows "?" and is tappable', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_app(CouldNotVerifyChip(onTap: () => tapped++)));
    expect(find.text('?'), findsOneWidget);
    await tester.tap(find.byType(CouldNotVerifyChip));
    expect(tapped, 1);
  });
}
