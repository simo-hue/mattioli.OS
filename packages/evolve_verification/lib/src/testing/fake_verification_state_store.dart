import '../verification_state_store.dart';

/// In-memory [VerificationStateStore] for tests.
class FakeVerificationStateStore implements VerificationStateStore {
  /// goalId -> frozen day (date-only) -> the status the user chose, or null for
  /// a freeze recorded without one.
  final Map<String, Map<DateTime, String?>> manual = {};

  /// goalId -> set of couldn't-verify day (date-only).
  final Map<String, Set<DateTime>> cnv = {};

  /// goalId -> set of couldn't-verify days already nudged (subset of [cnv]).
  final Map<String, Set<DateTime>> nudged = {};

  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  @override
  Future<Map<String, Map<DateTime, String?>>> manualDays({
    required Iterable<String> goalIds,
    required DateTime from,
    required DateTime to,
  }) async {
    final lo = _d(from);
    final hi = _d(to);
    final out = <String, Map<DateTime, String?>>{};
    for (final id in goalIds) {
      final days = manual[id];
      if (days == null) continue;
      final inRange = <DateTime, String?>{
        for (final e in days.entries)
          if (!e.key.isBefore(lo) && !e.key.isAfter(hi)) e.key: e.value,
      };
      if (inRange.isNotEmpty) out[id] = inRange;
    }
    return out;
  }

  @override
  Future<Set<DateTime>> couldNotVerifyDays(String goalId) async =>
      {...?cnv[goalId]};

  @override
  Future<void> markManual(String goalId, DateTime day, {String? status}) async {
    (manual[goalId] ??= {})[_d(day)] = status;
    cnv[goalId]?.remove(_d(day));
    nudged[goalId]?.remove(_d(day));
  }

  @override
  Future<void> clearManual(String goalId, DateTime day) async {
    manual[goalId]?.remove(_d(day));
  }

  @override
  Future<void> recordCouldNotVerify(String goalId, DateTime day) async {
    if (manual[goalId]?.containsKey(_d(day)) ?? false) return;
    (cnv[goalId] ??= {}).add(_d(day));
  }

  @override
  Future<void> resolveCouldNotVerify(String goalId, DateTime day) async {
    cnv[goalId]?.remove(_d(day));
    nudged[goalId]?.remove(_d(day));
  }

  @override
  Future<void> pruneCouldNotVerifyBefore(String goalId, DateTime day) async {
    final cut = _d(day);
    cnv[goalId]?.removeWhere((d) => d.isBefore(cut));
    nudged[goalId]?.removeWhere((d) => d.isBefore(cut));
  }

  @override
  Future<Set<DateTime>> nudgedDays(String goalId) async => {...?nudged[goalId]};

  @override
  Future<void> markNudged(String goalId, DateTime day) async {
    // Only a live couldn't-verify day can be nudged.
    if (!(cnv[goalId]?.contains(_d(day)) ?? false)) return;
    (nudged[goalId] ??= {}).add(_d(day));
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    manual.remove(goalId);
    cnv.remove(goalId);
    nudged.remove(goalId);
  }
}
