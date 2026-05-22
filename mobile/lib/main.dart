import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/goal_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'dart:ui';
import 'core/theme.dart';
import 'core/supabase_config.dart';
import 'core/sentry_config.dart';
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
import 'core/localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting();

  // ── Supabase init ─────────────────────────────────────────────────────────
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()),
  );

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

  // ── SharedPreferences init ───────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();

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
                const Text(
                  'Ops! Qualcosa è andato storto.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exception.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
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
      Sentry.captureException(error, stackTrace: stack);

      final context = navigatorKey.currentContext;
      if (context != null) {
        ErrorModal.show(
          context,
          title: 'Si è verificato un errore',
          message:
              'L\'applicazione ha riscontrato un problema imprevisto. Abbiamo registrato l\'errore e cercheremo di risolverlo.',
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
        child: const EvolveApp(),
      ),
    );
  }

  if (hasSentryConsent) {
    await SentryFlutter.init((options) {
      options.dsn = SentryConfig.dsn;
      options.environment = SentryConfig.environment;
      options.tracesSampleRate = SentryConfig.tracesSampleRate;
      options.reportPackages = true;
      options.debug = false;
      options.beforeSend = (event, hint) {
        return SentryConfig.sanitizeEvent(event);
      };
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
  final consentState = ref.watch(consentProvider);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: false,
    refreshListenable: authNotifier,
    observers: [SentryNavigatorObserver()],
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/consent',
        builder: (context, state) => const ConsentScreen(),
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = ref.read(authProvider).isLoggedIn;
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
        return isLoggedIn ? '/' : '/login';
      }

      // 3. Logica normale di autenticazione
      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/';
      return null;
    },
  );
});

// ── App ──────────────────────────────────────────────────────────────────────
class EvolveApp extends ConsumerWidget {
  const EvolveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Evolve',
      theme: AppTheme.lightTheme(settings.accentColor),
      darkTheme: AppTheme.darkTheme(settings.accentColor),
      themeMode: settings.themeMode == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light,
      locale: settings.localeOverride,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: _resolveAppLocale,
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

Locale _resolveAppLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  final primaryLocale = preferredLocales == null || preferredLocales.isEmpty
      ? null
      : preferredLocales.first;
  if (primaryLocale != null) {
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == primaryLocale.languageCode) {
        return supportedLocale;
      }
    }
  }

  return const Locale('en');
}
