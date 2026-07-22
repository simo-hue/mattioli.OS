// Coverage for the pure start-and-poll state machine (including the
// timeout-disambiguation step), the show-affordance predicate, and the
// LocalServerStartController (start transitions + re-entrancy), driven by
// injected fakes so nothing touches the native channel or network.
import 'package:evolve_desktop/features/ai_coach/application/local_server_start_controller.dart';
import 'package:evolve_desktop/features/ai_coach/data/local_app_launcher.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/domain/local_server_target.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _noWait(Duration _) async {}

ProviderContainer _container({
  required Future<LocalAppLaunchResult> Function() launch,
  required Future<bool> Function(String) probe,
  Future<bool> Function()? isRunning,
}) {
  final container = ProviderContainer(
    overrides: [
      localAppLaunchProvider.overrideWithValue((_) => launch()),
      localAppRunningProvider.overrideWithValue(
        (_) => (isRunning ?? () async => false)(),
      ),
      reachabilityProbeProvider.overrideWithValue(probe),
    ],
  );
  addTearDown(container.dispose);
  // Keep the autoDispose controller alive for the duration of the test.
  container.listen(localServerStartControllerProvider, (_, _) {});
  return container;
}

void main() {
  group('runLocalServerStart', () {
    test('not-installed launch short-circuits', () async {
      final status = await runLocalServerStart(
        launch: () async => LocalAppLaunchResult.notInstalled,
        probe: () async => true,
        isRunning: () async => false,
        delay: _noWait,
      );
      expect(status, LocalServerStartStatus.notInstalled);
    });

    test('failed launch short-circuits', () async {
      final status = await runLocalServerStart(
        launch: () async => LocalAppLaunchResult.failed,
        probe: () async => true,
        isRunning: () async => false,
        delay: _noWait,
      );
      expect(status, LocalServerStartStatus.failed);
    });

    test('connects when the server comes up on a later attempt', () async {
      var probes = 0;
      final status = await runLocalServerStart(
        launch: () async => LocalAppLaunchResult.launched,
        probe: () async => ++probes >= 3, // up on the 3rd probe
        isRunning: () async => false,
        delay: _noWait,
        maxAttempts: 10,
      );
      expect(status, LocalServerStartStatus.connected);
      expect(probes, 3);
    });

    test('app not running after the budget → timedOut', () async {
      var probes = 0;
      final status = await runLocalServerStart(
        launch: () async => LocalAppLaunchResult.launched,
        probe: () async {
          probes++;
          return false;
        },
        isRunning: () async => false,
        delay: _noWait,
        maxAttempts: 5,
      );
      expect(status, LocalServerStartStatus.timedOut);
      expect(probes, 5); // probed exactly maxAttempts times
    });

    test('app running after the budget → serverNotEnabled', () async {
      final status = await runLocalServerStart(
        launch: () async => LocalAppLaunchResult.launched,
        probe: () async => false,
        isRunning: () async => true,
        delay: _noWait,
        maxAttempts: 5,
      );
      expect(status, LocalServerStartStatus.serverNotEnabled);
    });

    // The timing is the whole point: LM Studio spends the first seconds of an
    // Electron cold start running-but-not-listening, so consulting isRunning
    // mid-poll would report "your server is off" while it is coming up fine.
    test('isRunning is consulted only once, after the poll gives up', () async {
      var runningChecks = 0;
      await runLocalServerStart(
        launch: () async => LocalAppLaunchResult.launched,
        probe: () async => false,
        isRunning: () async {
          runningChecks++;
          return true;
        },
        delay: _noWait,
        maxAttempts: 5,
      );
      expect(runningChecks, 1);
    });

    test('a successful connect never consults isRunning', () async {
      var runningChecks = 0;
      final status = await runLocalServerStart(
        launch: () async => LocalAppLaunchResult.launched,
        probe: () async => true,
        isRunning: () async {
          runningChecks++;
          return true;
        },
        delay: _noWait,
      );
      expect(status, LocalServerStartStatus.connected);
      expect(runningChecks, 0);
    });
  });

  group('LocalServerStartController.start', () {
    test('launched + server up → connected', () async {
      var launches = 0;
      final container = _container(
        launch: () async {
          launches++;
          return LocalAppLaunchResult.launched;
        },
        probe: (_) async => true,
      );
      await container.read(localServerStartControllerProvider.notifier).start();
      expect(
        container.read(localServerStartControllerProvider),
        LocalServerStartStatus.connected,
      );
      expect(launches, 1);
    });

    test('not-installed launch → notInstalled status', () async {
      final container = _container(
        launch: () async => LocalAppLaunchResult.notInstalled,
        probe: (_) async => true,
      );
      await container.read(localServerStartControllerProvider.notifier).start();
      expect(
        container.read(localServerStartControllerProvider),
        LocalServerStartStatus.notInstalled,
      );
    });

    test(
      'a second concurrent start() is a no-op (re-entrancy guard)',
      () async {
        var launches = 0;
        final container = _container(
          launch: () async {
            launches++;
            return LocalAppLaunchResult.launched;
          },
          probe: (_) async => true,
        );
        final notifier = container.read(
          localServerStartControllerProvider.notifier,
        );
        await Future.wait([notifier.start(), notifier.start()]);
        expect(launches, 1);
      },
    );
  });

  group('shouldOfferLocalServerStart', () {
    bool offer({
      CoachBackendKind backend = CoachBackendKind.local,
      LocalServerTarget? target,
      bool reachable = false,
      bool launcherSupported = true,
    }) => shouldOfferLocalServerStart(
      backend: backend,
      target: target ?? LocalServerTarget.ollama,
      reachable: reachable,
      launcherSupported: launcherSupported,
    );

    test('true for local + a launchable target + unreachable + macOS', () {
      expect(offer(), isTrue);
      // LM Studio is now a first-class citizen here — this is the case the whole
      // change exists for.
      expect(offer(target: LocalServerTarget.lmStudio), isTrue);
    });

    test('false when reachable', () {
      expect(offer(reachable: true), isFalse);
    });

    test('false on a remote backend', () {
      expect(offer(backend: CoachBackendKind.cloud), isFalse);
      expect(offer(backend: CoachBackendKind.standard), isFalse);
    });

    test('false for a custom endpoint (nothing to launch)', () {
      expect(offer(target: LocalServerTarget.custom), isFalse);
    });

    // Off macOS there is no native bridge, and inferring install state from a
    // bridge that always answers "no" is what used to show a Linux user with
    // Ollama installed a "Get Ollama" button.
    test('false when the platform has no launcher', () {
      expect(offer(launcherSupported: false), isFalse);
      expect(
        offer(target: LocalServerTarget.lmStudio, launcherSupported: false),
        isFalse,
      );
    });
  });
}
