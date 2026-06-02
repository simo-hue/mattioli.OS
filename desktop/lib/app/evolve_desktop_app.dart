import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/features/auth/presentation/auth_page.dart';
import 'package:evolve_desktop/features/auth/presentation/consent_page.dart';
import 'package:evolve_desktop/features/shell/presentation/desktop_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EvolveDesktopApp extends ConsumerWidget {
  const EvolveDesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backendConfigured = ref.watch(backendConfiguredProvider);
    final consent = ref.watch(desktopConsentControllerProvider);
    final auth = ref.watch(desktopAuthControllerProvider);
    final appearance = ref.watch(desktopAppearanceControllerProvider);

    return MaterialApp(
      title: 'Evolve Desktop',
      debugShowCheckedModeBanner: false,
      theme: EvolveTheme.light(appearance.accentColor),
      darkTheme: EvolveTheme.dark(appearance.accentColor),
      themeMode: appearance.themeMode,
      home: !backendConfigured
          ? const DesktopShell()
          : !consent.hasCompletedOnboarding
          ? const DesktopConsentPage()
          : auth.isLoggedIn
          ? const DesktopShell()
          : const DesktopAuthPage(),
    );
  }
}
