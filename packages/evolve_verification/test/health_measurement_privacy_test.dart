// Unit tests for stripHealthMeasurements (src/health_measurement_privacy.dart).
// Lives in the package because BOTH clients depend on it: desktop shipped for
// months without the guard while mobile had it, so the single implementation is
// tested in the single place it now lives.
// — the guard that keeps a HealthKit-measured quantity out of the Supabase
// payload the Cloud-mode backup restore uploads. Being pure, it needs no
// Supabase: _executeCloudImport feeds it plan.logs, the backup's goals and the
// account's existing goal rows, and uploads exactly what it returns.
import 'dart:convert';

import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final healthKit = VerificationProvider.healthKit.wireName;
  final screenTime = VerificationProvider.screenTime.wireName;

  Map<String, dynamic> goal(String id, [String? provider]) => {
        'id': id,
        'title': 'g-$id',
        'verify_provider': provider,
      };

  VerificationRule rule(VerificationProvider provider, String metric) =>
      VerificationRule(
        provider: provider,
        metricKey: metric,
        comparator: VerificationComparator.atLeast,
        threshold: 10000,
        unit: VerificationUnit.count,
      );

  /// A goal exactly as [verificationColumnsFor] persists a COMPOUND habit: the
  /// conditions JSON set, the flat `verify_*` columns deliberately nulled.
  Map<String, dynamic> compoundGoal(String id) => {
        ...goal(id),
        ...verificationColumnsFor([
          rule(VerificationProvider.healthKit, 'steps'),
          rule(VerificationProvider.healthKit, 'exercise'),
        ]),
      };

  Map<String, dynamic> log(String goalId, {num? value}) => {
        'id': 'log-$goalId',
        'goal_id': goalId,
        'date': '2026-07-14',
        'status': 'done',
        'streak': 3,
        'value': value,
      };

  List<Map<String, dynamic>> strip({
    required List<Map<String, dynamic>> logs,
    Object? backupGoals = const <Map<String, dynamic>>[],
  }) =>
      stripHealthMeasurements(logs: logs, backupGoals: backupGoals);

  test('drops the measured quantity of a HealthKit goal named by the backup',
      () {
    final out = strip(
      logs: [log('g1', value: 12043)],
      backupGoals: [goal('g1', healthKit)],
    );

    expect(out.single['value'], isNull);
  });

  test('keeps the verdict, streak and date of a HealthKit log', () {
    final out = strip(
      logs: [log('g1', value: 12043)],
      backupGoals: [goal('g1', healthKit)],
    );

    // Only the quantity is dropped: restoring must still rebuild the history.
    expect(out.single['status'], 'done');
    expect(out.single['streak'], 3);
    expect(out.single['date'], '2026-07-14');
    expect(out.single['goal_id'], 'g1');
    expect(out.single['id'], 'log-g1');
  });

  test('nulls value as an explicit key so an older upload is overwritten', () {
    final out = strip(
      logs: [log('g1', value: 12043)],
      backupGoals: [goal('g1', healthKit)],
    );

    // An omitted key would leave a value a pre-fix build uploaded in place.
    expect(out.single.containsKey('value'), isTrue);
  });

  test('strips a rule-less goal\'s value — the rule may have been REMOVED', () {
    // Regression: this expectation used to be the opposite, which is precisely
    // the leak. Removing a verification rule writes VerificationRule.nullColumns
    // (verificationColumnsFor with zero conditions) while the measured logs stay
    // — nothing deletes them — so "verify_provider is null" does NOT mean "this
    // number was never an Apple Health reading". Only a positively non-HealthKit
    // rule proves that. Nothing real is lost: goal_logs.value only ever carries a
    // verification measurement (a manual toggle clears it; a quantitative
    // target's number lives in goal_progress).
    final out = strip(logs: [log('g1', value: 12043)], backupGoals: [goal('g1')]);

    expect(out.single['value'], isNull);
  });

  test('keeps the verdict of a stripped rule-less goal', () {
    final out = strip(logs: [log('g1', value: 12043)], backupGoals: [goal('g1')]);

    expect(out.single['status'], 'done');
    expect(out.single['streak'], 3);
  });

  test('leaves a valueless manual log untouched', () {
    final logs = [log('g1')];

    final out = strip(logs: logs, backupGoals: [goal('g1')]);

    expect(out.single['value'], isNull);
    expect(out.single, same(logs.single)); // untouched rows are not copied
  });

  test('leaves a Screen Time goal\'s logs untouched', () {
    final logs = [log('g1', value: 45)];

    // The one positive proof of "not an Apple Health reading" the file carries.
    final out = strip(logs: logs, backupGoals: [goal('g1', screenTime)]);

    expect(out.single['value'], 45);
    expect(out.single, same(logs.single)); // untouched rows are not copied
  });

  test('strips a goal whose provider this build does not recognise', () {
    // A newer client's provider is unknowable, so it is not proof of anything.
    final out = strip(
      logs: [log('g1', value: 12043)],
      backupGoals: [goal('g1', 'some-future-provider')],
    );

    expect(out.single['value'], isNull);
  });

  test('strips a goal whose verify_provider is not even a string', () {
    // A hand-edited or foreign file must degrade to "not proven", never throw.
    final out = strip(
      logs: [log('g1', value: 12043)],
      backupGoals: [
        {'id': 'g1', 'verify_provider': 42},
      ],
    );

    expect(out.single['value'], isNull);
  });

  test('strips a COMPOUND goal, whose flat verify_* columns are all null', () {
    // Regression: converting a single HealthKit rule into a compound habit moves
    // the rule into verify_conditions and deliberately NULLS the flat columns, so
    // a pre-compound client reads the habit as manual. Values written while it
    // was still single-rule survive in goal_logs and used to leak.
    final backupGoal = compoundGoal('g1');
    expect(backupGoal['verify_provider'], isNull, reason: 'guards the premise');
    expect(backupGoal['verify_conditions'], isNotNull);

    final out = strip(logs: [log('g1', value: 12043)], backupGoals: [backupGoal]);

    expect(out.single['value'], isNull);
  });

  test('strips a compound blob this build cannot decode', () {
    // A newer client's set of MORE than kMaxVerificationConditions decodes to
    // null here (decodeVerifyConditions rejects it wholesale), so the goal would
    // otherwise read as manual — while every condition in it is HealthKit.
    final blob = jsonEncode({
      'v': kVerifyConditionsVersion,
      'op': VerificationJoin.or.wireName,
      'conditions': [
        for (var i = 0; i < kMaxVerificationConditions + 1; i++)
          rule(VerificationProvider.healthKit, 'metric-$i').toWire(),
      ],
    });
    expect(decodeVerifyConditions(blob), isNull, reason: 'guards the premise');

    final out = strip(
      logs: [log('g1', value: 12043)],
      backupGoals: [
        {...goal('g1'), 'verify_conditions': blob},
      ],
    );

    expect(out.single['value'], isNull);
  });

  test('strips a compound goal even when the blob is corrupt or foreign', () {
    for (final blob in ['{not json', '{}', '[]', 42]) {
      final out = strip(
        logs: [log('g1', value: 12043)],
        backupGoals: [
          {...goal('g1'), 'verify_conditions': blob},
        ],
      );

      expect(out.single['value'], isNull, reason: 'blob: $blob');
    }
  });

  test('a blank verify_conditions does not disqualify a Screen Time goal', () {
    // Null/empty is how EVERY single-rule and manual habit stores the column —
    // it must not be read as "compound", or no value would ever survive.
    for (final blank in [null, '', '   ']) {
      final out = strip(
        logs: [log('g1', value: 45)],
        backupGoals: [
          {...goal('g1', screenTime), 'verify_conditions': blank},
        ],
      );

      expect(out.single['value'], 45, reason: 'blank: "$blank"');
    }
  });

  test('a duplicated goal id needs UNANIMOUS proof to keep its value', () {
    // A hand-edited or merged file can name the same goal twice. One entry
    // vouching for it must not outvote another that doesn't — in either order.
    for (final entries in [
      [goal('g1', screenTime), goal('g1', healthKit)],
      [goal('g1', healthKit), goal('g1', screenTime)],
    ]) {
      final out = strip(logs: [log('g1', value: 12043)], backupGoals: entries);

      expect(out.single['value'], isNull,
          reason: 'first entry: ${entries.first['verify_provider']}');
    }
  });

  test('does not mutate the caller\'s log maps', () {
    final logs = [log('g1', value: 12043)];

    strip(logs: logs, backupGoals: [goal('g1', healthKit)]);

    expect(logs.single['value'], 12043);
  });

  test('treats a goal the backup does not resolve as HealthKit', () {
    // planCloudImport keeps a log whose goal exists on the account but is absent
    // from the file, so the rule behind such a value is unknowable here.
    final out = strip(logs: [log('server-only', value: 12043)]);

    expect(out.single['value'], isNull);
  });

  test('keeps only the provably non-health values in a mixed payload', () {
    final out = strip(
      logs: [
        log('steps', value: 12043),
        log('was-steps', value: 9871),
        log('compound', value: 11002),
        log('water', value: 2),
        log('screen', value: 45),
      ],
      backupGoals: [
        goal('steps', healthKit),
        goal('was-steps'), // its HealthKit rule was removed
        compoundGoal('compound'),
        goal('water'), // genuinely manual — but see the rule-less test above
        goal('screen', screenTime),
      ],
    );

    expect(out.map((l) => l['value']).toList(), [null, null, null, null, 45]);
  });

  test('tolerates a null backupGoals and malformed goal entries', () {
    expect(strip(logs: const [], backupGoals: null), isEmpty);
    expect(
      strip(logs: [log('g1', value: 1)], backupGoals: ['nonsense', 42]).single['value'],
      isNull, // unresolvable → treated as HealthKit
    );
  });
}
