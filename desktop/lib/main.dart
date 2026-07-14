import 'package:evolve_desktop/app/evolve_desktop_app.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/desktop_supabase_config.dart';
import 'package:evolve_desktop/core/desktop_sentry_service.dart';
import 'package:evolve_desktop/core/private_data_refresh.dart';
import 'package:evolve_desktop/core/secure_local_storage.dart';
import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  final sharedPreferences = await SharedPreferences.getInstance();

  // Determine the saved data mode *before* initializing backends.
  var savedMode = sharedPreferences.getString('active_data_mode');
  // Recover a Private-mode user whose data-mode preference was lost/reset: if it
  // is ABSENT (not an explicit 'supabase') but the encrypted private DB is still
  // on disk, restore Private mode so the intact local data is queried instead of
  // silently dropping into a logged-out Supabase view. Mirrors mobile's startup
  // recovery (the user can still switch in Settings).
  if (savedMode == null && await DesktopPrivateDb.databaseFileExists()) {
    await sharedPreferences.setString(
      'active_data_mode',
      DesktopDataMode.private.name,
    );
    savedMode = DesktopDataMode.private.name;
    AppLogger.warning(
      '[Startup] Restored Private mode from the on-disk database after a '
      'missing data-mode preference',
    );
  }
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

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sharedPreferences)],
  );

  // Refresh the full private-data surface after a notification-driven local
  // write (macOS Done/Skip actions write straight to the encrypted DB). Shares
  // one helper with the sync-pull paths so they can't drift.
  DesktopNotificationService.onLocalWrite =
      () => refreshPrivateAfterPull(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(child: const EvolveDesktopApp()),
    ),
  );
}
