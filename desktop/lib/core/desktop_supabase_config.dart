class DesktopSupabaseConfig {
  const DesktopSupabaseConfig._();

  static const url = String.fromEnvironment('EVOLVE_SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'EVOLVE_SUPABASE_PUBLISHABLE_KEY',
  );
  static const oauthRedirectUrl = String.fromEnvironment(
    'EVOLVE_DESKTOP_OAUTH_REDIRECT_URL',
    defaultValue: 'http://127.0.0.1:39876/auth/callback',
  );

  // Requires the macOS Sign in with Apple capability and a valid signing team.
  static const useNativeAppleSignIn = bool.fromEnvironment(
    'EVOLVE_DESKTOP_NATIVE_APPLE_SIGN_IN',
    defaultValue: false,
  );

  static Uri get oauthRedirectUri => Uri.parse(oauthRedirectUrl);

  static bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;

  static void validate() {
    if (!isConfigured) {
      throw StateError(
        'Desktop Supabase configuration is incomplete. Supply both '
        'EVOLVE_SUPABASE_URL and EVOLVE_SUPABASE_PUBLISHABLE_KEY.',
      );
    }
  }
}
