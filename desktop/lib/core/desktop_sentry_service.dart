import 'package:evolve_desktop/core/app_logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class DesktopSentryService {
  const DesktopSentryService._();

  static const _dsn = String.fromEnvironment('EVOLVE_SENTRY_DSN');
  static const _environment = String.fromEnvironment(
    'EVOLVE_SENTRY_ENVIRONMENT',
    defaultValue: 'production',
  );
  static const _tracesSampleRateValue = String.fromEnvironment(
    'EVOLVE_SENTRY_TRACES_SAMPLE_RATE',
    defaultValue: '0.1',
  );

  static bool _initialized = false;

  static bool get isConfigured => _dsn.trim().isNotEmpty;

  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await ensureInitialized();
      return;
    }
    if (!_initialized) return;
    await Sentry.close();
    _initialized = false;
  }

  static Future<void> ensureInitialized() async {
    if (_initialized || !isConfigured) return;
    try {
      await SentryFlutter.init((options) {
        options
          ..dsn = _dsn
          ..environment = _environment
          ..tracesSampleRate = double.tryParse(_tracesSampleRateValue) ?? 0.1
          ..reportPackages = true
          ..beforeSend = _sanitizeEvent;
      });
      _initialized = true;
    } catch (error, stack) {
      AppLogger.error('Unable to initialize desktop Sentry', error, stack);
    }
  }

  static SentryEvent _sanitizeEvent(SentryEvent event, Hint hint) {
    final user = event.user;
    if (user != null) user.email = null;
    return event;
  }
}
