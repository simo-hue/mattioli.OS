import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_search_widgets.dart';
import 'package:evolve_desktop/shared/widgets/evolve_search_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const _fieldKey = Key('settings.searchField');

Future<TextEditingController> _pumpField(
  WidgetTester tester, {
  String? shortcutHint = '⌘ F',
}) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      // The real app theme, deliberately: the ghost-border bug only existed
      // because of this theme's `inputDecorationTheme`. Pumping the field
      // under a bare ThemeData would test nothing.
      theme: EvolveTheme.dark(EvolveColors.primaryStrong),
      home: Scaffold(
        body: SizedBox(
          width: 236,
          child: EvolveSearchField(
            controller: controller,
            hintText: 'Search settings',
            clearTooltip: 'Clear',
            shortcutHint: shortcutHint,
            onChanged: (_) {},
          ),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  group('the ghost border', () {
    // The field draws its own pill. The global InputDecorationTheme also sets
    // `enabledBorder`, `focusedBorder` and `filled: true`, and state-specific
    // borders take precedence over `border` — so a lone
    // `border: InputBorder.none` still had Flutter painting a second,
    // radius-12 outlined box around the text inside the pill. Users saw a
    // double outline. Nulling `border` alone is not enough, and nothing but a
    // test says so.
    testWidgets('no decoration border survives in any state', (tester) async {
      await _pumpField(tester);

      final field = tester.widget<TextField>(find.byKey(_fieldKey));
      final decoration = field.decoration!;

      expect(decoration.border, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.disabledBorder, InputBorder.none);
      expect(decoration.filled, isFalse);
    });

    testWidgets('the theme would otherwise supply one', (tester) async {
      // Guards the guard: if the app theme ever stops setting input borders,
      // the test above becomes vacuous and this one fails to say so.
      final theme = EvolveTheme.dark(EvolveColors.primaryStrong);
      expect(theme.inputDecorationTheme.enabledBorder, isNotNull);
      expect(theme.inputDecorationTheme.filled, isTrue);
    });
  });

  group('the pill', () {
    testWidgets('wears the shared search chrome', (tester) async {
      await _pumpField(tester);

      final pill = tester.widget<Container>(
        find
            .ancestor(
              of: find.byKey(_fieldKey),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(pill.constraints?.maxHeight, EvolveSearchChrome.height);

      final decoration = pill.decoration! as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(EvolveSearchChrome.radius),
      );
    });

    testWidgets('borders in the accent colour only while focused', (
      tester,
    ) async {
      await _pumpField(tester);

      BorderSide side() {
        final pill = tester.widget<Container>(
          find
              .ancestor(
                of: find.byKey(_fieldKey),
                matching: find.byType(Container),
              )
              .first,
        );
        return (pill.decoration! as BoxDecoration).border!.top;
      }

      final resting = side().color;

      await tester.tap(find.byKey(_fieldKey));
      await tester.pumpAndSettle();

      expect(side().color, isNot(resting));
      // Compared on RGB alone: the focus ring is the accent at reduced opacity,
      // and pinning the exact alpha here would make a taste tweak look like a
      // regression.
      expect(
        side().color.toARGB32() & 0x00FFFFFF,
        EvolveColors.primaryStrong.toARGB32() & 0x00FFFFFF,
      );
    });
  });

  group('the trailing slot', () {
    testWidgets('shows the shortcut until there is something to clear', (
      tester,
    ) async {
      final controller = await _pumpField(tester);

      expect(find.text('⌘ F'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsNothing);

      await tester.enterText(find.byKey(_fieldKey), 'language');
      await tester.pumpAndSettle();

      expect(find.text('⌘ F'), findsNothing);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(controller.text, isEmpty);
      expect(find.text('⌘ F'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsNothing);
    });

    testWidgets('stays empty when no shortcut is advertised', (tester) async {
      await _pumpField(tester, shortcutHint: null);

      expect(find.text('⌘ F'), findsNothing);
      expect(find.byIcon(LucideIcons.x), findsNothing);
    });
  });
}
