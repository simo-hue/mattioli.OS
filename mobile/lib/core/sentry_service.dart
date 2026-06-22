import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_logger.dart';
import 'sentry_config.dart';

/// Centralizes Sentry initialization so the cold-start path (main.dart) and the
/// late (re)init when the user leaves Private Mode (SEC-4) share one config.
class SentryService {
  /// Apply the app's standard Sentry options, including explicit release/dist
  /// for correct per-build grouping (SEC-3).
  static void configure(
    SentryFlutterOptions options, {
    String? release,
    String? dist,
  }) {
    options.dsn = SentryConfig.dsn;
    options.environment = SentryConfig.environment;
    options.tracesSampleRate = SentryConfig.tracesSampleRate;
    if (release != null) options.release = release;
    if (dist != null) options.dist = dist;
    options.reportPackages = true;
    options.debug = false;
    options.beforeSend = (event, hint) => SentryConfig.sanitizeEvent(event);
  }

  /// Resolve the app version metadata for Sentry release/dist. Fails soft.
  static Future<({String? release, String? dist})> releaseInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return (
        release: '${info.packageName}@${info.version}+${info.buildNumber}',
        dist: info.buildNumber,
      );
    } catch (e, stack) {
      AppLogger.error('[Sentry] PackageInfo for release failed', e, stack);
      return (release: null, dist: null);
    }
  }

  /// Initialize Sentry if it isn't already running. Called when the user leaves
  /// Private Mode mid-session, having previously granted crash-reporting
  /// consent (SEC-4). No-ops when Sentry is already enabled.
  static Future<void> ensureInitialized() async {
    if (Sentry.isEnabled) return;
    final info = await releaseInfo();
    await SentryFlutter.init((options) {
      configure(options, release: info.release, dist: info.dist);
    });
  }
}
