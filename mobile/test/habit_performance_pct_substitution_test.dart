// F38 — the strongest/weakest-day cards substituted on a token no translation
// contains.
//
// `t.statistics.wellDoneCompletion.replaceFirst('done', pct)` works only if
// every locale's string contains the literal word "done" exactly where the
// number belongs. None of the ten shipped strings does — they carry a bare `%`
// sign standing in for "<n>%":
//
//   en "Well done! % completion"      it "Ben fatto! % di completamento"
//   de "Gut gemacht! % Fertigstellung" es "¡Bien hecho! % finalización"
//
// So four of the five locales rendered a naked `%` with no number, and English —
// the one locale where the token happened to appear — had the word eaten out of
// its own congratulation: at 86% it read "Well 86! % completion (12/14)". The
// weakest-day card is the same substitution on `onlyCompletion`: "Only %
// completion".
//
// The convention works elsewhere (`streakOfCountDaysBroken` really does contain
// "count" in all five locales) — which is why it was not obviously wrong here.
//
// KNOWN GAP, deliberately not fixed here: ar `onlyCompletion` is
// "نسبة الإكمال فقط", which has no `%` at all, so there is no slot to substitute
// into. That is a copy decision, not a code fix.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/ui/widgets/statistics/habit_performance_tab_widget.dart';

/// Monday 12/14 = 86%, Tuesday 2/14 = 14%: one strongest, one weakest.
final _rows = <Map<String, dynamic>>[
  {'day_index': 1, 'total_count': 14, 'done_count': 12},
  {'day_index': 2, 'total_count': 14, 'done_count': 2},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Non-English translations are deferred-loaded, and the load never
    // completes inside `testWidgets`' fake-async zone — warm them here so the
    // widget tests can switch locale synchronously.
    for (final locale in AppLocale.values) {
      await locale.build();
    }
  });

  Future<void> pump(WidgetTester tester, AppLocale locale) async {
    LocaleSettings.setLocaleSync(locale);
    await tester.binding.setSurfaceSize(const Size(600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        habitPerformanceProvider('g1').overrideWith((ref) async => _rows),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          locale: Locale(locale.languageCode),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: HabitPerformanceTabWidget(goalId: 'g1'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The two subtitle lines, which are the only Texts carrying the `(done/total)`
  /// suffix — the bar chart's own `86%` labels must not be mistaken for them.
  List<String> subtitles(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.data ?? '')
      .where((s) => s.contains('(12/14)') || s.contains('(2/14)'))
      .toList();

  for (final locale in [AppLocale.en, AppLocale.it]) {
    testWidgets('the ${locale.languageCode} cards carry the percentage',
        (tester) async {
      await pump(tester, locale);

      final lines = subtitles(tester);
      expect(lines, hasLength(2));
      expect(lines.first, contains('86%'));
      expect(lines.last, contains('14%'));
    });
  }

  testWidgets('the English congratulation is left intact', (tester) async {
    // The other half of the bug: `replaceFirst('done', …)` ate the word out of
    // "Well done!" in the one locale where the token existed.
    await pump(tester, AppLocale.en);

    expect(subtitles(tester).first, startsWith('Well done!'));
    expect(subtitles(tester).first, isNot(contains('Well 86!')));
  });

  test('every locale carries the % slot these cards substitute into', () async {
    // The root cause, pinned so the convention is not reintroduced here: the
    // placeholder the translations actually ship is `%`, not the word "done".
    for (final locale in AppLocale.values) {
      final strings = (await locale.build()).statistics;
      expect(strings.wellDoneCompletion, contains('%'),
          reason: '${locale.languageCode} has no slot for the percentage');
    }
  });
}
