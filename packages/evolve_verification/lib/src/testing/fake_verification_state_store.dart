import '../verification_state_store.dart';

/// In-memory [VerificationStateStore] for tests.
class FakeVerificationStateStore implements VerificationStateStore {
  /// goalId -> set of manually-frozen day (date-only).
  final Map<String, Set<DateTime>> manual = {};

  /// goalId -> set of couldn't-verify day (date-only).
  final Map<String, Set<DateTime>> cnv = {};

  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  @override
  Future<Map<String, Set<DateTime>>> manualDays({
    required Iterable<String> goalIds,
    required DateTime from,
    required DateTime to,
  }) async {
    final lo = _d(from);
    final hi = _d(to);
    final out = <String, Set<DateTime>>{};
    for (final id in goalIds) {
      final days = manual[id];
      if (days == null) continue;
      final inRange = days
          .where((d) => !d.isBefore(lo) && !d.isAfter(hi))
          .toSet();
      if (inRange.isNotEmpty) out[id] = inRange;
    }
    return out;
  }

  @override
  Future<Set<DateTime>> couldNotVerifyDays(String goalId) async =>
      {...?cnv[goalId]};

  @override
  Future<void> markManual(String goalId, DateTime day) async {
    (manual[goalId] ??= {}).add(_d(day));
    cnv[goalId]?.remove(_d(day));
  }

  @override
  Future<void> clearManual(String goalId, DateTime day) async {
    manual[goalId]?.remove(_d(day));
  }

  @override
  Future<void> recordCouldNotVerify(String goalId, DateTime day) async {
    if (manual[goalId]?.contains(_d(day)) ?? false) return;
    (cnv[goalId] ??= {}).add(_d(day));
  }

  @override
  Future<void> resolveCouldNotVerify(String goalId, DateTime day) async {
    cnv[goalId]?.remove(_d(day));
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    manual.remove(goalId);
    cnv.remove(goalId);
  }
}
