// The colour picker's RGB mode reads Color.r/.g/.b, which are normalized
// 0.0-1.0 doubles, but its fields and write path speak 0-255. Truncating
// instead of scaling made every field read 0 and let a bare focus/blur commit
// black over the user's accent colour, so these tests pin the scaling.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/shared/widgets/evolve_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's default accent, #3B82F6 — channels 59, 130, 246.
const _accent = Color(0xFF3B82F6);

Widget _host(Color initial, ValueChanged<Color> onColorChanged) {
  return MaterialApp(
    theme: EvolveTheme.dark(EvolveColors.primaryStrong),
    home: Scaffold(
      body: Center(
        child: EvolveColorPickerContent(
          initialColor: initial,
          onColorChanged: onColorChanged,
        ),
      ),
    ),
  );
}

/// Switches the picker out of its default HEX mode into RGB mode.
Future<void> _showRgbMode(WidgetTester tester) async {
  await tester.tap(find.text('HEX'));
  await tester.pumpAndSettle();
}

List<String> _fieldValues(WidgetTester tester) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .map((f) => f.controller!.text)
      .toList();
}

void main() {
  testWidgets('RGB fields show the colour\'s 0-255 channels, not truncated doubles', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_accent, (_) {}));
    await _showRgbMode(tester);

    expect(_fieldValues(tester), <String>['59', '130', '246']);
  });

  testWidgets('white reads 255,255,255 rather than 1,1,1', (tester) async {
    await tester.pumpWidget(_host(const Color(0xFFFFFFFF), (_) {}));
    await _showRgbMode(tester);

    expect(_fieldValues(tester), <String>['255', '255', '255']);
  });

  testWidgets('focusing an RGB field and blurring away preserves the colour', (
    tester,
  ) async {
    // The regression that mattered: _onFocusChange commits the controllers'
    // text on blur, so a stale "0" readout silently overwrote the real accent
    // colour with black — persisted and synced, with no undo.
    final committed = <Color>[];
    await tester.pumpWidget(_host(_accent, committed.add));
    await _showRgbMode(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    // Blur without typing.
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();

    expect(committed, isNot(contains(const Color(0xFF000000))));
    for (final color in committed) {
      expect(color, _accent);
    }
  });

  testWidgets('an edited channel round-trips, leaving the others intact', (
    tester,
  ) async {
    final committed = <Color>[];
    await tester.pumpWidget(_host(_accent, committed.add));
    await _showRgbMode(tester);

    await tester.enterText(find.byType(TextField).first, '10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(committed.last, const Color(0xFF0A82F6));
  });
}
