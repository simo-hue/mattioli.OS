// The Subscription pane's purchase surface.
//
// Everything here is about the step where money changes hands: the call to
// action naming what is about to be bought, its busy state actually being a
// state, and the plan cards saying which one is selected in more than one
// channel. The compliance disclosures around it live in
// subscription_compliance_test.
import 'dart:ui' show Tristate;

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/settings_navigation.dart';

/// Pins the pane to an exact subscription state.
///
/// The real `build()` listens to auth and fires a store round trip that under
/// `flutter test` resolves to no offering at all — which is exactly the one
/// state that cannot exercise a price, a busy spinner or the already-Pro
/// branch. Only `build()` is replaced, so everything else on the controller
/// stays the real implementation.
class _StubSubscriptionController extends DesktopSubscriptionController {
  _StubSubscriptionController(this.initial);

  final DesktopSubscriptionState initial;

  @override
  DesktopSubscriptionState build() => initial;
}

StoreProduct _product(
  String identifier,
  double price,
  String priceString, {
  String? perMonthString,
}) => StoreProduct(
  identifier,
  identifier,
  identifier,
  price,
  priceString,
  'EUR',
  pricePerMonthString: perMonthString,
);

final _monthly = _product('com.simo.evolve.pro.monthly', 4.99, '€4.99');
final _yearly = _product(
  'com.simo.evolve.pro.yearly',
  35.99,
  '€35.99',
  perMonthString: '€3.00',
);

DesktopSubscriptionState _state({
  bool isPro = false,
  bool isLoading = false,
  bool withPrices = true,
}) => DesktopSubscriptionState(
  isSupportedPlatform: true,
  isConfigured: true,
  isLoading: isLoading,
  isPro: isPro,
  monthlyProduct: withPrices ? _monthly : null,
  yearlyProduct: withPrices ? _yearly : null,
);

