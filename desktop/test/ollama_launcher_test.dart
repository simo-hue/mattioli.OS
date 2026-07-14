// Coverage for the native-bridge wrapper: status-string mapping and graceful
// MissingPluginException degradation (so the launcher is a safe no-op on
// platforms without the native side).
import 'package:evolve_desktop/features/ai_coach/data/ollama_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('evolve/local_llm');
  const launcher = OllamaLauncher(channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('isInstalled maps the native bool (and null → false)', () async {
    mock((call) {
      expect(call.method, 'ollamaInstalled');
      return true;
    });
    expect(await launcher.isInstalled(), isTrue);

    mock((_) => false);
    expect(await launcher.isInstalled(), isFalse);

    mock((_) => null);
    expect(await launcher.isInstalled(), isFalse);
  });

  test('launch maps each native status string', () async {
    mock((call) {
      expect(call.method, 'launchOllama');
      return 'launched';
    });
    expect(await launcher.launch(), OllamaLaunchResult.launched);

    mock((_) => 'notInstalled');
    expect(await launcher.launch(), OllamaLaunchResult.notInstalled);

    mock((_) => 'failed');
    expect(await launcher.launch(), OllamaLaunchResult.failed);

    // Any unrecognised value is treated as a failure, not a crash.
    mock((_) => 'nonsense');
    expect(await launcher.launch(), OllamaLaunchResult.failed);
  });

  test('missing native plugin degrades gracefully', () async {
    // No mock handler registered → MissingPluginException.
    messenger.setMockMethodCallHandler(channel, null);
    expect(await launcher.isInstalled(), isFalse);
    expect(await launcher.launch(), OllamaLaunchResult.notInstalled);
  });
}
