// The signed-out landing screen (Guideline 5.1.1(v)).
//
// iOS 1.1.2 was rejected because App Review concluded registration was required
// to reach paid content. It was not — Private mode has always unlocked every
// on-device Pro feature for free — but the app opened on a login wall with the
// no-account path buried fifth, labelled "Continue privately on this iPhone",
// which reads as a sync preference rather than as "skip registration".
//
// These tests guard the properties that make that argument legible, because
// they are the kind that a well-meaning layout tidy-up silently undoes:
//
//   * the no-account option EXISTS on the first signed-out screen,
//   * it comes BEFORE the sign-in option, and
//   * nothing on this screen asks for a credential.
//
// If one of these fails, do not just update the expectation. Re-read the class
// doc on DataModeChoiceScreen first.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/ui/screens/data_mode_choice_screen.dart';

Widget _app() => ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.lightTheme(null),
          home: const DataModeChoiceScreen(),
        ),
      ),
    );

void main() {
  testWidgets('offers a no-account path and a sign-in path', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.byKey(const Key('mode_choice_without_account')), findsOneWidget);
    expect(find.byKey(const Key('mode_choice_sign_in')), findsOneWidget);
  });

  testWidgets('the no-account option is named so a reviewer recognises it',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    // "without an account" is the phrase App Review scans for. The previous
    // label named only the privacy benefit and was not recognised as a way in.
    expect(find.text('Continue without an account'), findsOneWidget);
  });

  testWidgets('the no-account option is rendered before sign-in',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    final withoutAccount = tester.getTopLeft(
      find.byKey(const Key('mode_choice_without_account')),
    );
    final signIn = tester.getTopLeft(
      find.byKey(const Key('mode_choice_sign_in')),
    );

    expect(
      withoutAccount.dy,
      lessThan(signIn.dy),
      reason: 'the no-account path must be the first choice on the screen',
    );
  });

  testWidgets('asks for no credentials at all', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(
      find.byType(TextField),
      findsNothing,
      reason: 'no email or password field may appear before the user has '
          'chosen to sign in',
    );
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('states that signing in is optional', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    // Apple's own suggested remedy for this guideline: explain what
    // registering buys, rather than requiring it.
    expect(find.textContaining('optional'), findsOneWidget);
  });
}
