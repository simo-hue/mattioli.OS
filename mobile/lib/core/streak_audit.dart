/// Pure, read-only audit of the denormalized `goal_logs.streak` column.
///
/// `streak` is a **cache** of a pure function of data the app already holds — a
/// habit's full log history, its start date and its weekly schedule — so any
/// row whose stored value disagrees with [computeStreak] is stale or corrupt.
/// This library computes that disagreement and writes NOTHING.
///
/// Why it exists: `applyAutoVerdict` and `setDerivedStatus` recompute the
/// streak from a LIVE `ref.read(goalsProvider)` on every write. When that list
/// is transiently empty the goal resolves to null, `startDate` falls back to
/// the day being written, and [computeStreak]'s backward walk breaks on its
/// first step — persisting a long streak as ±1 into a SYNCED table. The damage
/// has to be measured before it can be argued about, and measured again after
/// the fix to prove the bleeding stopped.
///
/// The repair that acts on this report reuses [auditStreaks] as its core, so
/// the number reported and the number written can never drift apart.
///
/// Deliberately mirrors the per-goal shape of `_recomputeStreaks`
/// (`import_merge.dart`) and `_recomputeCloudStreaks`
/// (`backup_import_service.dart`): a goal's ENTIRE history is loaded before any
/// of its rows are scored, because a streak computed from a truncated history
/// is wrong — and would then be written back over the correct value.
///
/// Pure Dart on purpose (no Flutter imports), so `tool/audit_streaks.dart` can
/// run it over an exported backup with `dart run`.
library;

import 'streak_utils.dart';

/// A habit reduced to the three fields [computeStreak] needs.
class AuditHabit {
  const AuditHabit({
    required this.id,
    required this.startDate,
    this.frequencyDays,
  });

  final String id;
  final DateTime startDate;

  /// ISO weekdays 1=Mon…7=Sun; `null`/empty ⇒ every day.
  final List<int>? frequencyDays;
}

/// One persisted `goal_logs` row, reduced to what the audit needs.
class AuditLog {
  const AuditLog({
    required this.goalId,
    required this.date,
    required this.status,
    required this.storedStreak,
  });

  final String goalId;
  final DateTime date;

  /// `'done'` or `'missed'` — the values [computeStreak] recognises.
  final String status;

  /// The value currently persisted in `goal_logs.streak`. A NULL column reads
  /// as 0, matching `(r['streak'] as num?)?.toInt() ?? 0` in both existing
  /// recompute paths.
  final int storedStreak;
}

/// One row whose stored streak disagrees with the recomputed one.
class StreakMismatch {
  const StreakMismatch({
    required this.goalId,
    required this.date,
    required this.stored,
    required this.computed,
  });

  final String goalId;
  final DateTime date;
  final int stored;
  final int computed;

  /// True when this row carries the signature of the empty-goals-window bug: a
  /// real multi-day streak flattened to ±1 because [computeStreak] was handed
  /// the written day itself as `startDate`. Distinguishes the corruption we are
  /// hunting from ordinary staleness, which has no characteristic shape.
  bool get looksCollapsed => stored.abs() == 1 && computed.abs() > 1;

  @override
  String toString() =>
      '$goalId ${_isoDay(date)}: stored $stored, computed $computed';
}

/// The result of an audit. Carries the raw mismatches so a caller can repair
/// exactly the rows that are wrong rather than rewriting the whole table.
class StreakAuditReport {
  const StreakAuditReport({
    required this.habitsInInput,
    required this.habitsAudited,
    required this.logsAudited,
    required this.orphanLogs,
    required this.undatedLogs,
    required this.mismatches,
  });

  /// Every habit handed to the audit.
  final int habitsInInput;

  /// Habits that actually had at least one log to score.
  final int habitsAudited;

  /// Log rows scored.
  final int logsAudited;

  /// Rows whose `goal_id` matches no habit. Not auditable — there is no start
  /// date to score against — and skipped exactly as `_recomputeStreaks` skips
  /// them (`if (goalRows.isEmpty) continue;`).
  final int orphanLogs;

  /// Rows the CALLER could not parse a date for, and so never handed to the
  /// audit. Carried here only so the summary can account for every row in the
  /// source; both existing recompute paths skip these identically
  /// (`if (d == null) continue;`).
  final int undatedLogs;

  /// Sorted by goal then date, so two runs over the same data print identically.
  final List<StreakMismatch> mismatches;

  int get mismatchCount => mismatches.length;

  bool get isClean => mismatches.isEmpty;

  /// The subset carrying the collapse signature — see [StreakMismatch.looksCollapsed].
  List<StreakMismatch> get collapsed =>
      [for (final m in mismatches) if (m.looksCollapsed) m];

  /// Mismatch count per habit, so a repair can be scoped and so the worst
  /// affected habits are visible without dumping every row.
  Map<String, int> get mismatchesByGoal {
    final out = <String, int>{};
    for (final m in mismatches) {
      out[m.goalId] = (out[m.goalId] ?? 0) + 1;
    }
    return out;
  }
}

