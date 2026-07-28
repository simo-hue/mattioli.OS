import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens a Settings destination by its stable key.
///
/// Prefer this over `tester.tap(find.text(t.settingsPage.sectionApplication))`.
/// The old form asserted on a localized label as a side effect of navigating,
/// so every copy change broke navigation across the suite — and it silently
/// matched the pane heading too, which is why each call site needed `.first`.
Future<void> openSettingsSection(
  WidgetTester tester,
  SettingsSection section,
) async {
  final destination = find.byKey(section.key);
  expect(
    destination,
    findsOneWidget,
    reason:
        'Settings destination "${section.name}" is not in the rail. It may be '
        'filtered out by the current data mode.',
  );
  await tester.tap(destination);
  await tester.pumpAndSettle();
}
