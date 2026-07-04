// Item 4 — App Logs viewer + the AppLogger in-memory buffer that feeds it.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/features/settings/presentation/app_logs_dialog.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    LocaleSettings.setLocale(AppLocale.it);
    AppLogger.clearLogs();
  });

  test('AppLogger buffers by level, newest first, with working counts', () {
    AppLogger.info('info message');
    AppLogger.warning('warn message');
    AppLogger.error('error message', Exception('boom'), StackTrace.current);

    final logs = AppLogger.logs;
    expect(logs.length, 3);
    expect(logs.first.message, 'error message'); // newest first
    expect(logs.first.level, AppLogLevel.error);
    expect(logs.first.error, contains('boom'));
    expect(logs.first.stackTrace, isNotNull);

    expect(AppLogger.errorCount, 1);
    expect(AppLogger.warningCount, 1);
    expect(AppLogger.infoCount, 1);

    AppLogger.clearLogs();
    expect(AppLogger.logs, isEmpty);
  });

  testWidgets('log viewer shows entries and filters by level', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    AppLogger.info('info uno');
    AppLogger.error('errore uno', Exception('x'));

    await tester.pumpWidget(
      MaterialApp(
        theme: EvolveTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showAppLogsDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Title + both entries visible.
    expect(find.text(t.appLogs.title), findsOneWidget);
    expect(find.text('errore uno'), findsOneWidget);
    expect(find.text('info uno'), findsOneWidget);

    // Filter to errors only -> the info entry is hidden.
    await tester.tap(find.text(t.appLogs.filterErrors));
    await tester.pumpAndSettle();
    expect(find.text('errore uno'), findsOneWidget);
    expect(find.text('info uno'), findsNothing);
  });
}
