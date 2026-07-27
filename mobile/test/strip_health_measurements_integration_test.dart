// The mobile-only half of the stripHealthMeasurements coverage: the PURE unit
// tests live with the function in packages/evolve_verification. What can only be
// asserted here is the wiring — that mobile's own backup normalizer carries
// `verify_provider` into kGoalsKey, because the whole design rests on the rule
// travelling alongside the value it governs.
import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/import_merge.dart';

void main() {
  final healthKit = VerificationProvider.healthKit.wireName;

  test('strips a real Private-mode export routed through normalizeBackup', () {
    // The design rests on the rule travelling with the value it governs:
    // PrivateLocalDatabase.exportData emits verify_provider next to every log's
    // value, and normalizeBackup must carry it into kGoalsKey. If either stops,
    // the steps measurement below survives into the Supabase payload.
    final canonical = normalizeBackup({
      'habits': [
        {'id': 'steps', 'title': 'Steps', 'verify_provider': healthKit},
        {'id': 'water', 'title': 'Water', 'verify_provider': null},
      ],
      'habitLogs': [
        {'goal_id': 'steps', 'date': '2026-07-14', 'status': 'done', 'value': 12043},
        {'goal_id': 'water', 'date': '2026-07-14', 'status': 'done', 'value': 2},
      ],
    });

    final out = stripHealthMeasurements(
      logs: (canonical[kLogsKey] as List).cast<Map<String, dynamic>>(),
      backupGoals: canonical[kGoalsKey],
    );

    expect(out.firstWhere((l) => l['goal_id'] == 'steps')['value'], isNull);
    expect(out.firstWhere((l) => l['goal_id'] == 'water')['value'], 2);
  });
}
