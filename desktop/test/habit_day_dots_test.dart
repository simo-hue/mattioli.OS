// The habit dot strip itself, and its two surfaces: the dashboard's "Today's
// protocol" row and the Habits › Protocol table. Both must end the strip on
// TODAY — the point of the window — and neither may let a click on a history
// mark reach the row's toggle.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/clock.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/dashboard/presentation/dashboard_page.dart';
import 'package:evolve_desktop/features/habits/presentation/habits_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/habit_day_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tuesday of the week AFTER Europe/Rome's 2026 fall-back, so the rendered
/// window straddles the transition on the maintainer's own machine.
final _today = DateTime(2026, 10, 27);

class _Repo extends DashboardRepository {
  _Repo(this._snapshot);
  DashboardSnapshot _snapshot;
  final List<String> toggled = [];

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<void> save(DashboardSnapshot snapshot) async => _snapshot = snapshot;

  @override
  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) async {
    toggled.add(habitId);
    return super.setHabitStatus(
      habitId: habitId,
      date: date,
      currentStatus: currentStatus,
    );
  }
}

DashboardSnapshot _snapshot() => DashboardSnapshot(
  habits: [
    DashboardHabit(
      id: 'h1',
      title: 'Read',
      color: EvolveColors.primaryStrong,
      streak: 2,
      // Left false throughout: this suite asserts on the log-derived window, and
      // a true here would let the current-week fallback (which reads the real
      // wall clock, not the pinned one) colour a mark behind the test's back.
      weeklyProgress: List.filled(7, false),
      state: HabitState.completed,
    ),
  ],
  goals: const [],
  trend: const [],
  checkIn: const DailyCheckIn(),
  habitLogs: {
    dashboardDateKey(DateTime(2026, 10, 21)): {'h1': 'done'},
    dashboardDateKey(DateTime(2026, 10, 24)): {'h1': 'missed'},
    dashboardDateKey(DateTime(2026, 10, 27)): {'h1': 'done'},
    // Outside the window — must not appear.
    dashboardDateKey(DateTime(2026, 10, 20)): {'h1': 'done'},
  },
);

