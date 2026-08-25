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
import 'ui/screens/data_mode_choice_screen.dart';
import 'ui/screens/consent_screen.dart';
import 'ui/widgets/private_mode_gate.dart';
import 'ui/widgets/biometric_lock_gate.dart';
import 'providers/consent_provider.dart';
import 'core/notifications.dart';
import 'ui/widgets/error_modal.dart';
import 'core/navigator_key.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/app_logger.dart';
import 'core/streak_repair.dart';
import 'core/secure_local_storage.dart';
import 'core/secure_storage_utils.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/data_mode.dart';
import 'core/private_local_database.dart';
import 'core/reconcile_triggers.dart';
import 'models/goal.dart';
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
  if (savedDataMode == null &&
      await PrivateLocalDatabase.databaseFileExists()) {
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
  //
  // Gated on the consent question having been ANSWERED, through the same shape
  // as the Sentry gate below. This used to be `if (!startsInPrivateMode)`, which
  // is the whole condition on a FRESH install but not on a REINSTALL: Keychain
  // items survive app deletion and `NSUserDefaults` does not, so the session
  // outlived `has_completed_consent` and the SDK restored it — refreshing the
  // token over the network — while the router was still on its way to the
  // consent screen.
  //
  // Deferring is cheap because the lazy path already existed:
  // `ensureSupabaseInitialized` guards every auth entry point, and the consent
  // screen calls `adoptSessionAfterConsent` the moment the user answers.
  if (shouldInitialiseSupabaseAtStartup(
    hasCompletedConsent: prefs.getBool(kHasCompletedConsentPrefKey) ?? false,
    isPrivateMode: startsInPrivateMode,
  )) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()),
    );
    // Cold-start foreground: flush any habit-log actions queued by notification
    // taps while the app was terminated/offline (NOTIF-1). Non-blocking. Inside
    // the gate deliberately — replaying WRITES to the server, which is the last
    // thing that may happen before consent.
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
    AppLogger.error(
      '[Startup] goal_progress_cache secure read failed',
      e,
      stack,
    );
  }
  progressJson ??= '{}';

  // ── Sentry init ──────────────────────────────────────────────────────────
  // Gated on the consent question having been ANSWERED, not just on the answer:
  // 'has_sentry_consent' is absent on a fresh install, so gating on it alone
  // would initialize Sentry before the consent screen is shown. Once the user
  // answers, ConsentScreen starts the SDK itself, and _EvolveAppState keeps it
  // aligned for the rest of the session.
  final shouldStartSentry = SentryService.shouldRun(
    hasCompletedConsent: prefs.getBool(kHasCompletedConsentPrefKey) ?? false,
    hasSentryConsent: prefs.getBool('has_sentry_consent') ?? false,
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
      AppLogger.error('[System] Unhandled global exception', error, stack);

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
      SentryService.configure(options, release: info.release, dist: info.dist);
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
      GoRoute(
        path: '/',
        builder: (context, state) => const _PrivateAwareHome(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      // The signed-out landing screen. NOT '/login' — see
      // DataModeChoiceScreen's class doc for why the login wall could not stay
      // first (Guideline 5.1.1(v)).
      GoRoute(
        path: '/choose',
        builder: (context, state) => const DataModeChoiceScreen(),
      ),
      GoRoute(
        path: '/consent',
        builder: (context, state) => const ConsentScreen(),
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final canAccessApp = authState.canAccessApp;
      final isLoggingIn = state.matchedLocation == '/login';
      final isChoosingMode = state.matchedLocation == '/choose';
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
        return canAccessApp ? '/' : '/choose';
      }

      // 3. Logica normale di autenticazione.
      //
      // A signed-out user lands on '/choose', never on '/login'. '/login' stays
      // reachable — the chooser pushes it, and it is the target after a
      // sign-out — so it must NOT be redirected away from here, or the sign-in
      // path would be unreachable.
      if (!canAccessApp && !isLoggingIn && !isChoosingMode) return '/choose';
      if (canAccessApp && (isLoggingIn || isChoosingMode)) return '/';
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
    final isPrivate = ref.watch(activeDataModeProvider) == AppDataMode.private;
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
    _writeDebouncer = SyncWriteDebouncer(
      onFlush: () => _syncAndRefresh(reason: 'write'),
    );
    PrivateLocalDatabase.onPrivateWrite = _onPrivateWrite;

    // Launch sync. A cold start does NOT emit `resumed`, so without this the
    // first pull of a session waited for the user to background the app and
    // come back — the reason a freshly-opened iPhone could sit on stale data
    // indefinitely.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _syncIfPrivate('launch'),
    );

    // One-time repair of the streaks the empty-goals window corrupted. Runs
    // once per install, after the writers that caused it were fixed — running
    // it before would simply re-corrupt. Best-effort and off the critical path.
    WidgetsBinding.instance.addPostFrameCallback((_) => _repairStreaksOnce());
    _periodicSync = Timer.periodic(_periodicSyncInterval, (_) {
      _syncIfPrivate('poll');
      // Midnight rollover. Nothing else can cover it: an app left open across
      // 00:00 receives no lifecycle event, so before this the previous day was
      // never resolved — a count habit's closed day kept no verdict and a
      // verified habit's day was never scored. Cheap: a date comparison per
      // minute, and it schedules a pass only on the tick the date actually
      // changes.
      _reconcileIfDayChanged();
    });

    // The COLD-LAUNCH and habit-edit trigger for both end-of-day passes.
    //
    // `AppLifecycleState.resumed` — which was their only trigger — is not
    // delivered on a cold start, exactly as the launch-sync comment above
    // records for iCloud. So a force-quit → launch loop, the way a build is
    // actually tested on device, never ran either pass: no verdict was ever
    // written for a verified habit, and no closed count day was ever resolved.
    //
    // Listening to the goal list rather than calling from each mutation site
    // keeps the trigger in one place, so no future write path can forget it —
    // the same reasoning as the Screen Time registration listener below, and
    // `weak: true` is load-bearing here for the same reason: a normal
    // subscription would instantiate `GoalsNotifier` in `initState` and open the
    // encrypted private database ahead of `PrivateModeGate`, which on a device
    // left mid-recovery can turn a recoverable "locked" state into a permanently
    // undecryptable one.
    //
    // NOT gated on `VerificationConfig` — the manual-target sweep is independent
    // of the verification flag, and `_runReconciles` gates the verification half
    // on its own.
    ref.listenManual(goalsProvider, (_, next) {
      _goalsAlive = true;
      _reconcileIfGoalsChanged(next);
    }, weak: true);

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
      ref.listenManual(goalsProvider, (_, _) {
        _goalsAlive = true;
        _syncScreenTimeMonitoring();
      }, weak: true);
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

  /// True while a reconcile pass is running; a trigger arriving meanwhile only
  /// queues a re-run. Set BEFORE the async body starts, so no early return
  /// inside it can invert the flag. See [_scheduleReconciles].
  bool _reconcileRunning = false;

  /// Set when a trigger arrives while a pass is running: the in-flight pass
  /// re-runs once it finishes, with freshly-read state (latest wins).
  bool _reconcileQueued = false;

  /// The calendar day the last reconcile pass ran for, or null if none has run
  /// this session. Drives the midnight rollover trigger.
  DateTime? _lastReconciledDay;

  /// The goal-list signature the last pass was triggered by, so identity churn
  /// that leaves scoring-relevant content untouched costs nothing.
  String? _lastGoalSignature;

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
          selectionFor: (id) =>
              ref.read(screenTimeSelectionsProvider)[id]?.blob,
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
    AppLogger.info(
      '[AppLifecycle] State changed to ${state.name}',
      category: 'lifecycle',
    );

    // Foreground sync trigger: on resume, pull/push private data. Gated to
    // Private mode so it never opens the private DB or calls CloudKit in
    // Supabase mode; the service itself is a no-op on Android and when sync is
    // disabled. Fire-and-forget — failures never affect the UI.
    if (state == AppLifecycleState.resumed &&
        ref.read(activeDataModeProvider) == AppDataMode.private) {
      unawaited(_syncAndRefresh(reason: 'resume'));
    }

    // Auto-verified habits (D3) and quantitative targets: the two end-of-day
    // passes. `resumed` used to be their ONLY trigger, which meant they never
    // ran on a cold launch — see [_scheduleReconciles].
    if (state == AppLifecycleState.resumed) {
      _scheduleReconciles('resume');
    }
  }

  /// Runs the two end-of-day passes — the auto-verified verdict reconcile and
  /// the manual-target sweep — coalesced and serialized, latest wins.
  ///
  /// THREE triggers now feed this, because `resumed` alone reached none of the
  /// cases that actually matter:
  ///
  ///  * **`resumed`** — the original, and still the one that matters for a
  ///    background → foreground round trip.
  ///  * **the goal-list listener** — covers the COLD LAUNCH, which `resumed`
  ///    does not (see [reconcile_triggers.dart] for the framework mechanism).
  ///    A force-quit → launch loop therefore used to score nothing at all, ever:
  ///    a verified habit's day never became done/missed and a count habit's
  ///    closed day kept no verdict. The same listener covers the moment a habit
  ///    is CREATED or EDITED, so a freshly made verifiable habit no longer waits
  ///    for a background round trip to be judged.
  ///  * **the periodic date check** — covers an app left open across midnight,
  ///    which emits no lifecycle event at all, so yesterday was never resolved.
  ///
  /// Coalesced exactly like [_syncScreenTimeMonitoring]: the goal list changes
  /// identity several times per launch and per mutation, and overlapping passes
  /// would race each other's writes. Fire-and-forget and fully guarded — both
  /// passes are best-effort, so a failure must never surface in the UI.
  /// Fires the one-time streak repair in Private mode. Cloud-mode rows are
  /// repaired by their own path (a backup import's `_recomputeCloudStreaks`) —
  /// there is no equivalent local pass to run here.
  Future<void> _repairStreaksOnce() async {
    if (!mounted) return;
    if (ref.read(activeDataModeProvider) != AppDataMode.private) return;

    // Wait for the VERDICT MAP to be trustworthy before recomputing anything.
    //
    // The repair derives every streak from a habit's full log history and now
    // stamps a fresh `updated_at` so the correction WINS last-write-wins on the
    // other device. Those two facts together make running it over a partially
    // pulled history actively dangerous: a launch-time sync is still arriving,
    // so the history can be short, the recomputed streaks are wrong, and being
    // newer they overwrite the CORRECT values on the Mac. That is worse than the
    // corruption it exists to repair.
    //
    // The gate is the same one the sweeps use, and `loadIsTrustworthy` tells a
    // failed load apart from a genuinely empty one. On failure the repair simply
    // does not run and is retried next launch — it is never marked done.
    final logsLoaded = await ref
        .read(habitLogsProvider.notifier)
        .ensureLoaded()
        .timeout(const Duration(seconds: 10), onTimeout: () => false);
    if (!mounted || !logsLoaded) {
      AppLogger.warning(
        '[Streaks] repair deferred — the verdict map did not settle; '
        'recomputing from a partial history would push wrong streaks',
      );
      return;
    }
    final corrected = await runStreakRepairOnce(
      store: ref.read(privateLocalDatabaseProvider),
      prefs: ref.read(sharedPrefsProvider),
    );
    // A repair that changed rows makes every in-memory streak stale.
    if (corrected != null && corrected > 0 && mounted) {
      ref.invalidate(habitStatsProvider);
      ref.invalidate(habitAnalyticsProvider);
    }
  }

  void _scheduleReconciles(String reason) {
    if (!mounted) return;
    if (_reconcileRunning) {
      _reconcileQueued = true;
      return;
    }
    _reconcileRunning = true;
    unawaited(_runReconciles(reason));
  }

  Future<void> _runReconciles(String reason) async {
    try {
      do {
        _reconcileQueued = false;
        final startedAt = DateTime.now();
        final startedOn =
            DateTime(startedAt.year, startedAt.month, startedAt.day);
        AppLogger.info(
          '[Reconcile] running both passes ($reason)',
          category: 'lifecycle',
        );

        // Drain the notification queue BEFORE either pass, and exactly once.
        //
        // A Done tapped on a reminder while the app had no session is written to
        // `goal_logs` only — no number — and lands in that queue, not in the
        // in-memory map. BOTH passes would otherwise misread those days, in
        // mirror-image ways: the target sweep's auto-fail would see an untouched
        // day and write 'missed' over the user's own answer, and the
        // verification pass would see a D9 freeze with no verdict behind it,
        // conclude the write never landed, clear the freeze and overwrite the
        // day with a sensor verdict. Same "absence is not evidence" trap, one
        // layer out, once per pipeline.
        //
        // Reload the verdict map ONLY when the replay actually wrote something.
        // Invalidating unconditionally cost a full re-download of `goal_logs`
        // (or a full SQLCipher read) on EVERY foreground, repainted every
        // calendar empty for a frame — and, offline, re-seeded the map from the
        // blob frozen at app launch, silently reverting every check-in made
        // since. Failing here must not skip either pass, so the replay is
        // guarded separately.
        //
        // `pendingVerdicts == null` means the queue could not be READ. The
        // target sweep withholds auto-fail on it; the verification pass no
        // longer needs to react at all, because a frozen day is now RESTORED
        // from the status the freeze carries rather than judged, so nothing it
        // does depends on being able to enumerate the queue.
        Map<String, Map<String, String>>? pendingVerdicts;
        try {
          final replay = await NotificationService().replayPendingHabitLogs();
          if (replay.written > 0) ref.invalidate(habitLogsProvider);
          pendingVerdicts = replay.pending;
        } catch (e, stack) {
          AppLogger.error(
            '[Reconcile] pending-log replay failed ($reason)',
            e,
            stack,
          );
          pendingVerdicts = null;
        }
        if (!mounted) return;

        // Auto-verified habits: lazy reconcile is the authoritative verdict path
        // (D3). Gated by the feature flag (off ⇒ dead code). Isolated in its own
        // try so a HealthKit/channel failure cannot cost the target sweep below —
        // they share a trigger, not a fate.
        if (VerificationConfig.enabled) {
          try {
            // Passed through as a plain map: the queued verdicts are merged
            // under the stored ones so a queued Done reads as the verdict it
            // is. Null degrades to empty here without harm — a frozen day is
            // restored from its own recorded status, so the pass never needs
            // the queue to tell it what the user decided.
            await runVerificationReconcile(
              ref,
              pendingVerdicts: pendingVerdicts,
            );
          } catch (e, stack) {
            AppLogger.error(
              '[Verification] reconcile failed ($reason)',
              e,
              stack,
            );
          }
        }
        if (!mounted) return;

        // Quantitative targets: end-of-day resolution. Independent of the
        // verification flag and of data mode — a manual target is plain local
        // data that works in both modes — and a no-op until a habit actually has
        // a manual target. This is what resolves days that closed while the app
        // was shut: a limit habit's quiet days into 'done', and — from the
        // auto-fail anchor on — a count habit's untouched days into 'missed'.
        try {
          // A day still sitting in the queue is one the user has DECIDED but the
          // server has not been told about, so it is absent from the verdict map
          // — and auto-fail would read it as untouched and overwrite a Done with
          // 'missed', unrecoverably. Passing the entries through protects
          // exactly those days; it used to switch auto-fail off entirely, which
          // one permanently-unwritable entry then did forever.
          await ref
              .read(habitProgressProvider.notifier)
              .reconcileManualTargets(
                allowAutoFail: pendingVerdicts != null,
                pendingVerdicts: pendingVerdicts ?? const {},
              );
        } catch (e, stack) {
          AppLogger.error('[Targets] sweep failed ($reason)', e, stack);
        }

        // The rollover trigger's "we have looked at this day" marker.
        //
        // Stamped with the day the pass EVALUATED, not the wall clock when it
        // finished: a pass that starts at 23:59:59 and takes two seconds judged
        // yesterday, and stamping tomorrow's date would consume the rollover
        // that is supposed to bring it back for today.
        //
        // Late rather than early, because stamping up front marked days as
        // looked-at that a declined pass never reached. Late cannot cause the
        // churn early avoided: a tick arriving mid-pass only sets
        // `_reconcileQueued`, and a date that genuinely changed mid-pass
        // DESERVES the extra run.
        _lastReconciledDay = startedOn;
      } while (_reconcileQueued && mounted);
    } finally {
      _reconcileRunning = false;
    }
  }

  /// Fires the passes when the calendar day has rolled over since the last one.
  /// Driven by the existing 60-second tick, so an app sitting open at midnight
  /// resolves yesterday instead of waiting for the user to background it.
  void _reconcileIfDayChanged() {
    if (!mounted) return;
    if (!shouldReconcileForDayChange(
      lastReconciledDay: _lastReconciledDay,
      now: DateTime.now(),
    )) {
      return;
    }
    _scheduleReconciles('rollover');
  }

  /// Fires the passes when the goal list's SCORING-RELEVANT content changes.
  ///
  /// Signature-compared rather than identity-compared: the list is rebuilt on
  /// every applied iCloud sync, which the 60s poll can reach once a minute, and
  /// an identity trigger would run a full HealthKit pass (7 days × every
  /// condition) that often. See [goalReconcileSignature].
  ///
  /// Takes the listener's own `next` value rather than reading the provider:
  /// `ref.read(goalsProvider)` would INSTANTIATE `GoalsNotifier`, whose `build()`
  /// opens the encrypted private database, and the whole point of the `weak: true`
  /// subscription is to never do that ahead of `PrivateModeGate`. The callback's
  /// value is already in hand and costs nothing.
  void _reconcileIfGoalsChanged(List<Goal> goals) {
    if (!mounted) return;
    // An EMPTY list is never treated as a content change.
    //
    // `GoalsNotifier.build()` returns `[]` synchronously and fills in
    // asynchronously, and it re-runs on every applied iCloud sync — which the
    // 60s poll can reach once a minute. So the signature toggles
    // real → '' → real on each of those, firing two passes where one was
    // warranted, the first of them against a list that is empty only because it
    // has not loaded yet. Same "absence is not evidence" reading as everywhere
    // else: an empty list here is a not-yet-answered question, not an answer.
    //
    // Nothing is lost by ignoring it — the load lands moments later and fires
    // the listener again with the real list. A user who genuinely deletes their
    // last habit has nothing left to reconcile.
    if (goals.isEmpty) return;
    final signature = goalReconcileSignature(goals);
    if (signature == _lastGoalSignature) return;
    _lastGoalSignature = signature;
    _scheduleReconciles('goals');
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
    final isPrivate = ref.read(activeDataModeProvider) == AppDataMode.private;
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
      final status = await ref
          .read(privateSyncServiceProvider)
          .syncNow(reason: reason);
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
