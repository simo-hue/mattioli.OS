// Guards the iOS edge-swipe-back gesture on every pushed full-screen route.
//
// The bug this locks down: `PrivacySettingsScreen.route()` returned a raw
// `PageRouteBuilder` with a hand-written slide, so it silently had NO
// swipe-back — the gesture lives inside `CupertinoPageTransitionsBuilder`, and
// a route that supplies its own `transitionsBuilder` never reaches it. Seven
// sibling screens were correct only because each carried a copy-pasted comment
// saying to use `MaterialPageRoute`, which is exactly the kind of convention
// the eighth screen can miss.
//
// Three layers, which together are a proof and not a spot-check:
//
//  1. BEHAVIOUR — an `evolveRoute` really does pop on an edge drag, in LTR and
//     in RTL. This is the part that would catch a Flutter-side regression.
//  2. SHAPE — every screen's `route()` returns that same route type, so (1)
//     applies to all of them without pumping nine heavyweight screens.
//  3. SOURCE — no `PageRouteBuilder` may reappear under `lib/ui/screens/`,
//     which is the only layer that can catch a screen written tomorrow.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/ui/kit/evolve_route.dart';
import 'package:mattioli_os/ui/screens/ai_chat_screen.dart';
import 'package:mattioli_os/ui/screens/app_logs_screen.dart';
import 'package:mattioli_os/ui/screens/app_settings_screen.dart';
import 'package:mattioli_os/ui/screens/icloud_sync_screen.dart';
import 'package:mattioli_os/ui/screens/notification_settings_screen.dart';
import 'package:mattioli_os/ui/screens/personal_info_screen.dart';
import 'package:mattioli_os/ui/screens/privacy_settings_screen.dart';
import 'package:mattioli_os/ui/screens/profile_screen.dart';
import 'package:mattioli_os/ui/screens/subscription_screen.dart';

