import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeDateFormatting('it', null);

  // ── Supabase init ─────────────────────────────────────────────────────────
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(),
    ),
  );

  // ── Notifications init ───────────────────────────────────────────────────
  try {
    final notificationService = NotificationService();
    await notificationService.init().timeout(const Duration(seconds: 3));
  } catch (e, stack) {
    AppLogger.error('Notification initialization failed or timed out', e, stack);
  }

  // ── SharedPreferences init ───────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();

  // ── Secure Cache Loading & Migration ─────────────────────────────────────
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Carica Goals Cache
  String? goalsJson = await storage.read(key: 'goals_cache');
  if (goalsJson == null) {
    // Migrazione da SharedPreferences se esiste
    final oldGoals = prefs.getString('goals_cache');
    if (oldGoals != null) {
      goalsJson = oldGoals;
      await storage.write(key: 'goals_cache', value: goalsJson);
      await prefs.remove('goals_cache');
    } else {
      goalsJson = '[]';
    }
  }

  // Carica Logs Cache
  String? logsJson = await storage.read(key: 'goal_logs_cache');
  if (logsJson == null) {
    // Migrazione da SharedPreferences se esiste
    final oldLogs = prefs.getString('goal_logs_cache');
    if (oldLogs != null) {
      logsJson = oldLogs;
      await storage.write(key: 'goal_logs_cache', value: logsJson);
      await prefs.remove('goal_logs_cache');
    } else {
      logsJson = '{}';
    }
  }

  // ── Sentry init ──────────────────────────────────────────────────────────
  final hasSentryConsent = prefs.getBool('has_sentry_consent') ?? false;

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
      // Invia l'errore a Sentry (se inizializzato)
      Sentry.captureException(error, stackTrace: stack);

      final context = navigatorKey.currentContext;
      if (context != null) {
        ErrorModal.show(
          context,
          title: 'Si è verificato un errore',
          message: 'L\'applicazione ha riscontrato un problema imprevisto. Abbiamo registrato l\'errore e cercheremo di risolverlo.',
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
        child: const GrowthApp(),
      ),
    );
  }

  if (hasSentryConsent) {
    await SentryFlutter.init(
      (options) {
        options.dsn = SentryConfig.dsn;
        options.environment = SentryConfig.environment;
        options.tracesSampleRate = SentryConfig.tracesSampleRate;
        options.reportPackages = true;
        options.debug = false;
        options.beforeSend = (event, hint) {
          return SentryConfig.sanitizeEvent(event);
        };
      },
      appRunner: startApp,
    );
  } else {
    startApp();
  }
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
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthScreen(),
      ),
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
class GrowthApp extends ConsumerWidget {
  const GrowthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Growth',
      theme: AppTheme.lightTheme(settings.accentColor),
      darkTheme: AppTheme.darkTheme(settings.accentColor),
      themeMode: settings.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
