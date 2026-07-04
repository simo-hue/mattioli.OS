import 'dart:async';
import 'dart:io';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_revenuecat_config.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DesktopSubscriptionState {
  const DesktopSubscriptionState({
    required this.isSupportedPlatform,
    required this.isConfigured,
    this.isLoading = false,
    this.isPro = false,
    this.monthlyPackage,
    this.yearlyPackage,
    this.message,
  });

  final bool isSupportedPlatform;
  final bool isConfigured;
  final bool isLoading;
  final bool isPro;
  final Package? monthlyPackage;
  final Package? yearlyPackage;
  final String? message;

  DesktopSubscriptionState copyWith({
    bool? isLoading,
    bool? isPro,
    Package? monthlyPackage,
    Package? yearlyPackage,
    String? message,
    bool clearMessage = false,
  }) {
    return DesktopSubscriptionState(
      isSupportedPlatform: isSupportedPlatform,
      isConfigured: isConfigured,
      isLoading: isLoading ?? this.isLoading,
      isPro: isPro ?? this.isPro,
      monthlyPackage: monthlyPackage ?? this.monthlyPackage,
      yearlyPackage: yearlyPackage ?? this.yearlyPackage,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

final desktopSubscriptionControllerProvider =
    NotifierProvider<DesktopSubscriptionController, DesktopSubscriptionState>(
      DesktopSubscriptionController.new,
    );

/// Effective Pro entitlement used by feature gates.
///
/// In Private mode every feature is unlocked without a subscription (mirrors the
/// mobile client's forced `isPro`); otherwise it reflects the RevenueCat
/// entitlement. Feature gates should read THIS provider. Pro badges / paywalls /
/// upgrade prompts stay gated on `!isPrivateMode` so no monetization UI appears
/// in Private mode even though it is entitled.
final desktopIsProProvider = Provider<bool>((ref) {
  if (ref.watch(activeDesktopDataModeProvider).isPrivate) return true;
  return ref.watch(desktopSubscriptionControllerProvider).isPro;
});

class DesktopSubscriptionController extends Notifier<DesktopSubscriptionState> {
  static const entitlementIds = {'Evolve Pro', 'evolve_pro', 'pro'};
  static const proProductIds = {
    'com.simo.evolve.pro.monthly',
    'com.simo.evolve.pro.yearly',
  };

  String? _configuredUserId;

  @override
  DesktopSubscriptionState build() {
    final supported = Platform.isMacOS;
    final configured = supported && DesktopRevenueCatConfig.isConfigured;
    ref.listen(desktopAuthControllerProvider, (_, next) {
      if (next.user != null) unawaited(refresh());
    });
    final initial = DesktopSubscriptionState(
      isSupportedPlatform: supported,
      isConfigured: configured,
    );
    if (ref.read(desktopAuthControllerProvider).user != null) {
      unawaited(Future<void>.microtask(refresh));
    }
    return initial;
  }

  Future<void> refresh() async {
    if (!_canUseRevenueCat()) return;
    state = state.copyWith(isLoading: true, clearMessage: true);
    try {
      await _configure();
      final offerings = await Purchases.getOfferings();
      final customerInfo = await Purchases.getCustomerInfo();
      final current = offerings.current;
      state = state.copyWith(
        isLoading: false,
        isPro: _hasActiveProAccess(customerInfo),
        monthlyPackage: current?.monthly,
        yearlyPackage: current?.annual,
      );
      await _persistProStatus(state.isPro);
    } catch (error, stack) {
      AppLogger.error('Unable to refresh RevenueCat offerings', error, stack);
      state = state.copyWith(
        isLoading: false,
        message: 'Impossibile caricare le offerte RevenueCat.',
      );
    }
  }

  Future<bool> purchase(Package package) async {
    if (!_canUseRevenueCat()) return false;
    state = state.copyWith(isLoading: true, clearMessage: true);
    try {
      await _configure();
      final purchase = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      final isPro = _hasActiveProAccess(purchase.customerInfo);
      state = state.copyWith(
        isLoading: false,
        isPro: isPro,
        message: isPro
            ? 'Evolve Pro attivato.'
            : 'Acquisto completato: sincronizzazione entitlement in corso.',
      );
      await _persistProStatus(isPro);
      return isPro;
    } catch (error, stack) {
      AppLogger.error('RevenueCat purchase failed', error, stack);
      state = state.copyWith(
        isLoading: false,
        message: 'Acquisto non completato.',
      );
      return false;
    }
  }

  Future<bool> restore() async {
    if (!_canUseRevenueCat()) return false;
    state = state.copyWith(isLoading: true, clearMessage: true);
    try {
      await _configure();
      final customerInfo = await Purchases.restorePurchases();
      final isPro = _hasActiveProAccess(customerInfo);
      state = state.copyWith(
        isLoading: false,
        isPro: isPro,
        message: isPro
            ? 'Acquisti ripristinati.'
            : 'Nessun abbonamento Pro attivo trovato.',
      );
      await _persistProStatus(isPro);
      return isPro;
    } catch (error, stack) {
      AppLogger.error('RevenueCat restore failed', error, stack);
      state = state.copyWith(
        isLoading: false,
        message: 'Ripristino acquisti non riuscito.',
      );
      return false;
    }
  }

  Future<void> manageSubscription() async {
    final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      state = state.copyWith(
        message: 'Impossibile aprire la gestione abbonamenti Apple.',
      );
    }
  }

  bool _canUseRevenueCat() {
    if (!state.isSupportedPlatform) {
      state = state.copyWith(
        message: 'Gli acquisti in-app sono disponibili nel client macOS.',
      );
      return false;
    }
    if (!state.isConfigured) {
      state = state.copyWith(
        message: 'Configura la public key RevenueCat del client desktop.',
      );
      return false;
    }
    if (ref.read(desktopAuthControllerProvider).user == null) {
      state = state.copyWith(message: 'Accedi prima di gestire Evolve Pro.');
      return false;
    }
    return true;
  }

  Future<void> _configure() async {
    final userId = ref.read(desktopAuthControllerProvider).user!.id;
    if (_configuredUserId == userId && await Purchases.isConfigured) return;

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
    if (await Purchases.isConfigured) {
      await Purchases.logIn(userId);
    } else {
      final configuration = PurchasesConfiguration(
        DesktopRevenueCatConfig.appleApiKey,
      )..appUserID = userId;
      await Purchases.configure(configuration);
    }
    _configuredUserId = userId;
  }

  bool _hasActiveProAccess(CustomerInfo customerInfo) {
    for (final id in entitlementIds) {
      if (customerInfo.entitlements.all[id]?.isActive ?? false) return true;
    }
    for (final entitlement in customerInfo.entitlements.active.values) {
      if (proProductIds.contains(entitlement.productIdentifier)) return true;
    }
    return customerInfo.activeSubscriptions.any(proProductIds.contains);
  }

  Future<void> _persistProStatus(bool isPro) async {
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences != null) await preferences.setBool('pref_is_pro', isPro);
  }
}
