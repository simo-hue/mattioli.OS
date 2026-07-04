class OpenRouterConfig {
  /// Supplied at build time via `--dart-define=OPENROUTER_API_KEY=...` so the key
  /// is never committed. Empty by default → the AI stays inert (the service
  /// short-circuits to an "API key missing" message).
  static const String apiKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static const String baseUrl = 'https://openrouter.ai/api/v1';
  static const String defaultModel = 'google/gemini-2.5-flash';
}