/// The pulsing calendar cells and check-in tile never let `pumpAndSettle`
/// finish, so pump a fixed budget of frames (see widget_test).
Future<void> _settleFrames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<_Repo> _pumpPage(WidgetTester tester, Widget page) async {
  final repo = _Repo(_snapshot());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(() => _today),
      ],
      child: MaterialApp(
        theme: EvolveTheme.dark(),
        home: Scaffold(body: page),
      ),
    ),
  );
  await _settleFrames(tester);
  return repo;
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  group('HabitDayDots', () {
    Future<void> pumpStrip(
      WidgetTester tester,
      List<String?> statuses, {
      VoidCallback? onRowTap,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: EvolveTheme.dark(),
        home: Scaffold(
          body: Center(
            child: InkWell(
              onTap: onRowTap ?? () {},
              child: HabitDayDots(
                statuses: statuses,
                dates: habitWindowDays(_today, days: statuses.length),
                accent: EvolveColors.cyan,
                size: 18,
                gap: 8,
                borderRadius: 5,
              ),
            ),
          ),
        ),
      ),
    );

    /// The filled squares — one per day. The today halo is a separate, unfilled
    /// container, so it is deliberately excluded here.
    Finder fills = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          (widget.decoration as BoxDecoration?)?.color != null,
    );

    /// The today halo: bordered, unfilled.
    Finder halo = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          (widget.decoration as BoxDecoration?)?.color == null &&
          (widget.decoration as BoxDecoration?)?.border != null,
    );

    List<Color?> fillColors(WidgetTester tester) => tester
        .widgetList<Container>(fills)
        .map((container) => (container.decoration! as BoxDecoration).color)
        .toList();

    testWidgets('paints one mark per day, done / missed / unrecorded apart', (
      tester,
    ) async {
      await pumpStrip(tester, const ['done', 'missed', null]);

      final painted = fillColors(tester);
      expect(painted, hasLength(3));
      expect(painted[0], EvolveColors.cyan);
      expect(painted[1], EvolveColors.destructive);
      expect(
        painted[2],
        isNot(anyOf(EvolveColors.cyan, EvolveColors.destructive)),
        reason: 'an unrecorded day must not read as either outcome',
      );
    });

    testWidgets('haloes only the last mark — the day the user is living in', (
      tester,
    ) async {
      await pumpStrip(tester, const ['done', 'done', 'done']);

      expect(halo, findsOneWidget);
      expect(
        find.descendant(of: halo, matching: fills),
        findsOneWidget,
        reason: 'the halo must wrap TODAY, i.e. the final mark',
      );
      expect(tester.getCenter(fills.last).dx, tester.getCenter(halo).dx);
    });

    testWidgets('today\'s mark is haloed, not shrunk', (tester) async {
      // A Border is painted INSIDE its box: ringing the fill itself cost an
      // eighth of an 8 px dot, and with borderStrong darker than every filled
      // state the result read as "today's dot is smaller", not "ringed".
      await pumpStrip(tester, const ['done', 'missed', 'done']);

      final sizes = [
        for (var i = 0; i < 3; i++) tester.getSize(fills.at(i)),
      ];
      expect(sizes, everyElement(const Size(18, 18)));
      expect(tester.getSize(halo), const Size(22, 22));
    });

    testWidgets('a mark swallows the click instead of toggling today', (
      tester,
    ) async {
      var rowTaps = 0;
      await pumpStrip(
        tester,
        const ['done', 'missed', null],
        onRowTap: () => rowTaps++,
      );

      await tester.tap(find.byType(HabitDayDots));
      await tester.pump();

      expect(
        rowTaps,
        0,
        reason: 'clicking Wednesday\'s mark used to mark TODAY done',
      );
    });

    testWidgets('names today as today, and every other mark by its date', (
      tester,
    ) async {
      await pumpStrip(tester, const ['done', null, 'missed']);

      final messages = tester
          .widgetList<Tooltip>(
            find.descendant(
              of: find.byType(HabitDayDots),
              matching: find.byType(Tooltip),
            ),
          )
          .map((tooltip) => tooltip.message)
          .toList();

      expect(
        messages.last,
        t.habitsPage.dayDotTooltipToday(status: t.habitsPage.statusSkipped),
      );
      expect(
        messages.first,
        t.habitsPage.dayDotTooltip(
          day: 25,
          month: t.common.months[9],
          status: t.habitsPage.statusDone,
        ),
      );
    });
  });

  group('surfaces', () {
    void expectWindowEndsToday(WidgetTester tester) {
      final strip = tester.widget<HabitDayDots>(
        find.byType(HabitDayDots).first,
      );

      expect(strip.dates.last, _today, reason: 'the last mark must be today');
      expect(strip.statuses, hasLength(7));
      expect(strip.statuses.last, 'done', reason: "today's own check-in");
      expect(strip.statuses.first, 'done', reason: '21 Oct opens the window');
      expect(strip.statuses[3], 'missed', reason: '24 Oct');
      expect(
        strip.statuses.where((status) => status != null),
        hasLength(3),
        reason: '20 Oct falls outside the window and must not be shown',
      );
    }

    testWidgets('the dashboard protocol row ends on today', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpPage(tester, const DashboardPage());

      expectWindowEndsToday(tester);
    });

    testWidgets('the Habits protocol table ends on today', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpPage(tester, const HabitsPage());

      expectWindowEndsToday(tester);
    });

    testWidgets('a click on a mark writes nothing through the real row', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = await _pumpPage(tester, const DashboardPage());
      await tester.tap(find.byType(HabitDayDots).first);
      await _settleFrames(tester);

      expect(repo.toggled, isEmpty);
    });
  });
}
