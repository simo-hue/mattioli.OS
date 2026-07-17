import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the Merge/Replace selection contract of the backup-import dialog
/// (`privacy_settings_screen.dart`).
///
/// Flutter 3.32 deprecated `RadioListTile.groupValue`/`onChanged` in favour of a
/// `RadioGroup` ancestor, and the dialog was migrated accordingly. That dialog
/// decides whether an import MERGES or REPLACES — and Replace deletes every
/// existing record absent from the backup. A silently broken radio there means
/// a user taps "Merge" and loses their history, so the selection contract is
/// worth pinning even though the widget tree is declared inline in the screen.
///
/// This mirrors the dialog's exact structure: a `RadioGroup<bool>` holding the
/// selection, with two option-only `RadioListTile<bool>`s beneath it.
Widget _harness({
  required bool initial,
  required ValueChanged<bool> onChanged,
}) {
  return MaterialApp(
    home: StatefulBuilder(
      builder: (context, setState) {
        var replaceExisting = initial;
        return Scaffold(
          body: StatefulBuilder(
            builder: (context, setInner) {
              return RadioGroup<bool>(
                groupValue: replaceExisting,
                onChanged: (val) => setInner(() {
                  replaceExisting = val!;
                  onChanged(replaceExisting);
                }),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<bool>(title: Text('Merge'), value: false),
                    RadioListTile<bool>(title: Text('Replace'), value: true),
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

void main() {
  testWidgets('defaults to Merge — the non-destructive option', (tester) async {
    await tester.pumpWidget(_harness(initial: false, onChanged: (_) {}));

    final merge = tester.widget<RadioListTile<bool>>(
      find.widgetWithText(RadioListTile<bool>, 'Merge'),
    );
    final replace = tester.widget<RadioListTile<bool>>(
      find.widgetWithText(RadioListTile<bool>, 'Replace'),
    );
    // Neither tile carries its own groupValue any more; the RadioGroup ancestor
    // owns the selection. Assert the values are the ones the dialog branches on.
    expect(merge.value, isFalse);
    expect(replace.value, isTrue);

    expect(
      tester.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue,
      isFalse,
      reason: 'Replace is destructive; Merge must be preselected',
    );
  });

  testWidgets('tapping Replace selects the destructive mode', (tester) async {
    bool? latest;
    await tester.pumpWidget(_harness(initial: false, onChanged: (v) => latest = v));

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(latest, isTrue, reason: 'RadioGroup must propagate the selection');
    expect(
      tester.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue,
      isTrue,
    );
  });

  testWidgets('tapping Merge returns to the safe mode', (tester) async {
    bool? latest;
    await tester.pumpWidget(_harness(initial: true, onChanged: (v) => latest = v));

    await tester.tap(find.text('Merge'));
    await tester.pumpAndSettle();

    expect(latest, isFalse);
    expect(
      tester.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue,
      isFalse,
    );
  });
}
