// The AI Coach setup card points at the thing that is actually missing.
//
// The card appears when no transport resolves. What is missing differs by mode,
// and the button did not: it always pushed `AppSettingsScreen`.
//
// In ACCOUNT mode the missing thing is the subscription — and Settings cannot
// sell it. `app_settings_screen.dart` contains no navigation at all (zero
// `Navigator.push`, zero `.route()`), and its only subscription item opens
// Apple's external manage-subscriptions page, which is for managing one you
// already have. `SubscriptionScreen` is reachable from Profile, the habit sheet
// and the Pro modal — every route except the one screen whose whole copy is
// "the AI Coach comes with Evolve Pro". A user told exactly that was sent
// somewhere that could not act on it.
//
// In PRIVATE mode Settings is right: the BYOK key row lives there, and there is
// no subscription in that mode to offer.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/coach_endpoint.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/ai_chat_screen.dart';
import 'package:mattioli_os/ui/screens/app_settings_screen.dart';
import 'package:mattioli_os/ui/screens/subscription_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

class _NoopNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  Future<void> pumpSetupCard(
    WidgetTester tester, {
    required bool privateMode,
    bool isPro = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (privateMode) 'active_data_mode': 'private',
      if (isPro) 'pref_is_pro': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith(
          (ref) => FakePrivateDataStore(),
        ),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
        // No transport resolves — the state that shows the setup card at all.
        coachEndpointProvider.overrideWith((ref) async => null),
        canUseStandardCoachProvider.overrideWithValue(!privateMode),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          locale: const Locale('en'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          home: const AIChatScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('in ACCOUNT mode it offers Pro, and opens the paywall',
      (tester) async {
    await pumpSetupCard(tester, privateMode: false);

    final cta = find.text(t.profile.upgradeToPro);
    expect(cta, findsOneWidget,
        reason: 'the missing thing is the subscription, so say so');
    expect(find.text(t.ai.apiKey.setupAction), findsNothing);

    await tester.tap(cta);
    // Fixed frames, NOT pumpAndSettle: the paywall spins on a RevenueCat
    // offerings fetch that never resolves in a test, so settling never returns.
    // Reaching the screen is the assertion; what it renders is another test's.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SubscriptionScreen), findsOneWidget,
        reason: 'Settings has no purchase route — pushing it was a dead end');
  });

  testWidgets('in PRIVATE mode it still opens Settings, where the key lives',
      (tester) async {
    await pumpSetupCard(tester, privateMode: true);

    final cta = find.text(t.ai.apiKey.setupAction);
    expect(cta, findsOneWidget);
    expect(find.text(t.profile.upgradeToPro), findsNothing,
        reason: 'Private mode keeps no account, so offering a subscription '
            'there would put monetization UI in the mode that promises none');

    await tester.tap(cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AppSettingsScreen), findsOneWidget);
  });

  testWidgets('a Pro subscriber whose session lapsed is NOT sold it again',
      (tester) async {
    // The card renders whenever no transport resolves — and `resolveCoachMode`
    // returns null for `isPro && !hasSession` as well, a state its own comment
    // names: a Pro user mid sign-in or token refresh. Branching on the MODE
    // alone (`canUseStandardCoach` is just `!isPrivate`) offered that paying
    // subscriber a button reading "Upgrade to Pro", opening the paywall for the
    // subscription they already hold.
    await pumpSetupCard(tester, privateMode: false, isPro: true);

    expect(find.text(t.profile.upgradeToPro), findsNothing,
        reason: 'they already bought it');
    expect(find.text(t.ai.apiKey.setupAction), findsOneWidget);

    await tester.tap(find.text(t.ai.apiKey.setupAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SubscriptionScreen), findsNothing);
    expect(find.byType(AppSettingsScreen), findsOneWidget);
  });
}
