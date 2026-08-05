/// Reports how many `goal_logs.streak` values in an exported Evolve backup
/// disagree with the streak recomputed from that habit's full history.
///
/// Read-only. It opens one file, prints a summary, and writes nothing — not the
/// backup, not the database, not the network.
///
/// Usage:
///   `dart run tool/audit_streaks.dart <export.json> [--all] [--json]`
///
/// Get the file from the app: Settings → Privacy → Export data. Both the
/// Private (`evolve_private_export.json`) and account-mode
/// (`mattioli_os_export.json`) exports are plain JSON and share the same
/// `habits` / `habitLogs` keys, so either works.
///
/// The export contains personal data. This tool is local-only by design: keep
/// the file on your machine and delete it when you are done.
library;

import 'dart:convert';
import 'dart:io';

import 'package:mattioli_os/core/streak_audit.dart';

/// Returning a value from `main` does NOT set the process exit code in Dart —
/// it has to be assigned. Keeping the logic in [_run] lets every branch report
/// its status as a plain return while still reaching the shell.
Future<void> main(List<String> args) async {
  exitCode = await _run(args);
}

Future<int> _run(List<String> args) async {
  final paths = args.where((a) => !a.startsWith('--')).toList();
  final showAll = args.contains('--all');
  final asJson = args.contains('--json');

  if (paths.length != 1) {
    stderr.writeln(
        'usage: dart run tool/audit_streaks.dart <export.json> [--all] [--json]');
    return 64; // EX_USAGE
  }

  final file = File(paths.single);
  if (!file.existsSync()) {
    stderr.writeln('No such file: ${paths.single}');
    return 66; // EX_NOINPUT
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(await file.readAsString());
  } on FormatException catch (e) {
    stderr.writeln('Not valid JSON: ${e.message}');
    return 65; // EX_DATAERR
  }
  if (decoded is! Map<String, dynamic>) {
    stderr.writeln('Expected a JSON object at the top level.');
    return 65;
  }

  final rawHabits = decoded['habits'];
  final rawLogs = decoded['habitLogs'];
  if (rawHabits is! List || rawLogs is! List) {
    stderr.writeln('This does not look like an Evolve export: expected '
        '"habits" and "habitLogs" arrays.');
    return 65;
  }

  final habits = <AuditHabit>[];
  final titles = <String, String>{};
  var undatedHabits = 0;
  for (final raw in rawHabits) {
    if (raw is! Map) continue;
    final id = raw['id'];
    if (id is! String) continue;
    // A habit with no parseable start date cannot be scored. Both existing
    // recompute paths substitute DateTime(2000); do the same so the audit
    // reports the same number the repair would write.
    final start = DateTime.tryParse('${raw['start_date']}');
    if (start == null) undatedHabits++;
    habits.add(AuditHabit(
      id: id,
      startDate: start ?? DateTime(2000),
      frequencyDays: _frequencyDays(raw['frequency_days']),
    ));
    final title = raw['title'];
    if (title is String && title.isNotEmpty) titles[id] = title;
  }

  final logs = <AuditLog>[];
  var undated = 0;
  for (final raw in rawLogs) {
    if (raw is! Map) continue;
    final goalId = raw['goal_id'];
    final status = raw['status'];
    if (goalId is! String || status is! String) continue;
    final date = DateTime.tryParse('${raw['date']}');
    if (date == null) {
      undated++;
      continue;
    }
    logs.add(AuditLog(
      goalId: goalId,
      date: date,
      status: status,
      storedStreak: (raw['streak'] as num?)?.toInt() ?? 0,
    ));
  }

  final report =
      auditStreaks(habits: habits, logs: logs, undatedLogs: undated);

  if (asJson) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'habitsInInput': report.habitsInInput,
      'habitsAudited': report.habitsAudited,
      'logsAudited': report.logsAudited,
      'orphanLogs': report.orphanLogs,
      'undatedLogs': report.undatedLogs,
      'mismatchCount': report.mismatchCount,
      'collapsedCount': report.collapsed.length,
      'mismatchesByGoal': report.mismatchesByGoal,
      'mismatches': [
        for (final m in report.mismatches)
          {
            'goalId': m.goalId,
            'title': titles[m.goalId],
            'date': streakDateKey(m.date),
            'stored': m.stored,
            'computed': m.computed,
            'looksCollapsed': m.looksCollapsed,
          },
      ],
    }));
    return report.isClean ? 0 : 1;
  }

  stdout.writeln('Source: ${file.path}');
  if (decoded['exportDate'] != null) {
    stdout.writeln('Exported: ${decoded['exportDate']}');
  }
  if (decoded['mode'] != null) {
    stdout.writeln('Mode: ${decoded['mode']}');
  }
  if (undatedHabits > 0) {
    stdout.writeln('WARNING: $undatedHabits habit(s) had no parseable '
        'start_date and were scored from the year 2000, matching what the '
        'existing recompute does.');
  }
  stdout.writeln();
  stdout.writeln(formatStreakAuditReport(
    report,
    titlesByGoalId: titles,
    sampleRows: showAll ? report.mismatchCount : 10,
  ));

  // Exit 1 on damage so this can gate a check without parsing the text.
  return report.isClean ? 0 : 1;
}

/// Coerces an exported `frequency_days` to ISO weekdays 1-7, or null.
///
/// Private mode JSON-decodes its TEXT column into a list before export; account
/// mode writes Postgres' native `integer[]`. Both arrive here as a JSON list.
/// An empty or entirely-unusable value becomes null — the documented "every
/// day" default — never an empty list, which `computeStreak` would otherwise
/// have to special-case.
List<int>? _frequencyDays(Object? raw) {
  if (raw == null) return null;
  final list = raw is String ? jsonDecode(raw) : raw;
  if (list is! List) return null;
  final days = <int>[];
  for (final v in list) {
    final n = v is num ? v.toInt() : int.tryParse('$v');
    if (n != null && n >= 1 && n <= 7 && !days.contains(n)) days.add(n);
  }
  if (days.isEmpty) return null;
  days.sort();
  return days;
}
