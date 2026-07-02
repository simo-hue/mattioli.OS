import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'privacy_utils.dart';

/// Severity level for log entries.
enum AppLogLevel { info, warning, error }

/// A single log entry with full technical context.
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

  String get levelLabel {
    switch (level) {
      case AppLogLevel.info:
        return 'INFO';
      case AppLogLevel.warning:
        return 'WARN';
      case AppLogLevel.error:
        return 'ERROR';
    }
  }

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
        'error': error,
        'stackTrace': stackTrace,
        'extras': extras,
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: AppLogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => AppLogLevel.info,
      ),
      message: json['message'] as String,
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
      extras: json['extras'] as Map<String, dynamic>?,
    );
  }
}

/// Helper centralizzato per il reporting degli errori.
///
/// In debug mode: stampa in console (debugPrint).
/// In release mode: invia a Sentry con contesto opzionale.
/// Always: stores entries in an in-memory ring buffer for the in-app log viewer.
///
/// Uso:
/// ```dart
/// try {
///   await supabase.from('goals').select();
/// } catch (e, stack) {
///   AppLogger.error('[Goals] Sync error', e, stack);
/// }
/// ```
class AppLogger {
  static bool externalReportingDisabled = false;

  /// Maximum number of log entries kept in memory.
  static const int _maxEntries = 500;

  /// In-memory ring buffer of recent log entries.
  static final List<LogEntry> _logs = [];

  static Timer? _saveTimer;
  static bool _isLoading = false;

  static Future<File> get _logFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_logs.json');
  }

  /// Loads persisted logs from the local filesystem.
  /// Should be called once during app startup in main.dart.
  static Future<void> loadLogs() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final file = await _logFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(content);
        _logs.clear();
        for (final item in decoded) {
          try {
            _logs.add(LogEntry.fromJson(item as Map<String, dynamic>));
          } catch (_) {
            // Skip malformed entries safely
          }
        }
        _notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AppLogger] Failed to load persisted logs: $e');
    } finally {
      _isLoading = false;
    }
  }

  static void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () async {
      try {
        final file = await _logFile;
        // Make a copy to avoid concurrent modification errors during JSON encoding
        final logsCopy = _logs.toList();
        final serialized = jsonEncode(logsCopy.map((e) => e.toJson()).toList());
        await file.writeAsString(serialized);
      } catch (e) {
        if (kDebugMode) debugPrint('[AppLogger] Failed to persist logs: $e');
      }
    });
  }

  /// Listeners notified when a new log entry is added.
  static final List<VoidCallback> _listeners = [];

  /// Read-only view of stored log entries (newest first).
  static List<LogEntry> get logs => List.unmodifiable(_logs.reversed);

  /// Number of error-level entries currently in the buffer.
  static int get errorCount =>
      _logs.where((e) => e.level == AppLogLevel.error).length;

  /// Number of warning-level entries currently in the buffer.
  static int get warningCount =>
      _logs.where((e) => e.level == AppLogLevel.warning).length;

  /// Register a listener to be called when new log entries are added.
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a previously registered listener.
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Add a log entry to the in-memory buffer.
  static void _addEntry(LogEntry entry) {
    _logs.add(entry);
    if (_logs.length > _maxEntries) {
      _logs.removeAt(0);
    }
    _notifyListeners();
    _scheduleSave();
  }

  /// Clear all stored log entries.
  static void clearLogs() {
    _logs.clear();
    _notifyListeners();
    _scheduleSave();
  }

  static void setExternalReportingDisabled(bool disabled) {
    externalReportingDisabled = disabled;
  }

  /// Logga un errore con contesto opzionale.
  /// [message] — descrizione leggibile (es. '[Goals] Sync error').
  /// [error] — l'eccezione catturata.
  /// [stackTrace] — lo stack trace (sempre passarlo quando disponibile).
  /// [extras] — dati aggiuntivi per il debug (es. {'goalId': '123'}).
  static void error(
    String message,
    dynamic error, [
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  ]) {
    // Store in the in-memory buffer
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      level: AppLogLevel.error,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
      extras: extras,
    ));

    // Console output only in debug — never leak raw error text to device logs
    // in release builds (SEC-8).
    if (kDebugMode) {
      debugPrint('${PrivacyUtils.sanitizeString(message)}: $error');
    }

    // In release, invia a Sentry
    if (kReleaseMode && !externalReportingDisabled) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('source', message);
          if (extras != null) {
            // Usiamo setContexts invece di setExtra (deprecato)
            scope.setContexts('extras', extras);
          }
        },
      );
    }
  }

  /// Logga un messaggio informativo (breadcrumb) senza errore.
  /// Utile per tracciare azioni dell'utente prima di un crash.
  static void info(
    String message, {
    String? category,
    Map<String, dynamic>? extras,
  }) {
    final sanitizedMessage = PrivacyUtils.sanitizeString(message);

    // Store in the in-memory buffer
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      level: AppLogLevel.info,
      message: sanitizedMessage,
      extras: extras,
    ));

    if (kDebugMode) debugPrint('[Info] $sanitizedMessage');

    if (kReleaseMode && !externalReportingDisabled) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: sanitizedMessage,
          category: category ?? 'app',
          level: SentryLevel.info,
          data: PrivacyUtils.sanitizeMap(extras),
        ),
      );
    }
  }

  /// Logga un warning (non bloccante ma sospetto).
  static void warning(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  ]) {
    final sanitizedMessage = PrivacyUtils.sanitizeString(message);

    // Store in the in-memory buffer
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      level: AppLogLevel.warning,
      message: sanitizedMessage,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
      extras: extras,
    ));

    if (kDebugMode) debugPrint('[Warning] $sanitizedMessage: $error');

    if (kReleaseMode && !externalReportingDisabled) {
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
}

/// A NavigatorObserver that logs all navigation events (push, pop, replace)
/// to the AppLogger as Info-level breadcrumbs.
class AppLoggerNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != null) {
      AppLogger.info('[Nav] Pushed ${route.settings.name}', category: 'navigation');
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.settings.name != null) {
      AppLogger.info('[Nav] Popped to ${previousRoute?.settings.name}', category: 'navigation');
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute?.settings.name != null) {
      AppLogger.info('[Nav] Replaced with ${newRoute?.settings.name}', category: 'navigation');
    }
  }
}

