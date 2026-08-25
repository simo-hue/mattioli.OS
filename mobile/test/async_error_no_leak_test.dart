// A failed async provider shows a label, not the server's error.
//
// Seventeen statistics builders rendered `'${t.common.status.error}: $err'` —
// a Riverpod `AsyncValue` error object interpolated into user-facing copy. In
// practice that is a PostgREST body: table names, constraint names, and a
// sentence of English shown to someone reading the app in Arabic. Same
// SEC-7 / I18N-3 rule the global error handler already follows.
//
// The error is LOGGED rather than dropped, and that is why this is a widget and
// not a deleted string: none of those sites logged anything, and there is no
// `ProviderObserver` collecting provider failures either — so removing the
// interpolation alone would have traded a privacy leak for a silent failure.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/app_logger.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/ui/kit/evolve_async_error.dart';

/// The shape the leak actually took: a server error body, not a bare word.
const _serverError =
    'PostgrestException(message: permission denied for table goal_logs, '
    'code: 42501)';

Future<void> _pump(WidgetTester tester, Object error) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: AppTheme.darkTheme(null),
        locale: const Locale('en'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: AppLocaleUtils.supportedLocales,
        home: Scaffold(
          body: EvolveAsyncError(
            error: error,
            stackTrace: StackTrace.current,
            context: '[Stats] test',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// `AppLogger` debounces its disk write on a 2s timer, and logging is the whole
/// point of this widget — so every test here leaves one pending, and the binding
/// fails the test for it. Let it fire (the write itself is caught internally and
/// harmless with no file behind it) rather than reaching into the logger.
Future<void> _drainLogTimer(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();


  testWidgets('the error object never reaches the screen', (tester) async {
    await _pump(tester, _serverError);

    expect(find.text(t.common.status.error), findsOneWidget);
    expect(find.textContaining('goal_logs'), findsNothing,
        reason: 'a table name is exactly what must not be rendered');
    expect(find.textContaining('42501'), findsNothing);
    expect(find.textContaining('PostgrestException'), findsNothing);
    await _drainLogTimer(tester);
  });

  testWidgets('the label is the localized one, not a hardcoded word',
      (tester) async {
    // The old string concatenated a localized label with an untranslated error.
    // What survives has to be the whole message, in the user's language.
    await _pump(tester, _serverError);

    expect(find.text(t.common.status.error), findsOneWidget);
    expect(find.textContaining(':'), findsNothing,
        reason: 'no trailing separator left over from the concatenation');
    await _drainLogTimer(tester);
  });

  testWidgets('the error is logged, so removing it from the UI loses nothing',
      (tester) async {
    AppLogger.clearLogs();

    await _pump(tester, _serverError);

    // `LogEntry` has no toString override — read the fields it actually keeps.
    final logged = AppLogger.logs
        .map((l) => '${l.message} ${l.error ?? ''}')
        .join('\n');
    expect(logged, contains('[Stats] test'));
    expect(logged, contains('goal_logs'),
        reason: 'the detail the UI stopped showing has to land somewhere — '
            'these sites had no logging of their own and there is no '
            'ProviderObserver either');
    await _drainLogTimer(tester);
  });

  testWidgets('a rebuild carrying the same error does not log again',
      (tester) async {
    // These sit in tab views that rebuild on scroll, animation and theme
    // changes. A build()-time log would flood the ring buffer that
    // `app_logs_screen.dart` shows the user.
    //
    // RE-PUMPING the tree is what makes this test mean anything. A bare
    // `tester.pump()` with nothing dirty rebuilds nothing, so `didUpdateWidget`
    // never runs — the first version of this test passed even with the logging
    // moved into `build()`, which is precisely the regression it claims to
    // catch.
    AppLogger.clearLogs();
    await _pump(tester, _serverError);
    final afterFirst = AppLogger.logs.length;
    expect(afterFirst, 1, reason: 'the first appearance logs once');

    // Same error object, new frame: `didUpdateWidget` runs and must stay quiet.
    await _pump(tester, _serverError);
    await tester.pump();

    expect(AppLogger.logs.length, afterFirst);
    await _drainLogTimer(tester);
  });

  testWidgets('a DIFFERENT error in the same slot does log again',
      (tester) async {
    // The other half of the rule: quiet on a rebuild, never quiet on a new
    // failure. Without this, "logs once" could be satisfied by logging once ever.
    AppLogger.clearLogs();
    await _pump(tester, _serverError);

    await _pump(tester, 'StateError: a different failure entirely');
    await tester.pump();

    expect(AppLogger.logs.length, 2);
    await _drainLogTimer(tester);
  });
}