/// `yyyy-MM-dd`, the key format [StreakLogs] uses.
///
/// Deliberately a local copy of `streak_utils.dart`'s private `_dateKey` rather
/// than a public export from it — that file is kept in lock-step with the
/// desktop copy by hand, and widening its API would put the two out of step.
/// The duplication is pinned by a test that would fail if the formats diverged:
/// a wrong key makes every lookup miss, so [computeStreak] returns 0 for a
/// history that plainly has a streak.
String streakDateKey(DateTime d) => _isoDay(d);

String _isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Recomputes every log's streak from its habit's full history and reports the
/// rows that disagree with what is stored. Writes nothing.
StreakAuditReport auditStreaks({
  required List<AuditHabit> habits,
  required List<AuditLog> logs,
  int undatedLogs = 0,
}) {
  final habitById = {for (final h in habits) h.id: h};

  final byGoal = <String, List<AuditLog>>{};
  var orphanLogs = 0;
  for (final log in logs) {
    if (!habitById.containsKey(log.goalId)) {
      orphanLogs++;
      continue;
    }
    (byGoal[log.goalId] ??= <AuditLog>[]).add(log);
  }

  final mismatches = <StreakMismatch>[];
  var logsAudited = 0;

  for (final entry in byGoal.entries) {
    final habit = habitById[entry.key]!;
    final rows = entry.value;

    // The WHOLE of this habit's history, built before any row is scored.
    final history = <String, Map<String, String>>{};
    for (final row in rows) {
      (history[streakDateKey(row.date)] ??= <String, String>{})[habit.id] =
          row.status;
    }

    for (final row in rows) {
      logsAudited++;
      final computed = computeStreak(
        habitId: habit.id,
        date: row.date,
        logs: history,
        startDate: habit.startDate,
        frequencyDays: habit.frequencyDays,
      );
      if (computed != row.storedStreak) {
        mismatches.add(StreakMismatch(
          goalId: habit.id,
          date: row.date,
          stored: row.storedStreak,
          computed: computed,
        ));
      }
    }
  }

  mismatches.sort((a, b) {
    final byId = a.goalId.compareTo(b.goalId);
    return byId != 0 ? byId : a.date.compareTo(b.date);
  });

  return StreakAuditReport(
    habitsInInput: habits.length,
    habitsAudited: byGoal.length,
    logsAudited: logsAudited,
    orphanLogs: orphanLogs,
    undatedLogs: undatedLogs,
    mismatches: mismatches,
  );
}

/// Renders [report] as a plain-text summary for a terminal or a log.
String formatStreakAuditReport(
  StreakAuditReport report, {
  Map<String, String> titlesByGoalId = const {},
  int sampleRows = 10,
}) {
  final b = StringBuffer();
  b.writeln('Streak audit');
  b.writeln('  habits           : ${report.habitsAudited} '
      'of ${report.habitsInInput} (with logs)');
  b.writeln('  log rows scored  : ${report.logsAudited}');
  if (report.orphanLogs > 0) {
    b.writeln('  orphan rows      : ${report.orphanLogs} '
        '(goal_id matches no habit — not auditable)');
  }
  if (report.undatedLogs > 0) {
    b.writeln('  unparseable dates: ${report.undatedLogs} (skipped)');
  }
  b.writeln('  MISMATCHED       : ${report.mismatchCount}');
  b.writeln('  of which collapsed to ±1 : ${report.collapsed.length}');

  if (report.isClean) {
    b.writeln();
    b.writeln('No corruption found — every stored streak matches its '
        'recomputed value.');
    return b.toString();
  }

  b.writeln();
  b.writeln('Per habit:');
  final byGoal = report.mismatchesByGoal.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in byGoal) {
    final title = titlesByGoalId[e.key];
    b.writeln('  ${e.value.toString().padLeft(5)}  '
        '${title == null ? e.key : '$title  (${e.key})'}');
  }

  // ONE list under ONE budget, collapsed rows first so the corruption
  // signature leads. Selecting `collapsed` as the whole sample (rather than
  // merely ordering by it) would hide every other mismatched row the moment a
  // single ±1 row existed — and these are precisely the rows a repair would
  // overwrite, so the reader must be able to see all of them.
  final ordered = <StreakMismatch>[
    ...report.collapsed,
    for (final m in report.mismatches)
      if (!m.looksCollapsed) m,
  ];
  final shown = ordered.take(sampleRows).toList();

  b.writeln();
  b.writeln(report.collapsed.isEmpty
      ? 'Sample of mismatched rows:'
      : 'Sample of mismatched rows, ±1 collapses (the corruption signature) '
          'first:');
  for (final m in shown) {
    final title = titlesByGoalId[m.goalId];
    b.writeln('  ${_isoDay(m.date)}  ${title ?? m.goalId}  '
        'stored ${m.stored} -> should be ${m.computed}'
        '${m.looksCollapsed ? '  [collapsed]' : ''}');
  }
  if (ordered.length > shown.length) {
    b.writeln('  … and ${ordered.length - shown.length} more');
  }
  return b.toString();
}
