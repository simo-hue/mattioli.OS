// A settings write that FAILS used to be indistinguishable from one that
// succeeded.
//
// `_syncProfile` caught the error, logged one line, and returned `Future<void>`
// — no success signal, and its callers `unawaited` it anyway. `setState` had
// already committed the new value to the switch and `SharedPreferences` had
// already mirrored it, so the user was shown a saved-and-synced setting that
// was never persisted on any device. The realistic trigger is the Keychain
// key-guard lockout this app already ships recovery flows for, plus disk-full
// and a corrupt store.
//
// These tests assert what the USER sees after the failure — the toast, the
// switch position, the prefs mirror — never that a helper returned false.
import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'support/settings_navigation.dart';

/// Pumps the settings page in PRIVATE mode with the synced-settings write
/// replaced by [writer].
///
/// `activeDesktopDataModeProvider` reads the mode from SharedPreferences, so
/// seeding `active_data_mode` is what puts `_syncProfile` on its private
/// branch. The synced READ is stubbed too: left alone it reaches the real
/// encrypted DB, which cannot open under `flutter_test`, and the resulting
/// empty map makes both re-hydration listeners no-ops — i.e. the whole path
/// would be exercised only through its swallowed-error branch.
Future<SharedPreferences> _pumpPrivateSettings(
  WidgetTester tester, {
  required Future<void> Function(Map<String, String?>) writer,
  Map<String, String?> stored = const {},
  Map<String, Object> prefs = const {},
  bool light = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'active_data_mode': DesktopDataMode.private.name,
    ...prefs,
  });
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      desktopSyncedSettingsWriterProvider.overrideWithValue(writer),
      desktopSyncedSettingsProvider.overrideWith((_) async => stored),
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
          theme: light
              ? EvolveTheme.light(EvolveColors.lightForeground)
              : EvolveTheme.dark(EvolveColors.primaryStrong),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en')],
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return preferences;
}

Finder _switchIn(String rowLabel) => find.descendant(
  of: find.widgetWithText(ListTile, rowLabel),
  matching: find.byType(EvolveSwitch),
);

bool _switchValue(WidgetTester tester, String rowLabel) =>
    tester.widget<EvolveSwitch>(_switchIn(rowLabel)).value;

/// Lets the failure toast auto-dismiss.
///
/// `showEvolveToast` schedules a 2-second removal timer on the root overlay;
/// leaving it pending trips flutter_test's "a Timer is still pending" assertion
/// at teardown. Always call AFTER asserting the toast is visible.
Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

/// Focus mode now lives in Notifications, beside the reminders it silences.
Future<void> _openFocusMode(WidgetTester tester) async {
  await openSettingsSection(tester, SettingsSection.notifications);
}

/// Theme and accent live in General.
Future<void> _openAppearance(WidgetTester tester) async {
  await openSettingsSection(tester, SettingsSection.general);
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets(
    'a failed settings write is silent and leaves the switch showing a value '
    'nothing stored',
    (tester) async {
      // A generic write error (disk full, corrupt row): the store stays
      // READABLE, so this is the mildest version of the failure.
      final prefs = await _pumpPrivateSettings(
        tester,
        writer: (_) async => throw Exception('disk full'),
        stored: const {'pref_focus_mode': '0'},
      );
      await _openFocusMode(tester);

      expect(_switchValue(tester, t.settingsPage.focusMode), isFalse);
      await tester.ensureVisible(_switchIn(t.settingsPage.focusMode));
      await tester.tap(_switchIn(t.settingsPage.focusMode));
      await tester.pumpAndSettle();

      expect(
        find.text(t.settingsPage.settingSaveFailed),
        findsOneWidget,
        reason: 'the user must be told the setting did not save',
      );
      expect(
        _switchValue(tester, t.settingsPage.focusMode),
        isFalse,
        reason: 'the switch shows what is stored, not what the user attempted',
      );
      expect(
        prefs.getBool('pref_focus_mode'),
        isNot(isTrue),
        reason: 'no local mirror of a value no store agrees with',
      );
      await _drainToast(tester);
    },
  );

  testWidgets(
    'a failed write with an UNREADABLE store still leaves the UI lying',
    (tester) async {
      // The discriminating case. Re-reading the store cannot undo the UI here:
      // whatever locked the DB for the write locks it for the read too, so
      // `desktopSyncedSettingsProvider` resolves to `{}` and BOTH re-hydration
      // listeners skip it on their `isNotEmpty` guard. Only a LOCAL rollback
      // fixes this one — a fix built on `ref.invalidate` passes the test above
      // and fails this one.
      final prefs = await _pumpPrivateSettings(
        tester,
        writer: (_) async => throw const PrivateDatabaseLockedException(),
        stored: const {},
      );
      await _openFocusMode(tester);

      expect(_switchValue(tester, t.settingsPage.focusMode), isFalse);
      await tester.ensureVisible(_switchIn(t.settingsPage.focusMode));
      await tester.tap(_switchIn(t.settingsPage.focusMode));
      await tester.pumpAndSettle();

      expect(find.text(t.settingsPage.settingSaveFailed), findsOneWidget);
      expect(_switchValue(tester, t.settingsPage.focusMode), isFalse);
      expect(prefs.getBool('pref_focus_mode'), isNot(isTrue));
      await _drainToast(tester);
    },
  );

  testWidgets('a failed accent write leaves the wrong accent on screen', (
    tester,
  ) async {
    // The accent picker calls `_syncProfile` directly rather than through
    // `_setBool`/`_setString`, so a fix that only touches those two helpers
    // still loses this one — and the accent is one of the two symptoms the
    // whole sync-hardening effort started from.
    await _pumpPrivateSettings(
      tester,
      writer: (_) async => throw Exception('disk full'),
      stored: const {'accent_color': '#FF7A00'},
    );
    await _openAppearance(tester);

    final blue = find.byTooltip(t.settingsPage.useAccent(hex: '#3B82F6'));
    await tester.ensureVisible(blue);
    await tester.tap(blue);
    await tester.pumpAndSettle();

    expect(find.text(t.settingsPage.settingSaveFailed), findsOneWidget);
    expect(
      tester
          .element(find.byType(SettingsPage))
          .findAncestorWidgetOfExactType<UncontrolledProviderScope>()!
          .container
          .read(desktopAppearanceControllerProvider)
          .accentColor,
      const Color(0xFFFF7A00),
      reason: 'the accent reverts to the one that is actually stored',
    );
    await _drainToast(tester);
  });

  testWidgets('a settings write that succeeds warns anyway', (tester) async {
    // Guards the other direction: the toast must not become unconditional and
    // the rollback must not fire on the happy path.
    final written = <String, String?>{};
    final prefs = await _pumpPrivateSettings(
      tester,
      writer: (values) async => written.addAll(values),
      stored: const {'pref_focus_mode': '0'},
    );
    await _openFocusMode(tester);

    await tester.ensureVisible(_switchIn(t.settingsPage.focusMode));
    await tester.tap(_switchIn(t.settingsPage.focusMode));
    await tester.pumpAndSettle();

    expect(find.text(t.settingsPage.settingSaveFailed), findsNothing);
    expect(_switchValue(tester, t.settingsPage.focusMode), isTrue);
    expect(prefs.getBool('pref_focus_mode'), isTrue);
    expect(written['pref_focus_mode'], '1');
  });
}
