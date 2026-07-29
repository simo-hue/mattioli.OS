// The Overview page's "AI Chat" quick-action tile must gate the AI Coach
// exactly like the sidebar entry and ⌘5 do: in account mode the coach is
// Pro-only, so a free account gets the upsell instead of the page. It shipped
// ungated when the mobile PROTOCOLLO strip was ported, which is the regression
// this test exists to catch.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/clock.dart';
import 'package:evolve_desktop/features/ai_coach/application/coach_controllers.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/dashboard/presentation/dashboard_page.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The page only needs an (empty) snapshot to render its quick-action strip.
class _EmptyDashboardRepository extends DashboardRepository {
  @override
  DashboardSnapshot load() => DashboardSnapshot.empty;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {}
}

Future<ProviderContainer> _pumpDashboard(
  WidgetTester tester, {
  required bool gated,
}) async {
  final container = ProviderContainer(
    overrides: [
      dashboardRepositoryProvider.overrideWithValue(_EmptyDashboardRepository()),
      // The controller's unawaited refresh tail reads the clock; pin it so this
      // test can never depend on the day it runs.
      clockProvider.overrideWithValue(() => DateTime(2026, 7, 28, 9)),
      coachNeedsPaywallProvider.overrideWith((ref) => gated),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: EvolveTheme.dark(),
        home: const Scaffold(body: DashboardPage()),
      ),
    ),
  );
  // NOT pumpAndSettle: the Daily check-in tile pulses with `repeat(reverse:
  // true)` whenever today's check-in is missing, so this tree never settles.
  await _pumpFrames(tester);
  return container;
}

/// Advances enough frames for entry animations and the dialog route to appear,
/// without waiting for a tree that is animating forever.
Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('a paywalled account gets the Pro upsell, not the Coach', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = await _pumpDashboard(tester, gated: true);

    await tester.tap(find.text(t.dashboard.aiChat));
    await _pumpFrames(tester);

    expect(find.text(t.proModal.title), findsOneWidget);
    expect(
      container.read(navigationControllerProvider),
      DesktopSection.overview,
      reason: 'the tile must not navigate while the coach is Pro-gated',
    );
  });

  testWidgets('an entitled user reaches the Coach from the tile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = await _pumpDashboard(tester, gated: false);

    await tester.tap(find.text(t.dashboard.aiChat));
    await _pumpFrames(tester);

    expect(find.text(t.proModal.title), findsNothing);
    expect(
      container.read(navigationControllerProvider),
      DesktopSection.coach,
    );
  });
}
