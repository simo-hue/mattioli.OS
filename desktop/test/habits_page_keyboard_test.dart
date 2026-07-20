// Verifies the desktop Habits page calendar keyboard navigation: on the
// Calendar surface, ← / → page the period (month/week/year) exactly like the
// ‹ › buttons, and each change plays a transition.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/habits/presentation/habits_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyDashboardRepository extends DashboardRepository {
  @override
  DashboardSnapshot load() => DashboardSnapshot.empty;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {}
}

/// The calendar's day cells run an endless pulse (the "today" / active-day glow
/// in `_DayCell`), so `pumpAndSettle` never settles on the Calendar surface —
/// same reason the overview check-in tile is pumped by hand in `widget_test`.
/// Pump a fixed budget of frames instead; it comfortably covers the period
/// slide/fade transition.
Future<void> _settleFrames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pumpHabitsPage(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          _EmptyDashboardRepository(),
        ),
      ],
      child: MaterialApp(
        theme: EvolveTheme.dark(),
        home: const Scaffold(body: HabitsPage()),
      ),
    ),
  );
  await _settleFrames(tester);
}

/// Switches to the Calendar surface, Month view.
Future<void> _openMonthCalendar(WidgetTester tester) async {
  await tester.tap(find.text(t.habitsPage.tabCalendar));
  await _settleFrames(tester);
  await tester.tap(find.text(t.common.calendarView.month));
  await _settleFrames(tester);
}

void main() {
  testWidgets('→ pages to the next month on the calendar surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpHabitsPage(tester);
    await _openMonthCalendar(tester);

    final now = DateTime.now();
    final thisMonth = t.common.months[now.month - 1];
    final next = DateTime(now.year, now.month + 1, 1);
    final nextMonth = t.common.months[next.month - 1];

    expect(find.text(thisMonth), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settleFrames(tester);

    expect(find.text(nextMonth), findsWidgets);
    expect(find.text(thisMonth), findsNothing);

    // ← returns to the starting month.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _settleFrames(tester);
    expect(find.text(thisMonth), findsWidgets);
  });

  testWidgets('arrows are inert on the Protocol surface', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpHabitsPage(tester);
    // Default surface is Protocol; switch to Calendar+Month only to learn the
    // current month label, then go back to Protocol.
    await _openMonthCalendar(tester);
    final now = DateTime.now();
    final thisMonth = t.common.months[now.month - 1];
    await tester.tap(find.text(t.habitsPage.tabProtocol));
    await _settleFrames(tester);

    // On Protocol, arrows must not page the (hidden) calendar period.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _settleFrames(tester);

    await tester.tap(find.text(t.habitsPage.tabCalendar));
    await _settleFrames(tester);
    expect(
      find.text(thisMonth),
      findsWidgets,
      reason: 'the period must be unchanged — arrows are calendar-only',
    );
  });
}
