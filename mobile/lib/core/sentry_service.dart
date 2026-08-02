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

  /// Whether [SentryConfig.dsn] is a DSN the SDK can actually use.
  ///
  /// Load-bearing, not defensive noise. `sentry_config.dart` is git-ignored and
  /// CI provisions it by copying `sentry_config.dart.example`, whose DSN is the
  /// placeholder `YOUR_SENTRY_DSN_HERE`. That is non-empty, so every "is Sentry
  /// on?" check passed, and `SentryFlutter.init` then threw from deep inside the
  /// SDK — `FormatException: Invalid empty scheme` while building
  /// `:///api/YOUR_SENTRY_DSN_HERE/envelope/` — failing an unrelated test. An
  /// empty DSN was already safe (the SDK treats it as disabled); a *malformed*
  /// one was not.
  ///
  /// So: an unconfigured OR half-configured build runs WITHOUT Sentry instead of
  /// crashing. A real DSN is unaffected.
  static bool get isConfigured => isUsableDsn(SentryConfig.dsn);

  /// The pure predicate behind [isConfigured], exposed so it can be tested
  /// against arbitrary values — the getter alone can only ever assert whatever
  /// DSN this build happened to compile in, which is precisely the blind spot
  /// that let the placeholder through.
  static bool isUsableDsn(String dsn) {
    final uri = Uri.tryParse(dsn.trim());
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  /// Initialize Sentry if it isn't already running. Called when the user leaves
  /// Private Mode mid-session, having previously granted crash-reporting
  /// consent (SEC-4). No-ops when Sentry is already enabled, or when no usable
  /// DSN is configured.
  static Future<void> ensureInitialized() async {
    if (Sentry.isEnabled || !isConfigured) return;
    final info = await releaseInfo();
    await SentryFlutter.init((options) {
      configure(options, release: info.release, dist: info.dist);
    });
  }

  /// Whether the SDK is allowed to run right now.
  ///
  /// [hasCompletedConsent] is load-bearing, not redundant: `has_sentry_consent`
  /// is ABSENT on a fresh install, and every read of it now defaults an absent
  /// key to `false` — but that default is a second line of defence, not the
  /// argument. Gating on the answer alone would still be wrong, because it
  /// cannot distinguish "the user said no" from "the user was never asked".
  /// Requiring the question to have been ANSWERED keeps a first launch silent
  /// on its own terms, whatever a caller passes for the answer.
  /// Deliberately does NOT consult [isConfigured]: this is the CONSENT policy,
  /// and it stays a pure function of the user's choices so it can be reasoned
  /// about and tested without a provisioned DSN. Whether the SDK can physically
  /// start is a separate question, asked at the init sites.
  static bool shouldRun({
    required bool hasCompletedConsent,
    required bool hasSentryConsent,
    required bool isPrivateMode,
  }) => hasCompletedConsent && hasSentryConsent && !isPrivateMode;

  /// Start or stop the SDK to match the user's current choice — entering Private
  /// Mode, or withdrawing crash-report consent. Mirrors desktop's
  /// `DesktopSentryService.setEnabled`.
  ///
  /// Tearing the client down is what makes the choice effective:
  /// `AppLogger.setExternalReportingDisabled` only gates AppLogger's own capture
  /// calls, while the SDK's `FlutterError.onError` hook, the native crash
  /// handler, `tracesSampleRate` transactions and debugPrint breadcrumbs keep
  /// reporting until `Sentry.close()` runs.
  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await ensureInitialized();
      return;
    }
    if (!Sentry.isEnabled) return;
    await Sentry.close();
  }
}
