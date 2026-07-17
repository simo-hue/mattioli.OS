/// Non-secret OpenRouter endpoint constants.
///
/// Deliberately holds NO API key. The coach is BYOK: the key belongs to the
/// user, is entered in the coach settings dialog, and lives in the Keychain
/// (see `openrouter_key_store.dart`) — a compile-time constant (a literal or
/// `String.fromEnvironment`) would be baked into the AOT snapshot and
/// recoverable from a shipped build with `strings`.
class OpenRouterConfig {
  static const String baseUrl = 'https://openrouter.ai/api/v1';

  /// The BYOK default — a FREE model, so connecting a key costs the user nothing
  /// (see [kDefaultCloudModel] for the full rationale). Kept in sync with it.
  static const String defaultModel = 'google/gemma-4-26b-a4b-it:free';
}
