import 'package:flutter/services.dart';

import '../domain/local_server_target.dart';

/// Outcome of asking the native side to launch a local-LLM desktop app.
enum LocalAppLaunchResult {
  /// LaunchServices started (or re-activated) the app.
  launched,

  /// No such app is installed — nothing to launch.
  notInstalled,

  /// The app exists but the launch call failed.
  failed,
}

/// Thin Dart wrapper over the native `evolve/local_llm` MethodChannel. Lets the
/// sandboxed desktop app start a local LLM server by launching its installed
/// desktop app (the sandbox blocks running `ollama serve` / `lms server start`
/// directly, and no entitlement would change that).
///
/// The channel is deliberately product-agnostic: every method takes the bundle
/// ids and fallback path from a [LocalServerTarget], so adding a third provider
/// is a Dart-side data change with no Swift edit — and so the ids themselves are
/// reachable from unit tests.
///
/// Every call degrades gracefully: on a platform without the native bridge
/// (Windows/Linux, tests) a [MissingPluginException] is swallowed and the
/// launcher reports "not installed / not running", so callers can wire it
/// everywhere without guards. Note that this degradation is a LIE on Windows and
/// Linux — the app may well be installed there — which is why the UI gates the
/// launch affordances on macOS rather than on this result. See
/// `localLauncherSupportedProvider`.
class LocalAppLauncher {
  const LocalAppLauncher([
    this._channel = const MethodChannel('evolve/local_llm'),
  ]);

  final MethodChannel _channel;

  Map<String, Object?> _args(LocalServerTarget target) => {
    'bundleIds': target.bundleIds,
    'appPath': target.appPath,
  };

  /// Whether [target]'s desktop app is installed and thus launchable.
  Future<bool> isInstalled(LocalServerTarget target) async {
    if (!target.canLaunch) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'localAppInstalled',
            _args(target),
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Whether [target]'s app is currently RUNNING (as opposed to merely
  /// installed).
  ///
  /// This is what lets the start flow tell two very different timeouts apart:
  /// "the app never came up" versus "the app is open but its server is off".
  /// Without it, a first-run LM Studio user — whose server toggle is simply
  /// unticked — would be told the launch failed while LM Studio sits visibly
  /// open on their screen.
  Future<bool> isRunning(LocalServerTarget target) async {
    if (!target.canLaunch) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'localAppRunning',
            _args(target),
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the native side to launch [target]'s app. For Ollama that starts the
  /// `ollama serve` daemon outright; for LM Studio it opens the app, whose HTTP
  /// server then starts only if the user has ever enabled it. Never throws.
  Future<LocalAppLaunchResult> launch(LocalServerTarget target) async {
    if (!target.canLaunch) return LocalAppLaunchResult.notInstalled;
    try {
      final result = await _channel.invokeMethod<String>(
        'launchLocalApp',
        _args(target),
      );
      switch (result) {
        case 'launched':
          return LocalAppLaunchResult.launched;
        case 'notInstalled':
          return LocalAppLaunchResult.notInstalled;
        default:
          return LocalAppLaunchResult.failed;
      }
    } on MissingPluginException {
      return LocalAppLaunchResult.notInstalled;
    } catch (_) {
      return LocalAppLaunchResult.failed;
    }
  }
}
