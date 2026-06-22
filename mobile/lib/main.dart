import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/goal_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'dart:async';
import 'dart:ui';
import 'core/theme.dart';
import 'core/supabase_config.dart';
import 'core/sentry_service.dart';
import 'providers/shared_prefs_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/auth_provider.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/consent_screen.dart';
import 'providers/consent_provider.dart';
import 'core/notifications.dart';
import 'ui/widgets/error_modal.dart';
import 'core/navigator_key.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/app_logger.dart';
import 'core/secure_local_storage.dart';
import 'core/secure_storage_utils.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/data_mode.dart';
import 'i18n/translations.g.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await initializeDateFormatting();

  // ── SharedPreferences init ───────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  final startsInPrivateMode =
      prefs.getString('active_data_mode') == AppDataMode.private.name;
  AppLogger.setExternalReportingDisabled(startsInPrivateMode);

  // ── Supabase init ─────────────────────────────────────────────────────────
  if (!startsInPrivateMode) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()),
    );
    // Cold-start foreground: flush any habit-log actions queued by notification
    // taps while the app was terminated/offline (NOTIF-1). Non-blocking.
    unawaited(NotificationService().replayPendingHabitLogs());
  }

  // Warm-resume foreground: replay the same queue. No-ops when empty.
  WidgetsBinding.instance.addObserver(_NotificationReplayObserver());

  // ── Notifications init ───────────────────────────────────────────────────
  try {
    final notificationService = NotificationService();
    await notificationService.init().timeout(const Duration(seconds: 3));
  } catch (e, stack) {
    AppLogger.error(
      'Notification initialization failed or timed out',
      e,
      stack,
    );
  }

  // ── Secure Cache Loading & Migration ─────────────────────────────────────
  // Carica Goals Cache
  String? goalsJson;
  try {
    goalsJson = await SecureStorageUtils.read('goals_cache');
  } catch (e, stack) {
    AppLogger.error('[Startup] goals_cache secure read failed', e, stack);
  }
  if (goalsJson == null) {
    // Migrazione da SharedPreferences se esiste
    final oldGoals = prefs.getString('goals_cache');
    if (oldGoals != null) {
      goalsJson = oldGoals;
      await SecureStorageUtils.tryWrite(
        'goals_cache',
        goalsJson,
        context: '[Startup] goals_cache migration',
      );
    } else {
      goalsJson = '[]';
    }
  }

  // Carica Logs Cache
  String? logsJson;
  try {
    logsJson = await SecureStorageUtils.read('goal_logs_cache');
  } catch (e, stack) {
    AppLogger.error('[Startup] goal_logs_cache secure read failed', e, stack);
  }
  if (logsJson == null) {
    // Migrazione da SharedPreferences se esiste
    final oldLogs = prefs.getString('goal_logs_cache');
    if (oldLogs != null) {
      logsJson = oldLogs;
      await SecureStorageUtils.tryWrite(
        'goal_logs_cache',
        logsJson,
        context: '[Startup] goal_logs_cache migration',
      );
    } else {
      logsJson = '{}';
    }
  }

  // ── Sentry init ──────────────────────────────────────────────────────────
  final hasSentryConsent = prefs.getBool('has_sentry_consent') ?? true;

  void startApp() {
    // ── Global error handler (UI modale per l'utente) ─────────────────
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  t.common.unexpectedErrorTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Raw exception text only in debug — don't leak internals to
                // users in release (SEC-7 / I18N-3).
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  Text(
                    details.exception.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (_isRecoverableAuthSessionError(error)) {
        AppLogger.warning(
          '[Startup] Ignored recoverable auth session error',
          error,
          stack,
        );
        return true;
      }

      // Invia l'errore a Sentry (se inizializzato)
      if (!AppLogger.externalReportingDisabled) {
        Sentry.captureException(error, stackTrace: stack);
      }

      final context = navigatorKey.currentContext;
      if (context != null) {
        ErrorModal.show(
          context,
          title: t.common.unexpectedErrorOccurred,
          message: t.common.unexpectedErrorMessage,
          details: error.toString(),
        );
      }
      return true;
    };

    runApp(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          initialGoalsProvider.overrideWithValue(goalsJson!),
          initialLogsProvider.overrideWithValue(logsJson!),
        ],
        child: TranslationProvider(child: const EvolveApp()),
      ),
    );
  }

  // Apply the saved app language to slang before the first frame is built.
  // (Private mode stores language in its local DB; the settings listener in
  // EvolveApp re-syncs once those settings load.)
  await LocaleSettings.setLocale(_appLocaleFor(prefs.getString('pref_language')));

  if (hasSentryConsent && !startsInPrivateMode) {
    final info = await SentryService.releaseInfo();
    await SentryFlutter.init((options) {
      SentryService.configure(
        options,
        release: info.release,
        dist: info.dist,
      );
    }, appRunner: startApp);
  } else {
    startApp();
  }
}

