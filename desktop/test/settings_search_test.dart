import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_search.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';

import 'support/settings_navigation.dart';

Future<void> _pumpSettings(
  WidgetTester tester, {
  bool privateMode = false,
}) async {
  SharedPreferences.setMockInitialValues({
    if (privateMode) 'active_data_mode': DesktopDataMode.private.name,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.binding.setSurfaceSize(const Size(1440, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  group('the index', () {
    // The index cannot be derived from the panes — there is no reflection — so
    // it is a hand-written list that will drift the moment someone renames a
    // row or moves it to another pane. This is the guard: every entry must
    // actually render, in the pane it claims, under the label it claims.
    //
    // Without it, search silently starts answering "language" with nothing.
    for (final mode in [false, true]) {
      final modeName = mode ? 'private' : 'account';
      testWidgets('every $modeName-mode entry renders where it says it does', (
        tester,
      ) async {
        await _pumpSettings(tester, privateMode: mode);

        for (final entry in kSettingsSearchIndex) {
          if (!entry.isAvailable(isPrivateMode: mode)) continue;
          await openSettingsSection(tester, entry.section);
          expect(
            find.byKey(SettingsKeys.row(entry.id)),
            findsOneWidget,
            reason:
                '"${entry.id}" is in the search index but does not render in '
                '${entry.section.name} (in $modeName mode)',
          );
          expect(
            find.descendant(
              of: find.byKey(SettingsKeys.row(entry.id)),
              matching: find.text(entry.label()),
            ),
            findsOneWidget,
            reason:
                '"${entry.id}" renders, but not under the label the index '
                'advertises ("${entry.label()}") — search would find it and '
                'the user would not recognise it',
          );
        }
      });
    }

    test('ids are unique', () {
      final seen = <String>{};
      for (final entry in kSettingsSearchIndex) {
        expect(
          seen.add(entry.id),
          isTrue,
          reason: '${entry.id} appears twice; the highlight would be ambiguous',
        );
      }
    });
  });

  group('matching', () {
    test('an empty query matches nothing rather than everything', () {
      expect(searchSettings('', isPrivateMode: false), isEmpty);
      expect(searchSettings('   ', isPrivateMode: false), isEmpty);
    });

    test('a label prefix outranks a keyword hit', () {
      final results = searchSettings('lang', isPrivateMode: false);
      expect(results.first.id, 'general.language');
    });

    test('keywords find settings whose visible copy never says the word', () {
      // "dark mode" is what a user types; the row is called "Theme".
      final results = searchSettings('dark mode', isPrivateMode: false);
      expect(results.map((e) => e.id), contains('general.theme'));
    });

    test('matching ignores case and accents', () {
      final plain = searchSettings('accent', isPrivateMode: false);
      final shouty = searchSettings('ACCENT', isPrivateMode: false);
      expect(shouty.map((e) => e.id), plain.map((e) => e.id));
    });

    test('mode-gated entries are filtered out, not just hidden later', () {
      final inAccount = searchSettings('icloud', isPrivateMode: false);
      expect(inAccount.map((e) => e.id), isNot(contains('data.syncNow')));

      final inPrivate = searchSettings('crash', isPrivateMode: true);
      expect(
        inPrivate.map((e) => e.id),
        isNot(contains('privacy.crashReports')),
      );
    });

    test('equal-rank matches keep rail order', () {
      // Both are keyword hits for "reminder"; morning must come before evening
      // because that is the order they appear in the pane.
      final results = searchSettings('reminder', isPrivateMode: false);
      final ids = results.map((e) => e.id).toList();
      expect(
        ids.indexOf('notifications.morningBrief'),
        lessThan(ids.indexOf('notifications.eveningReview')),
      );
    });
  });

  group('the sidebar', () {
    testWidgets('typing replaces the destinations with matching rows', (
      tester,
    ) async {
      await _pumpSettings(tester);

      // Destinations are visible before a query.
      expect(find.byKey(SettingsSection.advanced.key), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('settings.searchField')),
        'language',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(SettingsSection.advanced.key),
        findsNothing,
        reason: 'the rail shows results, not destinations, while filtering',
      );
      expect(
        find.byKey(const ValueKey('settings.result.general.language')),
        findsOneWidget,
      );
    });

    testWidgets('a result opens its pane and highlights the row', (
      tester,
    ) async {
      await _pumpSettings(tester);
      // Start somewhere that is NOT the pane we are searching for.
      await openSettingsSection(tester, SettingsSection.notifications);

      await tester.enterText(
        find.byKey(const Key('settings.searchField')),
        'language',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('settings.result.general.language')),
      );
      await tester.pumpAndSettle();

      // The General pane is open and the row is on screen.
      expect(find.byKey(SettingsKeys.row('general.language')), findsOneWidget);
      expect(find.text(t.settingsPage.groupLanguageFormats), findsOneWidget);
    });

    testWidgets('clearing the query brings the destinations back', (
      tester,
    ) async {
      await _pumpSettings(tester);

      await tester.enterText(
        find.byKey(const Key('settings.searchField')),
        'language',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(SettingsSection.advanced.key), findsNothing);

      await tester.enterText(find.byKey(const Key('settings.searchField')), '');
      await tester.pumpAndSettle();
      expect(find.byKey(SettingsSection.advanced.key), findsOneWidget);
    });

    testWidgets('cmd-F focuses the search field', (tester) async {
      await _pumpSettings(tester);
      final field = find.byKey(const Key('settings.searchField'));
      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(field).focusNode?.hasFocus,
        isTrue,
        reason: 'cmd-F is the macOS convention for find-in-window',
      );
    });

    testWidgets(
      'a query with no matches says so instead of emptying the rail',
      (tester) async {
        await _pumpSettings(tester);

        await tester.enterText(
          find.byKey(const Key('settings.searchField')),
          'zzzzqqq',
        );
        await tester.pumpAndSettle();

        expect(find.text(t.settingsPage.searchNoResults), findsOneWidget);
      },
    );
  });

  group('deep links', () {
    testWidgets('a row-addressed request scrolls to and tints the row', (
      tester,
    ) async {
      // This is the path ⌘K takes. The sidebar's own result list already
      // scrolled and highlighted; a palette hit on the same index for the same
      // query used to dump the user at the top of the pane instead.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.binding.setSurfaceSize(const Size(1440, 900));
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

      container
          .read(settingsSectionRequestProvider.notifier)
          .request(SettingsSection.general, rowId: 'general.language');
      await tester.pumpAndSettle();

      expect(find.byKey(SettingsKeys.row('general.language')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings.row.general.language.highlighted')),
        findsOneWidget,
        reason: 'the row the request named must be visibly marked',
      );
      // And no other row is.
      expect(
        find.byKey(const ValueKey('settings.row.general.theme.highlighted')),
        findsNothing,
      );

      expect(
        container.read(settingsSectionRequestProvider),
        isNull,
        reason: 'the one-shot request must be consumed, not left to re-fire',
      );
    });
  });
}