/// Pumps Settings and opens the Subscription pane.
///
/// [settle] is false for the busy state: `EvolveSpinner` wraps a
/// `CupertinoActivityIndicator`, which animates forever, so `pumpAndSettle`
/// never returns once one is on screen.
Future<void> _pumpPane(
  WidgetTester tester,
  DesktopSubscriptionState subscription, {
  bool settle = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      desktopSubscriptionControllerProvider.overrideWith(
        () => _StubSubscriptionController(subscription),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.binding.setSurfaceSize(const Size(1440, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: EvolveTheme.dark(EvolveColors.primaryStrong),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en')],
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (settle) {
    await openSettingsSection(tester, SettingsSection.subscription);
    return;
  }
  await tester.tap(find.byKey(SettingsSection.subscription.key));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

final _subscribeButton = find.byKey(SettingsKeys.row('subscription.subscribe'));
final _restoreRow = find.byKey(SettingsKeys.row('subscription.restore'));
final _annualCard = find.byKey(SettingsKeys.row('subscription.planAnnual'));
final _monthlyCard = find.byKey(SettingsKeys.row('subscription.planMonthly'));

/// Whether the plan card under [card] announces itself as selected.
Tristate _selectedFlag(WidgetTester tester, Finder card) =>
    tester.getSemantics(card).getSemanticsData().flagsCollection.isSelected;

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('the CTA names the plan being bought and what it costs', (
    tester,
  ) async {
    await _pumpPane(tester, _state());

    // The annual plan is the default selection, so the button has to say so —
    // before this it read "Activate Evolve Pro" in both cases, which named
    // neither the plan nor the charge.
    expect(
      find.text(
        t.settingsPage.subscribeCta(
          plan: t.settingsPage.planAnnual,
          price: '€35.99',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(_monthlyCard);
    await tester.pumpAndSettle();

    expect(
      find.text(
        t.settingsPage.subscribeCta(
          plan: t.settingsPage.planMonthly,
          price: '€4.99',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('with no resolved price the CTA names the plan and stops there', (
    tester,
  ) async {
    // No offering and no direct product — the state every `flutter test` run
    // and every offline launch is in. A CTA is the last place to invent a
    // figure, and the card beside it already says the price is unavailable.
    await _pumpPane(tester, _state(withPrices: false));

    expect(
      find.text(
        t.settingsPage.subscribeCtaNoPrice(plan: t.settingsPage.planAnnual),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the plan selection survives a rebuild of the pane', (
    tester,
  ) async {
    await _pumpPane(tester, _state());

    await tester.tap(_monthlyCard);
    await tester.pumpAndSettle();

    // Leaving and returning rebuilds the pane from scratch. While the choice
    // was a `State` field it was destroyed here, silently reverting to the
    // annual plan — the larger charge — with the CTA following it.
    await openSettingsSection(tester, SettingsSection.general);
    await openSettingsSection(tester, SettingsSection.subscription);

    expect(_selectedFlag(tester, _monthlyCard), Tristate.isTrue);
    expect(
      find.text(
        t.settingsPage.subscribeCta(
          plan: t.settingsPage.planMonthly,
          price: '€4.99',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a purchase in flight disables the CTA and spins in its place', (
    tester,
  ) async {
    await _pumpPane(tester, _state(isLoading: true), settle: false);

    // The old rows kept the full fill, the hover and the ripple and simply
    // dropped the tap (`busy ? () {} : onTap`) — a live-looking control that
    // did nothing for the length of a purchase.
    final button = tester.widget<FilledButton>(
      find.descendant(
        of: _subscribeButton,
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(
      find.descendant(
        of: _subscribeButton,
        matching: find.byType(EvolveSpinner),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        t.settingsPage.subscribeCta(
          plan: t.settingsPage.planAnnual,
          price: '€35.99',
        ),
      ),
      findsNothing,
      reason: 'the label is replaced by the spinner, not shown beside it',
    );

    // Restore is the other half of the same failure: it shared the swallowed
    // -tap idiom, so it too accepted clicks it never acted on.
    final restoreTile = tester.widget<ListTile>(
      find.descendant(of: _restoreRow, matching: find.byType(ListTile)),
    );
    expect(restoreTile.enabled, isFalse);
  });

  testWidgets('the plan cards expose their selection to the semantics tree', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpPane(tester, _state());

    // Selection used to be an accent tint and nothing else: both cards
    // announced identically, and the difference was invisible to anyone who
    // could not separate the two hues.
    expect(_selectedFlag(tester, _annualCard), Tristate.isTrue);
    expect(_selectedFlag(tester, _monthlyCard), Tristate.isFalse);
    expect(
      tester
          .getSemantics(_annualCard)
          .getSemanticsData()
          .flagsCollection
          .isButton,
      isTrue,
    );

    await tester.tap(_monthlyCard);
    await tester.pumpAndSettle();

    expect(_selectedFlag(tester, _monthlyCard), Tristate.isTrue);
    expect(_selectedFlag(tester, _annualCard), Tristate.isFalse);

    handle.dispose();
  });

  testWidgets('restore renders exactly once, in both subscription states', (
    tester,
  ) async {
    await _pumpPane(tester, _state());
    expect(_restoreRow, findsOneWidget);
    expect(_subscribeButton, findsOneWidget);
  });

  testWidgets('an already-Pro user still gets exactly one restore row', (
    tester,
  ) async {
    // A desynced entitlement — new Mac, reinstall, a purchase made on the
    // iPhone — leaves a paying user with no other way back, which is why this
    // row outlives the purchase. There is one definition of it, so neither
    // state can grow a second copy.
    await _pumpPane(tester, _state(isPro: true));

    expect(_restoreRow, findsOneWidget);
    expect(find.text(t.settingsPage.restorePurchases), findsOneWidget);
    expect(
      _subscribeButton,
      findsNothing,
      reason: 'nothing left to buy once Pro is active',
    );
  });
}
