// Persistence + provider coverage for the coach config controller: hydration
// from SharedPreferences, dual-write of each setter, per-backend model memory,
// and the active-backend provider switching engines. Uses mock prefs so no
// network or DB is touched.
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/ai_coach/application/coach_controllers.dart';
import 'package:evolve_desktop/features/ai_coach/data/cloud_coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/data/local_coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/data/standard_coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to standard when nothing is persisted', () async {
    final container = await _container();
    final config = container.read(coachConfigProvider);
    // A fresh install lands on the subscription, not on a key prompt.
    expect(config.backend, CoachBackendKind.standard);
    expect(config.localBaseUrl, kDefaultLocalBaseUrl);
    expect(config.localModel, isNull);
  });

  test('hydrates a persisted standard choice as standard', () async {
    // Regression: the old binary `fromCode` mapped anything that wasn't 'local'
    // to cloud, so a subscriber's saved engine would silently come back as BYOK.
    final container = await _container({'coach_backend': 'standard'});
    expect(
      container.read(coachConfigProvider).backend,
      CoachBackendKind.standard,
    );
  });

  test('hydrates a persisted local configuration', () async {
    final container = await _container({
      'coach_backend': 'local',
      'coach_local_base_url': 'http://localhost:1234/v1',
      'coach_local_model': 'llama3.1:8b',
      'coach_temperature': 1.1,
      'coach_system_prompt': 'Be terse.',
    });
    final config = container.read(coachConfigProvider);
    expect(config.backend, CoachBackendKind.local);
    expect(config.localBaseUrl, 'http://localhost:1234/v1');
    expect(config.localModel, 'llama3.1:8b');
    expect(config.temperature, 1.1);
    expect(config.systemPromptOverride, 'Be terse.');
  });

  test('setBackend dual-writes the pref', () async {
    final container = await _container();
    // Same cached mock instance the provider override points at.
    final prefs = await SharedPreferences.getInstance();

    final controller = container.read(coachConfigProvider.notifier);
    await controller.setBackend(CoachBackendKind.local);

    expect(container.read(coachConfigProvider).backend, CoachBackendKind.local);
    expect(prefs.getString('coach_backend'), 'local');
  });

  test('setLocalBaseUrl normalizes before persisting', () async {
    final container = await _container();
    final controller = container.read(coachConfigProvider.notifier);
    await controller.setLocalBaseUrl('localhost:11434');
    expect(
      container.read(coachConfigProvider).localBaseUrl,
      'http://localhost:11434/v1',
    );
  });

  test('per-backend model memory: switching back restores each model',
      () async {
    final container = await _container();
    final controller = container.read(coachConfigProvider.notifier);

    await controller.setLocalModel('qwen2.5:7b');
    await controller.setCloudModel('google/gemini-2.5-flash');

    // On local, activeModel is the local pick.
    await controller.setBackend(CoachBackendKind.local);
    expect(container.read(coachConfigProvider).activeModel, 'qwen2.5:7b');

    // Switch to cloud → cloud model; local pick is retained, not lost.
    await controller.setBackend(CoachBackendKind.cloud);
    final cfg = container.read(coachConfigProvider);
    expect(cfg.activeModel, 'google/gemini-2.5-flash');
    expect(cfg.localModel, 'qwen2.5:7b');
  });

  test('clearing local model / system prompt removes the pref', () async {
    final container = await _container({
      'coach_local_model': 'x',
      'coach_system_prompt': 'y',
    });
    final controller = container.read(coachConfigProvider.notifier);
    await controller.setLocalModel(null);
    await controller.setSystemPromptOverride('   ');
    final cfg = container.read(coachConfigProvider);
    expect(cfg.localModel, isNull);
    expect(cfg.systemPromptOverride, isNull);
  });

  test('temperature is clamped on write', () async {
    final container = await _container();
    final controller = container.read(coachConfigProvider.notifier);
    await controller.setTemperature(5.0);
    expect(container.read(coachConfigProvider).temperature, 2.0);
  });

  test('useLocalServer switches backend and points at the URL', () async {
    final container = await _container();
    final controller = container.read(coachConfigProvider.notifier);
    await controller.useLocalServer('http://192.168.1.9:11434');
    final cfg = container.read(coachConfigProvider);
    expect(cfg.backend, CoachBackendKind.local);
    expect(cfg.localBaseUrl, 'http://192.168.1.9:11434/v1');
  });

  test('activeCoachBackendProvider is Standard in account mode, whatever is '
      'chosen', () async {
    // Account mode is Standard-only: BYOK and Local are Private-mode features,
    // so a persisted Cloud/Local choice is preserved but never serves here — the
    // engine that actually answers is always the Pro-funded proxy. (Private
    // mode's inverse is covered below.)
    final container = await _container();
    expect(
      container.read(activeCoachBackendProvider),
      isA<StandardCoachBackend>(),
    );
    await container
        .read(coachConfigProvider.notifier)
        .setBackend(CoachBackendKind.cloud);
    expect(
      container.read(activeCoachBackendProvider),
      isA<StandardCoachBackend>(),
    );
    await container
        .read(coachConfigProvider.notifier)
        .setBackend(CoachBackendKind.local);
    expect(
      container.read(activeCoachBackendProvider),
      isA<StandardCoachBackend>(),
    );
  });

  test('PRIVATE MODE + a stored standard choice builds the BYOK engine', () {
    // The end-to-end version of the effectiveCoachBackend rule: not just that
    // the enum is rewritten, but that the object actually constructed is the one
    // that can serve. A StandardCoachBackend here would 401 every send for a
    // user whose whole mode is "I keep no account".
    final container = ProviderContainer(
      overrides: [
        coachConfigProvider.overrideWith(_FixedConfigController.new),
        activeDesktopDataModeProvider.overrideWith(
          () => _FixedDataMode(DesktopDataMode.private),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(effectiveCoachBackendProvider),
      CoachBackendKind.cloud,
    );
    expect(container.read(activeCoachBackendProvider), isA<CloudCoachBackend>());
  });

  test('PRIVATE MODE keeps a stored Local choice as the Local engine', () async {
    // The other half of the mode/backend split: Private mode is BYOK + Local
    // only, and a Local choice must build the Local engine (not be rewritten the
    // way a Standard choice is).
    final container = ProviderContainer(
      overrides: [
        coachConfigProvider.overrideWith(_FixedConfigController.new),
        activeDesktopDataModeProvider.overrideWith(
          () => _FixedDataMode(DesktopDataMode.private),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(coachConfigProvider.notifier)
        .setBackend(CoachBackendKind.local);
    expect(container.read(activeCoachBackendProvider), isA<LocalCoachBackend>());
  });
}

/// A config pinned to Standard, as a private-mode user who chose it before
/// switching modes would have persisted.
class _FixedConfigController extends CoachConfigController {
  @override
  CoachConfig build() =>
      CoachConfig.defaults().copyWith(backend: CoachBackendKind.standard);
}

class _FixedDataMode extends ActiveDesktopDataModeNotifier {
  _FixedDataMode(this._mode);

  final DesktopDataMode _mode;

  @override
  DesktopDataMode build() => _mode;
}
