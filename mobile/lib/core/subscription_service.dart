import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../providers/settings_provider.dart';
import 'revenuecat_config.dart';
import 'app_logger.dart';

final subscriptionServiceProvider = Provider((ref) => SubscriptionService(ref));

class SubscriptionAccessStatus {
  final bool isActive;
  final String? matchedEntitlementId;
  final String? matchedProductId;
  final bool usedGenericEntitlementFallback;

  const SubscriptionAccessStatus({
    required this.isActive,
    this.matchedEntitlementId,
    this.matchedProductId,
    this.usedGenericEntitlementFallback = false,
  });
}

class SubscriptionOperationResult {
  final bool isProActive;
  final CustomerInfo customerInfo;
  final SubscriptionAccessStatus accessStatus;

  const SubscriptionOperationResult({
    required this.isProActive,
    required this.customerInfo,
    required this.accessStatus,
  });
}

class SubscriptionService {
  final Ref _ref;

  /// The official Entitlement ID configured on the RevenueCat Dashboard for premium access.
  static const String entitlementId = 'Evolve Pro';
  static const Set<String> entitlementIds = {
    entitlementId,
    'evolve_pro',
    'pro',
  };
  static const Set<String> proProductIds = {
    'com.simo.evolve.pro.monthly',
    'com.simo.evolve.pro.yearly',
  };

  static String? _configuredUserUuid;
  static Future<void>? _configurationFuture;
  static bool _customerInfoListenerRegistered = false;

  SubscriptionService(this._ref);

  /// Initializes the RevenueCat SDK and maps it to the current user's Supabase UUID.
  /// Sets up debug logging in development mode and applies configurations.
  Future<void> init(String userUuid) async {
    try {
      if (_configuredUserUuid == userUuid && await Purchases.isConfigured) {
        return;
      }

      if (_configurationFuture != null) {
        await _configurationFuture;
        if (_configuredUserUuid == userUuid && await Purchases.isConfigured) {
          return;
        }
      }

      _configurationFuture = _configureForUser(userUuid);
      await _configurationFuture;
    } catch (e, stack) {
      AppLogger.error(
        'Errore nell\'inizializzazione di RevenueCat SDK',
        e,
        stack,
      );
    } finally {
      _configurationFuture = null;
    }
  }

  Future<void> _configureForUser(String userUuid) async {
    // Set verbose logging in debug mode to trace StoreKit cycles
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);

    if (await Purchases.isConfigured) {
      final loginResult = await Purchases.logIn(userUuid);
      _syncLocalStatus(loginResult.customerInfo, source: 'revenuecat-login');
    } else {
      // Configure purchases_flutter with the static API key and current user's identifier
      PurchasesConfiguration configuration = PurchasesConfiguration(
        RevenueCatConfig.apiKey,
      )..appUserID = userUuid;
      await Purchases.configure(configuration);
    }

    _configuredUserUuid = userUuid;
    _ensureCustomerInfoListener();

    AppLogger.info(
      'RevenueCat SDK configurato con successo per l\'utente: $userUuid',
    );

