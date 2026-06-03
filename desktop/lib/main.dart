import 'package:evolve_desktop/app/evolve_desktop_app.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
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
  DesktopSupabaseConfig.validate();

  final sharedPreferences = await SharedPreferences.getInstance();
  await Supabase.initialize(
    url: DesktopSupabaseConfig.url.trim(),
    anonKey: DesktopSupabaseConfig.publishableKey.trim(),
    authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()),
  );
  await DesktopNotificationService.instance.init();

  await DesktopSentryService.setEnabled(
    sharedPreferences.getBool('has_sentry_consent') ?? true,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const EvolveDesktopApp(),
    ),
  );
}
