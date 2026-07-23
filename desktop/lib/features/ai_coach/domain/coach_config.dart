import 'coach_backend.dart';

/// Default OpenAI-compatible base URL for a fresh install — Ollama's port.
/// Stored/normalized WITH the `/v1` suffix so backends only append
/// `/chat/completions` and `/models` (mirrors `OpenRouterConfig.baseUrl`).
const String kDefaultLocalBaseUrl = 'http://localhost:11434/v1';

/// The model the "Your OpenRouter account" (BYOK) engine sends by default (kept
/// in sync with `OpenRouterConfig.defaultModel`; duplicated here so the domain
/// layer stays free of a data-layer import).
///
/// A **free** OpenRouter model, on purpose: BYOK bills the user's own account,
/// so a free model makes the coach genuinely $0 for anyone who connects a key.
/// The free-tier trade-offs (a per-account daily cap; a provider that may train
/// on the data) sit on the user's side of the line, which BYOK's consent copy
/// already discloses.
///
/// The Standard proxy now runs the SAME free model (2026-07-17 product
/// decision), via Google AI Studio rather than Vertex — see [kStandardCoachModel]
/// and `migrations/20260717_add_ai_coach_proxy.sql`.
const String kDefaultCloudModel = 'nvidia/nemotron-3-nano-30b-a3b:free';

/// The model the Standard proxy runs. Display only: the client does not choose
/// it — the Edge Function reads it from `ai_coach_limits.model` and ignores
/// whatever the body names, which is what stops a client from picking a model we
/// never disclosed. Kept here so the chip can say what is answering.
///
/// The proxy runs the free tier by explicit product decision: the coach costs
/// the developer nothing. If `ai_coach_limits.model` is ever retuned server-side
/// (the point of it being a row rather than a constant), this label goes stale
/// until the next release. It is a caption, not a control — but it is the only
/// thing here that can lie.
const String kStandardCoachModel = 'nvidia/nemotron-3-nano-30b-a3b:free';

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
/// The two data modes own disjoint backend sets, and this is where that is
/// enforced — every gate (send path, setup banners, chip) reads THIS, not
/// `config.backend`, so the rule holds everywhere at once.
///
/// **Account mode → Standard, always.** The account tier is the managed,
/// Pro-funded coach and nothing else: bring-your-own-key and local models are
/// Private-mode features by product decision, so a signed-in user's persisted
/// choice of Cloud or Local resolves to Standard. Their choice is preserved (not
/// rewritten) and takes effect again the moment they enter Private mode, so no
/// one is forced to re-pick after switching modes. A non-pro account user still
/// resolves to Standard; the proxy answers `needsPro` and the paywall does the
/// rest.
///
/// **Private mode → never Standard.** It cannot reach the proxy, for two
/// independent reasons, either sufficient on its own:
///
///  1. Private mode keeps no account. The Edge Function takes identity from the
///     caller's JWT and entitlement from `profiles.is_pro`; with neither, there
///     is nothing to authenticate and nothing to check.
///  2. `Supabase.initialize` is skipped entirely in Private mode (main.dart:
///     51-58), so there is no client to mint a token from. Desktop degrades that
///     to null in `supabaseClientProvider` rather than throwing — but a request
///     built from it would still go out with no bearer and come back 401.
///
/// So a persisted Standard choice resolves to [CoachBackendKind.cloud] there
/// (keeping the user's own remote key working if they have one, and showing the
/// "add your key" prompt otherwise); Local stays Local.
///
/// This function deliberately never reads entitlement — the data mode alone
/// decides the backend set — so the fact that `desktopIsProProvider` reports a
/// placeholder **true** in Private mode (desktop_subscription_controller.dart:
/// 68-71) can never mislead it.
CoachBackendKind effectiveCoachBackend({
  required CoachBackendKind chosen,
  required bool isPrivate,
}) {
  if (isPrivate) {
    // No account here: Standard cannot authenticate, so it resolves to the
    // user's own remote key. Cloud and Local are already reachable as-is.
    return chosen == CoachBackendKind.standard
        ? CoachBackendKind.cloud
        : chosen;
  }
  // Account mode is Standard-only. A stored Cloud/Local choice is preserved for
  // when the user returns to Private mode, but does not serve here.
  return CoachBackendKind.standard;
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
