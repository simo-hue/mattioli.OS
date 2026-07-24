// The compound-habit builder widget (Q8): the Any/All toggle, removable
// condition rows, and the Pro-gated "+ Add condition" affordance.
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/ui/widgets/compound_conditions_field.dart';

Widget _app(Widget child) => ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.lightTheme(null),
          home: Scaffold(body: child),
        ),
      ),
    );

void main() {
  final steps = VerificationCatalog.steps.ruleWith(10000);
  final exercise = VerificationCatalog.exerciseMinutes.ruleWith(30);

  testWidgets('renders the Any/All toggle and a removable condition row',
      (tester) async {
    await tester.pumpWidget(_app(CompoundConditionsField(
      primaryRule: steps,
      additionalConditions: [exercise],
      join: VerificationJoin.or,
      isPro: true,
      onConditionsChanged: (_) {},
      onJoinChanged: (_) {},
      onNeedPro: () {},
    )));

    expect(find.text('Any of these'), findsOneWidget);
    expect(find.text('All of these'), findsOneWidget);
    expect(find.textContaining('Exercise'), findsWidgets); // the row summary
    expect(find.byIcon(Icons.close), findsOneWidget); // the remove control
  });

  testWidgets('the remove control drops that condition', (tester) async {
    List<VerificationRule>? emitted;
    await tester.pumpWidget(_app(CompoundConditionsField(
      primaryRule: steps,
      additionalConditions: [exercise],
      join: VerificationJoin.or,
      isPro: true,
      onConditionsChanged: (c) => emitted = c,
      onJoinChanged: (_) {},
      onNeedPro: () {},
    )));

    await tester.tap(find.byIcon(Icons.close));
    expect(emitted, isEmpty);
  });

  testWidgets('flipping the toggle emits the new operator', (tester) async {
    VerificationJoin? emitted;
    await tester.pumpWidget(_app(CompoundConditionsField(
      primaryRule: steps,
      additionalConditions: [exercise],
      join: VerificationJoin.or,
      isPro: true,
      onConditionsChanged: (_) {},
      onJoinChanged: (j) => emitted = j,
      onNeedPro: () {},
    )));

    await tester.tap(find.text('All of these'));
    expect(emitted, VerificationJoin.and);
  });

  testWidgets('a free user tapping "+ Add condition" hits the paywall',
      (tester) async {
    var neededPro = false;
    await tester.pumpWidget(_app(CompoundConditionsField(
      primaryRule: steps,
      additionalConditions: const [],
      join: VerificationJoin.or,
      isPro: false,
      onConditionsChanged: (_) {},
      onJoinChanged: (_) {},
      onNeedPro: () => neededPro = true,
    )));

    expect(find.text('Add condition'), findsOneWidget);
    await tester.tap(find.text('Add condition'));
    await tester.pump();
    expect(neededPro, isTrue);
  });

  testWidgets('at the cap of 3, no "+ Add condition" is shown', (tester) async {
    final energy = VerificationCatalog.activeEnergy.ruleWith(500);
    await tester.pumpWidget(_app(CompoundConditionsField(
      primaryRule: steps,
      additionalConditions: [exercise, energy], // 3 total = cap
      join: VerificationJoin.and,
      isPro: true,
      onConditionsChanged: (_) {},
      onJoinChanged: (_) {},
      onNeedPro: () {},
    )));

    expect(find.text('Add condition'), findsNothing);
  });
}
