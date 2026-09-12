// The calendar day-detail dialog on a day older than yesterday.
//
// Those days used to be locked outright: the square rendered disabled under an
// "Only today and yesterday can be edited." hint, so a mis-scored day from last
// week could never be corrected — and a quantitative habit's square looked live
// and did nothing on ANY day (decisions file D2). Older days are now changed
// through an explicit Edit → Save flow, while today and yesterday keep the
// one-click toggle. These drive the real dialog through [showDayDetailsDialog]
// over a recording repository, and pin:
//
//   * view mode on an older day: a hint, an Edit button, an inert square;
//   * edit mode stages the same cycle a click performs; nothing is written
//     until Save, which commits the batch and repairs the changed streaks;
//   * Cancel drops the staging without asking; the X and Escape ask first when
//     there is something to lose;
//   * today still toggles on the click and offers no Edit;
//   * a verified habit stays read-only in edit mode (the freeze lives on the
//     iPhone), and a quantitative one opens the entry dialog for THAT day.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/calendar_days.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/habits/presentation/habits_page.dart';
import 'package:evolve_desktop/features/habits/presentation/target_entry_dialog.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/target_ring.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _RecordingRepository extends DashboardRepository {
  _RecordingRepository(this._snapshot);

  DashboardSnapshot _snapshot;
  final List<({String habitId, String date, String? landed})> statusWrites =
      [];
  final List<Set<String>> recomputes = [];

  @override
  DashboardSnapshot load() => _snapshot;

  /// Kept, like the real local cache: the controller's background refresh
  /// reloads from here, and a no-op save would hand the seed back over the
  /// optimistic state the test just observed.
  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<String?> setHabitStatus({
    required String habitId,
    required DateTime date,
    required String? currentStatus,
  }) async {
    final landed = await super.setHabitStatus(
      habitId: habitId,
      date: date,
      currentStatus: currentStatus,
    );
    statusWrites.add(
      (habitId: habitId, date: dashboardDateKey(date), landed: landed),
    );
    return landed;
  }

  @override
  Future<void> recomputeStreaks(Set<String> habitIds) async {
    recomputes.add(habitIds);
  }
}

