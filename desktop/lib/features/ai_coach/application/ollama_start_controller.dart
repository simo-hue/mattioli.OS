import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ollama_launcher.dart';
import '../domain/coach_backend.dart';
import '../domain/coach_config.dart';
import 'coach_controllers.dart';

/// Where the "start Ollama and wait for it" flow currently sits.
enum OllamaStartStatus {
  /// No attempt in flight.
  idle,

  /// Launched; polling for the server to come up.
  starting,

  /// The server answered — the coach can talk to it.
  connected,

  /// Launched but the server didn't answer within the budget (e.g. a slow
  /// first launch that needs Gatekeeper approval).
  timedOut,

  /// No Ollama app is installed to launch.
  notInstalled,

  /// The app exists but the launch itself failed.
  failed,
}

/// Pure launch-then-poll routine, decoupled from Riverpod/IO for testing.
/// Launches via [launch], then polls [probe] up to [maxAttempts] times with
/// [delay] between attempts, returning the terminal status. Injecting [delay]
/// lets tests run it with no real waiting.
Future<OllamaStartStatus> runOllamaStart({
  required Future<OllamaLaunchResult> Function() launch,
  required Future<bool> Function() probe,
  Future<void> Function(Duration) delay = _wait,
  int maxAttempts = 20,
  Duration interval = const Duration(milliseconds: 1500),
}) async {
  final result = await launch();
  if (result == OllamaLaunchResult.notInstalled) {
    return OllamaStartStatus.notInstalled;
  }
  if (result == OllamaLaunchResult.failed) {
    return OllamaStartStatus.failed;
  }
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (await probe()) return OllamaStartStatus.connected;
    if (attempt < maxAttempts - 1) await delay(interval);
  }
  return OllamaStartStatus.timedOut;
}

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

/// Whether to offer the in-app "Start Ollama" affordance: only when the coach
/// is on the local backend pointed at the Ollama preset and the server is
/// currently unreachable. (Other presets get setup guidance, not a launcher.)
bool shouldOfferOllamaStart({
  required CoachBackendKind backend,
  required LocalServerPreset preset,
  required bool reachable,
}) {
  return backend == CoachBackendKind.local &&
      preset == LocalServerPreset.ollama &&
      !reachable;
}

/// The native launcher (no-op off macOS).
final ollamaLauncherProvider = Provider<OllamaLauncher>(
  (ref) => const OllamaLauncher(),
);

/// The launch action the start flow triggers — injectable so tests can drive
/// [OllamaStartController.start] without the native channel.
final ollamaLaunchProvider = Provider<Future<OllamaLaunchResult> Function()>(
  (ref) => ref.read(ollamaLauncherProvider).launch,
);

/// The reachability probe the start flow polls with — injectable so tests can
/// drive [OllamaStartController.start] without real network calls.
final reachabilityProbeProvider = Provider<Future<bool> Function(String)>(
  (ref) => probeLocalReachable,
);

/// Whether an Ollama app is installed — drives Start vs "Get Ollama". This is a
/// snapshot; the offline banner re-invalidates it on its poll tick so a
/// mid-session install is picked up without navigating away.
final ollamaInstalledProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.read(ollamaLauncherProvider).isInstalled();
});

/// Orchestrates the launch-and-poll and exposes its status to the UI. On
/// success it refreshes the cached reachability + model list so the pill flips
/// to Connected and discovery re-runs.
///
/// autoDispose: the status is scoped to the surface that started the attempt,
/// so a terminal `timedOut`/`failed`/`notInstalled` can't leak into a fresh
/// view after the user navigates away (it resets to idle when unwatched).
final ollamaStartControllerProvider =
    NotifierProvider.autoDispose<OllamaStartController, OllamaStartStatus>(
      OllamaStartController.new,
    );

class OllamaStartController extends Notifier<OllamaStartStatus> {
  bool _disposed = false;

  @override
  OllamaStartStatus build() {
    ref.onDispose(() => _disposed = true);
    return OllamaStartStatus.idle;
  }

  Future<void> start() async {
    if (state == OllamaStartStatus.starting) return;
    state = OllamaStartStatus.starting;

    final launch = ref.read(ollamaLaunchProvider);
    final probe = ref.read(reachabilityProbeProvider);
    final baseUrl = ref.read(coachConfigProvider).localBaseUrl;

    final status = await runOllamaStart(
      launch: launch,
      probe: () => probe(baseUrl),
    );
    // The surface may have unmounted (autoDispose) during the ~30s poll.
    if (_disposed) return;
    state = status;

    if (status == OllamaStartStatus.connected) {
      ref.invalidate(coachLocalReachableProvider(baseUrl));
      ref.invalidate(coachLocalModelsProvider(baseUrl));
    } else if (status == OllamaStartStatus.notInstalled) {
      // The app went away since the last probe — re-check so the button flips
      // to "Get Ollama".
      ref.invalidate(ollamaInstalledProvider);
    }
  }
}
