import 'dart:convert';

import 'package:evolve_targets/evolve_targets.dart';
import 'package:flutter_test/flutter_test.dart';

HabitTarget _target({
  TargetFillSource fillSource = TargetFillSource.manual,
  TargetDirection direction = TargetDirection.atLeast,
  TargetPeriod period = TargetPeriod.day,
  TargetAggregation aggregation = TargetAggregation.sum,
  double amount = 80,
  TargetUnit unit = TargetUnit.count,
  double step = 20,
  TargetInput input = TargetInput.stepper,
  String? presetId = 'count_daily',
  Map<String, Object?> extra = const {},
}) =>
    HabitTarget(
      fillSource: fillSource,
      direction: direction,
      period: period,
      aggregation: aggregation,
      amount: amount,
      unit: unit,
      step: step,
      input: input,
      presetId: presetId,
      extra: extra,
    );

void main() {
  group('round-trip', () {
    test('encodes and decodes every axis', () {
      final original = _target();
      final decoded = decodeHabitTarget(original.encode());
      expect(decoded, original);
    });

    test('round-trips each preset in the catalog', () {
      for (final preset in TargetPresetCatalog.all) {
        final target = preset.targetWith();
        expect(decodeHabitTarget(target.encode()), target,
            reason: 'preset ${preset.id} failed to round-trip');
      }
    });

    test('accepts an already-decoded map as well as a string', () {
      final target = _target();
      expect(decodeHabitTarget(target.toWire()), target);
    });

    test('stamps the envelope version', () {
      final wire = jsonDecode(_target().encode()) as Map<String, Object?>;
      expect(wire['v'], kHabitTargetVersion);
    });
  });

  group('forward compatibility', () {
    test('preserves unknown keys through a decode/encode cycle', () {
      // The scenario: a newer build adds a field, the Mac on an older build
      // edits the habit's title and writes the row back. Without preservation
      // the newer build's field is silently destroyed.
      final blob = jsonEncode({
        ..._target().toWire(),
        'rampUp': {'weekly': 5},
        'futureFlag': true,
      });

      final decoded = decodeHabitTarget(blob)!;
      expect(decoded.extra, {
        'rampUp': {'weekly': 5},
        'futureFlag': true,
      });

      final reEncoded = jsonDecode(decoded.encode()) as Map<String, Object?>;
      expect(reEncoded['rampUp'], {'weekly': 5});
      expect(reEncoded['futureFlag'], true);
      // …and the known axes are untouched by the passenger keys.
      expect(decodeHabitTarget(decoded.encode()), decoded);
    });

    test('a known key cannot be shadowed by a stale unknown one', () {
      final target = _target(amount: 80, extra: const {'amount': 5});
      final wire = jsonDecode(target.encode()) as Map<String, Object?>;
      expect(wire['amount'], 80);
    });

    test('rejects an unknown axis value rather than defaulting it', () {
      // Strictness matters most for aggregation, because the underlying
      // VerificationAggregation.fromWire deliberately defaults unknown input to
      // `sum`. Silently guessing here would score days against a rule the user
      // never set.
      for (final mutation in <Map<String, Object?>>[
        {'agg': 'median'},
        {'dir': 'approximately'},
        {'per': 'fortnight'},
        {'src': 'garmin'},
        {'unit': 'furlongs'},
        {'input': 'telepathy'},
      ]) {
        final blob = jsonEncode({..._target().toWire(), ...mutation});
        expect(decodeHabitTarget(blob), isNull,
            reason: 'should have rejected $mutation');
      }
    });
  });

  group('defensive decoding', () {
    test('returns null for absent, blank and non-object input', () {
      expect(decodeHabitTarget(null), isNull);
      expect(decodeHabitTarget(''), isNull);
      expect(decodeHabitTarget('   '), isNull);
      expect(decodeHabitTarget('not json'), isNull);
      expect(decodeHabitTarget('[1,2,3]'), isNull);
      expect(decodeHabitTarget(42), isNull);
    });

    test('returns null when a required axis is missing', () {
      for (final key in ['src', 'dir', 'per', 'agg', 'amount', 'unit', 'step', 'input']) {
        final wire = _target().toWire()..remove(key);
        expect(decodeHabitTarget(jsonEncode(wire)), isNull,
            reason: 'missing $key should reject the blob');
      }
    });

    test('returns null for wrong-typed fields instead of throwing', () {
      for (final mutation in <Map<String, Object?>>[
        {'amount': 'eighty'},
        {'step': true},
        {'dir': 7},
        {'preset': 3},
      ]) {
        final blob = jsonEncode({..._target().toWire(), ...mutation});
        expect(() => decodeHabitTarget(blob), returnsNormally);
      }
      // A bad `preset` is not fatal — it is presentational — so the target
      // survives with a null id.
      final withBadPreset = jsonEncode({..._target().toWire(), 'preset': 3});
      expect(decodeHabitTarget(withBadPreset)?.presetId, isNull);
    });

    test('rejects a non-positive or non-finite amount or step', () {
      for (final mutation in <Map<String, Object?>>[
        {'amount': 0},
        {'amount': -5},
        {'step': 0},
        {'step': -1},
      ]) {
        final blob = jsonEncode({..._target().toWire(), ...mutation});
        expect(decodeHabitTarget(blob), isNull,
            reason: '$mutation must not produce an always-complete habit');
      }
      // Infinity / NaN cannot survive jsonEncode, so they are exercised through
      // the map path the sync engine can hand us directly.
      expect(decodeHabitTarget({..._target().toWire(), 'amount': double.nan}),
          isNull);
      expect(
          decodeHabitTarget({..._target().toWire(), 'amount': double.infinity}),
          isNull);
    });
  });

  group('hasUnreadableTarget', () {
    test('is false for no target and for a readable one', () {
      expect(hasUnreadableTarget(null), isFalse);
      expect(hasUnreadableTarget(''), isFalse);
      expect(hasUnreadableTarget(_target().encode()), isFalse);
    });

    test('is true for a blob this build cannot decode', () {
      // A newer client's target: well-formed JSON, unknown axis value. The save
      // path must write it back verbatim rather than nulling the column.
      final blob = jsonEncode({..._target().toWire(), 'per': 'quarter'});
      expect(hasUnreadableTarget(blob), isTrue);
    });

    test('is false for garbage that is not an object', () {
      expect(hasUnreadableTarget('not json'), isFalse);
      expect(hasUnreadableTarget('{}'), isFalse);
    });
  });

  test('equality covers every axis', () {
    final base = _target();
    expect(base, _target());
    expect(base.hashCode, _target().hashCode);
    expect(base == _target(amount: 81), isFalse);
    expect(base == _target(step: 21), isFalse);
    expect(base == _target(direction: TargetDirection.atMost), isFalse);
    expect(base == _target(period: TargetPeriod.week), isFalse);
    expect(base == _target(unit: TargetUnit.minutes), isFalse);
    expect(base == _target(input: TargetInput.timer), isFalse);
    expect(base == _target(fillSource: TargetFillSource.healthKit), isFalse);
    expect(base == _target(aggregation: TargetAggregation.count), isFalse);
    expect(base == _target(extra: const {'x': 1}), isFalse);
  });

  test('copyWith can clear the preset id', () {
    expect(_target().copyWith(clearPresetId: true).presetId, isNull);
    expect(_target().copyWith(amount: 100).amount, 100);
    expect(_target().copyWith(amount: 100).presetId, 'count_daily');
  });

  group('fill source', () {
    test('measured sources are the two sensor-backed ones', () {
      expect(TargetFillSource.manual.isMeasured, isFalse);
      expect(TargetFillSource.healthKit.isMeasured, isTrue);
      expect(TargetFillSource.screenTime.isMeasured, isTrue);
    });

    test('wire names round-trip and match the verification vocabulary', () {
      for (final s in TargetFillSource.values) {
        expect(TargetFillSource.fromWire(s.wireName), s);
      }
      expect(TargetFillSource.fromWire('unknown'), isNull);
      expect(TargetFillSource.fromWire(null), isNull);
    });

    test('only a manual target is user-enterable', () {
      expect(_target().isUserEnterable, isTrue);
      expect(_target(fillSource: TargetFillSource.healthKit).isUserEnterable,
          isFalse);
    });
  });
}
