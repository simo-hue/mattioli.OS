import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/ui/widgets/yearly_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The month bars sit under a `RepaintBoundary`, so their layer is only
/// refreshed when `shouldRepaint` says so. A theme toggle changes the painter's
/// colours without touching year/month/habits/logs, which is exactly the case
/// the painter has to notice.
class _EmptyGoals extends GoalsNotifier {
  @override
  List<Goal> build() => const [];
}

class _EmptyLogs extends HabitLogsNotifier {
  @override
  HabitLogsMap build() => const {};
}

void main() {
  Widget app(ThemeData theme) => ProviderScope(
    overrides: [
      goalsProvider.overrideWith(_EmptyGoals.new),
      habitLogsProvider.overrideWith(_EmptyLogs.new),
    ],
    child: MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: SizedBox(height: 700, width: 380, child: YearlyViewWidget()),
      ),
    ),
  );

  /// The 12 `_MonthBarsPainter`s, picked out of the Material widgets' own
  /// CustomPaints by runtime type (the class is library-private).
  List<CustomPainter> monthBarPainters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((c) => c.painter)
      .whereType<CustomPainter>()
      .where((p) => p.runtimeType.toString() == '_MonthBarsPainter')
      .toList();

  testWidgets('month bars repaint when the theme brightness changes', (
    tester,
  ) async {
    await tester.pumpWidget(app(AppTheme.darkTheme(null)));
    await tester.pumpAndSettle();

    final dark = monthBarPainters(tester);
    expect(dark, hasLength(12));

    await tester.pumpWidget(app(AppTheme.lightTheme(null)));
    await tester.pumpAndSettle();

    final light = monthBarPainters(tester);
    expect(light, hasLength(12));

    for (var i = 0; i < light.length; i++) {
      expect(
        light[i].shouldRepaint(dark[i]),
        isTrue,
        reason: 'month ${i + 1} kept the dark theme\'s bar colours',
      );
    }
  });

  testWidgets('month bars do not repaint when nothing they paint changed', (
    tester,
  ) async {
    final theme = AppTheme.darkTheme(null);

    await tester.pumpWidget(app(theme));
    await tester.pumpAndSettle();
    final first = monthBarPainters(tester);

    await tester.pumpWidget(app(theme));
    await tester.pumpAndSettle();
    final second = monthBarPainters(tester);

    for (var i = 0; i < second.length; i++) {
      expect(
        second[i].shouldRepaint(first[i]),
        isFalse,
        reason: 'month ${i + 1} repainted despite an unchanged month',
      );
    }
  });
}
