import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../providers/settings_provider.dart';
import 'revenuecat_config.dart';
import 'app_logger.dart';

final subscriptionServiceProvider = Provider((ref) => SubscriptionService(ref));

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
      await Purchases.logIn(userUuid);
    } else {
      // Configure purchases_flutter with the static API key and current user's identifier
      PurchasesConfiguration configuration = PurchasesConfiguration(
        RevenueCatConfig.apiKey,
      )..appUserID = userUuid;
      await Purchases.configure(configuration);
    }

    _configuredUserUuid = userUuid;

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
      final isProActive = hasActiveProAccess(customerInfo);

      AppLogger.info(
        'Stato abbonamento RevenueCat: pro=$isProActive, '
        'activeEntitlements=${customerInfo.entitlements.active.keys.toList()}, '
        'activeSubscriptions=${customerInfo.activeSubscriptions}',
      );

      // Sync local state if different from RevenueCat server truth
      final currentSettings = _ref.read(settingsProvider);
      if (currentSettings.isPro != isProActive) {
        _ref
            .read(settingsProvider.notifier)
            .updateSettings(currentSettings.copyWith(isPro: isProActive));
      }
      return isProActive;
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
    try {
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      final customerInfo = purchaseResult.customerInfo;
      await Purchases.invalidateCustomerInfoCache();
      final refreshedCustomerInfo = await Purchases.getCustomerInfo();
      final isProActive =
          hasActiveProAccess(refreshedCustomerInfo) ||
          hasActiveProAccess(customerInfo);

      // Sincronizza lo stato locale Pro
      final currentSettings = _ref.read(settingsProvider);
      _ref
          .read(settingsProvider.notifier)
          .updateSettings(currentSettings.copyWith(isPro: isProActive));

      return isProActive;
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
    try {
      final restoredCustomerInfo = await Purchases.restorePurchases();
      await Purchases.invalidateCustomerInfoCache();
      final refreshedCustomerInfo = await Purchases.getCustomerInfo();
      final isProActive =
          hasActiveProAccess(restoredCustomerInfo) ||
          hasActiveProAccess(refreshedCustomerInfo);

      final currentSettings = _ref.read(settingsProvider);
      _ref
          .read(settingsProvider.notifier)
          .updateSettings(currentSettings.copyWith(isPro: isProActive));

      return isProActive;
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
    final hasConfiguredEntitlement = entitlementIds.any(
      (id) => customerInfo.entitlements.all[id]?.isActive ?? false,
    );
    if (hasConfiguredEntitlement) return true;

    final hasAnyActiveEntitlement = customerInfo.entitlements.active.values.any(
      (entitlement) =>
          entitlement.isActive &&
          proProductIds.contains(entitlement.productIdentifier),
    );
    if (hasAnyActiveEntitlement) return true;

    return customerInfo.activeSubscriptions.any(proProductIds.contains);
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
}
