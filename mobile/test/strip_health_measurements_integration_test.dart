// The mobile-only half of the stripHealthMeasurements coverage: the PURE unit
// tests live with the function in packages/evolve_verification. What can only be
// asserted here is the wiring — that mobile's own backup normalizer carries BOTH
// verification columns (`verify_provider` AND `verify_conditions`) into
// kGoalsKey, because the strip's only evidence is what the file resolves.
import 'dart:convert';

import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/import_merge.dart';

void main() {
  final healthKit = VerificationProvider.healthKit.wireName;
  final screenTime = VerificationProvider.screenTime.wireName;

  /// The real pipeline `_executeCloudImport` runs: normalize the file, validate
  /// it, then strip the payload it is about to upsert. Both steps rebuild the
  /// goal maps field by field, so either one can drop a verification column.
  List<Map<String, dynamic>> stripped(Map<String, dynamic> raw) {
    final canonical = validateCanonical(normalizeBackup(raw)).canonical;
    return stripHealthMeasurements(
      logs: (canonical[kLogsKey] as List).cast<Map<String, dynamic>>(),
      backupGoals: canonical[kGoalsKey],
    );
  }

  Map<String, dynamic> habit(String id, String title) => {
        'id': id,
        'title': title,
        'color': '#3B82F6',
        'start_date': '2026-01-01',
      };

  Map<String, dynamic> log(String goalId, num value) => {
        'goal_id': goalId,
        'date': '2026-07-14',
        'status': 'done',
        'value': value,
      };

  test('strips a real Private-mode export routed through normalizeBackup', () {
    // PrivateLocalDatabase.exportData emits the verification columns next to
    // every log's value, and normalizeBackup must carry them into kGoalsKey. If
    // either stops, the measurements below survive into the Supabase payload.
    // Only `screen` is provably non-health; `water` has no rule at all, which is
    // indistinguishable from a HealthKit rule the user later REMOVED, so its
    // value goes too.
    final out = stripped({
      'habits': [
        {...habit('steps', 'Steps'), 'verify_provider': healthKit},
        {...habit('water', 'Water'), 'verify_provider': null},
        {...habit('screen', 'Screen'), 'verify_provider': screenTime},
      ],
      'habitLogs': [log('steps', 12043), log('water', 2), log('screen', 45)],
    });

    expect(out.firstWhere((l) => l['goal_id'] == 'steps')['value'], isNull);
    expect(out.firstWhere((l) => l['goal_id'] == 'water')['value'], isNull);
    expect(out.firstWhere((l) => l['goal_id'] == 'screen')['value'], 45);
  });

  test('carries verify_conditions through, so a compound habit still strips',
      () {
    // A compound habit stores its (all-HealthKit) rule in verify_conditions and
    // NULLS the flat columns. If the normalizer dropped that column the goal
    // would arrive looking manual, and every measurement recorded before the
    // conversion would upload.
    final columns = verificationColumnsFor([
      const VerificationRule(
        provider: VerificationProvider.healthKit,
        metricKey: 'steps',
        comparator: VerificationComparator.atLeast,
        threshold: 10000,
        unit: VerificationUnit.count,
      ),
      const VerificationRule(
        provider: VerificationProvider.healthKit,
        metricKey: 'exercise',
        comparator: VerificationComparator.atLeast,
        threshold: 30,
        unit: VerificationUnit.minutes,
      ),
    ]);

    final raw = {
      'habits': [
        {...habit('compound', 'Move'), ...columns},
      ],
      'habitLogs': [log('compound', 11002)],
    };

    // The premise: the pipeline preserved the blob, and nothing else.
    final canonical = validateCanonical(normalizeBackup(raw)).canonical;
    final goal = (canonical[kGoalsKey] as List).single as Map<String, dynamic>;
    expect(goal['verify_provider'], isNull);
    expect(jsonDecode(goal['verify_conditions'] as String), isA<Map>());

    expect(stripped(raw).single['value'], isNull);
  });
}
