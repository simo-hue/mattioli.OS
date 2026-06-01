class DesktopSupabaseConfig {
  const DesktopSupabaseConfig._();

  static const url = String.fromEnvironment('EVOLVE_SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'EVOLVE_SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get hasAnyValue => url.isNotEmpty || publishableKey.isNotEmpty;

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static void validate() {
    if (hasAnyValue && !isConfigured) {
      throw StateError(
        'Desktop Supabase configuration is incomplete. Supply both '
        'EVOLVE_SUPABASE_URL and EVOLVE_SUPABASE_PUBLISHABLE_KEY.',
      );
    }
  }
}
