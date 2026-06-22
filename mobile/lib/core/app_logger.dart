import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'privacy_utils.dart';

/// Helper centralizzato per il reporting degli errori.
///
/// In debug mode: stampa in console (debugPrint).
/// In release mode: invia a Sentry con contesto opzionale.
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
