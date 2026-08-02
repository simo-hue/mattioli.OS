// Regression test for the EvolveToast overlay leak (Bug 1).
//
// The toast drove its on-screen dwell with a non-cancellable
// `await Future<void>.delayed(duration)` and only removed its OverlayEntry via
// `onDismissed`. If the route tree was torn down / replaced (e.g. logout ->
// `context.go('/login')`) while a toast was still showing, that pending delay
// outlived the widget: the timer was never cancelled and the toast's inherited
// dependents (Theme / MediaQuery) were left dangling, tripping the framework
// assertion `InheritedElement.debugDeactivated: _dependents.isEmpty`.
//
// The toast now dwells on a `Timer` cancelled in `dispose()`, and
// `showEvolveToast` guards `entry.remove()` so it is never called twice / on an
// already-removed entry. Tearing the tree down mid-toast must therefore leave no
// pending timer and throw no exception.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/ui/kit/evolve_toast.dart';

Future<void> _pumpHost(
  WidgetTester tester,
  void Function(BuildContext) capture,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme(null),
      home: Builder(
        builder: (context) {
          capture(context);
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
  });

  testWidgets('toast torn down mid-display leaves no pending timer / exception',
      (tester) async {
    late BuildContext ctx;
    await _pumpHost(tester, (c) => ctx = c);

    showEvolveToast(ctx, message: 'Saved');
    await tester.pump(); // insert the overlay entry
    await tester.pump(const Duration(milliseconds: 300)); // finish fade-in
    expect(find.text('Saved'), findsOneWidget);

    // Tear the whole tree down while the toast is still on screen (models the
    // route tree being replaced on logout). Deliberately do NOT advance to the
    // 2s dwell: with the old `Future.delayed` this left a ~1.7s timer pending
    // past disposal (a test failure); the `Timer` is now cancelled in dispose().
    await tester.pumpWidget(const SizedBox());

    expect(tester.takeException(), isNull);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('toast dismisses itself normally after its dwell', (tester) async {
    late BuildContext ctx;
    await _pumpHost(tester, (c) => ctx = c);

    showEvolveToast(ctx, message: 'Done');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Done'), findsOneWidget);

    // Let the dwell + fade-out run: the entry removes itself and no timer leaks.
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Done'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
