import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_supabase_config.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cloud_coach_backend.dart';
import '../data/local_coach_backend.dart';
import '../data/openai_compatible_client.dart';
import '../data/openrouter_key_store.dart';
import '../data/standard_coach_backend.dart';
import '../domain/coach_backend.dart';
import '../domain/coach_config.dart';

/// Device-local coach configuration, persisted field-by-field in
/// SharedPreferences (never synced — a localhost URL is meaningless on another
/// device). Mirrors the biometric/data-mode controllers' prefs-backed shape.
final coachConfigProvider =
    NotifierProvider<CoachConfigController, CoachConfig>(
      CoachConfigController.new,
    );

class CoachConfigController extends Notifier<CoachConfig> {
  static const _kBackend = 'coach_backend';
  static const _kLocalBaseUrl = 'coach_local_base_url';
  static const _kCloudModel = 'coach_cloud_model';
  static const _kLocalModel = 'coach_local_model';
  static const _kTemperature = 'coach_temperature';
  static const _kSystemPrompt = 'coach_system_prompt';

  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  @override
  CoachConfig build() {
    final prefs = _prefs;
    final defaults = CoachConfig.defaults();
    if (prefs == null) return defaults;

    final cloudModel = prefs.getString(_kCloudModel)?.trim();
    final localModel = prefs.getString(_kLocalModel)?.trim();
    final systemPrompt = prefs.getString(_kSystemPrompt)?.trim();

    return CoachConfig(
      backend: CoachBackendKind.fromCode(prefs.getString(_kBackend)),
      localBaseUrl: normalizeBaseUrl(
        prefs.getString(_kLocalBaseUrl) ?? defaults.localBaseUrl,
      ),
      cloudModel: (cloudModel == null || cloudModel.isEmpty)
          ? defaults.cloudModel
          : cloudModel,
      localModel: (localModel == null || localModel.isEmpty) ? null : localModel,
      temperature: clampTemperature(
        prefs.getDouble(_kTemperature) ?? defaults.temperature,
      ),
      systemPromptOverride: (systemPrompt == null || systemPrompt.isEmpty)
          ? null
          : systemPrompt,
    );
  }

  Future<void> setBackend(CoachBackendKind kind) async {
    if (state.backend == kind) return;
    state = state.copyWith(backend: kind);
    await _prefs?.setString(_kBackend, kind.code);
  }

  Future<void> setLocalBaseUrl(String raw) async {
    final normalized = normalizeBaseUrl(raw);
    state = state.copyWith(localBaseUrl: normalized);
    await _prefs?.setString(_kLocalBaseUrl, normalized);
  }

  Future<void> setCloudModel(String model) async {
    final trimmed = model.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(cloudModel: trimmed);
    await _prefs?.setString(_kCloudModel, trimmed);
  }

  Future<void> setLocalModel(String? model) async {
    final trimmed = model?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      state = state.copyWith(clearLocalModel: true);
      await _prefs?.remove(_kLocalModel);
    } else {
      state = state.copyWith(localModel: trimmed);
      await _prefs?.setString(_kLocalModel, trimmed);
    }
  }

  Future<void> setTemperature(double value) async {
    final clamped = clampTemperature(value);
    state = state.copyWith(temperature: clamped);
    await _prefs?.setDouble(_kTemperature, clamped);
  }

  Future<void> setSystemPromptOverride(String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      state = state.copyWith(clearSystemPrompt: true);
      await _prefs?.remove(_kSystemPrompt);
    } else {
      state = state.copyWith(systemPromptOverride: trimmed);
      await _prefs?.setString(_kSystemPrompt, trimmed);
    }
  }

  /// One-shot for the auto-detect nudge: switch to local and point at [baseUrl].
  Future<void> useLocalServer(String baseUrl) async {
    final normalized = normalizeBaseUrl(baseUrl);
    state = state.copyWith(
      backend: CoachBackendKind.local,
      localBaseUrl: normalized,
    );
    await _prefs?.setString(_kBackend, CoachBackendKind.local.code);
    await _prefs?.setString(_kLocalBaseUrl, normalized);
  }
}

/// The user's own OpenRouter API key (BYOK), read from the Keychain. Null means
/// the cloud coach isn't configured yet. Unlike [coachConfigProvider] this is
/// NOT in SharedPreferences: it is a credential, so it lives only in the
/// Keychain and is never synced, exported, or logged.
final coachApiKeyProvider =
    AsyncNotifierProvider<CoachApiKeyController, String?>(
      CoachApiKeyController.new,
    );

class CoachApiKeyController extends AsyncNotifier<String?> {
  static const OpenRouterKeyStore _store = OpenRouterKeyStore();

  @override
  Future<String?> build() => _store.read();

  /// Stores [key] and publishes it. Returns false (leaving the previous state
  /// intact) when the Keychain write fails, so the dialog can say so rather
  /// than pretend the key was saved. Never logs [key].
  Future<bool> save(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return false;
    try {
      await _store.write(trimmed);
    } catch (_) {
      // SecureStorageUtils has already logged the failure (by item name only).
      return false;
    }
    state = AsyncValue.data(trimmed);
    return true;
  }

  Future<void> clear() async {
    await _store.clear();
    state = const AsyncValue.data(null);
  }
}

