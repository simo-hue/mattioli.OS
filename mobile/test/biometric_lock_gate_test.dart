import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/ui/widgets/biometric_lock_gate.dart';
import 'package:mattioli_os/i18n/translations.g.dart';

/// Renders [BiometricLockGate] over a sentinel child. [enabledForUser] is
/// overridden directly so the test drives the lock without a real settings /
/// auth stack. When the lock is armed, the gate's post-frame `_authenticate`
/// call hits the (unmocked) local_auth channel, which throws
/// `MissingPluginException` in the test host; the gate catches it and stays
/// locked — exactly the fail-closed behaviour we want to assert.
Future<ProviderContainer> _pumpGate(
  WidgetTester tester, {
  required bool enabledForUser,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        biometricLockEnabledForUserProvider.overrideWithValue(enabledForUser),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const BiometricLockGate(
            child: Scaffold(body: Center(child: Text('SECRET CONTENT'))),
          ),
        ),
      ),
    ),
  );
  // Flush the post-frame authenticate() attempt (and its caught exception).
  await tester.pump(const Duration(milliseconds: 50));
  return ProviderScope.containerOf(
    tester.element(find.byType(BiometricLockGate)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  testWidgets('covers the app with the lock screen when the lock is armed', (
    tester,
  ) async {
    await _pumpGate(tester, enabledForUser: true);

    // The lock overlay is rendered (this branch was previously unreachable),
    // covering the still-mounted app content beneath it.
    expect(find.text('App Locked'), findsOneWidget);
    expect(find.text('SECRET CONTENT'), findsOneWidget);
    // A benign MissingPluginException from local_auth is caught by the gate.
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the app content when the lock is disabled', (tester) async {
    await _pumpGate(tester, enabledForUser: false);

    expect(find.text('SECRET CONTENT'), findsOneWidget);
    expect(find.text('App Locked'), findsNothing);
  });

  testWidgets('reveals the content once the session is unlocked', (
    tester,
  ) async {
    final container = await _pumpGate(tester, enabledForUser: true);
    expect(find.text('App Locked'), findsOneWidget);

    // Simulate a successful authentication for this foreground session.
    container.read(biometricUnlockedProvider.notifier).set(true);
    await tester.pump();

    expect(find.text('App Locked'), findsNothing);
    expect(find.text('SECRET CONTENT'), findsOneWidget);
  });
}
