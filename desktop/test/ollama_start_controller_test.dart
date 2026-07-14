// Coverage for the pure start-and-poll state machine, the show-affordance
// predicate, and the OllamaStartController (start transitions + re-entrancy),
// driven by injected fakes so nothing touches the native channel or network.
import 'package:evolve_desktop/features/ai_coach/application/ollama_start_controller.dart';
import 'package:evolve_desktop/features/ai_coach/data/ollama_launcher.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _noWait(Duration _) async {}

ProviderContainer _container({
  required Future<OllamaLaunchResult> Function() launch,
  required Future<bool> Function(String) probe,
}) {
  final container = ProviderContainer(
    overrides: [
      ollamaLaunchProvider.overrideWithValue(launch),
      reachabilityProbeProvider.overrideWithValue(probe),
    ],
  );
  addTearDown(container.dispose);
  // Keep the autoDispose controller alive for the duration of the test.
  container.listen(ollamaStartControllerProvider, (_, _) {});
  return container;
}

void main() {
  group('runOllamaStart', () {
    test('not-installed launch short-circuits', () async {
      final status = await runOllamaStart(
        launch: () async => OllamaLaunchResult.notInstalled,
        probe: () async => true,
        delay: _noWait,
      );
      expect(status, OllamaStartStatus.notInstalled);
    });

    test('failed launch short-circuits', () async {
      final status = await runOllamaStart(
        launch: () async => OllamaLaunchResult.failed,
        probe: () async => true,
        delay: _noWait,
      );
      expect(status, OllamaStartStatus.failed);
    });

    test('connects when the server comes up on a later attempt', () async {
      var probes = 0;
      final status = await runOllamaStart(
        launch: () async => OllamaLaunchResult.launched,
        probe: () async => ++probes >= 3, // up on the 3rd probe
        delay: _noWait,
        maxAttempts: 10,
      );
      expect(status, OllamaStartStatus.connected);
      expect(probes, 3);
    });

    test('times out after maxAttempts when the server never answers', () async {
      var probes = 0;
      final status = await runOllamaStart(
        launch: () async => OllamaLaunchResult.launched,
        probe: () async {
          probes++;
          return false;
        },
        delay: _noWait,
        maxAttempts: 5,
      );
      expect(status, OllamaStartStatus.timedOut);
      expect(probes, 5); // probed exactly maxAttempts times
    });
  });

  group('OllamaStartController.start', () {
    test('launched + server up → connected', () async {
      var launches = 0;
      final container = _container(
        launch: () async {
          launches++;
          return OllamaLaunchResult.launched;
        },
        probe: (_) async => true,
      );
      await container.read(ollamaStartControllerProvider.notifier).start();
      expect(
        container.read(ollamaStartControllerProvider),
        OllamaStartStatus.connected,
      );
      expect(launches, 1);
    });

    test('not-installed launch → notInstalled status', () async {
      final container = _container(
        launch: () async => OllamaLaunchResult.notInstalled,
        probe: (_) async => true,
      );
      await container.read(ollamaStartControllerProvider.notifier).start();
      expect(
        container.read(ollamaStartControllerProvider),
        OllamaStartStatus.notInstalled,
      );
    });

    test('a second concurrent start() is a no-op (re-entrancy guard)', () async {
      var launches = 0;
      final container = _container(
        launch: () async {
          launches++;
          return OllamaLaunchResult.launched;
        },
        probe: (_) async => true,
      );
      final notifier = container.read(ollamaStartControllerProvider.notifier);
      await Future.wait([notifier.start(), notifier.start()]);
      expect(launches, 1);
    });
  });

  group('shouldOfferOllamaStart', () {
    test('true only for local + Ollama preset + unreachable', () {
      expect(
        shouldOfferOllamaStart(
          backend: CoachBackendKind.local,
          preset: LocalServerPreset.ollama,
          reachable: false,
        ),
        isTrue,
      );
    });

    test('false when reachable', () {
      expect(
        shouldOfferOllamaStart(
          backend: CoachBackendKind.local,
          preset: LocalServerPreset.ollama,
          reachable: true,
        ),
        isFalse,
      );
    });

    test('false on cloud backend', () {
      expect(
        shouldOfferOllamaStart(
          backend: CoachBackendKind.cloud,
          preset: LocalServerPreset.ollama,
          reachable: false,
        ),
        isFalse,
      );
    });

    test('false for a non-Ollama preset (LM Studio / custom get guidance)', () {
      expect(
        shouldOfferOllamaStart(
          backend: CoachBackendKind.local,
          preset: LocalServerPreset.lmStudio,
          reachable: false,
        ),
        isFalse,
      );
      expect(
        shouldOfferOllamaStart(
          backend: CoachBackendKind.local,
          preset: LocalServerPreset.custom,
          reachable: false,
        ),
        isFalse,
      );
    });
  });
}
