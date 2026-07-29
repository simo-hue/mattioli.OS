// _PersonalInfoDialog dissolved into the Account pane.
//
// Two defects went with it. The dialog was gated behind `if (!isPrivateMode)`,
// so a Private-mode user could never change their own name or birthday — while
// `privateProfileProvider.updateProfile` sat fully implemented and unreachable.
// And its Email field was a labelled `hintText` with no controller, so it
// rendered as an empty focusable box whose value only appeared once you clicked
// into it.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/settings_navigation.dart';

class _PrivateDataMode extends ActiveDesktopDataModeNotifier {
  @override
  DesktopDataMode build() => DesktopDataMode.private;
}

Future<void> _pump(WidgetTester tester, {bool private = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      if (private)
        activeDesktopDataModeProvider.overrideWith(_PrivateDataMode.new),
    ],
  );
  addTearDown(container.dispose);

  await tester.binding.setSurfaceSize(const Size(1440, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: EvolveTheme.dark(EvolveColors.primaryStrong),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en')],
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await openSettingsSection(tester, SettingsSection.account);
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('the fields are inline, and the launcher row is gone', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(SettingsKeys.row('account.fullName')), findsOneWidget);
    expect(find.byKey(SettingsKeys.row('account.dateOfBirth')), findsOneWidget);
    // The row that used to open the modal.
    expect(find.text(t.settingsPage.personalInfoDetail), findsNothing);
  });

  testWidgets('Private mode can edit name and date of birth', (tester) async {
    await _pump(tester, private: true);

    expect(
      find.byKey(SettingsKeys.row('account.fullName')),
      findsOneWidget,
      reason: 'the dialog these replace was hidden entirely in Private mode',
    );
    expect(find.byKey(SettingsKeys.row('account.dateOfBirth')), findsOneWidget);
  });

  testWidgets('email shows its value, and only in account mode', (
    tester,
  ) async {
    await _pump(tester);
    // A real value row, not an empty box with the address hidden in a hint.
    expect(find.byKey(SettingsKeys.row('account.email')), findsOneWidget);
    expect(find.text(t.settingsPage.email), findsOneWidget);

    await _pump(tester, private: true);
    expect(
      find.byKey(SettingsKeys.row('account.email')),
      findsNothing,
      reason: 'Private mode keeps no account, so there is no address to show',
    );
  });

  testWidgets('a rejected write reverts the field and says so', (tester) async {
    // There is no session in the test harness, so the write cannot succeed.
    // That is the point: the dialog swallowed failures whole (`catch (_)`) and
    // left the field showing a name nothing had stored.
    await _pump(tester);
    final field = find.descendant(
      of: find.byKey(SettingsKeys.row('account.fullName')),
      matching: find.byType(TextField),
    );

    await tester.enterText(field, 'Simone Mattioli');
    // Enter commits, same as blurring. (Tapping another row does NOT blur it —
    // the rows are InkWells, which do not take focus.)
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(field).controller?.text,
      '',
      reason: 'the write failed, so the row must not keep showing the edit',
    );
    expect(find.text(t.settingsPage.settingSaveFailed), findsOneWidget);
    // Let the toast's own removal timer run, or teardown trips on it.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
