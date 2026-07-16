// SEC-8 — AppLogger must scrub PII out of the message before it reaches the
// console. Covers the sanitize half of the guard added to error()/warning();
// the `if (kDebugMode)` half cannot be exercised here because `flutter test`
// always runs with kDebugMode == true.
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> printed;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    AppLogger.clearLogs();
    printed = [];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printed.add(message);
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  test('error() redacts the email in the message before printing', () {
    AppLogger.error(
      '[Sync] upsert failed for simo@example.com',
      Exception('boom'),
    );

    final line = printed.first;
    expect(line, contains('[EMAIL_REDACTED]'));
    expect(line, isNot(contains('simo@example.com')));
  });

  test('error() redacts a secret key/value in the message before printing', () {
    AppLogger.error('[Auth] refresh_token=hunter2 rejected', Exception('boom'));

    final line = printed.first;
    expect(line, contains('[REDACTED]'));
    expect(line, isNot(contains('hunter2')));
  });

  test('warning() redacts the email in the message before printing', () {
    AppLogger.warning('[Sync] retrying for simo@example.com', 'timeout');

    final line = printed.first;
    expect(line, contains('[EMAIL_REDACTED]'));
    expect(line, isNot(contains('simo@example.com')));
  });

  test('info() redacts the email in the message before printing', () {
    AppLogger.info('[Nav] opened profile for simo@example.com');

    final line = printed.first;
    expect(line, contains('[EMAIL_REDACTED]'));
    expect(line, isNot(contains('simo@example.com')));
  });
}
