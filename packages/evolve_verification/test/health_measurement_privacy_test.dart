// Unit tests for stripHealthMeasurements (src/health_measurement_privacy.dart).
// Lives in the package because BOTH clients depend on it: desktop shipped for
// months without the guard while mobile had it, so the single implementation is
// tested in the single place it now lives.
// — the guard that keeps a HealthKit-measured quantity out of the Supabase
// payload the Cloud-mode backup restore uploads. Being pure, it needs no
// Supabase: _executeCloudImport feeds it plan.logs, the backup's goals and the
// account's existing goal rows, and uploads exactly what it returns.
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

  test('leaves a manual goal\'s logs untouched', () {
    final logs = [log('g1', value: 2)];

    final out = strip(logs: logs, backupGoals: [goal('g1')]);

    expect(out.single['value'], 2);
    expect(out.single, same(logs.single)); // untouched rows are not copied
  });

  test('leaves a Screen Time goal\'s logs untouched', () {
    final out = strip(
      logs: [log('g1', value: 45)],
      backupGoals: [goal('g1', screenTime)],
    );

    expect(out.single['value'], 45);
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

  test('strips only the HealthKit goals in a mixed payload', () {
    final out = strip(
      logs: [
        log('steps', value: 12043),
        log('water', value: 2),
        log('screen', value: 45),
      ],
      backupGoals: [
        goal('steps', healthKit),
        goal('water'),
        goal('screen', screenTime),
      ],
    );

    expect(out.map((l) => l['value']).toList(), [null, 2, 45]);
  });

  test('tolerates a null backupGoals and malformed goal entries', () {
    expect(strip(logs: const [], backupGoals: null), isEmpty);
    expect(
      strip(logs: [log('g1', value: 1)], backupGoals: ['nonsense', 42]).single['value'],
      isNull, // unresolvable → treated as HealthKit
    );
  });
}
