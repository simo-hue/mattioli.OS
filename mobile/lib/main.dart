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
import 'ui/widgets/private_mode_gate.dart';
import 'ui/widgets/biometric_lock_gate.dart';
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
import 'core/verification_config.dart';
import 'core/verification_providers.dart';
import 'core/verification_wiring.dart';
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
  final savedDataMode = prefs.getString('active_data_mode');

  // Recover a private-mode user whose data-mode preference was lost/reset. If
  // the preference is ABSENT (not an explicit 'supabase') but the encrypted
  // private database is still on disk, the user is a Private-mode user whose
  // NSUserDefaults didn't survive; default to Supabase here would silently hide
  // their intact local data behind a logged-out cloud view. Restore the mode so
  // the local DB is queried again (they can still switch in Settings).
  if (savedDataMode == null && await PrivateLocalDatabase.databaseFileExists()) {
    await prefs.setString('active_data_mode', AppDataMode.private.name);
    AppLogger.warning(
      '[Startup] Restored Private mode from the on-disk database after a '
      'missing data-mode preference',
    );
  }

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

  // Carica Progress Cache (quantitative-habit daily numbers). No SharedPreferences
  // legacy to migrate — this cache is new in the targets feature — so a miss is
  // simply an empty map, seeded from the private store / Supabase on first sync.
  String? progressJson;
  try {
    progressJson = await SecureStorageUtils.read('goal_progress_cache');
  } catch (e, stack) {
    AppLogger.error('[Startup] goal_progress_cache secure read failed', e, stack);
  }
  progressJson ??= '{}';

  // ── Sentry init ──────────────────────────────────────────────────────────
  // Gated on the consent question having been ANSWERED, not just on the answer:
  // 'has_sentry_consent' is absent on a fresh install and reads back as true, so
  // gating on it alone initializes Sentry before the consent screen is shown.
  // Once the user answers, ConsentScreen starts the SDK itself, and
  // _EvolveAppState keeps it aligned for the rest of the session.
  final shouldStartSentry = SentryService.shouldRun(
    hasCompletedConsent: prefs.getBool('has_completed_consent') ?? false,
    hasSentryConsent: prefs.getBool('has_sentry_consent') ?? true,
    isPrivateMode: startsInPrivateMode,
  );

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
          initialProgressProvider.overrideWithValue(progressJson!),
        ],
        child: TranslationProvider(child: const EvolveApp()),
      ),
    );
  }

  // Apply the saved app language to slang before the first frame is built.
  await LocaleSettings.setLocale(_appLocaleFor(storedLanguageFor(prefs)));

  // `isConfigured` is the second half of the gate: shouldStartSentry answers
  // "may we?", this answers "can we?". A build whose sentry_config.dart is the
  // unfilled template (as every CI build's is) must start the app WITHOUT
  // Sentry rather than throw out of SentryFlutter.init.
  if (shouldStartSentry && SentryService.isConfigured) {
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
      GoRoute(path: '/', builder: (context, state) => const _PrivateAwareHome()),
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
/// The home route. In Private mode it wraps the dashboard in [PrivateModeGate]
/// so the encrypted DB is opened — and a LOCKED one recovered (auto re-pull from
/// iCloud when safe, else an explicit choice) — before the dashboard loads. This
/// covers both a fresh "continue privately" and a restored Private session.
class _PrivateAwareHome extends ConsumerWidget {
  const _PrivateAwareHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrivate =
        ref.watch(activeDataModeProvider) == AppDataMode.private;
    return isPrivate
        ? const PrivateModeGate(child: HomeScreen())
        : const HomeScreen();
  }
}

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

  /// Polls for another device's edits while the app is open and in the
  /// foreground — desktop has always had this; iOS did not.
  ///
  /// 60 seconds, matching desktop. Push is registered but has never been
  /// observed to deliver, so this timer is the real sync path, not a fallback.
  /// Foreground-only: iOS suspends timers in the background, so this costs
  /// nothing while the app is not on screen.
  ///
  /// Without it the ONLY automatic pull was `resumed`, so an iPhone left open on
  /// a screen never learned about a Mac edit at all: no launch sync, no timer,
  /// and no CloudKit push subscription. Matching desktop's cadence is also what
  /// makes the two apps behave the same way, which is the point of the exercise.
  Timer? _periodicSync;
  static const _periodicSyncInterval = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _writeDebouncer =
        SyncWriteDebouncer(onFlush: () => _syncAndRefresh(reason: 'write'));
    PrivateLocalDatabase.onPrivateWrite = _onPrivateWrite;

    // Launch sync. A cold start does NOT emit `resumed`, so without this the
    // first pull of a session waited for the user to background the app and
    // come back — the reason a freshly-opened iPhone could sit on stale data
    // indefinitely.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncIfPrivate('launch'));
    _periodicSync =
        Timer.periodic(_periodicSyncInterval, (_) => _syncIfPrivate('poll'));

    // Auto-verified habits: keep DeviceActivity monitoring in step with the goal
    // list. Creating, editing and deleting a Screen Time habit all land here, as
    // does the initial asynchronous load — so registration no longer waits for a
    // background→foreground round trip, which is what it used to do (the resumed
    // hook below was the only caller, so a cold-launched session that never
    // backgrounded registered nothing at all). Listening to the goal list rather
    // than calling the bridge from each mutation site keeps the trigger in one
    // place, so no future write path can forget it.
    //
    // `weak: true` is load-bearing, not an optimization. A normal subscription
    // would INSTANTIATE `GoalsNotifier` here in `initState`, and its `build()`
    // opens the encrypted private database (goal_provider.dart →
    // `_loadFromPrivateStore`). That would run before `PrivateModeGate` — which
    // owns key recovery — has had its turn, and on a device left mid-recovery an
    // early open mints a fresh key against a missing file, turning a recoverable
    // "locked" state into a permanently undecryptable one. Weak listening keeps
    // that ordering intact: it observes the provider without keeping it alive.
    //
    // So the first callback lands when something below the gate first watches
    // goals — carrying the not-yet-loaded `[]`, which is why the sync awaits
    // `ensureLoaded()` rather than trusting an empty list. `fireImmediately` is
    // not merely unnecessary here, it is forbidden: Riverpod asserts on
    // `weak && fireImmediately`.
    if (VerificationConfig.screenTimeEnabled) {
      ref.listenManual(
        goalsProvider,
        (_, _) {
          _goalsAlive = true;
          _syncScreenTimeMonitoring();
        },
        weak: true,
      );
      // The Mode-A selection blob is stored separately from the goal, so both a
      // re-pick that leaves the goal untouched AND the initial pick (committed
      // after the goal is saved, keyed by the final id) have to reach
      // DeviceActivity through here.
      ref.listenManual(
        screenTimeSelectionsProvider,
        (_, _) => _syncScreenTimeMonitoring(),
        weak: true,
      );
    }

    // CloudKit zone-change push: the low-latency path. It routes into the SAME
    // mode-gated sync as every other trigger — push changes only WHEN sync runs.
    // The timer above is deliberately kept: iOS drops silent pushes at its own
    // discretion, so push can shorten the wait but must never be the only way a
    // change arrives.
    MethodChannelCloudKitBridge.setRemoteChangeHandler(
      () => _syncIfPrivate('push'),
      // Native-side APNs events: the only way an "this device has no push
      // token" state becomes visible in an exported log.
      onNativeLog: (level, message) => level == 'error'
          ? AppLogger.error(message, null)
          : AppLogger.info(message),
    );
  }

  @override
  void dispose() {
    if (identical(PrivateLocalDatabase.onPrivateWrite, _onPrivateWrite)) {
      PrivateLocalDatabase.onPrivateWrite = null;
    }
    _periodicSync?.cancel();
    MethodChannelCloudKitBridge.clearRemoteChangeHandler();
    _writeDebouncer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Mode-gated fire-and-forget sync. Gated so it never opens the private DB or
  /// calls CloudKit in Supabase mode; the service itself no-ops on Android and
  /// when sync is disabled. Guarded on `mounted` because both callers fire from
  /// timers that can outlive a dispose.
  void _syncIfPrivate([String reason = 'unknown']) {
    if (!mounted) return;
    if (ref.read(activeDataModeProvider) != AppDataMode.private) return;
    unawaited(_syncAndRefresh(reason: reason));
  }

  /// True while a Screen Time monitoring sync is running. Set BEFORE the async
  /// body starts, so no synchronous early return inside it can invert the flag.
  bool _screenTimeSyncRunning = false;

  /// Set when a trigger arrives while a sync is running: the in-flight pass
  /// re-runs once it finishes, with freshly-read state (latest-wins).
  bool _screenTimeSyncQueued = false;

  /// Whether `goalsProvider` is known to be alive, i.e. its weak listener has
  /// fired at least once.
  ///
  /// Gating on this rather than reading the provider is what preserves the
  /// `weak: true` guarantee above: a strong `ref.read` from the SELECTIONS
  /// listener could instantiate `GoalsNotifier` — and with it the private
  /// database — ahead of `PrivateModeGate`, which is exactly what weak listening
  /// exists to prevent.
  bool _goalsAlive = false;

  /// Pushes the current Screen Time goals to DeviceActivity.
  ///
  /// Coalesced and serialized: the goal list changes identity several times per
  /// launch (cache seed, then server sync) and again per mutation (optimistic
  /// insert with a temporary id, then the persisted one). Overlapping passes
  /// would each read the same stale `cache.last` and could race to leave the
  /// cache describing something native does not hold — including re-registering
  /// a goal that was deleted mid-flight. One at a time, latest wins.
  ///
  /// Fire-and-forget and fully guarded: monitoring is best-effort infrastructure,
  /// so a failure here must never surface in the UI or break the write that
  /// triggered it.
  void _syncScreenTimeMonitoring() {
    if (!mounted || !_goalsAlive) return;
    if (_screenTimeSyncRunning) {
      _screenTimeSyncQueued = true;
      return;
    }
    _screenTimeSyncRunning = true;
    unawaited(_runScreenTimeSync());
  }

  Future<void> _runScreenTimeSync() async {
    try {
      do {
        _screenTimeSyncQueued = false;
        // Wait out the load before believing an empty list. `build()` returns
        // `[]` and fills in asynchronously, and it re-runs on EVERY applied
        // iCloud sync (`invalidatePrivateDataProviders`), which the 60s poll can
        // reach once a minute. Without this barrier each of those passes would
        // hand DeviceActivity an empty spec list — which means "stop monitoring
        // everything" — and then re-register moments later, re-zeroing every
        // goal's accumulated usage for the day.
        //
        // Bounded, because this await sits INSIDE the serialized region: while
        // it is pending every other trigger only sets `_screenTimeSyncQueued`
        // and returns, so an unbounded wait would deafen the feature for as long
        // as the load takes — and `_syncFromSupabase` has no request deadline of
        // its own, so a black-hole or captive-portal network can hold it for
        // minutes.
        // Two ways this can fail to give a trustworthy answer, and both must
        // land on the same cautious branch: the load never finishing (timeout),
        // and the barrier giving up because rebuilds kept outpacing loads
        // (`ensureLoaded` returning false). Neither is "the list is empty".
        final loaded = await ref
            .read(goalsProvider.notifier)
            .ensureLoaded()
            .timeout(const Duration(seconds: 10), onTimeout: () => false);
        if (!mounted) return;
        final goals = ref.read(goalsProvider);
        // A timed-out barrier leaves an empty list ambiguous again, and empty is
        // the DESTRUCTIVE direction — it tells DeviceActivity to stop watching
        // everything. So skip the pass rather than acting on it: monitoring
        // stays exactly as it is, and the load landing later fires the listener
        // again. A non-empty list needs no barrier — it is real data either way.
        if (!loaded && goals.isEmpty) {
          AppLogger.warning(
            '[Verification] goal load did not settle in time — leaving Screen '
            'Time monitoring untouched rather than stopping it',
          );
          // `continue`, NOT `return`. A trigger that arrived while the barrier
          // was stalled has only set `_screenTimeSyncQueued`; returning here
          // would clear `_screenTimeSyncRunning` in the `finally` with that flag
          // still set and nothing left to read it. `continue` re-tests the
          // condition, so a queued trigger gets another attempt.
          //
          // It narrows the window rather than closing it: if the barrier is
          // still stalled on the retry, the pass is deferred — the resume
          // reconcile calls the sync unbarriered and is the real backstop. That
          // is inherent to the policy, since nothing here can distinguish "empty
          // because unloaded" from "empty because deleted".
          continue;
        }
        // Read inside the loop: a pass queued while this one was awaiting native
        // must act on the goal list as it stands NOW, not as it stood then.
        await syncScreenTimeMonitoringFor(
          goals: goals,
          bridge: ref.read(screenTimeBridgeProvider),
          cache: ref.read(screenTimeSyncCacheProvider),
          selectionFor: (id) => ref.read(screenTimeSelectionsProvider)[id]?.blob,
          onMonitorLimit: (e) =>
              ref.read(screenTimeMonitorLimitProvider.notifier).report(e),
        );
      } while (_screenTimeSyncQueued && mounted);
    } catch (e, stack) {
      AppLogger.error('[Verification] monitoring sync failed', e, stack);
    } finally {
      _screenTimeSyncRunning = false;
    }
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
      unawaited(_syncAndRefresh(reason: 'resume'));
    }

    // Auto-verified habits: lazy reconcile on foreground is the authoritative
    // verdict path (D3). Gated by the feature flag (off ⇒ dead code) and
    // fire-and-forget so it never affects the UI; it no-ops when nothing is
    // verifiable and applies verdicts through the habit-log providers itself.
    if (state == AppLifecycleState.resumed && VerificationConfig.enabled) {
      unawaited(() async {
        try {
          await runVerificationReconcile(ref);
        } catch (e, stack) {
          AppLogger.error('[Verification] foreground reconcile failed', e, stack);
        }
      }());
    }

    // Quantitative targets: end-of-day resolution on foreground. Independent of
    // the verification flag and of data mode — a manual target is plain local
    // data that works in both modes — and a no-op until a habit actually has a
    // manual target. This is what materialises a limit habit's quiet days into
    // 'done' verdicts for days that closed while the app was shut.
    if (state == AppLifecycleState.resumed) {
      unawaited(() async {
        try {
          await ref.read(habitProgressProvider.notifier).reconcileManualTargets();
        } catch (e, stack) {
          AppLogger.error('[Targets] foreground reconcile failed', e, stack);
        }
      }());
    }
  }

  /// Bring the Sentry SDK back in line with the user's current privacy choice.
  ///
  /// Closing the client is what makes a withdrawn consent or Private Mode
  /// effective mid-session: `AppLogger.setExternalReportingDisabled` only gates
  /// AppLogger's own capture calls, while the SDK keeps its own
  /// `FlutterError.onError` hook, the native crash handler, `tracesSampleRate`
  /// transactions and debugPrint breadcrumbs installed until `Sentry.close()`
  /// runs. Both revoke paths (the Privacy Settings crash-report switch and any
  /// entry into Private Mode) write through the providers listened to in
  /// [build], so reconciling here covers them without each call site
  /// remembering to.
  Future<void> _reconcileSentry() async {
    final consent = ref.read(consentProvider);
    final isPrivate =
        ref.read(activeDataModeProvider) == AppDataMode.private;
    try {
      await SentryService.setEnabled(
        SentryService.shouldRun(
          hasCompletedConsent: consent.hasCompletedOnboarding,
          hasSentryConsent: consent.hasSentryConsent,
          isPrivateMode: isPrivate,
        ),
      );
    } catch (e, stack) {
      AppLogger.error('[Sentry] Applying the privacy choice failed', e, stack);
    }
  }

  Future<void> _syncAndRefresh({String reason = 'manual'}) async {
    // Every caller launches this with `unawaited`, so an escaping error becomes
    // an UNHANDLED zone error and pops the global "something went wrong" dialog.
    // When the private DB cannot be opened, that happens on the launch sync and
    // then on every 60-second poll — a modal stack piling up on top of the very
    // recovery screen the user needs to read, forever. The recovery UI owns that
    // conversation; sync must fail quietly and let it. Desktop's
    // DesktopSyncLifecycle already does this; the mobile twin never did.
    try {
      final status =
          await ref.read(privateSyncServiceProvider).syncNow(reason: reason);
      // If the sync pulled remote changes, refresh the cached providers so the
      // UI shows them (the engine writes straight to the local DB).
      if (mounted && status.appliedChanges > 0) {
        invalidatePrivateDataProviders(ref);
      }
    } on PrivateDatabaseLockedException catch (error) {
      AppLogger.warning(
        '[Sync] skipped: the private database is locked; PrivateModeGate owns '
        'the recovery.',
        error,
      );
    } on PrivateDatabaseUndecryptableException catch (error) {
      AppLogger.warning(
        '[Sync] skipped: the private database cannot be decrypted with this '
        'key; PrivateModeGate owns the recovery.',
        error,
      );
    } catch (error, stack) {
      AppLogger.error('[Sync] automatic sync failed', error, stack);
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

    // Start/stop the Sentry SDK whenever the user's answer or the data mode
    // changes, so the choice takes effect immediately rather than at the next
    // cold start. See [_reconcileSentry].
    ref.listen<ConsentState>(consentProvider, (previous, next) {
      if (previous?.hasSentryConsent == next.hasSentryConsent &&
          previous?.hasCompletedOnboarding == next.hasCompletedOnboarding) {
        return;
      }
      unawaited(_reconcileSentry());
    });
    ref.listen<AppDataMode>(activeDataModeProvider, (previous, next) {
      if (previous == next) return;
      unawaited(_reconcileSentry());
    });

    // Theme resolution goes through the shared codec. The old check here was
    // `themeMode == 'dark' ? dark : light`, which silently rendered LIGHT for
    // the `'system'` value the schema permits and macOS can write — while macOS
    // rendered the same stored string DARK. resolveIsDark is the one answer both
    // apps now use.
    final platformIsDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = SettingsCodec.resolveIsDark(
      settings.themeMode,
      platformIsDark: platformIsDark,
    );
    // Readability is applied at PAINT time, never written back: an accent that
    // is invisible in one theme stays the user's stored choice, and the swap is
    // not pushed to their other devices. See AppSettingsNotifier.readableAccent.
    final accent = AppSettingsNotifier.readableAccent(
      settings.accentColor,
      settings.themeMode,
      platformIsDark: platformIsDark,
    );

    return MaterialApp.router(
      title: 'Evolve',
      theme: AppTheme.lightTheme(accent),
      darkTheme: AppTheme.darkTheme(accent),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
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
          // App-wide biometric (Face ID / Touch ID) lock. Wraps every route,
          // covers content while locked/backgrounded, and re-arms on resume.
          child: BiometricLockGate(child: child),
        );
      },
    );
  }
}

