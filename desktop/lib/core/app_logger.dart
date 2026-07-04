import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppLogger {
  const AppLogger._();

  /// When true, Sentry reporting is suppressed (Private mode).
  static bool _externalReportingDisabled = false;

  static void setExternalReportingDisabled(bool disabled) {
    _externalReportingDisabled = disabled;
  }

  static void error(String message, Object error, [StackTrace? stackTrace]) {
    debugPrint('$message: $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
    if (kReleaseMode && !_externalReportingDisabled) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) => scope.setTag('source', message),
      );
    }
  }
}
