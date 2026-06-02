import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/app/localization/desktop_locale_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/features/auth/presentation/auth_page.dart';
import 'package:evolve_desktop/features/auth/presentation/consent_page.dart';
import 'package:evolve_desktop/features/shell/presentation/desktop_shell.dart';
import 'package:evolve_desktop/features/settings/application/desktop_biometric_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class EvolveDesktopApp extends ConsumerWidget {
  const EvolveDesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backendConfigured = ref.watch(supabaseClientProvider) != null;
    final consent = ref.watch(desktopConsentControllerProvider);
    final auth = ref.watch(desktopAuthControllerProvider);
    final appearance = ref.watch(desktopAppearanceControllerProvider);
    final locale = ref.watch(desktopLocaleControllerProvider);

    return MaterialApp(
      title: 'Evolve Desktop',
      debugShowCheckedModeBanner: false,
      theme: EvolveTheme.light(appearance.accentColor),
      darkTheme: EvolveTheme.dark(appearance.accentColor),
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
      home: !backendConfigured
          ? const _DesktopBackendConfigurationErrorPage()
          : !consent.hasCompletedOnboarding
          ? const DesktopConsentPage()
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
