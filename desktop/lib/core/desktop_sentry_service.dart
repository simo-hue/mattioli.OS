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

  /// Whether the SDK is allowed to run right now.
  ///
  /// [hasCompletedConsent] is load-bearing, not redundant: `has_sentry_consent`
  /// is absent on a fresh install, and gating on that key alone starts the SDK
  /// at cold start — i.e. it uploads diagnostics to a third-party server before
  /// the consent screen has ever been shown. That is precisely the "data
  /// uploaded before the user consented" that App Store Guideline 5.1.2 forbids,
  /// and it is what the macOS 1.0.0(26) submission was rejected for on
  /// 2026-08-01. Requiring the question to have been ANSWERED keeps a first
  /// launch silent until the user has actually been asked.
  ///
  /// Deliberately does NOT consult [isConfigured]: this is the CONSENT policy,
  /// and it stays a pure function of the user's choices so it can be reasoned
  /// about and tested without a provisioned DSN. Whether the SDK can physically
  /// start is a separate question, asked at the init sites.
  ///
  /// Mirrors mobile's `SentryService.shouldRun` exactly — the two apps make the
  /// same promise to the user, so they answer with the same predicate.
  static bool shouldRun({
    required bool hasCompletedConsent,
    required bool hasSentryConsent,
    required bool isPrivateMode,
  }) => hasCompletedConsent && hasSentryConsent && !isPrivateMode;

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
