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

/// Outcome of a purchase attempt, so the UI can pick the right feedback
/// (success dialog, silent on cancel, informative toast on failure) instead of
/// the controller owning presentation. Mirrors the mobile paywall's handling.
enum DesktopPurchaseStatus {
  /// Pro is active — show the celebratory success dialog.
  activated,

  /// The store accepted the purchase but the entitlement has not propagated
  /// yet; the user should wait and use Restore.
  registeredNotActive,

  /// A deferred/pending transaction (e.g. Ask to Buy) — parked, not failed.
  pending,

  /// The user dismissed the payment sheet — stay silent.
  cancelled,

  /// A real failure — surface [DesktopPurchaseResult.message].
  failed,
}

class DesktopPurchaseResult {
  const DesktopPurchaseResult(this.status, [this.message]);
  final DesktopPurchaseStatus status;

  /// Localized, user-facing message for [DesktopPurchaseStatus.failed] /
  /// `pending`. Null when nothing should be shown.
  final String? message;
}

enum DesktopRestoreStatus { restored, noActiveSub, cancelled, failed }

class DesktopRestoreResult {
  const DesktopRestoreResult(this.status, [this.message]);
  final DesktopRestoreStatus status;
  final String? message;
}

/// Presentation-ready snapshot of the active Pro entitlement, so the UI can
/// render the "already Pro" details panel without importing RevenueCat types.
class DesktopProDetails {
  const DesktopProDetails({
    this.productIdentifier,
    this.willRenew = false,
    this.expiration,
    this.isAppStorePayment = false,
  });

  final String? productIdentifier;
  final bool willRenew;

  /// Next-renewal / expiry instant (local time), or null for a non-expiring or
  /// unresolved entitlement — the row is then omitted rather than faked.
  final DateTime? expiration;
  final bool isAppStorePayment;
}

class DesktopSubscriptionState {
  const DesktopSubscriptionState({
    required this.isSupportedPlatform,
    required this.isConfigured,
    this.isLoading = false,
    this.isPro = false,
    this.monthlyPackage,
    this.yearlyPackage,
    this.monthlyProduct,
    this.yearlyProduct,
    this.customerInfo,
    this.message,
  });

  final bool isSupportedPlatform;
  final bool isConfigured;
  final bool isLoading;
  final bool isPro;
  final Package? monthlyPackage;
  final Package? yearlyPackage;

  /// The store products actually in play, resolved from the Offering package or
  /// — when no Offering is published — a direct product fetch. Everything
  /// price-related reads these so the two resolution paths cannot drift apart.
  final StoreProduct? monthlyProduct;
  final StoreProduct? yearlyProduct;

  /// Last resolved entitlement snapshot, feeding the "already Pro" panel.
  final CustomerInfo? customerInfo;
  final String? message;

