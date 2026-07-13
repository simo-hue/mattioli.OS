import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/ui/widgets/day_details_modal.dart';

/// Themed + translated harness for the verification card (it reads
/// `context.appColors` and `context.t`).
Widget _app(Widget child) => ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          home: Scaffold(body: child),
        ),
      ),
    );

Goal _goal() => Goal(
      id: 'g',
      title: 'Steps',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('renders the "?" resolve affordance when couldNotVerify',
      (tester) async {
    await tester.pumpWidget(_app(GoalLogCard(
      habit: _goal(),
      status: null,
      streak: 0,
      couldNotVerify: true,
      onTap: () {},
    )));

    expect(find.text('?'), findsOneWidget);
    expect(find.text("Couldn't verify — tap to resolve"), findsOneWidget);
  });

  testWidgets('a pending habit without couldNotVerify shows no "?"',
      (tester) async {
    await tester.pumpWidget(_app(GoalLogCard(
      habit: _goal(),
      status: null,
      streak: 0,
      couldNotVerify: false,
      onTap: () {},
    )));

    expect(find.text('?'), findsNothing);
    expect(find.text("Couldn't verify — tap to resolve"), findsNothing);
  });

  testWidgets('tapping the "?" card triggers the resolve callback',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(GoalLogCard(
      habit: _goal(),
      status: null,
      streak: 0,
      couldNotVerify: true,
      onTap: () => taps++,
    )));

    await tester.tap(find.byType(GoalLogCard));
    expect(taps, 1);
  });
}
