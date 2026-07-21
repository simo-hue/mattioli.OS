import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_sync_lifecycle.dart';
import 'package:evolve_desktop/core/navigator_key.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/features/auth/presentation/auth_page.dart';
import 'package:evolve_desktop/features/auth/presentation/consent_page.dart';
import 'package:evolve_desktop/features/auth/presentation/private_mode_gate.dart';
import 'package:evolve_desktop/features/shell/presentation/desktop_shell.dart';
import 'package:evolve_desktop/features/settings/application/desktop_biometric_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_synced_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';

AppLocale _appLocaleFor(Locale? locale) {
  switch (locale?.languageCode) {
    case 'it':
      return AppLocale.it;
    case 'es':
      return AppLocale.es;
    case 'de':
      return AppLocale.de;
    case 'ar':
      return AppLocale.ar;
    default:
      return AppLocale.en;
  }
}

class EvolveDesktopApp extends ConsumerWidget {
  const EvolveDesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backendConfigured = ref.watch(supabaseClientProvider) != null;
    final consent = ref.watch(desktopConsentControllerProvider);
    final auth = ref.watch(desktopAuthControllerProvider);
    final dataMode = ref.watch(activeDesktopDataModeProvider);
    final appearance = ref.watch(desktopAppearanceControllerProvider);
    final locale = ref.watch(desktopLocaleControllerProvider);

    // Apply the synced settings app-wide, not just on the settings page: a
    // theme/accent/language changed on the iPhone has to repaint the Mac even
    // when Settings is closed. The provider re-reads on every sync pull
    // (`refreshPrivateAfterPull` invalidates it), so this is also the path that
    // makes a cross-device change land without a restart.
    //
    // NOT `fireImmediately`: that fires synchronously inside this build, and
    // mutating another provider mid-build is an error. Registering the listener
    // is enough to create the provider, and the first value arrives
    // asynchronously — i.e. after the frame, where the mutation is legal.
    ref.listen(desktopSyncedSettingsProvider, (_, next) {
      final values = next.value;
      if (values != null && values.isNotEmpty) {
        applyDesktopSyncedSettings(ref, values);
      }
    });

    // Keep slang's active locale in sync with the app locale (guarded to avoid
    // a rebuild loop).
    final appLocale = _appLocaleFor(locale);
    if (LocaleSettings.currentLocale != appLocale) {
      LocaleSettings.setLocale(appLocale);
    }

    // Private mode lets the user bypass Supabase auth entirely.
    final isPrivateMode = dataMode.isPrivate;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Evolve Desktop',
      debugShowCheckedModeBanner: false,
      // Legibility is applied HERE, per brightness, and never written back —
      // the stored accent stays exactly what the user chose and exactly what
      // every other device holds.
      theme: EvolveTheme.light(
        DesktopAppearanceController.readableAccent(
          appearance.accentColor,
          Brightness.light,
        ),
      ),
      darkTheme: EvolveTheme.dark(
        DesktopAppearanceController.readableAccent(
          appearance.accentColor,
          Brightness.dark,
        ),
      ),
      themeMode: appearance.themeMode,
      locale: locale,
      supportedLocales: const [
        Locale('it'),
        Locale('en'),
        Locale('es'),
        Locale('de'),
        Locale('ar'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Hosts the automatic iCloud-sync triggers (launch / refocus /
      // after-write / periodic) above every page, in Private mode only.
      builder: (context, child) =>
          DesktopSyncLifecycle(child: child ?? const SizedBox.shrink()),
      home: !backendConfigured && !isPrivateMode
          ? const _DesktopBackendConfigurationErrorPage()
          : !consent.hasCompletedOnboarding
          ? const DesktopConsentPage()
          : isPrivateMode
          ? const PrivateModeGate(
              child: DesktopBiometricGate(child: DesktopShell()),
            )
          : auth.isLoggedIn
          ? const DesktopBiometricGate(child: DesktopShell())
          : const DesktopAuthPage(),
    );
  }
}

class _DesktopBackendConfigurationErrorPage extends StatelessWidget {
  const _DesktopBackendConfigurationErrorPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Configurazione Supabase desktop mancante.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
