import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalog integrity', () {
    test('ids are unique and stable-looking', () {
      final ids = TargetPresetCatalog.all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate preset id');
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[a-z0-9_]+$')),
            reason: '$id must be a stable snake_case wire value');
      }
    });

    test('every preset produces a manual, per-day, decodable target', () {
      for (final p in TargetPresetCatalog.all) {
        final t = p.targetWith();
        expect(t.fillSource, TargetFillSource.manual, reason: p.id);
        expect(t.period, TargetPeriod.day,
            reason: '${p.id}: v1 ships day targets only — the streak engine '
                'and analytics do not bucket by week yet');
        expect(t.presetId, p.id, reason: p.id);
        expect(decodeHabitTarget(t.encode()), t, reason: p.id);
      }
    });

    test('bounds are coherent', () {
      for (final p in TargetPresetCatalog.all) {
        expect(p.minAmount, greaterThan(0), reason: p.id);
        expect(p.maxAmount, greaterThan(p.minAmount), reason: p.id);
        expect(p.defaultAmount, greaterThanOrEqualTo(p.minAmount), reason: p.id);
        expect(p.defaultAmount, lessThanOrEqualTo(p.maxAmount), reason: p.id);
        expect(p.defaultStep, greaterThan(0), reason: p.id);
        expect(p.defaultStep, lessThanOrEqualTo(p.defaultAmount), reason: p.id);
      }
    });

    test('i18n keys are namespaced and distinct per preset', () {
      final keys = <String>{};
      for (final p in TargetPresetCatalog.all) {
        expect(p.labelKey, startsWith('targets.presets.'), reason: p.id);
        expect(p.descriptionKey, startsWith('targets.presets.'), reason: p.id);
        expect(keys.add(p.labelKey), isTrue, reason: 'duplicate ${p.labelKey}');
        expect(keys.add(p.descriptionKey), isTrue);
      }
    });

    test('covers both directions in both a counted and a timed flavour', () {
      // The v1 promise: reach-it and stay-under-it, each countable and timeable.
      final combos = {
        for (final p in TargetPresetCatalog.all) '${p.direction.wireName}/${p.unit.wireName}'
      };
      expect(combos, {'gte/count', 'gte/minutes', 'lte/count', 'lte/minutes'});
    });
  });

  group('targetWith', () {
    test('clamps the amount into the preset bounds', () {
      const p = TargetPresetCatalog.countDaily;
      expect(p.targetWith(amount: 0).amount, p.minAmount);
      expect(p.targetWith(amount: 10000000).amount, p.maxAmount);
      expect(p.targetWith(amount: 80).amount, 80);
    });

    test('the push-up case: 80 in sets of 20 fills in four taps', () {
      final target =
          TargetPresetCatalog.countDaily.targetWith(amount: 80, step: 20);
      var progress = 0.0;
      var taps = 0;
      while (evaluateTarget(
                  target: target, progress: progress, periodIsOver: false)
              .outcome !=
          TargetOutcome.met) {
        progress = progressAfterIncrement(target, progress);
        taps++;
        expect(taps, lessThan(10), reason: 'runaway loop');
      }
      expect(taps, 4);
      expect(progress, 80);
    });

    test('rejects a non-positive step instead of making the stepper inert', () {
      const p = TargetPresetCatalog.countDaily;
      expect(p.targetWith(amount: 50, step: 0).step, p.defaultStep);
      expect(p.targetWith(amount: 50, step: -3).step, p.defaultStep);
    });

    test('caps the step at the amount so one tap cannot overshoot the goal', () {
      final t = TargetPresetCatalog.countDaily.targetWith(amount: 5, step: 50);
      expect(t.step, 5);
    });
  });

  group('lookup', () {
    test('byId finds every preset and rejects the unknown', () {
      for (final p in TargetPresetCatalog.all) {
        expect(TargetPresetCatalog.byId(p.id), same(p));
      }
      expect(TargetPresetCatalog.byId('nope'), isNull);
      expect(TargetPresetCatalog.byId(null), isNull);
    });

    test('forTarget falls back to an axis match when the id is missing', () {
      final t = TargetPresetCatalog.limitCountDaily
          .targetWith(amount: 2)
          .copyWith(clearPresetId: true);
      expect(TargetPresetCatalog.forTarget(t), TargetPresetCatalog.limitCountDaily);
    });

    test('forTarget prefers the recorded id over an axis match', () {
      final t = TargetPresetCatalog.countDaily.targetWith();
      expect(TargetPresetCatalog.forTarget(t), TargetPresetCatalog.countDaily);
    });

    test('a projected (measured) target belongs to no preset', () {
      final measured = TargetPresetCatalog.countDaily
          .targetWith()
          .copyWith(fillSource: TargetFillSource.healthKit, clearPresetId: true);
      expect(TargetPresetCatalog.forTarget(measured), isNull);
    });
  });
}
