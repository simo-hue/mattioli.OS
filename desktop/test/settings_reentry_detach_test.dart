// Re-entering Settings while the shell is still cross-fading the previous visit
// away used to leave the LIVE page detached.
//
// `SettingsFormController` / `SyncSettingsController` are kept alive and scoped
// by `hydrate()` / `detach()` instead of `autoDispose`, and the scope was a
// single bare boolean. The shell renders sections inside an `AnimatedSwitcher`
// (220 ms) whose custom `transitionBuilder` returns an UNKEYED widget, so a
// re-entered section does NOT collide with its own outgoing entry: the new page
// mounts and hydrates, and ~220 ms later the OUTGOING page's `dispose()` clears
// the flag out from under it. For the rest of that visit `applySyncedSettings`
// early-returns, the Supabase profile branch bails, and `_persistOrRollback`
// returns before `revert(); reportSaveFailure();` — a rejected write leaves the
// switch showing a value nothing stored, with no toast.
//
// The lifecycle below is exactly what the shell produces (proved against a real
// `AnimatedSwitcher` with the shell's own transitionBuilder):
//   init visit#1 -> init visit#2 -> dispose visit#1
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/settings_navigation.dart';

Finder _switchIn(String rowLabel) => find.descendant(
  of: find.widgetWithText(ListTile, rowLabel),
  matching: find.byType(EvolveSwitch),
);

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets(
    'the page re-entered mid cross-fade still applies a pull after the '
    'outgoing one disposes',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'active_data_mode': DesktopDataMode.private.name,
      });
      final prefs = await SharedPreferences.getInstance();
      var generation = 0;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          desktopSyncedSettingsWriterProvider.overrideWithValue((_) async {}),
          desktopSyncedSettingsProvider.overrideWith(
            (_) async => generation++ == 0
                ? const {'pref_focus_mode': '0'}
                : const {'pref_focus_mode': '0', 'pref_time_format_24h': '0'},
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.binding.setSurfaceSize(const Size(1440, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<void> pumpVisits(List<Key> visits) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              theme: EvolveTheme.dark(EvolveColors.primaryStrong),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('en')],
              home: Scaffold(
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final key in visits)
                      KeyedSubtree(key: key, child: const SettingsPage()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      const first = ValueKey('visit#1');
      const second = ValueKey('visit#2');

      // Settings is open…
      await pumpVisits(const [first]);
      await tester.pumpAndSettle();

      // …the user leaves and comes straight back: the new page mounts while the
      // outgoing one is still on screen, mid-transition.
      await pumpVisits(const [first, second]);
      await tester.pumpAndSettle();

      // The transition ends and the OUTGOING page disposes — after the live one
      // hydrated.
      await pumpVisits(const [second]);
      await tester.pumpAndSettle();

      await openSettingsSection(tester, SettingsSection.general);
      expect(
        tester
            .widget<EvolveSwitch>(_switchIn(t.settingsPage.timeFormat24h))
            .value,
        isTrue,
      );

      // A preference changed on the iPhone arrives.
      container.invalidate(desktopSyncedSettingsProvider);
      await container.read(desktopSyncedSettingsProvider.future);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<EvolveSwitch>(_switchIn(t.settingsPage.timeFormat24h))
            .value,
        isFalse,
        reason:
            'the live page is still attached, so the pull must land — the '
            'outgoing page detached only its own visit',
      );
    },
  );
}
