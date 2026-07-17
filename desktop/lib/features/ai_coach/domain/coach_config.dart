import 'coach_backend.dart';

/// Default OpenAI-compatible base URL for a fresh install — Ollama's port.
/// Stored/normalized WITH the `/v1` suffix so backends only append
/// `/chat/completions` and `/models` (mirrors `OpenRouterConfig.baseUrl`).
const String kDefaultLocalBaseUrl = 'http://localhost:11434/v1';

/// The cloud model shipped by default (kept in sync with
/// `OpenRouterConfig.defaultModel`; duplicated here so the domain layer stays
/// free of a data-layer import).
const String kDefaultCloudModel = 'google/gemini-2.5-flash';

/// The model the Standard proxy runs. Display only: the client does not choose
/// it — the Edge Function reads it from `ai_coach_limits.model` and ignores
/// whatever the body names, which is what stops a client from billing us for a
/// model we never priced. Kept here so the chip can say what is answering.
///
/// If `ai_coach_limits.model` is ever retuned server-side (the point of it being
/// a row rather than a constant), this label goes stale until the next release.
/// It is a caption, not a control — but it is the only thing here that can lie.
const String kStandardCoachModel = 'google/gemini-2.5-flash';

/// Neutral sampling temperature — the historical coach value.
const double kDefaultTemperature = 0.7;

/// Ports probed when auto-detecting a running local server (Ollama, LM Studio).
const List<int> kLocalProbePorts = [11434, 1234];

/// A known local-server product. Selecting one prefills the base URL; [custom]
/// leaves the field to the user.
enum LocalServerPreset {
  ollama('http://localhost:11434/v1'),
  lmStudio('http://localhost:1234/v1'),
  custom('');

  const LocalServerPreset(this.baseUrl);

  /// The OpenAI-compatible base URL this preset points at ('' for [custom]).
  final String baseUrl;

  /// The preset whose base URL matches [url] (normalized), or [custom] when
  /// none does — lets the picker reflect a hand-typed URL correctly.
  static LocalServerPreset match(String url) {
    final normalized = normalizeBaseUrl(url);
    for (final preset in values) {
      if (preset != custom && normalizeBaseUrl(preset.baseUrl) == normalized) {
        return preset;
      }
    }
    return custom;
  }
}

/// Immutable, device-local coach configuration. Persisted field-by-field in
/// SharedPreferences (never synced — a localhost URL is meaningless on another
/// device).
class CoachConfig {
  const CoachConfig({
    required this.backend,
    required this.localBaseUrl,
    required this.cloudModel,
    required this.localModel,
    required this.temperature,
    this.systemPromptOverride,
  });

  /// A fresh install: [CoachBackendKind.standard], the zero-setup engine.
  ///
  /// This used to be [CoachBackendKind.cloud], which made "paste an OpenRouter
  /// key" the coach's front door — the exact surface Guideline 3.1.1 objected
  /// to. A user who has never chosen an engine now lands on the subscription,
  /// not on a key prompt.
  ///
  /// The cost: an existing BYOK user who never touched the setting (cloud was
  /// the default, so most never did) reads back as Standard and must re-pick
  /// "Your OpenRouter account" once. Their key is untouched, and Standard says
  /// exactly that when it can't serve — so this is one visible tap, not a silent
  /// break. Distinguishing "never chose" from "chose cloud" would need the
  /// Keychain, which `build()` cannot await.
  factory CoachConfig.defaults() => const CoachConfig(
    backend: CoachBackendKind.standard,
    localBaseUrl: kDefaultLocalBaseUrl,
    cloudModel: kDefaultCloudModel,
    localModel: null,
    temperature: kDefaultTemperature,
    systemPromptOverride: null,
  );

  /// Active engine.
  final CoachBackendKind backend;

  /// Normalized OpenAI-compatible base URL of the local server (ends in `/v1`).
  final String localBaseUrl;

  /// Last-used cloud model id.
  final String cloudModel;

  /// Last-used local model id, or null until the user picks one.
  final String? localModel;

  /// Sampling temperature applied to every request (0.0–2.0).
  final double temperature;

  /// A user-authored system prompt that replaces the default coach persona when
  /// non-null and non-empty.
  final String? systemPromptOverride;

