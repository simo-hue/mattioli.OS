/// Logging seam for the sync core.
///
/// The package must not depend on an app's logging stack (mobile routes through
/// `AppLogger` → Sentry with privacy sanitization; desktop has its own), so the
/// engine and service log through this interface instead. Each app passes a
/// thin adapter; tests default to [SilentSyncLogger].
///
/// The signatures deliberately mirror the apps' `AppLogger.info/error` so the
/// adapters are one-liners.
abstract class SyncLogger {
  const SyncLogger();

  void info(String message, {Map<String, dynamic>? extras});

  void error(
    String message,
    dynamic error, [
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  ]);
}

/// Default no-op logger (tests, and any caller that doesn't care).
class SilentSyncLogger extends SyncLogger {
  const SilentSyncLogger();

  @override
  void info(String message, {Map<String, dynamic>? extras}) {}

  @override
  void error(
    String message,
    dynamic error, [
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  ]) {}
}