/// The language preference to render the FIRST frame in, for whichever data
/// mode the app is about to start in.
///
/// The two modes keep separate caches and this has to read the right one. In
/// Private mode the source of truth is the local DB, which loads
/// asynchronously; [AppSettingsNotifier.privateLanguagePrefKey] is the mirror
/// that lets the first frame render in the user's language instead of visibly
/// re-languaging a moment later. Cloud mode's cache is `pref_language`, written
/// by `_saveToPrefs`.
///
/// They used to be ONE key, which is the bug this split fixes: every private
/// load stamped the private value over `pref_language`, so a cloud-mode user who
/// tried Private mode came back to the device locale instead of the language
/// they had chosen. `active_data_mode` is `ActiveDataModeNotifier._key` and is
/// readable synchronously from the same prefs.
///
/// The Private-mode fallback to `pref_language` covers exactly one cold start:
/// an install that predates the split has no private mirror yet, and without the
/// fallback that launch would flash the device locale before the DB load lands.
@visibleForTesting
String? storedLanguageFor(SharedPreferences prefs) {
  final isPrivate =
      prefs.getString('active_data_mode') == AppDataMode.private.name;
  if (!isPrivate) return prefs.getString('pref_language');
  return prefs.getString(AppSettingsNotifier.privateLanguagePrefKey) ??
      prefs.getString('pref_language');
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
