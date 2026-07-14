import 'package:flutter/services.dart';

/// Outcome of asking the native side to launch the Ollama desktop app.
enum OllamaLaunchResult {
  /// LaunchServices started (or re-activated) the app.
  launched,

  /// No Ollama app is installed — nothing to launch.
  notInstalled,

  /// The app exists but the launch call failed.
  failed,
}

/// Thin Dart wrapper over the native `evolve/local_llm` MethodChannel. Lets the
/// sandboxed desktop app start the local Ollama server by launching the
/// installed Ollama app (the sandbox blocks running `ollama serve` directly).
///
/// Every call degrades gracefully: on a platform without the native bridge
/// (non-macOS, tests) a [MissingPluginException] is swallowed and the launcher
/// behaves as "not installed", so callers can wire it everywhere without guards.
class OllamaLauncher {
  const OllamaLauncher([
    this._channel = const MethodChannel('evolve/local_llm'),
  ]);

  final MethodChannel _channel;

  /// Whether an Ollama desktop app is installed and thus launchable.
  Future<bool> isInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('ollamaInstalled') ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the native side to launch the installed Ollama app (which starts the
  /// `ollama serve` daemon). Never throws.
  Future<OllamaLaunchResult> launch() async {
    try {
      final result = await _channel.invokeMethod<String>('launchOllama');
      switch (result) {
        case 'launched':
          return OllamaLaunchResult.launched;
        case 'notInstalled':
          return OllamaLaunchResult.notInstalled;
        default:
          return OllamaLaunchResult.failed;
      }
    } on MissingPluginException {
      return OllamaLaunchResult.notInstalled;
    } catch (_) {
      return OllamaLaunchResult.failed;
    }
  }
}
