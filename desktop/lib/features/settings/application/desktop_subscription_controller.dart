import 'dart:async';
import 'dart:io';

import 'package:evolve_legal/evolve_legal.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_revenuecat_config.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  /// Entitlement cache key, scoped per account like the dashboard cache
  /// (`desktop_dashboard_cache_$userId`). This provider is never autoDisposed
  /// nor invalidated on sign-out, so an unscoped key would hand the previous
  /// account's Pro to whoever signs in next on the same Mac.
  static String _proCacheKey(String userId) => 'pref_is_pro_$userId';

  /// The unscoped key this cache used before it was per-account. It records no
  /// owner, so it can only ever re-seed the wrong account: drop it, never
  /// migrate it. An affected payer is re-seeded by the first online refresh.
  static const _legacyProCacheKey = 'pref_is_pro';

  String? _configuredUserId;
  bool _customerInfoListenerRegistered = false;

  @override
  DesktopSubscriptionState build() {
    final supported = Platform.isMacOS;
    final configured = supported && DesktopRevenueCatConfig.isConfigured;
    ref.listen(desktopAuthControllerProvider, (previous, next) {
      final nextUser = next.user;
      if (nextUser == null) {
        // Nothing else resets this provider on sign-out, so the entitlement has
        // to be dropped here or it survives into the next account's session.
        state = state.copyWith(isPro: false);
        final wasConfigured = _configuredUserId != null;
        _configuredUserId = null;
        if (wasConfigured) unawaited(_logOutRevenueCat());
        return;
      }
      // Supabase re-emits this state on every token refresh; only a real
      // account change needs a round-trip.
      if (previous?.user?.id != nextUser.id) unawaited(refresh());
    });
    final userId = ref.read(desktopAuthControllerProvider).user?.id;
    final preferences = ref.read(sharedPreferencesProvider);
    unawaited(preferences?.remove(_legacyProCacheKey));
    // Seed isPro offline-first from the signed-in account's cached pref so a
    // paying user launching offline (or during a transient RevenueCat failure)
    // keeps Pro until the async refresh resolves — mobile hydrates the same way.
    // Self-heals online. No account signed in means no entitlement to seed.
    final cachedPro = userId == null
        ? false
        : (preferences?.getBool(_proCacheKey(userId)) ?? false);
    final initial = DesktopSubscriptionState(
      isSupportedPlatform: supported,
      isConfigured: configured,
      isPro: cachedPro,
    );
    if (userId != null) {
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
        message: t.subscriptionCtrl.loadOffersFailed,
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
      var isPro = _hasActiveProAccess(purchase.customerInfo);

      // RevenueCat's CustomerInfo cache is eventually-consistent, so a real
      // purchase can momentarily read back as not-Pro. Sync + invalidate +
      // refetch before believing that (mobile parity).
      if (!isPro) {
        try {
          await Purchases.syncPurchases();
          await Purchases.invalidateCustomerInfoCache();
          isPro = _hasActiveProAccess(await Purchases.getCustomerInfo());
        } catch (e, stack) {
          AppLogger.warning(
            'Purchase completed but the RevenueCat sync fallback failed',
            e,
            stack,
          );
        }
      }

      state = state.copyWith(
        isLoading: false,
        isPro: isPro,
        message: isPro
            ? t.subscriptionCtrl.proActivated
            : t.subscriptionCtrl.purchaseComplete,
      );
      await _persistProStatus(isPro);
      return isPro;
    } on PlatformException catch (error, stack) {
      // Already-purchased (re-buying an active sub) → auto-restore instead of
      // surfacing a failure (mobile parity).
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.productAlreadyPurchasedError) {
        AppLogger.info('Product already purchased; auto-restoring');
        return restore();
      }
      AppLogger.error('RevenueCat purchase failed', error, stack);
      state = state.copyWith(
        isLoading: false,
        message: t.subscriptionCtrl.purchaseIncomplete,
      );
      return false;
    } catch (error, stack) {
      AppLogger.error('RevenueCat purchase failed', error, stack);
      state = state.copyWith(
        isLoading: false,
        message: t.subscriptionCtrl.purchaseIncomplete,
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
      var isPro = _hasActiveProAccess(customerInfo);

      // Refresh once against a cleared cache before concluding "no active sub"
      // (mobile parity), to avoid a stale false-negative right after restore.
      if (!isPro) {
        try {
          await Purchases.invalidateCustomerInfoCache();
          isPro = _hasActiveProAccess(await Purchases.getCustomerInfo());
        } catch (e, stack) {
          AppLogger.warning(
            'Restore completed but the CustomerInfo refresh failed',
            e,
            stack,
          );
        }
      }

      state = state.copyWith(
        isLoading: false,
        isPro: isPro,
        message: isPro
            ? t.subscriptionCtrl.purchasesRestored
            : t.subscriptionCtrl.noActiveSub,
      );
      await _persistProStatus(isPro);
      return isPro;
    } catch (error, stack) {
      AppLogger.error('RevenueCat restore failed', error, stack);
      state = state.copyWith(
        isLoading: false,
        message: t.subscriptionCtrl.restoreFailed,
      );
      return false;
    }
  }

  Future<void> manageSubscription() async {
    final uri = LegalUrls.manageSubscriptions;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      state = state.copyWith(message: t.subscriptionCtrl.cantOpenApple);
    }
  }

  bool _canUseRevenueCat() {
    if (!state.isSupportedPlatform) {
      state = state.copyWith(message: t.subscriptionCtrl.macOnly);
      return false;
    }
    if (!state.isConfigured) {
      state = state.copyWith(message: t.subscriptionCtrl.configKey);
      return false;
    }
    if (ref.read(desktopAuthControllerProvider).user == null) {
      state = state.copyWith(message: t.subscriptionCtrl.loginFirst);
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
    _ensureCustomerInfoListener();
  }

  /// Detaches RevenueCat from the account that just signed out, so a later
  /// CustomerInfo push carries no entitlement of theirs. Best-effort: it fails
  /// offline or when Purchases was never configured, and neither is worth
  /// surfacing on a sign-out the user already completed.
  Future<void> _logOutRevenueCat() async {
    try {
      if (await Purchases.isConfigured) await Purchases.logOut();
    } catch (error, stack) {
      AppLogger.warning('RevenueCat sign-out failed', error, stack);
    }
  }

  /// Keeps isPro live: RevenueCat pushes CustomerInfo on renewal, expiry,
  /// cross-device purchase, or billing lapse — without this, desktop only
  /// recomputes on auth change or an explicit refresh/purchase/restore. Mirrors
  /// mobile's `addCustomerInfoUpdateListener`. Registered once.
  void _ensureCustomerInfoListener() {
    if (_customerInfoListenerRegistered) return;
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      // The push carries the CustomerInfo of whoever Purchases is logged in as.
      // If that is no longer the signed-in account — a sign-out whose logOut
      // failed offline, or a push landing before _configure() switched user —
      // applying it would hand the previous account's entitlement to this one.
      if (_configuredUserId == null ||
          _configuredUserId != ref.read(desktopAuthControllerProvider).user?.id) {
        return;
      }
      final isPro = _hasActiveProAccess(customerInfo);
      state = state.copyWith(isPro: isPro);
      unawaited(_persistProStatus(isPro));
    });
    _customerInfoListenerRegistered = true;
  }

  bool _hasActiveProAccess(CustomerInfo customerInfo) {
    for (final id in entitlementIds) {
      if (customerInfo.entitlements.all[id]?.isActive ?? false) return true;
    }
    for (final entitlement in customerInfo.entitlements.active.values) {
      if (proProductIds.contains(entitlement.productIdentifier)) return true;
    }
    if (customerInfo.activeSubscriptions.any(proProductIds.contains)) {
      return true;
    }

    // Fallback (mobile parity): ANY active entitlement grants Pro. Covers a
    // renamed / mis-whitelisted entitlement so a legitimately-paying user isn't
    // locked out of Pro after a real purchase.
    if (customerInfo.entitlements.active.isNotEmpty) {
      AppLogger.warning(
        '[Subscription] granting Pro via a non-whitelisted active entitlement',
      );
      return true;
    }
    return false;
  }

  Future<void> _persistProStatus(bool isPro) async {
    // Read the account at write time, not at call time: the awaits upstream of
    // this leave room for a sign-out, and a cache written without an owner is
    // the leak this key is scoped to prevent.
    final userId = ref.read(desktopAuthControllerProvider).user?.id;
    if (userId == null) return;
    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences != null) {
      await preferences.setBool(_proCacheKey(userId), isPro);
    }
  }
}
