import 'coach_backend.dart';

/// Default OpenAI-compatible base URL for a fresh install — Ollama's port.
/// Stored/normalized WITH the `/v1` suffix so backends only append
/// `/chat/completions` and `/models` (mirrors `OpenRouterConfig.baseUrl`).
const String kDefaultLocalBaseUrl = 'http://localhost:11434/v1';

/// The cloud model shipped by default (kept in sync with
/// `OpenRouterConfig.defaultModel`; duplicated here so the domain layer stays
/// free of a data-layer import).
const String kDefaultCloudModel = 'google/gemini-2.5-flash';

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

  factory CoachConfig.defaults() => const CoachConfig(
    backend: CoachBackendKind.cloud,
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
  String get activeModel =>
      backend == CoachBackendKind.local ? (localModel ?? '') : cloudModel;

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