void main() {
  // English copy is asserted below; `setLocale` is async because non-base
  // locales are deferred, and the base one is what we want anyway.
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final oldDay = shiftDays(today, -10);
  final oldKey = dashboardDateKey(oldDay);

  DashboardHabit habit(
    String id, {
    VerificationRule? rule,
    HabitTarget? target,
  }) =>
      DashboardHabit(
        id: id,
        title: id,
        color: EvolveColors.primaryStrong,
        streak: 0,
        weeklyProgress: const [false, false, false, false, false, false, false],
        state: HabitState.pending,
        startDate: DateTime(2020, 1, 1),
        verificationRule: rule,
        target: target,
      );

  DashboardSnapshot snapshot(
    List<DashboardHabit> habits, {
    Map<String, Map<String, String>> logs = const {},
  }) =>
      DashboardSnapshot(
        habits: habits,
        goals: const [],
        trend: const [],
        checkIn: const DailyCheckIn(),
        habitLogs: logs,
      );

  /// Opens the dialog for [date] as the real route, so the X, Escape, the
  /// barrier and `Navigator.maybePop` behave as on the desktop.
  Future<(ProviderContainer, _RecordingRepository)> open(
    WidgetTester tester,
    DashboardSnapshot seed,
    DateTime date,
  ) async {
    final repo = _RecordingRepository(seed);
    final container = ProviderContainer(
      overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: EvolveTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showDayDetailsDialog(context, date),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (container, repo);
  }

  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');
  Finder editButton() => find.widgetWithText(TextButton, 'Edit');
  Finder cancelButton() => find.widgetWithText(TextButton, 'Cancel');
  // The row's control for a 'done' square: the header X is also a LucideIcons.x,
  // so the check glyph is the unambiguous handle.
  Finder doneSquare() => find.byIcon(LucideIcons.check);

  testWidgets('an older day opens in view mode: hint, Edit, inert square',
      (tester) async {
    final (_, repo) = await open(
      tester,
      snapshot([habit('Read')], logs: {
        oldKey: {'Read': 'done'},
      }),
      oldDay,
    );

    expect(find.text('Use Edit to change this day.'), findsOneWidget);
    expect(editButton(), findsOneWidget);
    expect(saveButton(), findsNothing);
    // Drawn disabled, and a click on it changes nothing.
    expect(
      find.ancestor(of: doneSquare(), matching: find.byType(Opacity)),
      findsOneWidget,
    );
    await tester.tap(doneSquare());
    await tester.pumpAndSettle();
    expect(repo.statusWrites, isEmpty);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('edit mode stages the cycle; Save writes the staged rows and '
      'repairs the streaks of exactly those habits', (tester) async {
    final (container, repo) = await open(
      tester,
      snapshot([habit('Read'), habit('Run')], logs: {
        oldKey: {'Read': 'done'},
      }),
      oldDay,
    );

    await tester.tap(editButton());
    await tester.pumpAndSettle();
    expect(find.text('Use Edit to change this day.'), findsNothing);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull,
        reason: 'nothing staged yet');

    // Read: done → missed. Run: none → done. Staged, not written.
    await tester.tap(doneSquare());
    await tester.pumpAndSettle();
    expect(find.text('Skipped'), findsOneWidget);
    // Run's square is the remaining empty one; the row is found by its title
    // and the control is the row's only GestureDetector.
    final runRow = find.ancestor(
      of: find.text('Run'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: runRow.first, matching: find.byType(GestureDetector)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(repo.statusWrites, isEmpty);
    expect(
      container.read(dashboardControllerProvider).habitStatusFor('Read', oldDay),
      'done',
      reason: 'staged only',
    );

    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    expect(
      {for (final w in repo.statusWrites) w.habitId: w.landed},
      {'Read': 'missed', 'Run': 'done'},
    );
    expect(repo.statusWrites.every((w) => w.date == oldKey), isTrue);
    expect(repo.recomputes, [
      {'Read', 'Run'},
    ]);
    final state = container.read(dashboardControllerProvider);
    expect(state.habitStatusFor('Read', oldDay), 'missed');
    expect(state.habitStatusFor('Run', oldDay), 'done');
    // Back in view mode, dialog still open, the batch acknowledged.
    expect(find.text('Changes saved'), findsOneWidget);
    expect(editButton(), findsOneWidget);
    expect(saveButton(), findsNothing);
  });

  testWidgets('Cancel drops the staging without asking', (tester) async {
    final (_, repo) = await open(
      tester,
      snapshot([habit('Read')], logs: {
        oldKey: {'Read': 'done'},
      }),
      oldDay,
    );
    await tester.tap(editButton());
    await tester.pumpAndSettle();
    await tester.tap(doneSquare());
    await tester.pumpAndSettle();
    expect(find.text('Skipped'), findsOneWidget);

    await tester.tap(cancelButton());
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Completed'), findsOneWidget, reason: 'back to persisted');
    expect(editButton(), findsOneWidget);
    expect(repo.statusWrites, isEmpty);
  });

  testWidgets('the X and Escape ask before discarding staged changes',
      (tester) async {
    final (_, repo) = await open(
      tester,
      snapshot([habit('Read')], logs: {
        oldKey: {'Read': 'done'},
      }),
      oldDay,
    );
    await tester.tap(editButton());
    await tester.pumpAndSettle();
    await tester.tap(doneSquare());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(saveButton(), findsOneWidget, reason: 'still editing');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(saveButton(), findsNothing, reason: 'the dialog is gone');
    expect(find.text('Use Edit to change this day.'), findsNothing);
    expect(repo.statusWrites, isEmpty);
  });

  testWidgets('a clean dialog closes on Escape with no question',
      (tester) async {
    await open(tester, snapshot([habit('Read')]), oldDay);
    await tester.tap(editButton());
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(saveButton(), findsNothing);
  });

  testWidgets('today is a quick-log day: the click toggles at once and there '
      'is no Edit', (tester) async {
    final (container, repo) = await open(
      tester,
      snapshot([habit('Read')]),
      today,
    );

    expect(editButton(), findsNothing);
    expect(find.text('Use Edit to change this day.'), findsNothing);
    // The pending square carries no glyph; the row's control is its only
    // GestureDetector.
    final row = find.ancestor(of: find.text('Read'), matching: find.byType(Row));
    await tester.tap(
      find.descendant(of: row.first, matching: find.byType(GestureDetector)),
    );
    await tester.pumpAndSettle();

    expect(repo.statusWrites, hasLength(1));
    expect(repo.statusWrites.single.landed, 'done');
    expect(
      container.read(dashboardControllerProvider).habitStatusFor('Read', today),
      'done',
    );
  });

  testWidgets('a quantitative habit is inert in view mode and opens the entry '
      'dialog for THAT day in edit mode (D2)', (tester) async {
    final target =
        TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);
    final (_, repo) = await open(
      tester,
      snapshot([habit('Push-ups', target: target)]),
      oldDay,
    );
    expect(find.byType(TargetRing), findsOneWidget);

    // View mode: the ring is drawn, and a click on it opens nothing. This is
    // the square that used to look live and silently do nothing.
    await tester.tap(find.byType(TargetRing));
    await tester.pumpAndSettle();
    expect(find.byType(TargetEntryDialog), findsNothing);

    await tester.tap(editButton());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TargetRing));
    await tester.pumpAndSettle();

    final entry = tester.widget<TargetEntryDialog>(
      find.byType(TargetEntryDialog),
    );
    expect(entry.date, oldDay,
        reason: 'the number belongs to the day on screen, not to today');
    expect(repo.statusWrites, isEmpty,
        reason: 'the entry dialog commits on its own; nothing is staged');
  });

  testWidgets('a verified habit stays read-only in edit mode', (tester) async {
    const rule = VerificationRule(
      provider: VerificationProvider.healthKit,
      metricKey: 'steps',
      comparator: VerificationComparator.atLeast,
      threshold: 8000,
      unit: VerificationUnit.count,
    );
    final (_, repo) = await open(
      tester,
      snapshot([habit('Auto', rule: rule)], logs: {
        oldKey: {'Auto': 'done'},
      }),
      oldDay,
    );
    await tester.tap(editButton());
    await tester.pumpAndSettle();

    expect(
      find.ancestor(of: doneSquare(), matching: find.byType(Opacity)),
      findsOneWidget,
      reason: 'the verdict is the iPhone\'s; a Mac cannot record the freeze',
    );
    await tester.tap(doneSquare());
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
    expect(repo.statusWrites, isEmpty);
  });
}