/// Two-page harness. Page 2 is pushed with the real [evolveRoute], so the drag
/// tests exercise the helper the screens actually use rather than a lookalike.
Widget _harness({
  TextDirection direction = TextDirection.ltr,
  bool fullscreenDialog = false,
}) {
  return MaterialApp(
    // The app's REAL theme, not a synthetic one. This matters: the gesture is
    // installed by whichever `PageTransitionsBuilder` the ambient
    // `PageTransitionsTheme` picks, so a `pageTransitionsTheme:` added to
    // AppTheme one day would kill the gesture on all nine screens — and a test
    // pinning its own `ThemeData()` would stay green through it, which is the
    // one regression this file otherwise could not see. `platform` is still
    // forced, because the host running the test is macOS or (in CI) Linux and
    // `PageTransitionsTheme` keys off the target platform.
    theme: AppTheme.lightTheme(null).copyWith(platform: TargetPlatform.iOS),
    // `builder` wraps the Navigator, so this Directionality sits above every
    // route (the same slot `BiometricLockGate` occupies in main.dart).
    builder: (context, child) =>
        Directionality(textDirection: direction, child: child!),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push<void>(
              context,
              evolveRoute<void>(
                (_) => const Scaffold(body: Text('page-two')),
                fullscreenDialog: fullscreenDialog,
              ),
            ),
            child: const Text('page-one'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    // AppTheme builds its text theme from GoogleFonts, which would otherwise
    // try to fetch over the network. Same shim the other screen tests use.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('evolveRoute is swipe-back capable', () {
    testWidgets('LTR: dragging from the left edge pops the route', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.tap(find.text('page-one'));
      await tester.pumpAndSettle();
      expect(find.text('page-two'), findsOneWidget);

      // Start inside the ~20pt leading drag area; 600px on an 800px-wide test
      // surface carries the route well past the halfway pop threshold.
      await tester.dragFrom(const Offset(2, 300), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(find.text('page-two'), findsNothing);
      expect(find.text('page-one'), findsOneWidget);
    });

    testWidgets('RTL: the drag area mirrors to the right edge', (tester) async {
      await tester.pumpWidget(_harness(direction: TextDirection.rtl));
      await tester.tap(find.text('page-one'));
      await tester.pumpAndSettle();
      expect(find.text('page-two'), findsOneWidget);

      // The whole point: in Arabic the gesture must live on the RIGHT edge and
      // travel leftward. A hand-rolled `Offset(1, 0)` slide cannot do this,
      // which is why the old PageRouteBuilder was an RTL bug as well as a
      // missing-gesture bug.
      await tester.dragFrom(const Offset(798, 300), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('page-two'), findsNothing);
      expect(find.text('page-one'), findsOneWidget);
    });

    testWidgets('LTR: a drag starting away from the edge does NOT pop', (
      tester,
    ) async {
      await tester.pumpWidget(_harness());
      await tester.tap(find.text('page-one'));
      await tester.pumpAndSettle();

      // Negative control. Without this, a test that popped for some unrelated
      // reason would still pass and prove nothing about the edge gesture.
      await tester.dragFrom(const Offset(400, 300), const Offset(300, 0));
      await tester.pumpAndSettle();

      expect(find.text('page-two'), findsOneWidget);
    });

    testWidgets('fullscreenDialog: true is a real opt-out of the gesture', (
      tester,
    ) async {
      // The helper's escape hatch has to mean something, or it is decoration.
      // An iOS modal editor is deliberately NOT swipe-dismissible, and the
      // route-shape assertions below pin `fullscreenDialog: false` on all nine
      // screens precisely because this flag disables the gesture.
      await tester.pumpWidget(_harness(fullscreenDialog: true));
      await tester.tap(find.text('page-one'));
      await tester.pumpAndSettle();
      expect(find.text('page-two'), findsOneWidget);

      await tester.dragFrom(const Offset(2, 300), const Offset(600, 0));
      await tester.pumpAndSettle();

      expect(find.text('page-two'), findsOneWidget);
    });
  });

  group('every screen route() is swipe-back capable', () {
    // `route()` is lazy — it builds a Route, never the widget — so this needs
    // no ProviderScope, no plugin shims, and no localization setup.
    final factories = <String, Route Function()>{
      'AIChatScreen': AIChatScreen.route,
      'AppLogsScreen': AppLogsScreen.route,
      'AppSettingsScreen': AppSettingsScreen.route,
      'IcloudSyncScreen': IcloudSyncScreen.route,
      'NotificationSettingsScreen': NotificationSettingsScreen.route,
      'PersonalInfoScreen': PersonalInfoScreen.route,
      'PrivacySettingsScreen': PrivacySettingsScreen.route,
      'ProfileScreen': ProfileScreen.route,
      'SubscriptionScreen': SubscriptionScreen.route,
    };

    for (final entry in factories.entries) {
      test('${entry.key}.route() returns a MaterialPageRoute', () {
        final route = entry.value();
        expect(
          route,
          isA<MaterialPageRoute>(),
          reason:
              '${entry.key} must push via evolveRoute(). Any other PageRoute '
              'subtype bypasses CupertinoPageTransitionsBuilder and loses the '
              'iOS edge-swipe-back gesture.',
        );
        expect(
          (route as MaterialPageRoute).fullscreenDialog,
          isFalse,
          reason:
              '${entry.key} is a pushed destination, not a modal editor. '
              'fullscreenDialog: true disables the swipe-back gesture.',
        );
      });
    }
  });

  test('no gesture-losing route type reappears anywhere under lib/ui', () {
    // Catches a screen that does not exist yet, which the enumerated factories
    // above cannot. Scoped to ALL of lib/ui, not just lib/ui/screens: six of
    // the sixteen push sites live in lib/ui/widgets (sync_off_banner,
    // protocollo_panel, pro_features_modal, habit_management_modal ×3), so a
    // guard that watched only the screens directory would be blind to a third
    // of the navigation code.
    //
    // Both banned types lose the gesture the same way — they supply their own
    // transition instead of delegating to the ambient PageTransitionsTheme, so
    // CupertinoPageTransitionsBuilder never runs and never installs the
    // detector. A raw `MaterialPageRoute` is deliberately NOT banned: it keeps
    // the gesture, so using it is a consistency wart, not a bug (the
    // ProfileImageCropper push is one, on purpose).
    //
    // If a future screen genuinely needs a bespoke transition, delete this test
    // deliberately and say why — do not weaken it quietly.
    const banned = <String, String>{
      'PageRouteBuilder': 'supplies its own transitionsBuilder',
      'CustomTransitionPage': 'go_router\'s bespoke-transition page',
    };

    final ui = Directory('lib/ui');
    expect(
      ui.existsSync(),
      isTrue,
      reason: 'flutter test runs from the package root; lib/ui should resolve. '
          'If this fails the guard below is silently vacuous.',
    );

    final offenders = <String>[];
    for (final file in ui.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      // Comments are stripped before matching. Without this the guard fires on
      // evolve_route.dart's own doc comment, which names PageRouteBuilder
      // twice on purpose — the explanation of what went wrong is the most
      // valuable thing in that file, and a guard that punishes writing it down
      // is a guard that teaches people to delete documentation. Line-based,
      // which is enough here: Dart comments are `//`/`///` and this tree has
      // no `/* */` blocks. A trailing comment on a code line still matches,
      // which is the safe direction to err.
      final code = file
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final entry in banned.entries) {
        if (code.contains(entry.key)) {
          offenders.add('${file.path}: ${entry.key} (${entry.value})');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These route types never reach CupertinoPageTransitionsBuilder, '
          'so they have no iOS edge-swipe-back gesture. Use evolveRoute().',
    );
  });
}
