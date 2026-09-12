// F24 — the Info tab's Positive / Negative correlation carousels could never
// render.
//
// _CorrelationsSection watches habitCorrelationsProvider(goalId) — a PER-GOAL
// query — and then kept only the rows whose `goal_id` equals that same goal.
// But `get_habit_correlations` selects other_goal_id INTO the returned goal_id
// column (`WHERE gl2.goal_id != p_target_goal_id`), and the private mirror skips
// `goalId == targetGoalId`, so the target is precisely the one id that can never
// appear there. The filter was always empty and both sections returned
// SizedBox.shrink() with no empty state. Had a row ever matched,
// `item['other_goal_id'] as String` would have thrown on a null cast — the key
// does not exist in either payload.
//
// The correct sibling consumer of the SAME provider,
// habit_overview_tab_widget.dart, reads item['goal_id'] as the other goal.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/ui/widgets/statistics/info_tab_widget.dart';

final _goals = [
  Goal(
    id: 'h1',
    title: 'Correre',
    color: Colors.blue,
    startDate: DateTime.utc(2026, 1, 1),
  ),
  Goal(
    id: 'h2',
    title: 'Leggere',
    color: Colors.green,
    startDate: DateTime.utc(2026, 1, 1),
  ),
  Goal(
    id: 'h3',
    title: 'Meditare',
    color: Colors.orange,
    startDate: DateTime.utc(2026, 1, 1),
  ),
];

class _Goals extends GoalsNotifier {
  @override
  List<Goal> build() => _goals;
}

class _EmptyLogs extends HabitLogsNotifier {
  @override
  HabitLogsMap build() => const {};
}

Map<String, dynamic> _stat(String id, double rate) => {
      'goal_id': id,
      'title': _goals.firstWhere((g) => g.id == id).title,
      'rate': rate,
      'current_streak': 3,
      'best_streak': 5,
      'total_completions': 10,
      'total_active_days': 20,
      'missed_days': 2,
    };

/// Rows exactly as both backends emit them: `goal_id` is the OTHER habit, and
/// there is no `other_goal_id` key at all.
const _correlations = <Map<String, dynamic>>[
  {'goal_id': 'h2', 'together_count': 12, 'percentage': 80},
  {'goal_id': 'h3', 'together_count': 1, 'percentage': 10},
];

/// Loads the bundled Inter faces. flutter_test's default font is a fixed-width
/// block whose metrics are fiction (~2x too wide), so a card sized for real text
/// "overflows" under it. Must run in setUpAll: real file I/O never completes
/// inside a testWidgets fake-async zone.
Future<void> _loadInter() async {
  final dir = Directory('assets/fonts');
  if (!dir.existsSync()) return;
  for (final face in dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.ttf'))) {
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
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  testWidgets('the correlation carousels render the other habit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goalsProvider.overrideWith(_Goals.new),
          habitLogsProvider.overrideWith(_EmptyLogs.new),
          habitStatsProvider.overrideWith((ref) async => [_stat('h1', 90)]),
          globalCriticalDayProvider.overrideWith((ref) async => 'Monday'),
          allHabitCorrelationsProvider.overrideWith(
              (ref) async => const <Map<String, dynamic>>[]),
          habitCorrelationsProvider
              .overrideWith((ref, goalId) async => _correlations),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            theme: AppTheme.darkTheme(null),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: AppLocaleUtils.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(
              body: SingleChildScrollView(child: InfoTabWidget()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(t.statistics.positiveCorrelations), findsOneWidget,
        reason: 'the section filtered on a column that never holds the target '
            'goal, so it always collapsed to SizedBox.shrink()');
    expect(find.text(t.statistics.negativeCorrelations), findsOneWidget);
    // The >= 50 row goes to the positive carousel, the < 50 one to the negative.
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    // The other habit's name is read off `goal_id`, like the sibling consumer.
    expect(find.text('Leggere'), findsWidgets);
    expect(find.text('Meditare'), findsWidgets);
  });
}
