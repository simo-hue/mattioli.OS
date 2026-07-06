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
import 'core/private_local_database.dart';
import 'core/private_sync_service.dart';
import 'providers/sync_refresh.dart';
import 'i18n/translations.g.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // ── Load persisted App Logs ───────────────────────────────────────────────
  await AppLogger.loadLogs();

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

      // Registra l'errore globalmente (App Logs + Sentry se abilitato)
      AppLogger.error(
        '[System] Unhandled global exception',
        error,
        stack,
      );

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
    observers: [
      AppLoggerNavigatorObserver(),
      if (dataMode != AppDataMode.private) SentryNavigatorObserver(),
    ],
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

class EvolveApp extends ConsumerStatefulWidget {
  const EvolveApp({super.key});

  @override
  ConsumerState<EvolveApp> createState() => _EvolveAppState();
}

class _EvolveAppState extends ConsumerState<EvolveApp>
    with WidgetsBindingObserver {
  /// After-write sync trigger (iCloud sync trigger #2): private-mode writes
  /// funnel through [PrivateLocalDatabase.onPrivateWrite] and coalesce here
  /// into one sync a few quiet seconds after the last edit.
  late final SyncWriteDebouncer _writeDebouncer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _writeDebouncer = SyncWriteDebouncer(onFlush: _syncAndRefresh);
    PrivateLocalDatabase.onPrivateWrite = _onPrivateWrite;
  }

  @override
  void dispose() {
    if (identical(PrivateLocalDatabase.onPrivateWrite, _onPrivateWrite)) {
      PrivateLocalDatabase.onPrivateWrite = null;
    }
    _writeDebouncer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onPrivateWrite() {
    // Mode-gated like the resume trigger; the service additionally no-ops when
    // sync is disabled, so a disabled user costs one cheap call per burst.
    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      _writeDebouncer.notifyWrite();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.info('[AppLifecycle] State changed to ${state.name}', category: 'lifecycle');

    // Foreground sync trigger: on resume, pull/push private data. Gated to
    // Private mode so it never opens the private DB or calls CloudKit in
    // Supabase mode; the service itself is a no-op on Android and when sync is
    // disabled. Fire-and-forget — failures never affect the UI.
    if (state == AppLifecycleState.resumed &&
        ref.read(activeDataModeProvider) == AppDataMode.private) {
      unawaited(_syncAndRefresh());
    }
  }

  Future<void> _syncAndRefresh() async {
    final status = await ref.read(privateSyncServiceProvider).syncNow();
    // If the sync pulled remote changes, refresh the cached providers so the UI
    // shows them (the engine writes straight to the local DB).
    if (mounted && status.appliedChanges > 0) {
      invalidatePrivateDataProviders(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
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
/// code with no shipped translation resolves to the base locale (English) via
/// slang's `parse` fallback.
AppLocale _appLocaleFor(String? language) {
  final override = AppLanguagePreference.localeOverrideFor(
    language ?? AppLanguagePreference.system,
  );
  if (override == null) {
    return AppLocaleUtils.findDeviceLocale();
  }
  return AppLocaleUtils.parse(override.languageCode);
}