  /// The model id that will actually be sent for the active [backend]. Empty
  /// string when the user is on local but hasn't chosen a model yet.
  ///
  /// Standard reports the server's pinned model rather than [cloudModel]: the
  /// two are different facts that happen to hold the same string today, and
  /// reading the user's BYOK preference here would let a stale pick misreport
  /// what the proxy is actually running.
  String get activeModel => switch (backend) {
    CoachBackendKind.local => localModel ?? '',
    CoachBackendKind.standard => kStandardCoachModel,
    CoachBackendKind.cloud => cloudModel,
  };

  /// Whether the configured local endpoint is a private (loopback/LAN) host.
  bool get localIsPrivate => isLoopbackOrLan(localBaseUrl);

  CoachConfig copyWith({
    CoachBackendKind? backend,
    String? localBaseUrl,
    String? cloudModel,
    String? localModel,
    bool clearLocalModel = false,
    double? temperature,
    String? systemPromptOverride,
    bool clearSystemPrompt = false,
  }) {
    return CoachConfig(
      backend: backend ?? this.backend,
      localBaseUrl: localBaseUrl ?? this.localBaseUrl,
      cloudModel: cloudModel ?? this.cloudModel,
      localModel: clearLocalModel ? null : (localModel ?? this.localModel),
      temperature: temperature ?? this.temperature,
      systemPromptOverride: clearSystemPrompt
          ? null
          : (systemPromptOverride ?? this.systemPromptOverride),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoachConfig &&
      other.backend == backend &&
      other.localBaseUrl == localBaseUrl &&
      other.cloudModel == cloudModel &&
      other.localModel == localModel &&
      other.temperature == temperature &&
      other.systemPromptOverride == systemPromptOverride;

  @override
  int get hashCode => Object.hash(
    backend,
    localBaseUrl,
    cloudModel,
    localModel,
    temperature,
    systemPromptOverride,
  );
}

/// Canonicalizes a user- or preset-supplied base URL:
/// - trims surrounding whitespace,
/// - defaults an empty value to [kDefaultLocalBaseUrl],
/// - prepends `http://` when no scheme is present,
/// - strips trailing slashes,
/// - appends `/v1` when the URL has no path (bare host:port), so both
///   `localhost:11434` and `http://localhost:11434/v1` resolve identically.
///
/// Returns the input trimmed of trailing slashes when it cannot be parsed
/// (never throws) so odd input still round-trips through the picker.
String normalizeBaseUrl(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return kDefaultLocalBaseUrl;

  final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) {
    return _stripTrailingSlashes(withScheme);
  }

  final hasVersionPath = uri.path.isNotEmpty && uri.path != '/';
  // Rebuild from the parsed components (never the raw input) so normalization is
  // idempotent and consistent: uri.scheme/host are already lowercased, query and
  // fragment are dropped, and uri.authority keeps bracketed IPv6 hosts like
  // `[::1]:11434` intact (uri.host alone strips the brackets and corrupts the URL).
  final rebuilt = hasVersionPath
      ? '${uri.scheme}://${uri.authority}${uri.path}'
      : '${uri.scheme}://${uri.authority}/v1';
  return _stripTrailingSlashes(rebuilt);
}

String _stripTrailingSlashes(String value) {
  var end = value.length;
  while (end > 0 && value[end - 1] == '/') {
    end--;
  }
  return value.substring(0, end);
}

/// Whether [baseUrl]'s host is loopback or an RFC-1918 private/`.local` LAN
/// address — i.e. traffic to it stays on the user's machine or local network,
/// which is what makes the "zero-egress" privacy promise true. A public host
/// (or an unparseable value) returns false so the UI can badge it as remote.
bool isLoopbackOrLan(String baseUrl) {
  final withScheme = baseUrl.contains('://') ? baseUrl : 'http://$baseUrl';
  final host = Uri.tryParse(withScheme)?.host.toLowerCase();
  if (host == null || host.isEmpty) return false;

  if (host == 'localhost' ||
      host == '0.0.0.0' ||
      host.endsWith('.local') ||
      host.endsWith('.localhost')) {
    return true;
  }

  // IPv6 (Uri.host strips the brackets): loopback ::1, unique-local fc00::/7,
  // link-local fe80::/10.
  if (host.contains(':')) {
    if (host == '::1') return true;
    if (host.startsWith('fc') || host.startsWith('fd')) return true;
    if (host.startsWith('fe8') ||
        host.startsWith('fe9') ||
        host.startsWith('fea') ||
        host.startsWith('feb')) {
      return true;
    }
    return false;
  }

  // IPv4: the whole 127.0.0.0/8 loopback block + RFC-1918 private ranges
  // (10.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12).
  final octets = host.split('.');
  if (octets.length == 4 && octets.every((o) => int.tryParse(o) != null)) {
    final a = int.parse(octets[0]);
    final b = int.parse(octets[1]);
    if (a == 127) return true;
    if (a == 10) return true;
    if (a == 192 && b == 168) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
  }
  return false;
}

/// Clamps a temperature into the accepted [0.0, 2.0] range (OpenAI's bound).
double clampTemperature(double value) => value.clamp(0.0, 2.0);

/// The engine that can actually serve, given the engine the user picked.
///
/// Only Private mode overrides the choice, and only for
/// [CoachBackendKind.standard], which it cannot reach for two independent
/// reasons — either sufficient on its own:
///
///  1. Private mode keeps no account. The Edge Function takes identity from the
///     caller's JWT and entitlement from `profiles.is_pro`; with neither, there
///     is nothing to authenticate and nothing to check.
///  2. `Supabase.initialize` is skipped entirely in Private mode (main.dart:
///     51-58), so there is no client to mint a token from. Desktop degrades that
///     to null in `supabaseClientProvider` rather than throwing — but a request
///     built from it would still go out with no bearer and come back 401.
///
/// Note that `desktopIsProProvider` reports **true** in Private mode
/// unconditionally (desktop_subscription_controller.dart:68-71). So entitlement
/// must never be read before the data mode: the `isPro` the client sees and the
/// `profiles.is_pro` the proxy checks are different facts that share a name.
///
/// Falling back to [CoachBackendKind.cloud] rather than [CoachBackendKind.local]
/// keeps the user's own remote key working if they have one, and shows the
/// "add your key" prompt if they don't — which is the honest end state for a
/// mode that has no account to bill.
CoachBackendKind effectiveCoachBackend({
  required CoachBackendKind chosen,
  required bool isPrivate,
}) {
  if (isPrivate && chosen == CoachBackendKind.standard) {
    return CoachBackendKind.cloud;
  }
  return chosen;
}

/// Why the Standard engine can or cannot answer right now.
enum StandardCoachStatus {
  /// Signed in, subscribed, and pointed at a configured backend.
  ready,

