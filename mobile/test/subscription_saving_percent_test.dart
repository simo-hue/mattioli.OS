import 'package:mattioli_os/ui/screens/subscription_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// The annual card's saving is computed from live StoreKit prices, not stated as
/// a constant. It is user-visible pricing copy on a paywall that App Review has
/// already rejected under Guideline 3.1.2, so a wrong number here is a rejection,
/// not a cosmetic bug.
void main() {
  group('annualSavingPercent', () {
    test('EUR tiers: 4.99/mo vs 29.99/yr is 50%, not the "over 40%" we claimed', () {
      expect(
        annualSavingPercent(monthlyPrice: 4.99, yearlyPrice: 29.99),
        50,
      );
    });

    test('a storefront whose tiers are less generous reports its own figure', () {
      // USD tiers happen to land differently; the point is the number follows
      // the store rather than the copy.
      expect(annualSavingPercent(monthlyPrice: 4.99, yearlyPrice: 39.99), 33);
    });

    test('no saving at all yields null rather than "Save 0%"', () {
      expect(annualSavingPercent(monthlyPrice: 4.99, yearlyPrice: 59.88), isNull);
    });

    test('an annual plan that costs MORE yields null, never a negative saving', () {
      expect(annualSavingPercent(monthlyPrice: 4.99, yearlyPrice: 79.99), isNull);
    });

    test('a saving that rounds below 1% yields null, not "Save 0%"', () {
      // 59.50 vs 59.88 is ~0.63% -> rounds to 1... so pick one that rounds to 0.
      expect(annualSavingPercent(monthlyPrice: 4.99, yearlyPrice: 59.70), isNull);
    });

    test('rounds to whole percent', () {
      // 1 - 45/59.88 = 24.85% -> 25
      expect(annualSavingPercent(monthlyPrice: 4.99, yearlyPrice: 45.00), 25);
    });

    test('unusable prices yield null rather than dividing by zero', () {
      expect(annualSavingPercent(monthlyPrice: 0, yearlyPrice: 29.99), isNull);
      expect(annualSavingPercent(monthlyPrice: 4.99, yearlyPrice: 0), isNull);
      expect(annualSavingPercent(monthlyPrice: -1, yearlyPrice: 29.99), isNull);
    });

    test('zero-decimal currencies (JPY) work without decimal assumptions', () {
      // JPY has no minor unit; prices arrive as whole numbers.
      expect(annualSavingPercent(monthlyPrice: 800, yearlyPrice: 4800), 50);
    });
  });
}
