import 'coach_config.dart';

/// Everything the app knows about a specific local-LLM product, in one place.
///
/// This exists because the launch-and-recover flow is the ONLY part of the local
/// coach that has to care which product it is talking to. Chat, model discovery
/// and reachability all go through `OpenAiCompatibleClient`, which deliberately
/// knows nothing about Ollama or LM Studio — they are just an OpenAI-compatible
/// server at a base URL. Launching one, however, needs its bundle ids, its
/// download page, and copy that names its own UI.
///
/// Product identity lives HERE, in Dart, rather than in `AppDelegate.swift` where
/// the Ollama bundle ids used to sit. That file's own comment admits its ids were
/// never confirmed — and nothing could have told us, because no Flutter test can
/// reach a Swift constant. Here every field is assertable in `coach_config_test`.
class LocalServerTarget {
  const LocalServerTarget({
    required this.preset,
    required this.displayName,
    required this.bundleIds,
    required this.appPath,
    required this.downloadUrl,
    required this.baseUrlHint,
    required this.modelHint,
    required this.firstTokenTimeout,
    required this.startPollAttempts,
    required this.serverIsOptIn,
  });

  /// The preset this describes.
  final LocalServerPreset preset;

  /// The product's own name, used verbatim in copy via slang's `{app}` param.
  /// Never translated — it is a proper noun in every locale we ship, including
  /// `ar` (`تشغيل Ollama`).
  final String displayName;

  /// macOS bundle identifiers to try, most-likely first. Empty means "this
  /// target cannot be launched" ([canLaunch]).
  final List<String> bundleIds;

  /// Conventional install path, tried when every bundle id misses. This is what
  /// makes an unconfirmed bundle id a soft failure rather than a hard one: a
  /// default install still resolves.
  final String appPath;

  /// Where to send a user who doesn't have the app.
  final String downloadUrl;

  /// Placeholder for the base-URL field. Technical, not prose — so it lives here
  /// rather than in i18n, where five translators would copy the same URL.
  final String baseUrlHint;

  /// Example model id, in THIS product's naming scheme. Ollama's `llama3.1:8b`
  /// and LM Studio's `lmstudio-community/…-GGUF` look nothing alike, and this
  /// hint is shown in the manual-entry field a stuck user lands in.
  final String modelHint;

  /// How long to wait for the first streamed token.
  ///
  /// Ollama keeps a model resident once loaded, so a cold load is a first-request
  /// event and 60s is plenty. LM Studio defaults to Auto-Evict (at most one
  /// JIT-loaded model resident) with a 60-minute TTL, which makes cold loads
  /// routine — every model switch pays one — so it gets a much larger budget.
  final Duration firstTokenTimeout;

  /// How many times to poll for the server after launching the app.
  ///
  /// LM Studio is an Electron app and boots slower than Ollama's daemon.
  final int startPollAttempts;

  /// Whether this product's HTTP server must be switched on by the user
  /// separately from launching the app.
  ///
  /// True for LM Studio: its server is a Developer-tab toggle, so launching the
  /// app is necessary but not sufficient. This is what makes a launch timeout
  /// mean something different per product, and why the start flow consults
  /// "is the app running?" before calling a timeout a failure.
  ///
  /// (Mitigating fact: LM Studio persists "Remember last server state", so a
  /// user who has ever started it gets the Ollama-like path on every later
  /// launch. This flag governs the first-run case.)
  final bool serverIsOptIn;

  /// Whether this target can be launched at all. False for [LocalServerPreset.custom],
  /// which is any-server-you-like and has no app to open.
  bool get canLaunch => bundleIds.isNotEmpty;

  static const ollama = LocalServerTarget(
    preset: LocalServerPreset.ollama,
    displayName: 'Ollama',
    // Unconfirmed on-device (see TO_SIMO_DO.md) — hence [appPath] below.
    bundleIds: [
      'com.electron.ollama',
      'ai.ollama.app',
      'com.ollama.ollama',
      'com.ollama.app',
    ],
    appPath: '/Applications/Ollama.app',
    downloadUrl: 'https://ollama.com/download',
    baseUrlHint: 'http://localhost:11434/v1',
    modelHint: 'e.g. llama3.1:8b',
    firstTokenTimeout: Duration(seconds: 60),
    startPollAttempts: 20,
    serverIsOptIn: false,
  );

  static const lmStudio = LocalServerTarget(
    preset: LocalServerPreset.lmStudio,
    displayName: 'LM Studio',
    // Triangulated from the Homebrew cask's `uninstall quit:` stanza, the brew
    // API JSON, and an independent Info.plist scrape of v0.2.6 — the same id
    // from 0.2.6 through 0.4.19, with no legacy variants found. Still worth the
    // one-command on-device confirmation in TO_SIMO_DO.md.
    bundleIds: ['ai.elementlabs.lmstudio'],
    appPath: '/Applications/LM Studio.app',
    downloadUrl: 'https://lmstudio.ai/download',
    baseUrlHint: 'http://localhost:1234/v1',
    // LM Studio reports the publisher-prefixed repo id, not a short tag.
    modelHint: 'e.g. lmstudio-community/Llama-3.2-3B-Instruct-GGUF',
    // Cold loads are the norm here, not the exception — see [firstTokenTimeout].
    // Not 300s: that is LM Studio's server-side *inference* ceiling, a different
    // thing. Past ~3 minutes something is genuinely wrong and saying so beats
    // waiting.
    firstTokenTimeout: Duration(seconds: 180),
    // Electron cold start, then the server comes up after it — 40 × 1.5s = 60s.
    startPollAttempts: 40,
    serverIsOptIn: true,
  );

  /// A stand-in for a hand-typed endpoint: no app, no launcher, house defaults.
  static const custom = LocalServerTarget(
    preset: LocalServerPreset.custom,
    displayName: 'Local server',
    bundleIds: [],
    appPath: '',
    downloadUrl: '',
    baseUrlHint: 'http://localhost:11434/v1',
    modelHint: 'e.g. llama3.1:8b',
    firstTokenTimeout: Duration(seconds: 60),
    startPollAttempts: 20,
    serverIsOptIn: false,
  );

  /// Total by construction — every preset has a target, so callers never need a
  /// null check and a new preset cannot be forgotten (the switch is exhaustive).
  static LocalServerTarget forPreset(LocalServerPreset preset) =>
      switch (preset) {
        LocalServerPreset.ollama => ollama,
        LocalServerPreset.lmStudio => lmStudio,
        LocalServerPreset.custom => custom,
      };

  /// The target for a (possibly hand-typed) base URL, via [LocalServerPreset.match].
  static LocalServerTarget forBaseUrl(String baseUrl) =>
      forPreset(LocalServerPreset.match(baseUrl));
}
