import 'package:evolve_desktop/app/evolve_desktop_app.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_supabase_config.dart';
import 'package:evolve_desktop/core/desktop_sentry_service.dart';
import 'package:evolve_desktop/core/secure_local_storage.dart';
import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();

  // Determine the saved data mode *before* initializing backends.
  final savedMode = sharedPreferences.getString('active_data_mode');
  final isPrivateMode = savedMode == DesktopDataMode.private.name;

  // Only initialize Supabase when in Supabase mode (or first launch).
  if (!isPrivateMode) {
    DesktopSupabaseConfig.validate();
    await Supabase.initialize(
      url: DesktopSupabaseConfig.url.trim(),
      anonKey: DesktopSupabaseConfig.publishableKey.trim(),
      authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()),
    );
  }

  await DesktopNotificationService.instance.init();

  // Sentry: disabled in Private mode; in Supabase mode honour user consent.
  if (isPrivateMode) {
    await DesktopSentryService.setEnabled(false);
  } else {
    await DesktopSentryService.setEnabled(
      sharedPreferences.getBool('has_sentry_consent') ?? true,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const EvolveDesktopApp(),
    ),
  );
}