  /// Private mode: no account, so the proxy is not an option at all. The picker
  /// hides the segment rather than offering a mode that can only fail.
  unavailablePrivate,

  /// This build shipped without a Supabase URL/key, so there is no function to
  /// call. Distinct from [needsSignIn]: the user cannot fix it.
  unavailableUnconfigured,

  /// Signed out (or mid token refresh) — the proxy authenticates the JWT.
  needsSignIn,

  /// Signed in without an active Evolve Pro entitlement. This is the state
  /// Guideline 3.1.1 wants: the purchase unlocks the feature.
  needsPro,
}

/// Which [StandardCoachStatus] applies. Pure so the rule is stated once, in one
/// place, where it can be read and tested.
///
/// **The order is load-bearing**: `isPrivate` must be checked before [isPro] for
/// the reasons documented on [effectiveCoachBackend] — in Private mode `isPro`
/// is a placeholder, not a fact.
StandardCoachStatus resolveStandardCoachStatus({
  required bool isPrivate,
  required bool isConfigured,
  required bool hasSession,
  required bool isPro,
}) {
  if (isPrivate) return StandardCoachStatus.unavailablePrivate;
  if (!isConfigured) return StandardCoachStatus.unavailableUnconfigured;
  if (!hasSession) return StandardCoachStatus.needsSignIn;
  if (!isPro) return StandardCoachStatus.needsPro;
  return StandardCoachStatus.ready;
}

/// The models to offer in the local picker: the server's [discovered] list,
/// plus the currently-selected [current] id when the server didn't list it (a
/// hand-typed model, or a model from a different server). Ensures the active
/// pick always stays visible/selectable instead of showing a blank dropdown.
List<CoachModel> effectiveLocalModelOptions(
  List<CoachModel> discovered,
  String? current,
) {
  final trimmed = current?.trim();
  if (trimmed == null || trimmed.isEmpty) return discovered;
  if (discovered.any((model) => model.id == trimmed)) return discovered;
  return [...discovered, CoachModel(id: trimmed)];
}
