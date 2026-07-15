// Guards the desktop Goals page quick-add composer: the text the user types to
// create a goal must sit on the vertical centerline of its 44px pill. A prior
// build let the field's InputDecorator reserve its Material footprint, dropping
// the glyphs to the bottom of the pill — a subtle-but-visible misalignment.
//
// This test loads the REAL Inter font (pubspec `fonts:`), so the measured text
// metrics match the shipped macOS render rather than the flutter_test fallback
// font, whose symmetric em-box would mask a real vertical-centering bug.
import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/goals/presentation/goals_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal in-memory repository so the page renders its quick-add composer
/// without touching the cloud.
class _EmptyDashboardRepository extends DashboardRepository {
  @override
  DashboardSnapshot load() => DashboardSnapshot.empty;

  @override
  Future<void> save(DashboardSnapshot snapshot) async {}
}

/// Skips the cloud/private category fetch so the page renders hermetically.
class _NoCategoriesController extends DesktopGoalCategoriesController {
  @override
  Future<List<DesktopGoalCategory>> build() async => const [];
}

Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final path in const [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
    'assets/fonts/Inter-ExtraBold.ttf',
  ]) {
    loader.addFont(
      File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
  }
  await loader.load();
}

Future<void> _pumpGoalsPage(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(
          _EmptyDashboardRepository(),
        ),
        desktopGoalCategoriesControllerProvider.overrideWith(
          _NoCategoriesController.new,
        ),
      ],
      child: MaterialApp(
        theme: EvolveTheme.dark(),
        home: const Scaffold(body: GoalsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadInter);

  testWidgets('quick-add goal text sits on the pill vertical centerline', (
    tester,
  ) async {
    // Wide enough (>= 1000) to lay the quick-add out inline on one row at its
    // fixed 44px height.
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpGoalsPage(tester);

    // The quick-add composer is the only text field on the page.
    await tester.enterText(find.byType(TextField), 'Here is My goal');
    await tester.pumpAndSettle();

    // The pill is the decorated 44px Container wrapping the field; the glyphs
    // are the single line box of the editable. Compare their centerlines.
    final pill = tester.getRect(
      find.ancestor(of: find.byType(TextField), matching: find.byType(Container))
          .first,
    );
    final glyphs = tester.getRect(find.byType(EditableText));
    // ignore: avoid_print
    print('PILL   top=${pill.top} bottom=${pill.bottom} '
        'h=${pill.height} cy=${pill.center.dy}');
    // ignore: avoid_print
    print('GLYPHS top=${glyphs.top} bottom=${glyphs.bottom} '
        'h=${glyphs.height} cy=${glyphs.center.dy}  '
        'delta=${(glyphs.center.dy - pill.center.dy).toStringAsFixed(2)}');

    expect(
      pill.height,
      inInclusiveRange(43, 45),
      reason: 'sanity: grabbed the fixed 44px quick-add composer pill',
    );
    expect(
      (glyphs.center.dy - pill.center.dy).abs(),
      lessThan(1.0),
      reason: 'the typed goal text must be vertically centered in the pill '
          '(delta ${(glyphs.center.dy - pill.center.dy).toStringAsFixed(2)}px)',
    );
  });
}
