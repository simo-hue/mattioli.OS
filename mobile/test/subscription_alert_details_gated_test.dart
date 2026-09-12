// SEC-7 on the paywall: the raw exception is a DEBUG channel, not user copy.
//
// `ErrorModal` already states the rule and honours it — the technical-details
// block is behind `(kDebugMode || forceDetails)`. `SubscriptionAlertModal` grew
// the same `details:` channel without the gate, and it is the one surface where
// the string is guaranteed to be a StoreKit `PlatformException`: both the
// restore path and the purchase path pass `details: e.toString()`.
//
// So an Arabic user tapping Restore Purchases with the App Store unreachable
// read, in a monospace box under the localized title, an English
// `PlatformException(2, There was a problem with the App Store., {...})` — in
// release.
//
// `no_raw_exception_in_user_copy_test.dart` cannot see this: it deliberately
// exempts the `details:` channel BECAUSE ErrorModal gates it. That exemption was
// only ever true of ErrorModal.
//
// This is a source assertion rather than a widget pump on purpose. `flutter
// test` runs in debug, so `kDebugMode` is true and the block renders either way
// — a pumped widget cannot tell a gated tree from an ungated one. The gate is
// what is under test, so the gate is what is asserted.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/ui/widgets/subscription_alert_modal.dart';

String _scannable(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
    .replaceAll(RegExp(r'\s+'), ' ');

void main() {
  const modalPath = 'lib/ui/widgets/subscription_alert_modal.dart';

  test('the subscription alert gates its raw-details block like ErrorModal', () {
    final source = _scannable(modalPath);

    // The gate must be on the SAME `if` as the details block, not merely
    // somewhere in the file.
    expect(
      source,
      contains('if ((kDebugMode || forceDetails) && details != null'),
      reason: 'SubscriptionAlertModal shows `details: e.toString()` from the '
          'restore and purchase catch blocks. Without the kDebugMode gate that '
          'raw StoreKit PlatformException is user-facing copy, in release, '
          'untranslated.',
    );
    // `kDebugMode` lives in foundation.dart, which this file did not import at
    // all — so the gate could not even have been written without noticing.
    expect(source, contains("import 'package:flutter/foundation.dart'"));
  });

  test('the two paywall catch blocks still feed the debug channel', () {
    // The other way to make the first test pass is to delete the channel. That
    // would lose the one thing it is good for, so pin the call sites too.
    final screen = _scannable('lib/ui/screens/subscription_screen.dart');
    expect(
      RegExp(r'details: e\.toString\(\)').allMatches(screen).length +
          RegExp(r'details: isPending \? null : e\.toString\(\)')
              .allMatches(screen)
              .length,
      2,
      reason: 'restore + purchase both pass the exception as debug details',
    );
  });

  testWidgets('in a debug build the details are still shown', (tester) async {
    // The gate must not become an unconditional deletion: under `flutter test`
    // kDebugMode is true, so this is the branch a developer actually gets.
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          locale: const Locale('en'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          home: const Scaffold(
            body: SubscriptionAlertModal(
              title: 'Restore failed',
              message: 'We could not restore your purchases.',
              type: SubscriptionAlertType.error,
              details: 'PlatformException(2, App Store problem)',
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PlatformException(2, App Store problem)'), findsOneWidget);
  });
}
