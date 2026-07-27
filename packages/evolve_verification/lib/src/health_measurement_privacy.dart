import 'verification_provider.dart';

/// Returns [logs] with the HealthKit-measured quantity removed from every log
/// that belongs to a HealthKit-verified goal, ready to upload to Supabase.
///
/// A HealthKit measurement may live in the private (SQLCipher + end-to-end
/// encrypted CloudKit) store but must never reach Supabase. It rides in
/// `goal_logs.value`, which a Private-mode backup carries, so restoring such a
/// file into a Cloud account would upload it. The verdict (status, streak, date)
/// still restores — only the quantity behind it is dropped. `value` is written
/// as an explicit null rather than omitted so a measurement an older build
/// uploaded is cleared by the restore instead of surviving under it.
///
/// [backupGoals] is the canonical `kGoalsKey` list, and a goal it does not
/// resolve is treated as HealthKit-verified — mirroring the `?? true` fallback
/// in HabitLogsNotifier.applyAutoVerdict, the only other Supabase writer of this
/// column. The file is the only source consulted: a measured value can only
/// reach a backup through a Private-mode export, which always writes
/// `verify_provider` (null when manual), so the rule always travels with the
/// value it governs. Reading the rule back from Supabase instead would make
/// every cloud import depend on the verification migration having been applied,
/// which `Goal.toJson` deliberately avoids.
List<Map<String, dynamic>> stripHealthMeasurements({
  required List<Map<String, dynamic>> logs,
  required Object? backupGoals,
}) {
  final healthKit = VerificationProvider.healthKit.wireName;
  final knownGoalIds = <String>{};
  final healthGoalIds = <String>{};

  if (backupGoals is List) {
    for (final goal in backupGoals) {
      if (goal is! Map) continue;
      final id = goal['id'];
      if (id is! String) continue;
      knownGoalIds.add(id);
      if (goal['verify_provider'] == healthKit) healthGoalIds.add(id);
    }
  }

  bool isHealthDerived(Object? goalId) =>
      healthGoalIds.contains(goalId) || !knownGoalIds.contains(goalId);

  return [
    for (final log in logs)
      if (log['value'] != null && isHealthDerived(log['goal_id']))
        {...log, 'value': null}
      else
        log,
  ];
}
