import 'verification_provider.dart';

/// Returns [logs] with the measured quantity removed from every log whose goal
/// the backup does not PROVE is free of HealthKit verification, ready to upload
/// to Supabase.
///
/// A HealthKit measurement may live in the private (SQLCipher + end-to-end
/// encrypted CloudKit) store but must never reach Supabase. It rides in
/// `goal_logs.value`, which a Private-mode backup carries, so restoring such a
/// file into a Cloud account would upload it. The verdict (status, streak, date)
/// still restores — only the quantity behind it is dropped. `value` is written
/// as an explicit null rather than omitted so a measurement an older build
/// uploaded is cleared by the restore instead of surviving under it.
///
/// [backupGoals] is the canonical `kGoalsKey` list, and the test against it is
/// deliberately ONE-SIDED: a value survives only when the file resolves its goal
/// AND that goal carries a rule positively known not to be HealthKit — today
/// only Screen Time, whose number is not an Apple Health reading. Every other
/// goal strips, because the rule does NOT reliably travel with the value it
/// governs (as this doc once claimed):
///
/// - a goal the file does not resolve — planCloudImport keeps a log whose goal
///   lives on the account but not in the backup, so its rule is unknowable;
/// - a habit whose HealthKit rule the user later REMOVED: [verificationColumnsFor]
///   writes `VerificationRule.nullColumns`, while the measured logs stay (nothing
///   deletes them), so the goal reads as manual with real quantities behind it;
/// - a habit the user CONVERTED to compound: the rule moves into
///   `verify_conditions` and the flat columns are deliberately nulled so a
///   pre-compound client can't mis-verify it — which would read as manual here
///   too, over values written while it was still a single rule;
/// - any `verify_conditions` blob, decodable or not: a compound habit's
///   conditions are all HealthKit by construction (Q2), and a newer client's
///   wider set this build cannot decode is unknowable, so both strip.
///
/// That is the same one-sided test as `goal?.verificationRule?.isHealthKit ??
/// true` in HabitLogsNotifier.applyAutoVerdict, the only other Supabase writer of
/// this column — absent evidence counts as health-derived. Being this blunt costs
/// no real data: `goal_logs.value` only ever carries a verification measurement
/// (a manual toggle CLEARS it, and a quantitative target's number lives in
/// `goal_progress`), so a value sitting on a rule-less goal is a stale HealthKit
/// reading by construction.
///
/// The file is the only source consulted. Reading the rule back from Supabase
/// instead would make every cloud import depend on the verification migration
/// having been applied, which `Goal.toJson` deliberately avoids.
List<Map<String, dynamic>> stripHealthMeasurements({
  required List<Map<String, dynamic>> logs,
  required Object? backupGoals,
}) {
  // The goals whose measured quantity is provably NOT an Apple Health reading.
  // Anything absent from this set — unresolvable, manual, rule-removed, compound
  // or outright HealthKit — has its value dropped.
  final keepValueGoalIds = <String>{};
  // Ids some entry FAILED to prove non-health. A hand-edited or merged file can
  // carry the same id twice, and one entry vouching for it must not outvote
  // another that doesn't: proof has to be unanimous, so these are subtracted.
  final unproven = <String>{};

  if (backupGoals is List) {
    for (final goal in backupGoals) {
      if (goal is! Map) continue;
      final id = goal['id'];
      if (id is! String) continue;
      (_isProvablyNonHealth(goal) ? keepValueGoalIds : unproven).add(id);
    }
    keepValueGoalIds.removeAll(unproven);
  }

  return [
    for (final log in logs)
      if (log['value'] != null && !keepValueGoalIds.contains(log['goal_id']))
        {...log, 'value': null}
      else
        log,
  ];
}

/// Whether [goal] (one canonical backup goal map) carries a verification rule
/// that is positively NOT HealthKit — today only Screen Time.
///
/// Any `verify_conditions` blob disqualifies the goal outright, without decoding
/// it: a compound habit is HealthKit-only by construction, and a blob this build
/// can't read is unknowable. Reads are type-safe throughout — a hand-edited or
/// foreign file may put anything in these keys, and a wrong-typed field must
/// degrade to "not proven" rather than throw out of the upload path.
bool _isProvablyNonHealth(Map<Object?, Object?> goal) {
  final conditions = goal['verify_conditions'];
  final hasConditions =
      conditions is String ? conditions.trim().isNotEmpty : conditions != null;
  if (hasConditions) return false;

  final rawProvider = goal['verify_provider'];
  final provider =
      VerificationProvider.fromWire(rawProvider is String ? rawProvider : null);
  return provider != null && provider != VerificationProvider.healthKit;
}
