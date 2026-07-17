// The weekly-frequency picker in the (now consolidated) habit editor must not
// be inert: a habit created via the editor has to persist the picked
// `frequency_days`, and an untouched all-7 selection has to collapse to null
// (the every-day encoding both platforms' scheduled-day guards read). These
// tests drive the real public entry point [showCreateHabitDialog] so the whole
// editor → controller → repository chain is covered, not the controller alone.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/habits/presentation/habits_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // These tests tap the Italian CTA copy; pin the slang locale to Italian.
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  Widget harness(DashboardRepository repository) => ProviderScope(
    overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: EvolveTheme.dark(),
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          // `navigateToHabits: false` keeps the create flow self-contained (no
          // navigation provider needed) — the same path the dashboard "+" uses.
          body: FilledButton(
            onPressed: () =>
                showCreateHabitDialog(context, ref, navigateToHabits: false),
            child: const Text('Apri'),
          ),
        ),
      ),
    ),
  );

  // The 7 weekday chips are the only InkWells wrapping an AnimatedContainer (the
  // color picker uses GestureDetector). Locating them positionally is required:
  // `weekdayInitials` is ['L','M','M','G','V','S','D'] in Italian, so 'M' does
  // not identify a single chip.
  final chips = find.byWidgetPredicate(
    (widget) => widget is InkWell && widget.child is AnimatedContainer,
  );

  Future<void> openDialog(WidgetTester tester, DashboardRepository repo) async {
    await tester.pumpWidget(harness(repo));
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    expect(chips, findsNWidgets(7));
  }

  testWidgets('the weekly frequency picked in the editor reaches the '
      'repository', (tester) async {
    final repository = _RecordingDashboardRepository();
    await openDialog(tester, repository);

    // The title field is the first TextField (the reminder field is read-only).
    await tester.enterText(find.byType(TextField).first, 'Palestra');
    // All 7 start selected; deselect Tue/Thu/Sat/Sun to leave Mon/Wed/Fri.
    for (final index in [1, 3, 5, 6]) {
      await tester.tap(chips.at(index));
      await tester.pump();
    }
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    final created = repository.created;
    expect(created, isNotNull);
    expect(created!.title, 'Palestra');
    // ISO weekdays, sorted — the canonical shared-schema shape (1 = Monday).
    expect(created.frequencyDays, [1, 3, 5]);
  });

  testWidgets('an untouched picker still stores every-day as null', (
    tester,
  ) async {
    final repository = _RecordingDashboardRepository();
    await openDialog(tester, repository);

    await tester.enterText(find.byType(TextField).first, 'Lettura');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    // All 7 selected must not write [1..7]: null is the every-day encoding the
    // scheduled-day guards on both platforms read.
    expect(repository.created, isNotNull);
    expect(repository.created!.frequencyDays, isNull);
  });
}

class _RecordingDashboardRepository extends DashboardRepository {
  DashboardSnapshot _snapshot = DashboardSnapshot.empty;

  /// The habit handed to the persistence layer by the last [createHabit].
  DashboardHabit? created;

  @override
  DashboardSnapshot load() => _snapshot;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<DashboardHabit> createHabit(DashboardHabit habit) async {
    created = habit;
    return habit;
  }
}
