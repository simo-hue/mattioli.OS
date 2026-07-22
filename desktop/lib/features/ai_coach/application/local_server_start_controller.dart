import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_app_launcher.dart';
import '../domain/coach_backend.dart';
import '../domain/coach_config.dart';
import '../domain/local_server_target.dart';
import 'coach_controllers.dart';

/// Where the "start the local server and wait for it" flow currently sits.
enum LocalServerStartStatus {
  /// No attempt in flight.
  idle,

  /// Launched; polling for the server to come up.
  starting,

  /// The server answered — the coach can talk to it.
  connected,

  /// Launched, the app is NOT running, and the server never answered. A real
  /// failure: a slow first launch needing Gatekeeper approval, or an app that
  /// quit on its own.
  timedOut,

  /// The app IS running, but its port stayed closed for the whole budget.
  ///
  /// For LM Studio this is the ordinary first-run state — the HTTP server is a
  /// Developer-tab toggle the user hasn't flipped — and it is emphatically not
  /// an error. For Ollama it means the daemon died or is wedged, which a second
  /// launch will not fix. Either way it is a different fact from [timedOut] and
  /// deserves different copy.
  serverNotEnabled,

  /// No such app is installed to launch.
  notInstalled,

  /// The app exists but the launch itself failed.
  failed,
}

/// Pure launch-then-poll routine, decoupled from Riverpod/IO for testing.
///
/// Launches via [launch], then polls [probe] up to [maxAttempts] times with
/// [interval] between attempts. Injecting [delay] lets tests run it with no real
/// waiting.
///
/// [isRunning] is consulted **only after the poll has given up**, never during
/// it. That timing is load-bearing: LM Studio spends the first several seconds
/// of an Electron cold start running-but-not-listening, so a mid-poll check
/// would report "your server is off" while it is in fact coming up perfectly
/// normally. By the time the budget is exhausted, "running but not listening" is
/// a settled fact rather than a startup artifact.
Future<LocalServerStartStatus> runLocalServerStart({
  required Future<LocalAppLaunchResult> Function() launch,
  required Future<bool> Function() probe,
  required Future<bool> Function() isRunning,
  Future<void> Function(Duration) delay = _wait,
  int maxAttempts = 20,
  Duration interval = const Duration(milliseconds: 1500),
}) async {
  final result = await launch();
  if (result == LocalAppLaunchResult.notInstalled) {
    return LocalServerStartStatus.notInstalled;
  }
  if (result == LocalAppLaunchResult.failed) {
    return LocalServerStartStatus.failed;
  }
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (await probe()) return LocalServerStartStatus.connected;
    if (attempt < maxAttempts - 1) await delay(interval);
  }
  // Budget exhausted — now, and only now, ask what kind of timeout this was.
  return await isRunning()
      ? LocalServerStartStatus.serverNotEnabled
      : LocalServerStartStatus.timedOut;
}

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

/// Whether to offer the in-app start affordance: only on the local backend,
/// pointed at a launchable product, currently unreachable, on a platform where
/// we actually have a native launcher.
///
/// [launcherSupported] is a parameter rather than a `Platform.isMacOS` read so
/// this stays pure and testable — and so the macOS-only rule is stated once,
/// here, instead of being inferred from a native call that returns `false` on
/// Windows/Linux whether or not the app is installed. Inferring it was a real
/// bug: a Linux user with Ollama installed was shown "Get Ollama".
bool shouldOfferLocalServerStart({
  required CoachBackendKind backend,
  required LocalServerTarget target,
  required bool reachable,
  required bool launcherSupported,
}) {
  return backend == CoachBackendKind.local &&
      target.canLaunch &&
      launcherSupported &&
      !reachable;
}

/// Whether this platform has the native launch bridge at all.
///
/// macOS-only by decision: the Windows and Linux runners are stock Flutter
/// scaffolding with no MethodChannel bridges, no CI, and no release artifact.
/// Overridable in tests.
final localLauncherSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && Platform.isMacOS,
);

