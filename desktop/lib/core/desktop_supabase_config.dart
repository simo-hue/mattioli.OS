class DesktopSupabaseConfig {
  const DesktopSupabaseConfig._();

  static const url = String.fromEnvironment(
    'EVOLVE_SUPABASE_URL',
    defaultValue: 'https://raxizttlmsofixqyanwc.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'EVOLVE_SUPABASE_PUBLISHABLE_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJheGl6dHRsbXNvZml4cXlhbndjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1ODI0NjIsImV4cCI6MjA5MzE1ODQ2Mn0.Mauqn4tPL0oPdkjyjpJt8cpCFLpVzzixt7MAIjAeF_Y',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static void validate() {
    if (!isConfigured) {
      throw StateError(
        'Desktop Supabase configuration is incomplete. Supply both '
        'EVOLVE_SUPABASE_URL and EVOLVE_SUPABASE_PUBLISHABLE_KEY.',
      );
    }
  }
}
