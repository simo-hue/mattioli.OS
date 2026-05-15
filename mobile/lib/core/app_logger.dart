import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
    // Sempre stampa in console durante lo sviluppo
    debugPrint('$message: $error');

    // In release, invia a Sentry
    if (kReleaseMode) {
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
  static void info(String message, {String? category}) {
    debugPrint('[Info] $message');

    if (kReleaseMode) {
      Sentry.addBreadcrumb(Breadcrumb(
        message: message,
        category: category ?? 'app',
        level: SentryLevel.info,
      ));
    }
  }

  /// Logga un warning (non bloccante ma sospetto).
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('[Warning] $message: $error');

    if (kReleaseMode) {
      Sentry.captureMessage(
        message,
        level: SentryLevel.warning,
        withScope: (scope) {
          if (error != null) {
            // Usiamo setContexts con una mappa invece di setExtra (deprecato)
            scope.setContexts('error_details', {'error': error.toString()});
          }
        },
      );
    }
  }
}
