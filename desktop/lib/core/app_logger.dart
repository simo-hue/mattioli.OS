import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'message': message,
        if (error != null) 'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace,
        if (extras != null) 'extras': extras,
      };

  static LogEntry fromJson(Map<String, dynamic> json) => LogEntry(
        timestamp: DateTime.parse(json['timestamp'] as String),
        level: AppLogLevel.values.firstWhere(
          (l) => l.name == json['level'],
          orElse: () => AppLogLevel.info,
        ),
        message: json['message'] as String,
        error: json['error'] as String?,
        stackTrace: json['stackTrace'] as String?,
        extras: (json['extras'] as Map?)?.cast<String, dynamic>(),
      );
}

/// Centralized error/diagnostic logging.
///
/// - Debug: prints to the console (`debugPrint`).
/// - Release: reports to Sentry (unless external reporting is disabled — Private
///   mode), with the message as the `source` tag.
/// - Always: keeps entries in a ring buffer for the in-app log viewer (see
///   `app_logs_dialog.dart`), PERSISTED to disk and reloaded at startup.
///
/// Persistence matters more here than it looks. The buffer used to be
/// process-local, so quitting and reopening the app erased it — and quitting and
/// reopening is exactly what a user does when sync appears stuck. The single
/// action taken to work around a problem destroyed the only record of it, and
/// every log exported after that showed a clean session starting AFTER the
/// interesting moment. Mobile has always persisted; this brings the Mac to
/// parity so the two apps can actually be compared.
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
    _scheduleSave();
  }

  /// Clears every stored entry, on disk as well as in memory.
  static void clearLogs() {
    _logs.clear();
    _notifyListeners();
    _scheduleSave();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  static Timer? _saveTimer;
  static bool _isLoading = false;

  /// Set false in widget tests. The debounced save schedules a real 2-second
  /// timer, and `pumpWidget` fails a test that finishes with one pending — so
  /// without this seam any test that logs anything (which is most of them, via
  /// the code under test) would fail on a timer it never asked for.
  ///
  /// Deliberately opt-OUT rather than opt-in: production must persist by
  /// default, and a logger that silently stops recording because a flag was not
  /// set is the failure this whole change exists to prevent.
  @visibleForTesting
  static bool persistenceEnabled = true;

  static Future<File> get _logFile async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/app_logs.json');
  }

  /// Reload the persisted buffer. Call once at startup, before anything worth
  /// logging happens.
  static Future<void> loadLogs() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final file = await _logFile;
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      _logs.clear();
      for (final item in decoded) {
        try {
          _logs.add(LogEntry.fromJson(item as Map<String, dynamic>));
        } catch (_) {
          // Skip a malformed entry rather than losing the whole history to it.
        }
      }
      _notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('[AppLogger] Failed to load persisted logs: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Debounced so a burst of entries costs one write. Deliberately fire-and-
  /// forget: logging must never fail an operation it is only observing.
  static void _scheduleSave() {
    if (!persistenceEnabled) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () async {
      try {
        final file = await _logFile;
        final copy = _logs.toList(); // avoid concurrent modification
        await file.writeAsString(
          jsonEncode(copy.map((e) => e.toJson()).toList()),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[AppLogger] Failed to persist logs: $e');
      }
    });
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
    // Console output only in debug — never leak raw error text to device logs
    // in release builds (SEC-8). `debugPrint` writes to the console in release
    // too, so the guard is what keeps it out of Console.app.
    if (kDebugMode) {
      debugPrint('${PrivacyUtils.sanitizeString(message)}: $error');
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace);
      }
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
    // Debug-only for the same reason as `error()`: `$error` is raw (SEC-8).
    if (kDebugMode) {
      debugPrint(
        '[Warning] $sanitizedMessage${error != null ? ': $error' : ''}',
      );
    }
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
