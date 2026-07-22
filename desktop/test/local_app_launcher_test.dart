// Coverage for the native-bridge wrapper: argument marshalling, status-string
// mapping, and graceful MissingPluginException degradation (so the launcher is a
// safe no-op on platforms without the native side).
import 'package:evolve_desktop/features/ai_coach/data/local_app_launcher.dart';
import 'package:evolve_desktop/features/ai_coach/domain/local_server_target.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('evolve/local_llm');
  const launcher = LocalAppLauncher(channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mock(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('isInstalled maps the native bool (and null → false)', () async {
    mock((call) {
      expect(call.method, 'localAppInstalled');
      return true;
    });
    expect(await launcher.isInstalled(LocalServerTarget.ollama), isTrue);

    mock((_) => false);
    expect(await launcher.isInstalled(LocalServerTarget.ollama), isFalse);

    mock((_) => null);
    expect(await launcher.isInstalled(LocalServerTarget.ollama), isFalse);
  });

  test('isRunning maps the native bool', () async {
    mock((call) {
      expect(call.method, 'localAppRunning');
      return true;
    });
    expect(await launcher.isRunning(LocalServerTarget.lmStudio), isTrue);

    mock((_) => false);
    expect(await launcher.isRunning(LocalServerTarget.lmStudio), isFalse);

    mock((_) => null);
    expect(await launcher.isRunning(LocalServerTarget.lmStudio), isFalse);
  });

  test('launch maps each native status string', () async {
    mock((call) {
      expect(call.method, 'launchLocalApp');
      return 'launched';
    });
    expect(
      await launcher.launch(LocalServerTarget.ollama),
      LocalAppLaunchResult.launched,
    );

    mock((_) => 'notInstalled');
    expect(
      await launcher.launch(LocalServerTarget.ollama),
      LocalAppLaunchResult.notInstalled,
    );

    mock((_) => 'failed');
    expect(
      await launcher.launch(LocalServerTarget.ollama),
      LocalAppLaunchResult.failed,
    );

    // Any unrecognised value is treated as a failure, not a crash.
    mock((_) => 'nonsense');
    expect(
      await launcher.launch(LocalServerTarget.ollama),
      LocalAppLaunchResult.failed,
    );
  });

  // The whole point of moving product identity out of Swift: the ids the native
  // side receives are now assertable. A silent typo here used to be invisible.
  test('every call carries the target bundle ids and path fallback', () async {
    for (final target in [
      LocalServerTarget.ollama,
      LocalServerTarget.lmStudio,
    ]) {
      for (final call in <Future<Object?> Function()>[
        () => launcher.isInstalled(target),
        () => launcher.isRunning(target),
        () => launcher.launch(target),
      ]) {
        late MethodCall seen;
        mock((c) {
          seen = c;
          return c.method == 'launchLocalApp' ? 'launched' : true;
        });
        await call();
        final args = seen.arguments as Map;
        expect(args['bundleIds'], target.bundleIds);
        expect(args['appPath'], target.appPath);
      }
    }
  });

  test('a target with no app never reaches the channel', () async {
    var calls = 0;
    mock((_) {
      calls++;
      return true;
    });
    expect(await launcher.isInstalled(LocalServerTarget.custom), isFalse);
    expect(await launcher.isRunning(LocalServerTarget.custom), isFalse);
    expect(
      await launcher.launch(LocalServerTarget.custom),
      LocalAppLaunchResult.notInstalled,
    );
    expect(calls, 0);
  });

  test('missing native plugin degrades gracefully', () async {
    // No mock handler registered → MissingPluginException.
    messenger.setMockMethodCallHandler(channel, null);
    expect(await launcher.isInstalled(LocalServerTarget.ollama), isFalse);
    expect(await launcher.isRunning(LocalServerTarget.ollama), isFalse);
    expect(
      await launcher.launch(LocalServerTarget.ollama),
      LocalAppLaunchResult.notInstalled,
    );
  });
}
