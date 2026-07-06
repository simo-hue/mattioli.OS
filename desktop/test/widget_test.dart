import 'package:evolve_desktop/app/evolve_desktop_app.dart';
import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/shell/presentation/desktop_shell.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // These tests assert on the Italian UI copy, so pin the slang locale to
  // Italian (base locale is English). The global `t` accessor reads this.
  // `setLocale` is async because slang lazy-loads the deferred locale library.
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  testWidgets('desktop app reports unavailable Supabase initialization', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: EvolveDesktopApp()));

    expect(
      find.textContaining('Configurazione Supabase desktop mancante'),
      findsOne,
    );
    expect(find.byType(DesktopShell), findsNothing);
  });

  testWidgets('desktop shell exposes the primary navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: _DesktopTestApp()));

    expect(find.text('Evolve'), findsOneWidget);
    expect(find.text('Panoramica'), findsOneWidget);
    expect(find.text('Abitudini'), findsOneWidget);
    expect(find.text('Statistiche'), findsOneWidget);
    expect(find.text('Obiettivi'), findsOneWidget);
    expect(find.text('AI Coach'), findsOneWidget);
  });

  testWidgets('habits calendar exposes the supported views', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: _DesktopTestApp()));
    await tester.tap(find.text('Abitudini'));
    await tester.pumpAndSettle();

    // Wide desktop layout: protocol and calendar are shown side by side, so
    // the calendar view switcher is visible without any tab tap.
    expect(find.text('Protocollo'), findsOneWidget);
    expect(find.text('Calendario'), findsOneWidget);
    expect(find.text('Mese'), findsOneWidget);
    expect(find.text('Settimana'), findsOneWidget);
    expect(find.text('Anno'), findsOneWidget);
    expect(find.text('Vita'), findsOneWidget);
  });

  testWidgets('habits page falls back to tabs on a narrow window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: _DesktopTestApp()));
    await tester.tap(find.byTooltip('Abitudini'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendario'));
    await tester.pumpAndSettle();

    expect(find.text('Mese'), findsOneWidget);
    expect(find.text('Settimana'), findsOneWidget);
    expect(find.text('Anno'), findsOneWidget);
    expect(find.text('Vita'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('macro goals expose horizons and period selectors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: _DesktopTestApp()));
    await tester.tap(find.text('Obiettivi'));
    await tester.pumpAndSettle();

    expect(find.text('Lifetime'), findsOneWidget);
    expect(find.text('Annuale'), findsOneWidget);
    expect(find.text('Trimestrale'), findsOneWidget);
    expect(find.text('Mensile'), findsOneWidget);
    expect(find.text('Settimanale'), findsOneWidget);
    expect(find.byTooltip('Categorie'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
  });

  testWidgets('macro goals toolbar fits the minimum desktop window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: _DesktopTestApp()));
    await tester.tap(find.byTooltip('Obiettivi'));
    await tester.pumpAndSettle();

    expect(find.text('Settimanale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance settings apply the selected contrast color', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: _DesktopTestApp()));
    await tester.tap(find.text('Impostazioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Applicazione'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Usa accento #3B82F6'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme?.colorScheme.primary, const Color(0xFF3B82F6));
    expect(find.byTooltip('Colore personalizzato'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings menu exposes the complete account surfaces', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: _DesktopTestApp()));
    await tester.tap(find.text('Impostazioni'));
    await tester.pumpAndSettle();

    expect(find.text('Informazioni personali'), findsOneWidget);
    expect(find.text('Aggiorna avatar'), findsOneWidget);
    expect(find.text('Ripristina tutorial'), findsNothing);

    await tester.tap(find.text('Applicazione'));
    await tester.pumpAndSettle();
    expect(find.text('Modalita scura'), findsOneWidget);
    expect(find.text('Colore accento'), findsOneWidget);
    expect(find.text('Vista calendario predefinita'), findsOneWidget);
    expect(find.text('Feedback aptico'), findsOneWidget);
    expect(find.text('Lingua'), findsOneWidget);
    expect(find.text('Formato 24h'), findsOneWidget);
    expect(find.text('Ripristina tutorial'), findsOneWidget);

    await tester.tap(find.text('Notifiche'));
    await tester.pumpAndSettle();
    expect(find.text('Promemoria abitudini'), findsOneWidget);
    expect(find.text('Orario morning brief'), findsOneWidget);
    expect(find.text('Review serale'), findsOneWidget);
    expect(find.text('Orario review serale'), findsOneWidget);

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Blocco biometrico'), findsOneWidget);
    expect(find.text('Cambia password'), findsOneWidget);
    expect(find.text('Esporta dati'), findsOneWidget);
    expect(find.text('Elimina account e dati'), findsOneWidget);

    await tester.tap(find.text('Abbonamento'));
    await tester.pumpAndSettle();
    expect(find.text('Attiva Evolve Pro'), findsOneWidget);
    expect(find.text('Ripristina acquisti'), findsOneWidget);
    expect(find.text('Gestisci abbonamento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tutorial reset clears the three canonical flags', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_tutorial': true,
      'has_seen_goals_tutorial': true,
      'has_seen_stats_tutorial': true,
    });
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const _DesktopTestApp(),
      ),
    );
    await tester.tap(find.text('Impostazioni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Applicazione'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ripristina tutorial'));
    await tester.pumpAndSettle();

    expect(preferences.getBool('has_seen_tutorial'), isFalse);
    expect(preferences.getBool('has_seen_goals_tutorial'), isFalse);
    expect(preferences.getBool('has_seen_stats_tutorial'), isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _DesktopTestApp extends ConsumerWidget {
  const _DesktopTestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(desktopAppearanceControllerProvider);
    return MaterialApp(
      theme: EvolveTheme.light(appearance.accentColor),
      darkTheme: EvolveTheme.dark(appearance.accentColor),
      themeMode: appearance.themeMode,
      home: const DesktopShell(),
    );
  }
}
