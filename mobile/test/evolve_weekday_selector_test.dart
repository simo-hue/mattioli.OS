import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/ui/kit/evolve_weekday_selector.dart';

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  // The 7 chips are the only InkWells wrapping an AnimatedContainer.
  final chips = find.byWidgetPredicate(
    (w) => w is InkWell && w.child is AnimatedContainer,
  );

  Widget harness({
    required List<int> selected,
    required ValueChanged<List<int>> onChanged,
  }) => ProviderScope(
    child: TranslationProvider(
      child: MaterialApp(
        theme: AppTheme.darkTheme(null),
        home: Scaffold(
          body: EvolveWeekdaySelector(
            selectedDays: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );

  testWidgets('renders 7 weekday chips', (tester) async {
    await tester.pumpWidget(harness(selected: const [1, 2, 3, 4, 5, 6, 7], onChanged: (_) {}));
    expect(chips, findsNWidgets(7));
  });

  testWidgets('tapping a selected day deselects it and emits a sorted list', (
    tester,
  ) async {
    List<int>? emitted;
    await tester.pumpWidget(
      harness(selected: const [1, 2, 3, 4, 5, 6, 7], onChanged: (d) => emitted = d),
    );
    // Deselect Tuesday (index 1, Monday-first).
    await tester.tap(chips.at(1));
    await tester.pump();
    expect(emitted, [1, 3, 4, 5, 6, 7]);
  });

  testWidgets('tapping an unselected day adds it, keeping the list sorted', (
    tester,
  ) async {
    List<int>? emitted;
    await tester.pumpWidget(
      harness(selected: const [1, 3, 5], onChanged: (d) => emitted = d),
    );
    // Add Tuesday (index 1).
    await tester.tap(chips.at(1));
    await tester.pump();
    expect(emitted, [1, 2, 3, 5]);
  });

  testWidgets('the last remaining day cannot be deselected', (tester) async {
    var emittedCount = 0;
    await tester.pumpWidget(
      harness(selected: const [3], onChanged: (_) => emittedCount++),
    );
    // Tapping the only selected day (Wednesday, index 2) is a no-op.
    await tester.tap(chips.at(2));
    await tester.pump();
    expect(emittedCount, 0);
  });
}
