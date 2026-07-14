import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'privacy_utils.dart';

/// Severity level for log entries.
enum AppLogLevel { info, warning, error }

/// A single log entry with full technical context, shown in the in-app viewer.
class LogEntry {
  final DateTime timestamp;
  final AppLogLevel level;
  final String message;
  final String? error;
  final String? stackTrace;
  final Map<String, dynamic>? extras;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    this.extras,
  });

  String get levelLabel => switch (level) {
    AppLogLevel.info => 'INFO',
    AppLogLevel.warning => 'WARN',
    AppLogLevel.error => 'ERROR',
  };

  String get formattedTimestamp {
    final t = timestamp;
    return '${t.year}-${_pad(t.month)}-${_pad(t.day)} '
        '${_pad(t.hour)}:${_pad(t.minute)}:${_pad(t.second)}.${_pad3(t.millisecond)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
  static String _pad3(int n) => n.toString().padLeft(3, '0');
}

/// Centralized error/diagnostic logging.
///
/// - Debug: prints to the console (`debugPrint`).
/// - Release: reports to Sentry (unless external reporting is disabled — Private
///   mode), with the message as the `source` tag.
/// - Always: keeps entries in an in-memory ring buffer for the in-app log viewer
///   (see `app_logs_dialog.dart`). The buffer is process-local and not persisted
///   to disk.
class AppLogger {
  const AppLogger._();

  /// When true, Sentry reporting is suppressed (Private mode).
  static bool _externalReportingDisabled = false;

  static void setExternalReportingDisabled(bool disabled) {
    _externalReportingDisabled = disabled;
  }

  /// Maximum number of log entries kept in memory.
  static const int _maxEntries = 500;

  /// In-memory ring buffer of recent log entries (oldest first).
  static final List<LogEntry> _logs = [];

  /// Listeners notified when the buffer changes (the viewer subscribes).
  static final List<VoidCallback> _listeners = [];

  /// Read-only view of the stored entries, newest first.
  static List<LogEntry> get logs => List.unmodifiable(_logs.reversed);

  static int get errorCount =>
      _logs.where((e) => e.level == AppLogLevel.error).length;

  static int get warningCount =>
      _logs.where((e) => e.level == AppLogLevel.warning).length;

  static int get infoCount =>
      _logs.where((e) => e.level == AppLogLevel.info).length;

  static void addListener(VoidCallback listener) => _listeners.add(listener);

  static void removeListener(VoidCallback listener) =>
      _listeners.remove(listener);

  static void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

  static void _addEntry(LogEntry entry) {
    _logs.add(entry);
    if (_logs.length > _maxEntries) _logs.removeAt(0);
    _notifyListeners();
  }

  /// Clears every stored entry.
  static void clearLogs() {
    _logs.clear();
    _notifyListeners();
  }

  static void error(
    String message,
    Object error, [
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  ]) {
    _addEntry(
      LogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.error,
        message: message,
        error: error.toString(),
        stackTrace: stackTrace?.toString(),
        extras: extras,
      ),
    );
    debugPrint('$message: $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
    if (kReleaseMode && !_externalReportingDisabled) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('source', message);
          if (extras != null) scope.setContexts('extras', extras);
        },
      );
    }
  }

  /// Logs a non-blocking warning.
  ///
  /// The message is PII-scrubbed (emails, JWTs, secret key/values) everywhere —
  /// buffer, debug print, and Sentry — and extras are scrubbed before leaving
  /// the device. `error()` is deliberately NOT scrubbed (matches mobile: it
  /// captures exception objects, not free-form user text). Mirrors mobile's
  /// `AppLogger.warning`.
  static void warning(
    String message, [
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  ]) {
    final sanitizedMessage = PrivacyUtils.sanitizeString(message);
    _addEntry(
      LogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.warning,
        message: sanitizedMessage,
        error: error?.toString(),
        stackTrace: stackTrace?.toString(),
        extras: extras,
      ),
    );
    debugPrint(
      '[Warning] $sanitizedMessage${error != null ? ': $error' : ''}',
    );
    if (kReleaseMode && !_externalReportingDisabled) {
      Sentry.captureMessage(
        sanitizedMessage,
        level: SentryLevel.warning,
        withScope: (scope) {
          if (error != null) {
            scope.setContexts('error_details', {'error': error.toString()});
          }
          if (extras != null) {
            scope.setContexts('extras', PrivacyUtils.sanitizeMap(extras)!);
          }
        },
      );
    }
  }

  /// Logs an informational breadcrumb (no error). PII-scrubbed like [warning].
  static void info(String message, {Map<String, dynamic>? extras}) {
    final sanitizedMessage = PrivacyUtils.sanitizeString(message);
    _addEntry(
      LogEntry(
        timestamp: DateTime.now(),
        level: AppLogLevel.info,
        message: sanitizedMessage,
        extras: extras,
      ),
    );
    if (kDebugMode) debugPrint('[Info] $sanitizedMessage');
    if (kReleaseMode && !_externalReportingDisabled) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: sanitizedMessage,
          level: SentryLevel.info,
          data: PrivacyUtils.sanitizeMap(extras),
        ),
      );
    }
  }
}
