import 'dart:io';

import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the rule the codebase states as absolute: **a HealthKit measurement
/// must never reach Supabase.**
///
/// It rides in `goal_logs.value`, which a Private-mode backup carries, so
/// restoring such a file into a Cloud account uploads every quantity Apple
/// Health measured. Mobile enforced this from the start; desktop shipped
/// WITHOUT the guard because the port dropped the `stripHealthMeasurements`
/// call while keeping the sibling comment on the very next line — which is
/// exactly why nobody noticed by reading the file.
///
/// The behavioural unit tests live with the function
/// (packages/evolve_verification/test/health_measurement_privacy_test.dart).
/// What cannot be asserted there is that each client actually CALLS it, and
/// that is the thing that regressed. A source-level assertion is the honest
/// instrument here: `_executeCloudImport` needs a live SupabaseClient, so
/// driving it in a unit test would mean mocking the very call site under test.
/// Same approach as desktop_supabase_config_security_test.
void main() {
  final repoRoot = _findRepoRoot();

  /// Both cloud importers, keyed by the app they belong to.
  final cloudImporters = {
    'desktop': '${repoRoot.path}/desktop/lib/core/desktop_backup_import_service.dart',
    'mobile': '${repoRoot.path}/mobile/lib/core/backup_import_service.dart',
  };

  for (final entry in cloudImporters.entries) {
    test('${entry.key} strips health measurements before upserting goal_logs',
        () {
      final file = File(entry.value);
      expect(file.existsSync(), isTrue, reason: 'not found: ${entry.value}');
      final src = file.readAsStringSync();

      // Find the goal_logs upsert and confirm the stripping wraps it. The
      // payload argument must not be a bare `plan.logs`.
      final upsert = RegExp(
        r"_bulkUpsert\(\s*client,\s*'goal_logs',\s*([^;]*?)\)\s*;",
        dotAll: true,
      ).firstMatch(src);

      expect(upsert, isNotNull,
          reason: 'no goal_logs cloud upsert found in ${entry.key} — if the '
              'call was renamed, update this guard rather than deleting it');

      final payload = upsert!.group(1)!;
      expect(
        payload.contains('stripHealthMeasurements'),
        isTrue,
        reason: 'the ${entry.key} cloud import uploads goal_logs without '
            'stripHealthMeasurements, so a Private-mode backup would carry '
            'HealthKit quantities into Supabase. Payload was: '
            '${payload.trim()}',
      );
    });
  }

  test('the shared implementation still nulls a health-derived value', () {
    // A canary tying this file to real behaviour: if the function stops
    // stripping, the source check above would still pass while the guarantee is
    // gone. `screen` is the control — a Screen Time number is the one value the
    // strip is allowed to keep, so an all-null result would pass this vacuously.
    final out = stripHealthMeasurements(
      logs: [
        {'goal_id': 'steps', 'date': '2026-07-27', 'status': 'done', 'value': 12043},
        {'goal_id': 'screen', 'date': '2026-07-27', 'status': 'done', 'value': 45},
      ],
      backupGoals: [
        {'id': 'steps', 'verify_provider': VerificationProvider.healthKit.wireName},
        {'id': 'screen', 'verify_provider': VerificationProvider.screenTime.wireName},
      ],
    );

    expect(out.firstWhere((l) => l['goal_id'] == 'steps')['value'], isNull);
    expect(out.firstWhere((l) => l['goal_id'] == 'screen')['value'], 45);
  });
}

Directory _findRepoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (Directory('${dir.path}/mobile').existsSync() &&
        Directory('${dir.path}/desktop').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Could not locate the repo root from ${Directory.current.path}');
}
