import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/subscription_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

void main() {
  group('SubscriptionService.hasActiveProAccess', () {
    test('returns true for the configured RevenueCat entitlement', () {
      final customerInfo = _customerInfo(
        entitlements: {
          'Evolve Pro': _entitlement(
            identifier: 'Evolve Pro',
            isActive: true,
            productIdentifier: 'com.simo.evolve.pro.monthly',
          ),
        },
        activeEntitlements: {
          'Evolve Pro': _entitlement(
            identifier: 'Evolve Pro',
            isActive: true,
            productIdentifier: 'com.simo.evolve.pro.monthly',
          ),
        },
      );

      expect(SubscriptionService.hasActiveProAccess(customerInfo), isTrue);
    });

    test('returns true for an active expected StoreKit subscription', () {
      final customerInfo = _customerInfo(
        activeSubscriptions: ['com.simo.evolve.pro.yearly'],
      );

      expect(SubscriptionService.hasActiveProAccess(customerInfo), isTrue);
    });

    test(
      'returns true for any active RevenueCat entitlement as a safe fallback',
      () {
        final customerInfo = _customerInfo(
          activeEntitlements: {
            'premium': _entitlement(
              identifier: 'premium',
              isActive: true,
              productIdentifier: 'com.example.renamed.product',
            ),
          },
        );

        final accessStatus = SubscriptionService.evaluateProAccess(
          customerInfo,
        );

        expect(accessStatus.isActive, isTrue);
        expect(accessStatus.usedGenericEntitlementFallback, isTrue);
        expect(accessStatus.matchedEntitlementId, 'premium');
      },
    );

    test(
      'returns false when no known Pro entitlement or subscription is active',
      () {
        final customerInfo = _customerInfo(
          activeSubscriptions: ['com.example.other.subscription'],
        );

        expect(SubscriptionService.hasActiveProAccess(customerInfo), isFalse);
      },
    );
  });
}

CustomerInfo _customerInfo({
  Map<String, EntitlementInfo> entitlements = const {},
  Map<String, EntitlementInfo> activeEntitlements = const {},
  List<String> activeSubscriptions = const [],
}) {
  return CustomerInfo(
    EntitlementInfos(entitlements, activeEntitlements),
    const {},
    activeSubscriptions,
    const [],
    const [],
    '2026-05-19T00:00:00Z',
    'test-user',
    const {},
    '2026-05-19T00:00:00Z',
  );
}

EntitlementInfo _entitlement({
  required String identifier,
  required bool isActive,
  required String productIdentifier,
}) {
  return EntitlementInfo(
    identifier,
    isActive,
    true,
    '2026-05-19T00:00:00Z',
    '2026-05-19T00:00:00Z',
    productIdentifier,
    true,
  );
}