  DesktopSubscriptionState copyWith({
    bool? isLoading,
    bool? isPro,
    Package? monthlyPackage,
    Package? yearlyPackage,
    StoreProduct? monthlyProduct,
    StoreProduct? yearlyProduct,
    CustomerInfo? customerInfo,
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
      monthlyProduct: monthlyProduct ?? this.monthlyProduct,
      yearlyProduct: yearlyProduct ?? this.yearlyProduct,
      customerInfo: customerInfo ?? this.customerInfo,
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
  static const _monthlyProductId = 'com.simo.evolve.pro.monthly';
  static const _yearlyProductId = 'com.simo.evolve.pro.yearly';
  static const proProductIds = {_monthlyProductId, _yearlyProductId};
  static const _proProductIdList = [_monthlyProductId, _yearlyProductId];

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

      // Two-tier price resolution (mobile parity). Prefer the published
      // Offering; if it hasn't been configured yet, fall back to fetching the
      // raw store products so prices still render (and the annual saving can
      // still be computed) before an Offering exists. An Offering failure alone
      // must not blank the surface, so it is caught locally rather than aborting
      // the whole refresh.
      Package? monthlyPackage;
      Package? yearlyPackage;
      try {
        final current = (await Purchases.getOfferings()).current;
        monthlyPackage = current?.monthly;
        yearlyPackage = current?.annual;
      } catch (error, stack) {
        AppLogger.warning(
          'Unable to load offerings; will try products',
          error,
          stack,
        );
      }

      StoreProduct? monthlyProduct = monthlyPackage?.storeProduct;
      StoreProduct? yearlyProduct = yearlyPackage?.storeProduct;
      if (monthlyProduct == null || yearlyProduct == null) {
        try {
          final products = await Purchases.getProducts(_proProductIdList);
          for (final product in products) {
            if (product.identifier == _monthlyProductId) {
              monthlyProduct ??= product;
            } else if (product.identifier == _yearlyProductId) {
              yearlyProduct ??= product;
            }
          }
        } catch (error, stack) {
          AppLogger.warning('Unable to load store products', error, stack);
        }
      }

      // Commit the resolved prices/packages BEFORE the entitlement fetch, so a
      // getCustomerInfo failure (which drops to the outer catch) still leaves
      // the prices on screen — mobile keeps the two independent, and blanking a
      // resolved price on an unrelated entitlement hiccup is exactly the failure
      // the fallback exists to prevent. isPro is deliberately NOT touched here:
      // it stays at its offline-first seed until the entitlement resolves below.
      state = state.copyWith(
        monthlyPackage: monthlyPackage,
        yearlyPackage: yearlyPackage,
        monthlyProduct: monthlyProduct,
        yearlyProduct: yearlyProduct,
      );

      // The entitlement is the source of truth for isPro. Fetch it last and
      // unguarded: if it throws (offline, or no store plugin under `flutter
      // test`), the outer catch leaves the offline-first seeded isPro untouched
      // — the guarantee subscription_entitlement_scope_test pins.
      final customerInfo = await Purchases.getCustomerInfo();
      // Several awaits have passed since this refresh began (configure, the
      // offering fetch, the customer-info fetch), and refresh() is called
      // fire-and-forget from build(). The notifier can therefore be gone by now
      // — a data-mode switch, a sign-out, or simply a widget test finishing —
      // and writing `state` on a disposed Ref throws.
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        isPro: _hasActiveProAccess(customerInfo),
        customerInfo: customerInfo,
      );
      await _persistProStatus(state.isPro);
    } catch (error, stack) {
      AppLogger.error('Unable to refresh subscription state', error, stack);
      // Same guard on the failure path, and it is the one that actually bit:
      // `Purchases.setLogLevel` throws MissingPluginException under
      // `flutter test` (the RevenueCat key has a committed defaultValue, so
      // `isConfigured` is true and the plugin IS reached), the catch ran after
      // the test had disposed its container, and the resulting "Ref used after
      // dispose" was misfiled for weeks as a parallel-load flake.
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        message: t.subscriptionCtrl.loadOffersFailed,
      );
    }
  }

  Future<DesktopPurchaseResult> purchase(Package package) async {
    if (!_canUseRevenueCat()) {
      // `_canUseRevenueCat` already set the reason on state.message.
      return DesktopPurchaseResult(DesktopPurchaseStatus.failed, state.message);
    }
    state = state.copyWith(isLoading: true, clearMessage: true);
    try {
      await _configure();
      final purchase = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      var customerInfo = purchase.customerInfo;
      var isPro = _hasActiveProAccess(customerInfo);

      // RevenueCat's CustomerInfo cache is eventually-consistent, so a real
      // purchase can momentarily read back as not-Pro. Sync + invalidate +
      // refetch before believing that (mobile parity).
      if (!isPro) {
        try {
          await Purchases.syncPurchases();
          await Purchases.invalidateCustomerInfoCache();
          customerInfo = await Purchases.getCustomerInfo();
          isPro = _hasActiveProAccess(customerInfo);
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
        customerInfo: customerInfo,
      );
      await _persistProStatus(isPro);
      return DesktopPurchaseResult(
        isPro
            ? DesktopPurchaseStatus.activated
            : DesktopPurchaseStatus.registeredNotActive,
      );
    } on PlatformException catch (error, stack) {
      final code = _errorCode(error);

      // Already-purchased (re-buying an active sub) → auto-restore instead of
      // surfacing a failure (mobile parity). Map the restore outcome onto
      // purchase semantics so the user sees what the direct path would give:
      // a cancelled restore prompt stays silent, and an entitlement that hasn't
      // propagated yet is the benign "registered, not active" warning — never a
      // hard error. Only a genuine restore failure surfaces as a failure.
      if (code == PurchasesErrorCode.productAlreadyPurchasedError) {
        AppLogger.info('Product already purchased; auto-restoring');
        final restored = await restore();
        return switch (restored.status) {
          DesktopRestoreStatus.restored => const DesktopPurchaseResult(
            DesktopPurchaseStatus.activated,
          ),
          DesktopRestoreStatus.noActiveSub => const DesktopPurchaseResult(
            DesktopPurchaseStatus.registeredNotActive,
          ),
          DesktopRestoreStatus.cancelled => const DesktopPurchaseResult(
            DesktopPurchaseStatus.cancelled,
          ),
          DesktopRestoreStatus.failed => DesktopPurchaseResult(
            DesktopPurchaseStatus.failed,
            restored.message,
          ),
        };
      }

      state = state.copyWith(isLoading: false);

      // A user-dismissed payment sheet is not a failure — stay silent.
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const DesktopPurchaseResult(DesktopPurchaseStatus.cancelled);
      }

      // A deferred/pending transaction is parked awaiting approval, not failed.
      final pending =
          code == PurchasesErrorCode.paymentPendingError ||
          code == PurchasesErrorCode.operationAlreadyInProgressError;
      AppLogger.error('RevenueCat purchase failed', error, stack);
      return DesktopPurchaseResult(
        pending ? DesktopPurchaseStatus.pending : DesktopPurchaseStatus.failed,
        _purchaseErrorMessage(error),
      );
    } catch (error, stack) {
      AppLogger.error('RevenueCat purchase failed', error, stack);
      state = state.copyWith(isLoading: false);
      return DesktopPurchaseResult(
        DesktopPurchaseStatus.failed,
        _purchaseErrorMessage(error),
      );
    }
  }

  Future<DesktopRestoreResult> restore() async {
    if (!_canUseRevenueCat()) {
      return DesktopRestoreResult(DesktopRestoreStatus.failed, state.message);
    }
    state = state.copyWith(isLoading: true, clearMessage: true);
    try {
      await _configure();
      var customerInfo = await Purchases.restorePurchases();
      var isPro = _hasActiveProAccess(customerInfo);

      // Refresh once against a cleared cache before concluding "no active sub"
      // (mobile parity), to avoid a stale false-negative right after restore.
      if (!isPro) {
        try {
          await Purchases.invalidateCustomerInfoCache();
          customerInfo = await Purchases.getCustomerInfo();
          isPro = _hasActiveProAccess(customerInfo);
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
        customerInfo: customerInfo,
      );
      await _persistProStatus(isPro);
      return DesktopRestoreResult(
        isPro
            ? DesktopRestoreStatus.restored
            : DesktopRestoreStatus.noActiveSub,
      );
    } on PlatformException catch (error, stack) {
      state = state.copyWith(isLoading: false);
      if (_errorCode(error) == PurchasesErrorCode.purchaseCancelledError) {
        return const DesktopRestoreResult(DesktopRestoreStatus.cancelled);
      }
      AppLogger.error('RevenueCat restore failed', error, stack);
      return DesktopRestoreResult(
        DesktopRestoreStatus.failed,
        _restoreErrorMessage(error),
      );
    } catch (error, stack) {
      AppLogger.error('RevenueCat restore failed', error, stack);
      state = state.copyWith(isLoading: false);
      return DesktopRestoreResult(
        DesktopRestoreStatus.failed,
        _restoreErrorMessage(error),
      );
    }
  }

  /// Opens Apple's subscription-management page (where a subscription is
  /// cancelled or changed). Returns false if the URL could not be opened, so
  /// the UI can surface it; RevenueCat's in-app Customer Center is iOS/Android
  /// only, so the external page is the macOS-correct surface.
  Future<bool> manageSubscription() {
    return launchUrl(
      LegalUrls.manageSubscriptions,
      mode: LaunchMode.externalApplication,
    );
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
          _configuredUserId !=
              ref.read(desktopAuthControllerProvider).user?.id) {
        return;
      }
      final isPro = _hasActiveProAccess(customerInfo);
      state = state.copyWith(isPro: isPro, customerInfo: customerInfo);
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

  /// The entitlement that actually grants Pro, resolved with the same
  /// precedence as [_hasActiveProAccess]. Null when Pro comes from a bare
  /// active subscription with no entitlement, or nothing grants it.
  EntitlementInfo? _activeProEntitlement(CustomerInfo customerInfo) {
    for (final id in entitlementIds) {
      final entitlement = customerInfo.entitlements.all[id];
      if (entitlement?.isActive ?? false) return entitlement;
    }
    for (final entitlement in customerInfo.entitlements.active.values) {
      if (proProductIds.contains(entitlement.productIdentifier)) {
        return entitlement;
      }
    }
    return customerInfo.entitlements.active.values.isEmpty
        ? null
        : customerInfo.entitlements.active.values.first;
  }

  /// Presentation snapshot of the active Pro entitlement for the details panel.
  /// Null when there is no CustomerInfo yet; an empty [DesktopProDetails] when
  /// Pro is granted without a resolvable entitlement (rows are then omitted).
  DesktopProDetails? proDetails() {
    final customerInfo = state.customerInfo;
    if (customerInfo == null) return null;
    final entitlement = _activeProEntitlement(customerInfo);
    if (entitlement == null) return const DesktopProDetails();

    // `expirationDate` is a nullable ISO-8601 string, absent for non-expiring
    // entitlements. Unparseable or absent means the row is omitted, never faked.
    final rawExpiration = entitlement.expirationDate;
    final expiration = rawExpiration == null
        ? null
        : DateTime.tryParse(rawExpiration)?.toLocal();
    return DesktopProDetails(
      productIdentifier: entitlement.productIdentifier,
      willRenew: entitlement.willRenew,
      expiration: expiration,
      isAppStorePayment:
          entitlement.store == Store.appStore ||
          entitlement.store == Store.macAppStore,
    );
  }

  static PurchasesErrorCode? _errorCode(PlatformException exception) {
    try {
      return PurchasesErrorHelper.getErrorCode(exception);
    } catch (_) {
      return null;
    }
  }

  /// Maps a purchase error to localized, user-facing copy. Mirrors the mobile
  /// paywall's mapping; deliberately names no vendor or SDK (desktop keeps its
  /// monetization copy free of implementation detail — see
  /// subscription_compliance_test).
  static String _purchaseErrorMessage(Object error) {
    if (error is PlatformException) {
      if (_isPaidAppsAgreement(error)) {
        return t.subscriptionCtrl.paidAppsAgreement;
      }
      return switch (_errorCode(error)) {
        PurchasesErrorCode.productAlreadyPurchasedError =>
          t.subscriptionCtrl.alreadyPurchased,
        PurchasesErrorCode.purchaseNotAllowedError =>
          t.subscriptionCtrl.purchasesNotAllowed,
        PurchasesErrorCode.productNotAvailableForPurchaseError =>
          t.subscriptionCtrl.planUnavailable,
        PurchasesErrorCode.paymentPendingError =>
          t.subscriptionCtrl.paymentPending,
        PurchasesErrorCode.networkError ||
        PurchasesErrorCode.offlineConnectionError ||
        PurchasesErrorCode.apiEndpointBlocked =>
          t.subscriptionCtrl.connectionUnavailable,
        PurchasesErrorCode.configurationError ||
        PurchasesErrorCode.invalidCredentialsError ||
        PurchasesErrorCode.invalidReceiptError ||
        PurchasesErrorCode.missingReceiptFileError =>
          t.subscriptionCtrl.invalidConfig,
        PurchasesErrorCode.receiptAlreadyInUseError ||
        PurchasesErrorCode.receiptInUseByOtherSubscriberError ||
        PurchasesErrorCode.purchaseBelongsToOtherUser =>
          t.subscriptionCtrl.linkedToAnotherAccount,
        PurchasesErrorCode.operationAlreadyInProgressError =>
          t.subscriptionCtrl.purchaseInProgress,
        _ => t.subscriptionCtrl.purchaseFailedMessage,
      };
    }
    return t.subscriptionCtrl.purchaseFailedMessage;
  }

  static String _restoreErrorMessage(Object error) {
    if (error is PlatformException) {
      if (_isPaidAppsAgreement(error)) {
        return t.subscriptionCtrl.paidAppsAgreement;
      }
      return switch (_errorCode(error)) {
        PurchasesErrorCode.networkError ||
        PurchasesErrorCode.offlineConnectionError ||
        PurchasesErrorCode.apiEndpointBlocked =>
          t.subscriptionCtrl.connectionUnavailable,
        PurchasesErrorCode.receiptAlreadyInUseError ||
        PurchasesErrorCode.receiptInUseByOtherSubscriberError ||
        PurchasesErrorCode.purchaseBelongsToOtherUser =>
          t.subscriptionCtrl.linkedToAnotherAccount,
        PurchasesErrorCode.configurationError ||
        PurchasesErrorCode.invalidCredentialsError ||
        PurchasesErrorCode.invalidReceiptError ||
        PurchasesErrorCode.missingReceiptFileError =>
          t.subscriptionCtrl.invalidConfig,
        PurchasesErrorCode.operationAlreadyInProgressError =>
          t.subscriptionCtrl.restoreInProgress,
        _ => t.subscriptionCtrl.restoreFailedMessage,
      };
    }
    return t.subscriptionCtrl.restoreFailedMessage;
  }

  /// The store surfaces the un-signed Paid Apps agreement as a generic error;
  /// match on its text so the user gets an actionable message instead of a
  /// bare failure (mobile parity).
  static bool _isPaidAppsAgreement(PlatformException error) {
    final msg = error.message?.toLowerCase() ?? '';
    final details = error.details?.toString().toLowerCase() ?? '';
    return msg.contains('paid apps agreement') ||
        msg.contains('paid applications agreement') ||
        details.contains('paid apps agreement') ||
        details.contains('paid applications agreement');
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
