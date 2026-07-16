import 'package:evolve_desktop/core/secure_storage_utils.dart';

/// Keychain-backed home of the user's own OpenRouter API key (BYOK).
///
/// The app ships no provider key, so the cloud coach only works once the user
/// pastes theirs. The value goes to the macOS Keychain via
/// `flutter_secure_storage` — never SharedPreferences, which is a plaintext
/// plist inside the container. It is deliberately absent from every export and
/// backup path (those read the database, not the Keychain) and must never be
/// logged: [read] and [write] hand the value straight to the caller and nothing
/// in between prints it.
class OpenRouterKeyStore {
  const OpenRouterKeyStore();

  /// Keychain item name. Uses the general (non device-local) tier, matching how
  /// desktop stores its other non-Private-Mode secrets.
  static const String storageKey = 'openrouter_api_key';

  /// The stored key, or null when unset. Whitespace-only is treated as unset so
  /// a stray paste can't masquerade as a configured key.
  Future<String?> read() async {
    final value = (await SecureStorageUtils.read(storageKey))?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Persists [key] (trimmed — pasted keys routinely carry a trailing newline).
  /// Throws when the Keychain write fails, so callers can surface it.
  Future<void> write(String key) => SecureStorageUtils.write(
    storageKey,
    key.trim(),
    context: 'OpenRouterKeyStore',
  );

  Future<void> clear() => SecureStorageUtils.delete(storageKey);
}
