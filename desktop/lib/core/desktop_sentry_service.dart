import 'package:evolve_desktop/core/app_logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class DesktopSentryService {
  const DesktopSentryService._();

  /// DSN baked into local/dev builds when EVOLVE_SENTRY_DSN isn't provided.
  /// Treated as UNCONFIGURED (see [isConfigured]) so Sentry stays OFF without a
  /// real project — it points at a bogus project that can't deliver events
  /// anyway, and this mirrors mobile's empty-DSN stub.
  static const _placeholderDsn = 'https://default_placeholder@sentry.io/12345';

  static const _dsn = String.fromEnvironment(
    'EVOLVE_SENTRY_DSN',
    defaultValue: _placeholderDsn,
  );
  static const _environment = String.fromEnvironment(
    'EVOLVE_SENTRY_ENVIRONMENT',
    defaultValue: 'development',
  );
  // Matches mobile's production sample rate (0.2); its stub is 0.0. Previously
  // defaulted to 1.0 (100% transaction sampling) when unset.
  static const _tracesSampleRateValue = String.fromEnvironment(
    'EVOLVE_SENTRY_TRACES_SAMPLE_RATE',
    defaultValue: '0.2',
  );

  static bool _initialized = false;

  static bool get isConfigured {
    final dsn = _dsn.trim();
    return dsn.isNotEmpty && dsn != _placeholderDsn;
  }

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
          ..tracesSampleRate = double.tryParse(_tracesSampleRateValue) ?? 0.2
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