/// The native launcher (degrades to "not installed" without the bridge).
final localAppLauncherProvider = Provider<LocalAppLauncher>(
  (ref) => const LocalAppLauncher(),
);

/// The launch action the start flow triggers — injectable so tests can drive
/// [LocalServerStartController.start] without the native channel.
final localAppLaunchProvider =
    Provider<Future<LocalAppLaunchResult> Function(LocalServerTarget)>(
      (ref) => ref.read(localAppLauncherProvider).launch,
    );

/// The "is the app running?" check used to classify a timeout — injectable for
/// the same reason as [localAppLaunchProvider].
final localAppRunningProvider =
    Provider<Future<bool> Function(LocalServerTarget)>(
      (ref) => ref.read(localAppLauncherProvider).isRunning,
    );

/// The reachability probe the start flow polls with — injectable so tests can
/// drive [LocalServerStartController.start] without real network calls.
final reachabilityProbeProvider = Provider<Future<bool> Function(String)>(
  (ref) => probeLocalReachable,
);

/// Whether a given product's app is installed — drives Start vs "Get {app}".
///
/// Keyed by preset so switching Ollama → LM Studio re-probes instead of
/// reporting the previous product's install state. This is a snapshot; the
/// offline banner re-invalidates it on its poll tick so a mid-session install is
/// picked up without navigating away.
final localAppInstalledProvider = FutureProvider.autoDispose
    .family<bool, LocalServerPreset>((ref, preset) {
      if (!ref.watch(localLauncherSupportedProvider)) {
        return Future.value(false);
      }
      return ref
          .read(localAppLauncherProvider)
          .isInstalled(LocalServerTarget.forPreset(preset));
    });

/// Orchestrates the launch-and-poll and exposes its status to the UI. On success
/// it refreshes the cached reachability + model list so the pill flips to
/// Connected and discovery re-runs.
///
/// autoDispose: the status is scoped to the surface that started the attempt, so
/// a terminal `timedOut`/`serverNotEnabled`/`failed`/`notInstalled` can't leak
/// into a fresh view after the user navigates away (it resets to idle when
/// unwatched).
///
/// Not a family: only one local server is configured at a time, and the target
/// is derived from the live config — so a preset change mid-attempt is reflected
/// by the config read, not by a stale family key.
final localServerStartControllerProvider =
    NotifierProvider.autoDispose<
      LocalServerStartController,
      LocalServerStartStatus
    >(LocalServerStartController.new);

class LocalServerStartController extends Notifier<LocalServerStartStatus> {
  bool _disposed = false;

  @override
  LocalServerStartStatus build() {
    ref.onDispose(() => _disposed = true);
    return LocalServerStartStatus.idle;
  }

  Future<void> start() async {
    if (state == LocalServerStartStatus.starting) return;
    state = LocalServerStartStatus.starting;

    final launch = ref.read(localAppLaunchProvider);
    final isRunning = ref.read(localAppRunningProvider);
    final probe = ref.read(reachabilityProbeProvider);
    final baseUrl = ref.read(coachConfigProvider).localBaseUrl;
    final target = LocalServerTarget.forBaseUrl(baseUrl);

    final status = await runLocalServerStart(
      launch: () => launch(target),
      probe: () => probe(baseUrl),
      isRunning: () => isRunning(target),
      maxAttempts: target.startPollAttempts,
    );
    // The surface may have unmounted (autoDispose) during the poll, which for
    // LM Studio can run a full minute.
    if (_disposed) return;
    state = status;

    if (status == LocalServerStartStatus.connected) {
      ref.invalidate(coachLocalReachableProvider(baseUrl));
      ref.invalidate(coachLocalModelsProvider(baseUrl));
    } else if (status == LocalServerStartStatus.notInstalled) {
      // The app went away since the last probe — re-check so the button flips
      // to "Get {app}".
      ref.invalidate(localAppInstalledProvider(target.preset));
    }
  }
}
