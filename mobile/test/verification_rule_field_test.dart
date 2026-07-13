import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/ui/widgets/verification_rule_field.dart';

class _Harness extends StatefulWidget {
  const _Harness(this.initial);
  final VerificationRule? initial;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late VerificationRule? rule = widget.initial;
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: VerificationRuleField(
            rule: rule,
            onChanged: (r) => setState(() => rule = r),
          ),
        ),
      );
}

void main() {
  group('verificationRuleSummary', () {
    test('formats HealthKit and Screen Time rules', () {
      expect(
        verificationRuleSummary(VerificationCatalog.steps.ruleWith(10000)),
        '≥ 10,000 Steps',
      );
      expect(
        verificationRuleSummary(
            VerificationCatalog.screenTimeTotal.ruleWith(120)),
        '≤ 120 min Screen time',
      );
      expect(
        verificationRuleSummary(VerificationCatalog.sleepHours.ruleWith(8)),
        '≥ 8 h Sleep hours',
      );
    });
  });

  group('VerificationRuleField', () {
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
      expect(find.byType(ChoiceChip), findsNWidgets(9));
    });

    testWidgets('selecting a template switches the rule + its default',
        (tester) async {
      await tester.pumpWidget(_Harness(VerificationCatalog.steps.ruleWith(10000)));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Screen time'));
      await tester.pumpAndSettle();
      expect(find.text('≤ 120 min Screen time'), findsOneWidget);
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
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: VerificationBadge()),
    ));
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });
}
