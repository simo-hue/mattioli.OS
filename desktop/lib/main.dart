import 'package:evolve_desktop/app/evolve_desktop_app.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/desktop_supabase_config.dart';
import 'package:evolve_desktop/core/desktop_sentry_service.dart';
import 'package:evolve_desktop/core/navigator_key.dart';
import 'package:evolve_desktop/core/private_data_refresh.dart';
import 'package:evolve_desktop/core/secure_local_storage.dart';
import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  // ── Global error boundary (before the first frame) ──────────────────────
  // Friendly localized fallback for build-time widget errors. The raw
  // exception is shown only in debug — don't leak internals to users in
  // release (SEC-7). Mirrors mobile's main.dart.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                t.common.unexpectedErrorTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  details.exception.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  };

  // Catch async/platform-dispatched errors that escape the widget tree.
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isRecoverableAuthSessionError(error)) {
      AppLogger.warning(
        '[Startup] Ignored recoverable auth session error',
        error,
        stack,
      );
      return true;
    }

    AppLogger.error('[System] Unhandled global exception', error, stack);
    _showGlobalErrorDialog(error);
    return true;
  };

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(child: const EvolveDesktopApp()),
    ),
  );
}

/// Supabase occasionally surfaces a stale/rotated refresh token as an
/// [AuthException] that resolves itself on the next refresh. These are
/// recoverable no-ops, so the global handler swallows them instead of alarming
/// the user. Mirrors mobile's `_isRecoverableAuthSessionError`.
bool _isRecoverableAuthSessionError(Object error) {
  if (error is! AuthException) return false;

  final message = error.message.toLowerCase();
  final code = error is AuthApiException ? error.code?.toLowerCase() : null;

  return code == 'refresh_token_not_found' ||
      message.contains('invalid refresh token') ||
      message.contains('refresh token not found');
}

/// Surfaces a localized "something went wrong" dialog through the global
/// [navigatorKey], since startup-level handlers have no widget [BuildContext].
/// Raw error text is gated on [kDebugMode] (SEC-7).
void _showGlobalErrorDialog(Object error) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  showEvolveDialog<void>(
    context: context,
    builder: (ctx) => EvolveAlertDialog(
      icon: Icons.error_outline,
      iconColor: Colors.red,
      title: Text(t.common.unexpectedErrorTitle),
      subtitle: t.common.unexpectedErrorMessage,
      content: kDebugMode
          ? SelectableText(
              error.toString(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
          : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.common.actions.gotIt),
        ),
      ],
    ),
  );
}