    // Check current entitlements immediately to sync client cache
    await checkAndSyncStatus();
  }

  /// Checks active entitlements on RevenueCat and synchronizes Evolve's local `isPro` state.
  /// Returns `true` if the user has the 'Evolve Pro' entitlement active.
  Future<bool> checkAndSyncStatus() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      final accessStatus = _syncLocalStatus(
        customerInfo,
        source: 'revenuecat-check',
      );
      return accessStatus.isActive;
    } catch (e, stack) {
      AppLogger.error(
        'Errore nel recupero delle info abbonamento da RevenueCat',
        e,
        stack,
      );
      return false;
    }
  }

  /// Retrieves the current available offerings configured in your RevenueCat Dashboard.
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e, stack) {
      AppLogger.error(
        'Errore nel recupero delle Offerte da RevenueCat',
        e,
        stack,
      );
      return null;
    }
  }

  /// Purchases a specific RevenueCat Package (supports Monthly, Yearly, Lifetime).
  /// Automatically updates global app settings to PRO if the purchase is successful.
  Future<bool> purchasePackage(Package package) async {
    final result = await purchasePackageWithResult(package);
    return result.isProActive;
  }

  Future<SubscriptionOperationResult> purchasePackageWithResult(
    Package package,
  ) async {
    try {
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      var result = await _resultFromCustomerInfo(
        purchaseResult.customerInfo,
        source: 'revenuecat-purchase',
      );

      if (!result.isProActive) {
        try {
          await Purchases.syncPurchases();
          await Purchases.invalidateCustomerInfoCache();
          result = await _resultFromFreshCustomerInfo(
            source: 'revenuecat-purchase-sync-fallback',
          );
        } catch (e, stack) {
          AppLogger.warning(
            'Acquisto completato ma fallback sync RevenueCat non riuscito',
            e,
            stack,
          );
        }
      }

      return result;
    } on PlatformException catch (e, stack) {
      final errorCode = purchasesErrorCode(e);
      if (errorCode == PurchasesErrorCode.productAlreadyPurchasedError) {
        AppLogger.info(
          'Prodotto gia acquistato: avvio restore automatico dopo azione utente.',
          category: 'subscriptions',
        );
        return restorePurchasesWithResult();
      }

      AppLogger.error(
        'Acquisto fallito o annullato per il pacchetto: ${package.identifier}',
        e,
        stack,
      );
      rethrow;
    } catch (e, stack) {
      AppLogger.error(
        'Acquisto fallito o annullato per il pacchetto: ${package.identifier}',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Restores previous transactions (Apple compliance require this button to be prominent).
  Future<bool> restorePurchases() async {
    final result = await restorePurchasesWithResult();
    return result.isProActive;
  }

  Future<SubscriptionOperationResult> restorePurchasesWithResult() async {
    try {
      final restoredCustomerInfo = await Purchases.restorePurchases();
      var result = await _resultFromCustomerInfo(
        restoredCustomerInfo,
        source: 'revenuecat-restore',
      );

      if (!result.isProActive) {
        try {
          await Purchases.invalidateCustomerInfoCache();
          result = await _resultFromFreshCustomerInfo(
            source: 'revenuecat-restore-refresh',
          );
        } catch (e, stack) {
          AppLogger.warning(
            'Restore completato ma refresh CustomerInfo non riuscito',
            e,
            stack,
          );
        }
      }

      return result;
    } catch (e, stack) {
      AppLogger.error('Errore durante il ripristino degli acquisti', e, stack);
      rethrow;
    }
  }

  /// Presents the beautiful, dynamic RevenueCat Paywall configured in the RC dashboard.
  /// This loads the Paywall UI directly from the cloud without releasing app updates.
  Future<void> presentPaywall() async {
    try {
      final paywallResult = await RevenueCatUI.presentPaywall();
      AppLogger.info('Paywall RevenueCat chiuso. Risultato: $paywallResult');

      // Sincronizza lo stato dopo la chiusura del paywall
      await checkAndSyncStatus();
    } catch (e, stack) {
      AppLogger.error(
        'Errore nel caricamento del Paywall RevenueCatUI',
        e,
        stack,
      );
    }
  }

  /// Presents the Paywall only if the user does NOT have the active 'Evolve Pro' entitlement.
  Future<void> presentPaywallIfNeeded() async {
    try {
      final paywallResult = await RevenueCatUI.presentPaywallIfNeeded(
        entitlementId,
      );
      AppLogger.info('Paywall "IfNeeded" chiuso. Risultato: $paywallResult');
      await checkAndSyncStatus();
    } catch (e, stack) {
      AppLogger.error(
        'Errore nel caricamento condizionale del Paywall RevenueCatUI',
        e,
        stack,
      );
    }
  }

  static bool hasActiveProAccess(CustomerInfo customerInfo) {
    return evaluateProAccess(customerInfo).isActive;
  }

  static PurchasesErrorCode? purchasesErrorCode(PlatformException exception) {
    try {
      return PurchasesErrorHelper.getErrorCode(exception);
    } catch (_) {
      return null;
    }
  }

  static SubscriptionAccessStatus evaluateProAccess(CustomerInfo customerInfo) {
    for (final entitlementId in entitlementIds) {
      final entitlement = customerInfo.entitlements.all[entitlementId];
      if (entitlement?.isActive ?? false) {
        return SubscriptionAccessStatus(
          isActive: true,
          matchedEntitlementId: entitlementId,
          matchedProductId: entitlement?.productIdentifier,
        );
      }
    }

    for (final entry in customerInfo.entitlements.active.entries) {
      final entitlement = entry.value;
      if (entitlement.isActive &&
          proProductIds.contains(entitlement.productIdentifier)) {
        return SubscriptionAccessStatus(
          isActive: true,
          matchedEntitlementId: entry.key,
          matchedProductId: entitlement.productIdentifier,
        );
      }
    }

    for (final productId in customerInfo.activeSubscriptions) {
      if (proProductIds.contains(productId)) {
        return SubscriptionAccessStatus(
          isActive: true,
          matchedProductId: productId,
        );
      }
    }

    for (final entry in customerInfo.entitlements.active.entries) {
      final entitlement = entry.value;
      if (entitlement.isActive) {
        return SubscriptionAccessStatus(
          isActive: true,
          matchedEntitlementId: entry.key,
          matchedProductId: entitlement.productIdentifier,
          usedGenericEntitlementFallback: true,
        );
      }
    }

    return const SubscriptionAccessStatus(isActive: false);
  }

  /// Presents the RevenueCat Customer Center (for managing active subscriptions, refunds, etc.)
  /// This is compliant with Apple guidelines and offers a unified dashboard.
  Future<void> presentCustomerCenter() async {
    try {
      await RevenueCatUI.presentCustomerCenter();
      // Sync state afterwards in case they cancelled or updated their plan
      await checkAndSyncStatus();
    } catch (e, stack) {
      AppLogger.error(
        'Errore nell\'apertura del Customer Center di RevenueCat',
        e,
        stack,
      );
    }
  }

  void _ensureCustomerInfoListener() {
    if (_customerInfoListenerRegistered) return;

    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _syncLocalStatus(customerInfo, source: 'revenuecat-listener');
    });
    _customerInfoListenerRegistered = true;
  }

  Future<SubscriptionOperationResult> _resultFromFreshCustomerInfo({
    required String source,
  }) async {
    final customerInfo = await Purchases.getCustomerInfo();
    return _resultFromCustomerInfo(customerInfo, source: source);
  }

  Future<SubscriptionOperationResult> _resultFromCustomerInfo(
    CustomerInfo customerInfo, {
    required String source,
  }) async {
    final accessStatus = _syncLocalStatus(customerInfo, source: source);
    return SubscriptionOperationResult(
      isProActive: accessStatus.isActive,
      customerInfo: customerInfo,
      accessStatus: accessStatus,
    );
  }

  SubscriptionAccessStatus _syncLocalStatus(
    CustomerInfo customerInfo, {
    required String source,
  }) {
    final accessStatus = evaluateProAccess(customerInfo);

    AppLogger.info(
      'Stato abbonamento RevenueCat: source=$source, '
      'pro=${accessStatus.isActive}, '
      'matchedEntitlement=${accessStatus.matchedEntitlementId}, '
      'matchedProduct=${accessStatus.matchedProductId}, '
      'activeEntitlements=${customerInfo.entitlements.active.keys.toList()}, '
      'activeSubscriptions=${customerInfo.activeSubscriptions}',
      category: 'subscriptions',
    );

    if (accessStatus.usedGenericEntitlementFallback) {
      AppLogger.warning(
        'Entitlement RevenueCat attivo non presente nella whitelist locale. '
        'Accesso Pro concesso per evitare blocchi post-acquisto; verificare la dashboard RevenueCat.',
        null,
        null,
        {
          'matchedEntitlement': accessStatus.matchedEntitlementId,
          'matchedProduct': accessStatus.matchedProductId,
          'source': source,
        },
      );
    }

    final currentSettings = _ref.read(settingsProvider);
    if (currentSettings.isPro != accessStatus.isActive) {
      _ref
          .read(settingsProvider.notifier)
          .updateSettings(
            currentSettings.copyWith(isPro: accessStatus.isActive),
          );
    }

    return accessStatus;
  }
}
