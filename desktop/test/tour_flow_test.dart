// End-to-end continuity test for the guided tour. Drives the REAL
// TourController + REAL CoachTutorialOverlay through all five segments by
// tapping the actual Continue/Finish buttons, asserting the navigation hands
// off Overview → Habits → Insights → Goals → Coach, then completes and returns
// to Overview. Uses lightweight stub pages that mirror the real page wiring
// (the real pages' spotlight targets are verified on-device); the point here is
// the cross-page continuity that the old per-page implementation lacked.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/coach_tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the real page pattern: renders the shared overlay when its segment
/// is active; the last step advances (or, on Coach, completes + returns home).
class _StubSegmentPage extends ConsumerStatefulWidget {
  const _StubSegmentPage(this.segment, {super.key});
  final TourSegment segment;
  @override
  ConsumerState<_StubSegmentPage> createState() => _StubSegmentPageState();
}

class _StubSegmentPageState extends ConsumerState<_StubSegmentPage> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final show = ref
        .watch(tourControllerProvider)
        .isSegmentActive(widget.segment);
    final isCoach = widget.segment == TourSegment.coach;
    return Stack(
      children: [
        Center(child: Text('page-${widget.segment.name}')),
        if (show)
          CoachTutorialOverlay(
            steps: const [
              CoachStep(title: 'a', description: 'da'),
              CoachStep(title: 'b', description: 'db'),
            ],
            index: _i,
            onIndexChanged: (v) => setState(() => _i = v),
            onFinish: () async {
              final tour = ref.read(tourControllerProvider.notifier);
              if (isCoach) {
                await tour.complete();
                ref
                    .read(navigationControllerProvider.notifier)
                    .select(DesktopSection.overview);
              } else {
                await tour.advance();
              }
            },
            backLabel: t.tour.back,
            nextLabel: t.tour.next,
            finishLabel: isCoach ? t.tour.finish : t.tour.continueLabel,
          ),
      ],
    );
  }
}

class _StubShell extends ConsumerWidget {
  const _StubShell();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(navigationControllerProvider);
    final seg = TourSegment.values.firstWhere(
      (s) => s.section == section,
      orElse: () => TourSegment.overview,
    );
    return MaterialApp(
      theme: EvolveTheme.dark(),
      home: Scaffold(
        // Keyed by segment so each page gets fresh step state on hand-off,
        // exactly like the shell's KeyedSubtree(key: ValueKey(section)).
        body: _StubSegmentPage(seg, key: ValueKey(seg)),
      ),
    );
  }
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  testWidgets('drives the whole tour across pages and ends on Overview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _StubShell(),
      ),
    );

    // Start the tour (as the welcome dialog's "Start tour" does).
    container.read(tourControllerProvider.notifier).activate();
    await tester.pumpAndSettle();
    expect(
      container.read(navigationControllerProvider),
      DesktopSection.overview,
    );
    expect(find.text('page-overview'), findsOneWidget);

    // Each segment has 2 steps: "Avanti" (next) then "Continua" (advance).
    const handoffs = [
      DesktopSection.habits,
      DesktopSection.insights,
      DesktopSection.goals,
      DesktopSection.coach,
    ];
    for (final expected in handoffs) {
      await tester.tap(find.text('Avanti'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(
        container.read(navigationControllerProvider),
        expected,
        reason: 'hand-off should land on ${expected.name}',
      );
      expect(container.read(tourControllerProvider).completed, isFalse);
    }

    // On Coach (final): "Avanti" then "Fine" completes and returns to Overview.
    expect(find.text('page-coach'), findsOneWidget);
    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fine'));
    await tester.pumpAndSettle();

    final s = container.read(tourControllerProvider);
    expect(s.completed, isTrue);
    expect(s.active, isFalse);
    expect(
      container.read(navigationControllerProvider),
      DesktopSection.overview,
    );
    expect(
      container.read(navigationControllerProvider.notifier).isLocked,
      isFalse,
    );
  });
}
