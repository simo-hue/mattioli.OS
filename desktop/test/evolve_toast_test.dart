// Kit primitive (shared/widgets/evolve_toast.dart): the desktop replacement for
// Material SnackBar feedback. Asserts showEvolveToast inserts a root-overlay
// banner carrying the message, that the error kind picks up its alert icon, and
// that the banner removes itself after its duration.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Pumps a host app and hands back a context that sits under the root overlay,
/// so [showEvolveToast] can resolve `Overlay.maybeOf(..., rootOverlay: true)`.
Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      theme: EvolveTheme.dark(EvolveColors.primaryStrong),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return ctx;
}

void main() {
  group('showEvolveToast', () {
    testWidgets('inserts an overlay banner carrying the message', (
      tester,
    ) async {
      final ctx = await _pumpHost(tester);

      showEvolveToast(ctx, message: 'Saved to iCloud');
      await tester.pump();

      expect(find.text('Saved to iCloud'), findsOneWidget);
    });

    testWidgets('error kind shows the alert icon', (tester) async {
      final ctx = await _pumpHost(tester);

      showEvolveToast(
        ctx,
        message: 'Import failed',
        kind: EvolveToastKind.error,
      );
      await tester.pump();

      expect(find.text('Import failed'), findsOneWidget);
      expect(find.byIcon(LucideIcons.circleAlert), findsOneWidget);
    });

    testWidgets('auto-dismisses after its duration', (tester) async {
      final ctx = await _pumpHost(tester);

      showEvolveToast(
        ctx,
        message: 'Transient',
        duration: const Duration(milliseconds: 100),
      );
      // Fade-in settles; the banner is on screen.
      await tester.pumpAndSettle();
      expect(find.text('Transient'), findsOneWidget);

      // The visible-duration timer fires, then the fade-out plays out and the
      // overlay entry removes itself.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Transient'), findsNothing);
    });
  });
}
