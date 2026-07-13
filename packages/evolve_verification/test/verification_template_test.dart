import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VerificationCatalog', () {
    test('ships exactly the nine v1 templates', () {
      expect(VerificationCatalog.all, hasLength(9));
    });

    test('template keys are unique', () {
      final keys = VerificationCatalog.all.map((t) => t.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('every HealthKit template is atLeast with a native identifier', () {
      final health = VerificationCatalog.all
          .where((t) => t.provider == VerificationProvider.healthKit);
      expect(health, hasLength(8));
      for (final t in health) {
        expect(t.comparator, VerificationComparator.atLeast, reason: t.key);
        expect(t.healthKitTypeIdentifier, isNotNull, reason: t.key);
        expect(t.healthKitTypeIdentifier, isNotEmpty, reason: t.key);
      }
    });

    test('screen time is the only atMost template and has no HK identifier', () {
      final screen = VerificationCatalog.all
          .where((t) => t.provider == VerificationProvider.screenTime)
          .toList();
      expect(screen, hasLength(1));
      expect(screen.single.key, 'screen_time_total');
      expect(screen.single.comparator, VerificationComparator.atMost);
      expect(screen.single.healthKitTypeIdentifier, isNull);
    });

    test('only stand hours requires a Watch', () {
      final watchGated =
          VerificationCatalog.all.where((t) => t.requiresWatch).toList();
      expect(watchGated, hasLength(1));
      expect(watchGated.single.key, 'stand_hours');
    });

    test('default thresholds sit within [min, max] and bounds are ordered', () {
      for (final t in VerificationCatalog.all) {
        expect(t.minThreshold, lessThan(t.maxThreshold), reason: t.key);
        expect(t.defaultThreshold,
            inInclusiveRange(t.minThreshold, t.maxThreshold),
            reason: t.key);
        expect(t.step, greaterThan(0), reason: t.key);
      }
    });

    test('byKey resolves known keys and rejects unknown ones', () {
      expect(VerificationCatalog.byKey('steps'), same(VerificationCatalog.steps));
      expect(VerificationCatalog.byKey('nope'), isNull);
      expect(VerificationCatalog.byKey(null), isNull);
    });
  });

  group('VerificationTemplate.ruleWith', () {
    test('clamps the threshold into the template bounds', () {
      final tooHigh = VerificationCatalog.steps.ruleWith(999999);
      expect(tooHigh.threshold, VerificationCatalog.steps.maxThreshold);

      final tooLow = VerificationCatalog.steps.ruleWith(1);
      expect(tooLow.threshold, VerificationCatalog.steps.minThreshold);

      final ok = VerificationCatalog.steps.ruleWith(8000);
      expect(ok.threshold, 8000);
      expect(ok.metricKey, 'steps');
      expect(ok.provider, VerificationProvider.healthKit);
    });
  });
}
