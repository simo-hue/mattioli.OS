import 'package:flutter/foundation.dart';

/// FamilyControls authorization state. Unlike HealthKit reads, Screen Time
/// authorization *is* directly queryable, so revocation is detected immediately
/// (D9).
enum ScreenTimeAuthorizationStatus { notDetermined, approved, denied }

/// A goal the DeviceActivity monitor should watch (D2/D6).
///
/// v1 measures *total* device usage, expressed as an **empty** DeviceActivity
/// event (all activity) with a per-day threshold. [activeWeekdays] lets the app
/// ignore off-day threshold fires; empty means every day.
@immutable
class ScreenTimeGoalSpec {
  final String goalId;
  final int thresholdMinutes;

  /// ISO weekday numbers (1 = Mon … 7 = Sun); empty = daily.
  final Set<int> activeWeekdays;

  const ScreenTimeGoalSpec({
    required this.goalId,
    required this.thresholdMinutes,
    this.activeWeekdays = const {},
  });

  @override
  bool operator ==(Object other) =>
      other is ScreenTimeGoalSpec &&
      other.goalId == goalId &&
      other.thresholdMinutes == thresholdMinutes &&
      setEquals(other.activeWeekdays, activeWeekdays);

  @override
  int get hashCode =>
      Object.hash(goalId, thresholdMinutes, Object.hashAllUnordered(activeWeekdays));

  @override
  String toString() =>
      'ScreenTimeGoalSpec($goalId, ≤$thresholdMinutes min, days: $activeWeekdays)';
}

/// What the `DeviceActivityMonitor` extension observed for a goal-day.
enum ScreenTimeSignalKind {
  /// `eventDidReachThreshold` fired — usage exceeded the limit ⇒ fail.
  reachedThreshold,

  /// `intervalDidEnd` arrived with no threshold event — stayed under ⇒ pass.
  stayedUnder,
}

/// One outcome the Monitor extension wrote to the App Group (D3). The app
/// drains these on foreground and maps them to verdicts.
@immutable
class ScreenTimeSignal {
  final String goalId;

  /// The local calendar day the signal refers to.
  final DateTime day;
  final ScreenTimeSignalKind kind;

  const ScreenTimeSignal({
    required this.goalId,
    required this.day,
    required this.kind,
  });

  @override
  bool operator ==(Object other) =>
      other is ScreenTimeSignal &&
      other.goalId == goalId &&
      other.day == day &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(goalId, day, kind);

  @override
  String toString() => 'ScreenTimeSignal($goalId, $day, ${kind.name})';
}

/// Raised by [ScreenTimeBridge.syncMonitoredGoals] when the number of monitored
/// activities would exceed Apple's documented cap of 20 (D10).
class ScreenTimeMonitorLimitException implements Exception {
  final int attempted;
  final int limit;
  const ScreenTimeMonitorLimitException(this.attempted, {this.limit = 20});

  @override
  String toString() =>
      'ScreenTimeMonitorLimitException: attempted $attempted, limit $limit';
}

/// Thin, event-based contract over native Screen Time / DeviceActivity (D7).
///
/// Unlike HealthKit there is no "query today's usage" — the app can only
/// register thresholds and later drain the extension's fired signals. The real
/// implementation is a MethodChannel to Swift in `mobile/`; tests use a fake.
abstract interface class ScreenTimeBridge {
  Future<ScreenTimeAuthorizationStatus> authorizationStatus();

  /// Requests `.individual` (self-monitoring) authorization once; covers all
  /// screen-time goals app-wide (D1/D9).
  Future<void> requestIndividualAuthorization();

  /// Reconciles the DeviceActivity registration to exactly [specs] — registers
  /// new goals, updates changed thresholds, and deregisters removed ones.
  /// Throws [ScreenTimeMonitorLimitException] past the 20-activity cap.
  Future<void> syncMonitoredGoals(List<ScreenTimeGoalSpec> specs);

  /// Reads and clears the App Group buffer of signals the Monitor extension
  /// has written since the last drain.
  Future<List<ScreenTimeSignal>> drainSignals();
}
