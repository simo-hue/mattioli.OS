// Desktop target UI: the create/edit preset picker (TargetField) and the
// increment entry dialog (TargetEntryDialog) driving the real controller.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/habits/presentation/target_entry_dialog.dart';
import 'package:evolve_desktop/features/habits/presentation/target_field.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/target_ring.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class _Repo extends DashboardRepository {
  _Repo(this._snapshot);
  DashboardSnapshot _snapshot;
  final List<Map<String, Object?>> progressCalls = [];
  @override
  DashboardSnapshot load() => _snapshot;
  @override
  Future<void> save(DashboardSnapshot snapshot) async => _snapshot = snapshot;
  @override
  Future<void> setHabitProgress({
    required String habitId,
    required DateTime date,
    required double amount,
    required String? derivedStatus,
    required int streak,
  }) async =>
      progressCalls.add({'amount': amount, 'status': derivedStatus});
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  group('TargetField', () {
    Widget fieldHarness(ValueChanged<HabitTarget?> onChanged,
            {HabitTarget? initial}) =>
        ProviderScope(
          child: MaterialApp(
            theme: EvolveTheme.dark(),
            home: Scaffold(
              body: _FieldHost(onChanged: onChanged, initial: initial),
            ),
          ),
        );

    testWidgets('choosing Count emits a manual count target + stepper',
        (tester) async {
      HabitTarget? emitted;
      await tester.pumpWidget(fieldHarness((t) => emitted = t));
      await tester.tap(find.text('Count'));
      await tester.pumpAndSettle();
      expect(emitted!.fillSource, TargetFillSource.manual);
      expect(emitted!.direction, TargetDirection.atLeast);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('the stepper bumps by the preset step', (tester) async {
      HabitTarget? emitted;
      await tester.pumpWidget(fieldHarness((t) => emitted = t));
      await tester.tap(find.text('Count'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(emitted!.amount, 11); // default 10 + step 1
    });

    testWidgets('Simple clears the target', (tester) async {
      HabitTarget? emitted;
      await tester.pumpWidget(fieldHarness((t) => emitted = t));
      await tester.tap(find.text('Limit'));
      await tester.pumpAndSettle();
      expect(emitted, isNotNull);
      await tester.tap(find.text('Simple'));
      await tester.pumpAndSettle();
      expect(emitted, isNull);
    });
  });

  group('TargetEntryDialog', () {
    final target =
        TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);
    final habit = DashboardHabit(
      id: 'h1',
      title: 'Push-ups',
      color: EvolveColors.primaryStrong,
      streak: 0,
      weeklyProgress: const [false, false, false, false, false, false, false],
      state: HabitState.pending,
      startDate: DateTime(2026, 7, 1),
      target: target,
    );

    Widget dialogHarness(_Repo repo) => ProviderScope(
          overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: EvolveTheme.dark(),
            home: Scaffold(
              body: TargetEntryDialog(
                habit: habit,
                target: target,
                date: DateTime.now(),
              ),
            ),
          ),
        );

    testWidgets('the + button increments and persists', (tester) async {
      final repo = _Repo(DashboardSnapshot(
        habits: [habit],
        goals: const [],
        trend: const [],
        checkIn: const DailyCheckIn(),
      ));
      await tester.pumpWidget(dialogHarness(repo));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pumpAndSettle();
      expect(find.text('20'), findsOneWidget);
      expect(repo.progressCalls.last['amount'], 20);
    });

    testWidgets('exposes increment/decrement accessibility actions',
        (tester) async {
      final repo = _Repo(DashboardSnapshot(
        habits: [habit],
        goals: const [],
        trend: const [],
        checkIn: const DailyCheckIn(),
      ));
      await tester.pumpWidget(dialogHarness(repo));
      await tester.pumpAndSettle();

      var inc = false, dec = false;
      void visit(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.hasAction(SemanticsAction.increase)) inc = true;
        if (d.hasAction(SemanticsAction.decrease)) dec = true;
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      // The documented replacement (RendererBinding.rootPipelineOwner) exposes
      // no semanticsOwner in the test binding, so this stays until the
      // semantics API settles.
      // ignore: deprecated_member_use
      visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
      expect(inc, isTrue);
      expect(dec, isTrue);
    });
  });

  test('formatTargetAmount trims trailing .0', () {
    expect(formatTargetAmount(5), '5');
    expect(formatTargetAmount(0.5), '0.5');
  });
}

class _FieldHost extends StatefulWidget {
  const _FieldHost({required this.onChanged, this.initial});
  final ValueChanged<HabitTarget?> onChanged;
  final HabitTarget? initial;
  @override
  State<_FieldHost> createState() => _FieldHostState();
}

class _FieldHostState extends State<_FieldHost> {
  HabitTarget? target;
  @override
  void initState() {
    super.initState();
    target = widget.initial;
  }

  @override
  Widget build(BuildContext context) => TargetField(
        target: target,
        onChanged: (t) {
          setState(() => target = t);
          widget.onChanged(t);
        },
      );
}
