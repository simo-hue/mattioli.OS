// Guards the Goals empty state against RenderFlex overflow at iOS accessibility
// text sizes.
//
// Why this exists: the period navigator is an INFLEXIBLE sibling of the
// Expanded(PageView) that renders the goal list, so every point the header
// grows is a point the page loses. Moving the period's date range onto a second
// line under the title grew it by ~17pt at default scale and proportionally
// more as text scales — enough that the non-scrolling empty state started
// overflowing at AX2 and above on devices that were clean before.
//
// The fonts matter. flutter_test substitutes a fixed-width block font whose
// glyph metrics are fiction (roughly 2x too wide, no line gap), so wrapping and
// therefore height are both wrong under it. These cases load the real bundled
// Inter faces, or they would be measuring nothing.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/macro_goal.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/macro_goals_stats_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/macro_goals_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isLoggedIn: false);
}

Map<String, dynamic> _emptyStats() => {
  'total_goals': 0,
  'completed_goals': 0,
  'success_rate': 0,
  'best_category_rate': 0,
  'best_month_rate': 0,
  'best_type_rate': 0,
  'category_rates': <dynamic>[],
  'category_distribution': <dynamic>[],
  'category_performance': <dynamic>[],
  'monthly_performance': <dynamic>[],
  'type_performance': <dynamic>[],
  'annual_progression': <dynamic>[],
  'seasonality': <dynamic>[],
  'monthly_history': <dynamic>[],
  'interest_evolution': <dynamic>[],
};

/// Loads the bundled Inter faces. Must run in [setUpAll]: real file I/O never
/// completes inside a `testWidgets` fake-async zone, so loading it per-test
/// hangs until the harness timeout.
Future<void> _loadInter() async {
  final dir = Directory('assets/fonts');
  if (!dir.existsSync()) return;
  final faces = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.ttf'));
  for (final face in faces) {
    final loader = FontLoader('Inter')
      ..addFont(
        Future.value(
          ByteData.sublistView(Uint8List.fromList(face.readAsBytesSync())),
        ),
      );
    await loader.load();
  }
}

void main() {
  setUpAll(_loadInter);

  /// Pumps the Goals screen with NO goals, at [size] and [textScale], on the
  /// given plan, and returns every vertical overflow Flutter reported.
  Future<List<String>> overflowsFor(
    WidgetTester tester, {
    required Size size,
    required double textScale,
    required GoalType type,
  }) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_tutorial_supabase': true,
      'has_seen_goals_tutorial_supabase': true,
      'has_seen_stats_tutorial_supabase': true,
      'macro_goals_cache': '[]',
    });
    final prefs = await SharedPreferences.getInstance();

    final reported = <String>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) reported.add(text);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        macroGoalsStatsProvider.overrideWith((ref, year) async => _emptyStats()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            theme: AppTheme.darkTheme(null),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: AppLocaleUtils.supportedLocales,
            locale: const Locale('en'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const Scaffold(body: MacroGoalsScreen(isActive: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(macroGoalsViewProvider.notifier)
      ..setType(type)
      ..setYear(2026)
      ..setQuarter(3)
      ..setMonth(8)
      ..setWeek(2);
    await tester.pumpAndSettle();

    // Only the empty state is under test here; the plan-picker Row at the top
    // of the screen has a pre-existing HORIZONTAL overflow at these scales that
    // predates the date-range change and is out of scope.
    return reported.where((e) => e.contains('bottom')).toList();
  }

  // The three sizes the review measured a regression at, on the two plans whose
  // headers are tallest. Every one of these overflowed before the empty state
  // was made scrollable.
  const cases = <(String, Size, double, GoalType)>[
    ('iPhone 14 @ AX5, weekly', Size(390, 844), 3.1, GoalType.weekly),
    ('iPhone 14 @ AX5, quarterly', Size(390, 844), 3.1, GoalType.quarterly),
    ('iPhone SE zoomed @ 2.0, quarterly', Size(320, 568), 2.0, GoalType.quarterly),
    ('iPhone SE zoomed @ 2.0, weekly', Size(320, 568), 2.0, GoalType.weekly),
    ('iPhone SE @ AX5, quarterly', Size(375, 667), 3.1, GoalType.quarterly),
    ('iPhone SE @ AX5, monthly', Size(375, 667), 3.1, GoalType.monthly),
  ];

  for (final (name, size, scale, type) in cases) {
    testWidgets('empty state does not overflow — $name', (tester) async {
      final overflows = await overflowsFor(
        tester,
        size: size,
        textScale: scale,
        type: type,
      );
      expect(
        overflows,
        isEmpty,
        reason: 'vertical overflow at $name:\n${overflows.join('\n')}',
      );
    });
  }

  /// The scroll position of the empty state's own scroll view. Finding it by
  /// type is deliberate: if the fix is ever reverted to a bare Center this
  /// throws, which is exactly the kill these two tests exist for. An overflow
  /// assertion alone cannot do that — reverting the fix wedges the harness
  /// rather than reporting a clean failure.
  ScrollPosition emptyStateScroll(WidgetTester tester) {
    final view = find.byType(SingleChildScrollView);
    expect(
      view,
      findsOneWidget,
      reason: 'the empty state must stay scrollable, or it overflows at AX sizes',
    );
    return tester.widget<Scrollable>(
      find.descendant(of: view, matching: find.byType(Scrollable)),
    ).controller!.position;
  }

  testWidgets('at AX5 the content is taller than the page and can scroll to it', (
    tester,
  ) async {
    final overflows = await overflowsFor(
      tester,
      size: const Size(390, 844),
      textScale: 3.1,
      type: GoalType.quarterly,
    );
    expect(overflows, isEmpty);

    // The positive half of the guard: at this scale the icon + two paragraphs
    // genuinely do NOT fit the page the taller header leaves behind. Under the
    // old bare Center that surplus was a RenderFlex overflow; now it is scroll
    // extent, and every pixel of the copy remains reachable.
    expect(emptyStateScroll(tester).maxScrollExtent, greaterThan(0.0));
  });

  testWidgets('at ordinary text sizes nothing scrolls and it stays centred', (
    tester,
  ) async {
    final overflows = await overflowsFor(
      tester,
      size: const Size(390, 844),
      textScale: 1.0,
      type: GoalType.weekly,
    );
    expect(overflows, isEmpty);

    // ConstrainedBox(minHeight: viewport) preserves the old visual exactly: the
    // content is never taller than the page, so there is nothing to scroll and
    // the Center still has the full viewport to centre within. Asserting zero
    // extent is the whole property — a fitting page cannot be off-centre, since
    // Center is unchanged and its box is the viewport by construction.
    expect(emptyStateScroll(tester).maxScrollExtent, 0.0);
  });
}
