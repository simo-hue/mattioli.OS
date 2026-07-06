// Kit controls (shared/widgets/evolve_controls.dart): the Apple-feeling
// replacements for the Material form controls. Covers the behavioral contract
// of each control — value changes fire the callback, disabled controls are
// inert, and the direction-sensitive ones render under RTL.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: EvolveTheme.dark(EvolveColors.primaryStrong),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('EvolveSwitch', () {
    testWidgets('tap fires onChanged with the toggled value', (tester) async {
      bool? received;
      await tester.pumpWidget(
        _host(EvolveSwitch(value: false, onChanged: (v) => received = v)),
      );

      await tester.tap(find.byType(EvolveSwitch));
      expect(received, isTrue);
    });

    testWidgets('null onChanged disables the control', (tester) async {
      await tester.pumpWidget(
        _host(const EvolveSwitch(value: true, onChanged: null)),
      );

      await tester.tap(find.byType(EvolveSwitch));
      await tester.pump();
      // No callback to observe — the tap must simply not throw, and the
      // control must render its disabled (faded) state.
      expect(
        tester.widget<Opacity>(
          find.descendant(
            of: find.byType(EvolveSwitch),
            matching: find.byType(Opacity),
          ),
        ).opacity,
        lessThan(1),
      );
    });

    testWidgets('renders and toggles under RTL', (tester) async {
      bool? received;
      await tester.pumpWidget(
        _host(
          EvolveSwitch(value: true, onChanged: (v) => received = v),
          direction: TextDirection.rtl,
        ),
      );

      await tester.tap(find.byType(EvolveSwitch));
      expect(received, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('EvolveSelect', () {
    Widget select({ValueChanged<String>? onChanged}) {
      return EvolveSelect<String>(
        value: 'alpha',
        options: const [
          EvolveSelectOption(value: 'alpha', label: 'Alpha'),
          EvolveSelectOption(value: 'beta', label: 'Beta'),
          EvolveSelectOption(value: 'gamma', label: 'Gamma'),
        ],
        onChanged: onChanged,
      );
    }

    testWidgets('opens the menu and picking an option fires onChanged',
        (tester) async {
      String? received;
      await tester.pumpWidget(_host(select(onChanged: (v) => received = v)));

      // Closed: only the trigger label is visible.
      expect(find.text('Beta'), findsNothing);

      await tester.tap(find.byType(EvolveSelect<String>));
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      expect(received, 'beta');
      expect(find.text('Beta'), findsNothing, reason: 'menu closed');
    });

    testWidgets('re-selecting the current value does not fire onChanged',
        (tester) async {
      String? received;
      await tester.pumpWidget(_host(select(onChanged: (v) => received = v)));

      await tester.tap(find.byType(EvolveSelect<String>));
      await tester.pumpAndSettle();
      // Trigger + menu row both say Alpha — tap the menu row (last).
      await tester.tap(find.text('Alpha').last);
      await tester.pumpAndSettle();

      expect(received, isNull);
    });

    testWidgets('null onChanged keeps the menu closed', (tester) async {
      await tester.pumpWidget(_host(select()));

      await tester.tap(find.byType(EvolveSelect<String>));
      await tester.pumpAndSettle();

      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('renders and opens under RTL', (tester) async {
      String? received;
      await tester.pumpWidget(
        _host(
          select(onChanged: (v) => received = v),
          direction: TextDirection.rtl,
        ),
      );

      await tester.tap(find.byType(EvolveSelect<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gamma'));
      await tester.pumpAndSettle();

      expect(received, 'gamma');
      expect(tester.takeException(), isNull);
    });
  });

  group('EvolveTimePicker', () {
    testWidgets('shows the formatted 24h value on the trigger',
        (tester) async {
      await tester.pumpWidget(
        _host(
          EvolveTimePicker(
            value: const TimeOfDay(hour: 8, minute: 5),
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('08:05'), findsOneWidget);
    });

    testWidgets('stepping the hour and confirming returns the new time',
        (tester) async {
      TimeOfDay? received;
      await tester.pumpWidget(
        _host(
          EvolveTimePicker(
            value: const TimeOfDay(hour: 8, minute: 30),
            onChanged: (v) => received = v,
          ),
        ),
      );

      await tester.tap(find.byType(EvolveTimePicker));
      await tester.pumpAndSettle();

      // Hour column comes first in the dialog row.
      await tester.tap(find.byIcon(LucideIcons.chevronUp).first);
      await tester.pumpAndSettle();

      final localizations = DefaultMaterialLocalizations();
      await tester.tap(find.text(localizations.okButtonLabel));
      await tester.pumpAndSettle();

      expect(received, const TimeOfDay(hour: 9, minute: 30));
    });

    testWidgets('cancel leaves the value untouched', (tester) async {
      TimeOfDay? received;
      await tester.pumpWidget(
        _host(
          EvolveTimePicker(
            value: const TimeOfDay(hour: 8, minute: 30),
            onChanged: (v) => received = v,
          ),
        ),
      );

      await tester.tap(find.byType(EvolveTimePicker));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(DefaultMaterialLocalizations().cancelButtonLabel),
      );
      await tester.pumpAndSettle();

      expect(received, isNull);
    });

    testWidgets('dialog opens and confirms under RTL (HH:MM stays LTR)',
        (tester) async {
      TimeOfDay? received;
      await tester.pumpWidget(
        _host(
          EvolveTimePicker(
            value: const TimeOfDay(hour: 8, minute: 30),
            onChanged: (v) => received = v,
          ),
          direction: TextDirection.rtl,
        ),
      );

      await tester.tap(find.byType(EvolveTimePicker));
      await tester.pumpAndSettle();

      // The digit cluster is pinned LTR: the hour field sits left of the
      // minute field even under an RTL ambient direction.
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      final first = tester.getTopLeft(fields.first);
      final second = tester.getTopLeft(fields.last);
      expect(first.dx, lessThan(second.dx));

      await tester.tap(find.byIcon(LucideIcons.chevronUp).first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(DefaultMaterialLocalizations().okButtonLabel),
      );
      await tester.pumpAndSettle();

      expect(received, const TimeOfDay(hour: 9, minute: 30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('12-hour mode shows the AM/PM toggle and converts the hour',
        (tester) async {
      TimeOfDay? received;
      await tester.pumpWidget(
        _host(
          EvolveTimePicker(
            value: const TimeOfDay(hour: 8, minute: 0),
            use24hFormat: false,
            onChanged: (v) => received = v,
          ),
        ),
      );

      await tester.tap(find.byType(EvolveTimePicker));
      await tester.pumpAndSettle();

      final localizations = DefaultMaterialLocalizations();
      expect(find.text(localizations.anteMeridiemAbbreviation), findsOneWidget);

      await tester.tap(find.text(localizations.postMeridiemAbbreviation));
      await tester.pumpAndSettle();
      await tester.tap(find.text(localizations.okButtonLabel));
      await tester.pumpAndSettle();

      expect(received, const TimeOfDay(hour: 20, minute: 0));
    });
  });

  group('EvolveDateField / showEvolveDatePicker', () {
    testWidgets('picking a day from the calendar fires onChanged',
        (tester) async {
      DateTime? received;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: EvolveDateField(
              value: DateTime(2024, 5, 10),
              label: 'Date of birth',
              onChanged: (v) => received = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(EvolveDateField));
      await tester.pumpAndSettle();

      // Calendar opens on the value's month.
      expect(find.text('May 2024'), findsOneWidget);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(received, DateTime(2024, 5, 15));
    });

    testWidgets('month navigation moves the visible grid', (tester) async {
      DateTime? received;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: EvolveDateField(
              value: DateTime(2024, 5, 10),
              onChanged: (v) => received = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(EvolveDateField));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.chevronRight));
      await tester.pumpAndSettle();

      expect(find.text('June 2024'), findsOneWidget);

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(received, DateTime(2024, 6, 3));
    });

    testWidgets('the clear affordance empties the value', (tester) async {
      DateTime? value = DateTime(2024, 5, 10);
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: EvolveDateField(
              value: value,
              onChanged: (v) => value = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pump();

      expect(value, isNull);
    });

    testWidgets('days outside firstDate/lastDate are inert', (tester) async {
      DateTime? received;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: EvolveDateField(
              value: DateTime(2024, 5, 10),
              firstDate: DateTime(2024, 5, 5),
              lastDate: DateTime(2024, 5, 20),
              onChanged: (v) => received = v,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(EvolveDateField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25'));
      await tester.pumpAndSettle();

      expect(received, isNull);
      expect(find.text('May 2024'), findsOneWidget, reason: 'dialog stays up');
    });

    testWidgets('calendar renders under RTL', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: EvolveDateField(
              value: DateTime(2024, 5, 10),
              onChanged: (_) {},
            ),
          ),
          direction: TextDirection.rtl,
        ),
      );

      await tester.tap(find.byType(EvolveDateField));
      await tester.pumpAndSettle();

      expect(find.text('May 2024'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('EvolveRadioRow', () {
    testWidgets('tapping an unselected row fires onChanged with its value',
        (tester) async {
      String? received;
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EvolveRadioRow<String>(
                value: 'replace',
                groupValue: 'replace',
                onChanged: (v) => received = v,
                title: 'Replace',
                subtitle: 'Wipe and reload',
              ),
              EvolveRadioRow<String>(
                value: 'merge',
                groupValue: 'replace',
                onChanged: (v) => received = v,
                title: 'Merge',
                subtitle: 'Keep both',
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Merge'));
      expect(received, 'merge');
    });
  });

  group('EvolveProBadge', () {
    testWidgets('renders the PRO chip', (tester) async {
      await tester.pumpWidget(_host(const EvolveProBadge()));
      expect(find.text('PRO'), findsOneWidget);
    });
  });
}