/// The live Supabase session's access token, or null when signed out.
///
/// Injected as a closure rather than read inline so it resolves at SEND time.
/// The Standard backend authenticates with this JWT, which rotates roughly
/// hourly; a token read once and captured would 401 forever after the first
/// refresh. The client object is stable, the session is not — so the closure
/// holds the client and re-reads the session on every call.
///
/// `supabaseClientProvider` is null in Private mode (Supabase is never
/// initialised there), which makes this null-safe by construction.
final coachSessionTokenProvider = Provider<Future<String?> Function()>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return () async => client?.auth.currentSession?.accessToken;
});

/// Whether the Standard engine can serve, and if not, why.
///
/// Watches the auth controller rather than reading `currentSession` directly so
/// the picker and the banner update the moment the user signs in or out, instead
/// of on the next unrelated rebuild.
final standardCoachStatusProvider = Provider<StandardCoachStatus>((ref) {
  final isPrivate = ref.watch(activeDesktopDataModeProvider).isPrivate;
  return resolveStandardCoachStatus(
    isPrivate: isPrivate,
    isConfigured: DesktopSupabaseConfig.isConfigured,
    hasSession: ref.watch(desktopAuthControllerProvider).isLoggedIn,
    // Only read where it means something: `desktopIsProProvider` returns true
    // unconditionally in Private mode, where it is a placeholder rather than a
    // fact about `profiles.is_pro` — which is what the proxy actually checks.
    isPro: !isPrivate && ref.watch(desktopIsProProvider),
  );
});

/// The engine that will actually serve, given the one the user picked.
///
/// Private mode cannot reach the proxy (no account, no client), so a persisted
/// Standard choice resolves to BYOK there. Every gate — the send path, the setup
/// banners, the chip — must read THIS rather than `config.backend`, or a
/// Private-mode user would be routed at a function that can only 401.
final effectiveCoachBackendProvider = Provider<CoachBackendKind>((ref) {
  return effectiveCoachBackend(
    chosen: ref.watch(coachConfigProvider.select((c) => c.backend)),
    isPrivate: ref.watch(activeDesktopDataModeProvider).isPrivate,
  );
});

/// The engine that answers the coach. Depends on the effective backend + local
/// base URL (so an unrelated config edit — temperature, system prompt, model
/// memory — doesn't needlessly rebuild it), on the BYOK key for cloud, and on
/// the entitlement status for standard.
final activeCoachBackendProvider = Provider<CoachBackend>((ref) {
  final backend = ref.watch(effectiveCoachBackendProvider);
  final localBaseUrl = ref.watch(
    coachConfigProvider.select((c) => c.localBaseUrl),
  );
  switch (backend) {
    case CoachBackendKind.local:
      return LocalCoachBackend(baseUrl: localBaseUrl);
    case CoachBackendKind.standard:
      return StandardCoachBackend(
        status: ref.watch(standardCoachStatusProvider),
        authorization: ref.watch(coachSessionTokenProvider),
      );
    case CoachBackendKind.cloud:
      // While the Keychain read is in flight (or if it failed) the key reads as
      // absent here and the backend reports itself unconfigured; it rebuilds
      // with the real key the moment the read resolves. `.asData?.value` is what
      // makes a failed read degrade to absent — senders awaiting
      // `coachApiKeyProvider.future` instead see it THROW, so they must catch it
      // themselves.
      final apiKey = ref.watch(coachApiKeyProvider).asData?.value ?? '';
      return CloudCoachBackend(apiKey: apiKey);
  }
});

/// Live model discovery for a local server, keyed by its (normalized) base URL
/// so switching URLs refetches while unrelated config edits don't. Empty on
/// failure → the picker falls back to manual entry.
final coachLocalModelsProvider = FutureProvider.autoDispose
    .family<List<CoachModel>, String>((ref, baseUrl) async {
      return LocalCoachBackend(baseUrl: baseUrl).listModels();
    });

/// Reachability of a local server, keyed by (normalized) base URL — drives the
/// status pill in the settings dialog. Uses the short-timeout probe so the pill
/// resolves quickly instead of hanging on the default 15s connect budget.
final coachLocalReachableProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, baseUrl) async {
      return probeLocalReachable(baseUrl);
    });

/// Best-effort local-server auto-detection for the first-run nudge: probes the
/// common Ollama/LM Studio ports and returns the first reachable base URL, or
/// null when nothing answers.
final coachLocalDetectionProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  for (final port in kLocalProbePorts) {
    final baseUrl = 'http://localhost:$port/v1';
    if (await probeLocalReachable(baseUrl)) return baseUrl;
  }
  return null;
});

/// A short-timeout reachability probe shared by auto-detection, the status
/// pill, and the start-and-poll flow. The error strings are irrelevant here
/// (reachability never surfaces them), so a shared empty set keeps this
/// allocation-light.
Future<bool> probeLocalReachable(String baseUrl) {
  return OpenAiCompatibleClient(
    baseUrl: baseUrl,
    headers: const {'Authorization': 'Bearer local'},
    connectTimeout: const Duration(seconds: 2),
    errors: _silentErrors,
  ).reachable();
}

String _noError(int _) => '';
const CoachErrorMessages _silentErrors = CoachErrorMessages(
  preflightFailed: '',
  modelNotFound: '',
  contextTooLong: '',
  serverTimeout: '',
  connectionError: '',
  apiError: _noError,
);
