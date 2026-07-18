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

  // Native Sign in with Apple on macOS — the same flow the iOS app uses. It
  // relies on the `com.apple.developer.applesignin` entitlement (declared in
  // macos/Runner/*.entitlements) and a signed build with a valid Apple team.
  // Defaults to on so macOS uses the native credential sheet instead of the
  // browser OAuth redirect (which needs an Apple OAuth secret configured on the
  // Supabase provider). Set the define to false to force the browser flow — the
  // only Apple path available on Windows/Linux, which ignore this flag anyway
  // because the controller gates native behind Platform.isMacOS.
  static const useNativeAppleSignIn = bool.fromEnvironment(
    'EVOLVE_DESKTOP_NATIVE_APPLE_SIGN_IN',
    defaultValue: true,
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
