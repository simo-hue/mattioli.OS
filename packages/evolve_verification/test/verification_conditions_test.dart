// Serialization for compound verifiable habits: the VerificationRule wire codec
// and the `goals.verify_conditions` JSON envelope ({v, op, conditions:[...]}).
// A malformed or over-cap blob must decode to null ("not compound"), never a
// half-rule.
import 'dart:convert';

import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final steps = VerificationCatalog.steps.ruleWith(10000);
  final exercise = VerificationCatalog.exerciseMinutes.ruleWith(30);
  final energy = VerificationCatalog.activeEnergy.ruleWith(500);

  group('VerificationRule wire codec', () {
    test('toWire → fromWire round-trips', () {
      expect(VerificationRule.fromWire(steps.toWire()), steps);
    });

    test('fromWire rejects a missing or invalid field', () {
      final good = steps.toWire();
      expect(VerificationRule.fromWire({...good}..remove('metric')), isNull);
      expect(VerificationRule.fromWire({...good, 'provider': 'bogus'}), isNull);
      expect(VerificationRule.fromWire({...good, 'threshold': null}), isNull);
      expect(VerificationRule.fromWire('not a map'), isNull);
    });

    test('fromWire returns null on a WRONG-TYPED field, never throws', () {
      final good = steps.toWire();
      // A corrupted / foreign blob may carry the wrong runtime type — the cast
      // must degrade to null, not throw a TypeError out of the decode path.
      expect(VerificationRule.fromWire({...good, 'provider': 1}), isNull);
      expect(VerificationRule.fromWire({...good, 'metric': 42}), isNull);
      expect(VerificationRule.fromWire({...good, 'comparator': true}), isNull);
      expect(VerificationRule.fromWire({...good, 'threshold': 'lots'}), isNull);
      expect(VerificationRule.fromWire({...good, 'unit': <String, int>{}}), isNull);
    });
  });

  group('encodeVerifyConditions', () {
    test('returns null for fewer than 2 conditions (single uses flat columns)',
        () {
      expect(encodeVerifyConditions([steps], VerificationJoin.or), isNull);
      expect(encodeVerifyConditions([], VerificationJoin.and), isNull);
    });

    test('emits the {v, op, conditions} envelope', () {
      final json = encodeVerifyConditions([steps, exercise], VerificationJoin.or);
      final map = jsonDecode(json!) as Map<String, dynamic>;
      expect(map['v'], kVerifyConditionsVersion);
      expect(map['op'], 'or');
      expect((map['conditions'] as List).length, 2);
    });
  });

  group('encode ↔ decode round-trip', () {
    test('two conditions with OR', () {
      final json = encodeVerifyConditions([steps, exercise], VerificationJoin.or);
      final back = decodeVerifyConditions(json)!;
      expect(back.op, VerificationJoin.or);
      expect(back.conditions, [steps, exercise]);
    });

    test('three conditions with AND, order preserved', () {
      final json =
          encodeVerifyConditions([steps, exercise, energy], VerificationJoin.and);
      final back = decodeVerifyConditions(json)!;
      expect(back.op, VerificationJoin.and);
      expect(back.conditions, [steps, exercise, energy]);
    });

    test('decodes an already-decoded Map too', () {
      final json = encodeVerifyConditions([steps, exercise], VerificationJoin.and);
      final asMap = jsonDecode(json!);
      expect(decodeVerifyConditions(asMap)!.op, VerificationJoin.and);
    });
  });

  group('decodeVerifyConditions is a strict, non-throwing gate', () {
    test('null / blank / malformed / wrong-type → null', () {
      expect(decodeVerifyConditions(null), isNull);
      expect(decodeVerifyConditions(''), isNull);
      expect(decodeVerifyConditions('   '), isNull);
      expect(decodeVerifyConditions('{not json'), isNull);
      expect(decodeVerifyConditions('[]'), isNull); // not a map
      expect(decodeVerifyConditions(42), isNull);
    });

    test('missing/invalid op or conditions → null', () {
      expect(
          decodeVerifyConditions(jsonEncode({
            'v': 1,
            'conditions': [steps.toWire(), exercise.toWire()],
          })),
          isNull); // no op
      expect(
          decodeVerifyConditions(jsonEncode({
            'v': 1,
            'op': 'xor',
            'conditions': [steps.toWire(), exercise.toWire()],
          })),
          isNull); // bad op
      expect(
          decodeVerifyConditions(
              jsonEncode({'v': 1, 'op': 'or', 'conditions': 'nope'})),
          isNull); // conditions not a list
    });

    test('any invalid condition rejects the whole set', () {
      final json = jsonEncode({
        'v': 1,
        'op': 'or',
        'conditions': [steps.toWire(), {'metric': 'steps'}],
      });
      expect(decodeVerifyConditions(json), isNull);
    });

    test('a WRONG-TYPED op or condition field → null, never throws', () {
      // op is a non-null non-string (number / bool / object).
      for (final badOp in [5, true, <String, int>{'x': 1}]) {
        expect(
            decodeVerifyConditions(jsonEncode({
              'v': 1,
              'op': badOp,
              'conditions': [steps.toWire(), exercise.toWire()],
            })),
            isNull,
            reason: 'op=$badOp must not throw');
      }
      // A condition carrying a wrong-typed field (a numeric provider, a string
      // threshold) — the whole set is rejected rather than throwing.
      final badProvider = {
        'provider': 1,
        'metric': 'steps',
        'comparator': 'gte',
        'threshold': 1000,
        'unit': 'count',
      };
      final badThreshold = {
        'provider': 'healthkit',
        'metric': 'steps',
        'comparator': 'gte',
        'threshold': '1000',
        'unit': 'count',
      };
      expect(
          decodeVerifyConditions(jsonEncode({
            'v': 1,
            'op': 'or',
            'conditions': [steps.toWire(), badProvider],
          })),
          isNull);
      expect(
          decodeVerifyConditions(jsonEncode({
            'v': 1,
            'op': 'and',
            'conditions': [steps.toWire(), badThreshold],
          })),
          isNull);
    });

    test('fewer than 2 valid conditions → null', () {
      final json = jsonEncode({
        'v': 1,
        'op': 'or',
        'conditions': [steps.toWire()],
      });
      expect(decodeVerifyConditions(json), isNull);
    });

    test('more than the cap → null (a set we cannot faithfully represent)', () {
      final json = jsonEncode({
        'v': 1,
        'op': 'and',
        'conditions': [
          steps.toWire(),
          exercise.toWire(),
          energy.toWire(),
          VerificationCatalog.distance.ruleWith(5).toWire(),
        ],
      });
      expect(decodeVerifyConditions(json), isNull);
    });
  });

  group('verificationColumnsFor (write) — flat vs JSON', () {
    test('manual (empty) nulls all six columns', () {
      final cols = verificationColumnsFor([]);
      expect(cols['verify_provider'], isNull);
      expect(cols['verify_conditions'], isNull);
    });

    test('single uses the flat columns, verify_conditions null', () {
      final cols = verificationColumnsFor([steps]);
      expect(cols['verify_metric'], 'steps');
      expect(cols['verify_conditions'], isNull);
    });

    test('compound uses verify_conditions and NULLS the flat columns', () {
      final cols = verificationColumnsFor([steps, exercise], VerificationJoin.and);
      expect(cols['verify_provider'], isNull);
      expect(cols['verify_metric'], isNull);
      expect(cols['verify_conditions'], isNotNull);
      expect(decodeVerifyConditions(cols['verify_conditions'])!.op,
          VerificationJoin.and);
    });
  });

  group('readVerificationColumns (read) — precedence', () {
    test('a manual row → null', () {
      expect(readVerificationColumns({'verify_provider': null}), isNull);
    });

    test('flat columns → a single condition, default OR', () {
      final row = {...steps.toColumns(), 'verify_conditions': null};
      final v = readVerificationColumns(row)!;
      expect(v.conditions, [steps]);
      expect(v.op, VerificationJoin.or);
    });

    test('verify_conditions → the compound set', () {
      final row = {
        ...VerificationRule.nullColumns,
        'verify_conditions':
            encodeVerifyConditions([steps, exercise], VerificationJoin.and),
      };
      final v = readVerificationColumns(row)!;
      expect(v.conditions, [steps, exercise]);
      expect(v.op, VerificationJoin.and);
    });

    test('verify_conditions WINS when both are present', () {
      // Defensive: a row that somehow carries both should honor the compound.
      final row = {
        ...energy.toColumns(), // stray flat single
        'verify_conditions':
            encodeVerifyConditions([steps, exercise], VerificationJoin.or),
      };
      final v = readVerificationColumns(row)!;
      expect(v.conditions, [steps, exercise]);
    });

    test('write→read round-trips for single and compound', () {
      final single = readVerificationColumns(verificationColumnsFor([steps]))!;
      expect(single.conditions, [steps]);
      final compound = readVerificationColumns(
          verificationColumnsFor([steps, exercise, energy], VerificationJoin.and))!;
      expect(compound.conditions, [steps, exercise, energy]);
      expect(compound.op, VerificationJoin.and);
    });
  });
}
