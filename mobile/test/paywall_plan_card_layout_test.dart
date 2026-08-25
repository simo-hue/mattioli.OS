// Layout regression test for the paywall's plan cards.
//
// The price `Text` must stay a NON-flexible child of the card's Row. A flex
// child (`Flexible`/`Expanded`) is measured against its proportional share of
// the row's free space rather than against its own content, so a short price
// stops before the card's right edge and a long one wraps — and either way the
// title `Expanded` beside it is squeezed to a fixed half of the row instead of
// taking what the price leaves.
//
// Guarded because this is the App Store's IAP screen and the breakage is
// invisible to `flutter analyze` and to every other test in the suite.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/subscription_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _purchasesChannel = MethodChannel('purchases_flutter');

/// Stand-ins for `StoreProduct.priceString`, which is already localized and
/// storefront-formatted by StoreKit. The screen must render these verbatim.
const String _monthlyPrice = '4,99 EUR';
const String _yearlyPrice = '29,99 EUR';

Map<String, dynamic> _product(String id, double price, String priceString) => {
  'identifier': id,
  'description': 'Evolve Pro',
  'title': 'Evolve Pro',
  'price': price,
  'priceString': priceString,
  'currencyCode': 'EUR',
  'productCategory': 'SUBSCRIPTION',
};

class _NoopNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancelAll() async {}
}

/// `settingsProvider` listens to `authProvider`. Its real build no longer
/// throws on an uninitialized `Supabase.instance` — it reports signed-out, since
/// startup defers the SDK until consent is answered — but this override still
/// states the state under test rather than inferring it. Cloud mode + signed out
/// is the free user
/// the paywall is written for; Private mode forces `isPro` true and would render
/// the Pro branch instead of the plan cards.
class _SignedOutAuth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(isLoggedIn: false, dataMode: AppDataMode.supabase);
}

Future<void> _pumpPaywall(WidgetTester tester) async {
  // iPhone 12/13/14 logical width — the narrowest layout the cards must hold.
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'pref_is_pro': false});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_SignedOutAuth.new),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const SubscriptionScreen(),
        ),
      ),
    ),
  );
  // Not pumpAndSettle: the pre-load state is a CupertinoActivityIndicator,
  // which never stops animating.
  await tester.pump();
  await tester.pump();

  // Everything on this page renders in flutter_test's fallback font, which is
  // far wider than Inter — widget tests do not load the bundled faces. That
  // overflows unrelated rows further down the page (the compliance links).
  // Draining is safe for what is under test here: a price that overflowed its
  // own row would push its right edge past the row's, which is asserted below.
  while (tester.takeException() != null) {}
}

/// The plan card's Row — the price's nearest Row ancestor.
Finder _cardRow(Finder price) =>
    find.ancestor(of: price, matching: find.byType(Row)).first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
    // RevenueCat has no platform implementation under flutter_test, and its
    // channel calls otherwise never complete, hanging the screen on its
    // spinner. Serve the products; fail everything else.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_purchasesChannel, (call) async {
          if (call.method == 'getProductInfo') {
            return [
              _product('com.simo.evolve.pro.monthly', 4.99, _monthlyPrice),
              _product('com.simo.evolve.pro.yearly', 29.99, _yearlyPrice),
            ];
          }
          throw PlatformException(code: 'unavailable');
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_purchasesChannel, null);
  });

  testWidgets('each plan price is content-sized and flush with the card edge', (
    tester,
  ) async {
    await _pumpPaywall(tester);

    for (final priceString in [_monthlyPrice, _yearlyPrice]) {
      final price = find.text(priceString);
      expect(price, findsOneWidget, reason: '$priceString did not render');

      expect(
        tester.getRect(price).right,
        moreOrLessEquals(tester.getRect(_cardRow(price)).right, epsilon: 0.5),
        reason:
            '$priceString does not end at its row\'s right edge. A flex wrapper '
            'caps the price at its share of the free space and strands dead '
            'space beside it.',
      );

      final paragraph = tester.renderObject<RenderParagraph>(price);
      expect(
        tester.getRect(price).width,
        moreOrLessEquals(
          paragraph.getMaxIntrinsicWidth(double.infinity),
          epsilon: 0.5,
        ),
        reason:
            '$priceString was laid out narrower than the single line it needs, '
            'so it wrapped or ellipsized: it was measured against a share of '
            'the row instead of against its own content.',
      );
    }

    // AppLogger debounces its buffer save behind a 2s timer, which the RevenueCat
    // failures above arm. Let it fire so the binding's no-pending-timer
    // invariant holds.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the AI Coach does not head the paywall — it is free via BYOK', (
    tester,
  ) async {
    // The coach led this list from when it was Pro-gated. It is not any more:
    // bring-your-own-key is free, which is the Guideline 3.1.1 fix. Heading the
    // IAP screen with a feature you can have for nothing is an inaccurate
    // subscription description — Guideline 3.1.2, the one this app is already
    // rejected under. The habit limit is the gate a free user actually meets
    // (five habits), so it leads; the coach goes last, selling what Pro really
    // buys for it: no setup.
    await _pumpPaywall(tester);

    final habits = find.text(t.subscription.unlimitedHabits);
    final coach = find.text(t.subscription.personalizedAiCoach);
    expect(habits, findsOneWidget);
    expect(coach, findsOneWidget);

    expect(
      tester.getTopLeft(habits).dy,
      lessThan(tester.getTopLeft(coach).dy),
      reason: 'the coach must not head the Pro pitch',
    );

    // The pitch must not resell the coach as the thing being unlocked.
    expect(
      t.subscription.personalizedAiCoach,
      isNot(contains('Personalized AI Coach')),
      reason: 'the old headline framing is back',
    );

    await tester.pump(const Duration(seconds: 3));
  });
}