bool _isRecoverableAuthSessionError(Object error) {
  if (error is! AuthException) return false;

  final message = error.message.toLowerCase();
  final code = error is AuthApiException ? error.code?.toLowerCase() : null;

  return code == 'refresh_token_not_found' ||
      message.contains('invalid refresh token') ||
      message.contains('refresh token not found');
}

// ── Router ───────────────────────────────────────────────────────────────────
// Usa un listenable che reagisce ai cambiamenti di sessione Supabase,
// così GoRouter redireziona automaticamente senza polling.
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);
  final dataModeNotifier = ref.watch(activeDataModeProvider.notifier);
  final dataMode = ref.watch(activeDataModeProvider);
  final consentState = ref.watch(consentProvider);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: false,
    refreshListenable: Listenable.merge([authNotifier, dataModeNotifier]),
    observers: dataMode == AppDataMode.private
        ? const []
        : [SentryNavigatorObserver()],
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/consent',
        builder: (context, state) => const ConsentScreen(),
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final canAccessApp = authState.canAccessApp;
      final isLoggingIn = state.matchedLocation == '/login';
      final isConsentPage = state.matchedLocation == '/consent';

      // 1. Se non ha completato il consenso, deve andare a /consent
      if (!consentState.hasCompletedOnboarding) {
        if (!isConsentPage) {
          return '/consent';
        }
        return null; // Rimani su /consent
      }

      // 2. Se ha completato il consenso ed è su /consent, vai avanti
      if (isConsentPage) {
        return canAccessApp ? '/' : '/login';
      }

      // 3. Logica normale di autenticazione
      if (!canAccessApp && !isLoggingIn) return '/login';
      if (canAccessApp && isLoggingIn) return '/';
      return null;
    },
  );
});

// ── App ──────────────────────────────────────────────────────────────────────
/// Replays notification-queued habit logs whenever the app returns to the
/// foreground (NOTIF-1). [NotificationService.replayPendingHabitLogs] cheaply
/// no-ops when the queue is empty, so this is safe on every resume.
class _NotificationReplayObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(NotificationService().replayPendingHabitLogs());
    }
  }
}

class EvolveApp extends ConsumerWidget {
  const EvolveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);

    // Keep slang's active locale in sync with the user's language preference
    // (covers the private-mode case where settings load asynchronously, and any
    // runtime language change). slang drives the app locale; MaterialApp follows.
    ref.listen<String>(settingsProvider.select((s) => s.language), (_, next) {
      final target = _appLocaleFor(next);
      if (LocaleSettings.currentLocale != target) {
        LocaleSettings.setLocale(target);
      }
    });

    return MaterialApp.router(
      title: 'Evolve',
      theme: AppTheme.lightTheme(settings.accentColor),
      darkTheme: AppTheme.darkTheme(settings.accentColor),
      themeMode: settings.themeMode == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light,
      locale: TranslationProvider.of(context).flutterLocale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: AppLocaleUtils.supportedLocales,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mediaQuery = MediaQuery.maybeOf(context);
        if (mediaQuery == null || child == null) {
          return child ?? const SizedBox.shrink();
        }

        return MediaQuery(
          data: mediaQuery.copyWith(
            alwaysUse24HourFormat: settings.timeFormat24h,
          ),
          child: child,
        );
      },
    );
  }
}

/// Maps the app's stored language preference to a slang [AppLocale].
/// "System" follows the device locale (clamped to a shipped locale); any
/// unsupported/deferred code (e.g. legacy 'ar', deferred until the RTL pass)
/// resolves to the base locale (English).
AppLocale _appLocaleFor(String? language) {
  final override = AppLanguagePreference.localeOverrideFor(
    language ?? AppLanguagePreference.system,
  );
  if (override == null) {
    return AppLocaleUtils.findDeviceLocale();
  }
  return AppLocaleUtils.parse(override.languageCode);
}
