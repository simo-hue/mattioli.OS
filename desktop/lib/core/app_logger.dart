import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AppLogger {
  const AppLogger._();

  static void error(String message, Object error, [StackTrace? stackTrace]) {
    debugPrint('$message: $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
    if (kReleaseMode) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) => scope.setTag('source', message),
      );
    }
  }
}
