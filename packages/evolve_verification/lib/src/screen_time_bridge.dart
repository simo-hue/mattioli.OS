import 'package:flutter/foundation.dart';

/// FamilyControls authorization state. Unlike HealthKit reads, Screen Time
/// authorization *is* directly queryable, so revocation is detected immediately
/// (D9).
enum ScreenTimeAuthorizationStatus { notDetermined, approved, denied }

/// How a Screen Time goal is scoped on the device (Mode A vs Mode B).
///
/// - [appsAndCategories] (Mode A): the threshold measures the **combined** usage
///   of the apps/categories the user picked with `FamilyActivityPicker`, carried
///   as an opaque [ScreenTimeGoalSpec.selectionBlob]. Ships live.
/// - [totalUsage] (Mode B): the threshold measures **total** device usage,
///   expressed as an empty DeviceActivity event. Its on-device semantics are
///   still unverified, so it ships dark behind a feature flag.
enum ScreenTimeMode {
  appsAndCategories,
  totalUsage;

  /// The wire value the native side switches on. Must match Swift exactly.
  String get wireName => switch (this) {
        ScreenTimeMode.appsAndCategories => 'apps',
        ScreenTimeMode.totalUsage => 'total',
      };
}

/// A goal the DeviceActivity monitor should watch (D2/D6).
///
/// A [mode] of [ScreenTimeMode.appsAndCategories] carries a [selectionBlob] — an
/// opaque, base64-encoded `FamilyActivitySelection` the native side decodes into
/// the app/category tokens the threshold measures. The blob is device-local and
/// keyed by [goalId] by the app; it is NEVER synced. [ScreenTimeMode.totalUsage]
/// carries a null blob (empty selection = all activity). [activeWeekdays] lets
/// the app ignore off-day threshold fires; empty means every day.
@immutable
class ScreenTimeGoalSpec {
  final String goalId;
  final int thresholdMinutes;

  /// ISO weekday numbers (1 = Mon … 7 = Sun); empty = daily.
  final Set<int> activeWeekdays;

  /// How the goal is scoped (Mode A = picked apps, Mode B = total usage).
  final ScreenTimeMode mode;

  /// Opaque base64 `FamilyActivitySelection` for
  /// [ScreenTimeMode.appsAndCategories]; null for [ScreenTimeMode.totalUsage].
  /// Device-local, never synced.
  final String? selectionBlob;

  const ScreenTimeGoalSpec({
    required this.goalId,
    required this.thresholdMinutes,
    this.activeWeekdays = const {},
    this.mode = ScreenTimeMode.totalUsage,
    this.selectionBlob,
  });

  @override
  bool operator ==(Object other) =>
      other is ScreenTimeGoalSpec &&
      other.goalId == goalId &&
      other.thresholdMinutes == thresholdMinutes &&
      other.mode == mode &&
      other.selectionBlob == selectionBlob &&
      setEquals(other.activeWeekdays, activeWeekdays);

  @override
  int get hashCode => Object.hash(goalId, thresholdMinutes, mode, selectionBlob,
      Object.hashAllUnordered(activeWeekdays));

  @override
  String toString() =>
      'ScreenTimeGoalSpec($goalId, ≤$thresholdMinutes min, ${mode.name}, '
      'days: $activeWeekdays, selection: ${selectionBlob == null ? 'none' : 'set'})';
}

/// The outcome of presenting `FamilyActivityPicker` (Mode A). The [blob] is an
/// opaque base64 `FamilyActivitySelection` the caller persists device-locally
/// keyed by goalId (never synced); the counts drive the "N apps, M categories"
/// summary shown in the habit editor.
@immutable
class ScreenTimeSelectionResult {
  final String blob;
  final int applicationCount;
  final int categoryCount;

  const ScreenTimeSelectionResult({
    required this.blob,
    required this.applicationCount,
    required this.categoryCount,
  });

  /// Whether the user actually picked anything. An empty selection cannot be
  /// monitored and must not be treated as "watch everything".
  bool get isEmpty => applicationCount == 0 && categoryCount == 0;

  @override
  String toString() =>
      'ScreenTimeSelectionResult(apps: $applicationCount, categories: $categoryCount)';
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

  /// Presents Apple's `FamilyActivityPicker` (Mode A) and returns the encoded
  /// selection, or null if the user cancelled or the picker is unavailable
  /// (dark build / entitlement absent / pre-iOS 16). [initialSelectionBlob]
  /// pre-seeds the picker when editing an existing goal. The label params
  /// localize the picker's own chrome (title / Done / Cancel); the app passes
  /// them because this package is i18n-free — native falls back to English.
  Future<ScreenTimeSelectionResult?> presentActivityPicker({
    String? initialSelectionBlob,
    String? pickerTitle,
    String? doneLabel,
    String? cancelLabel,
  });

  /// Hands the extension the current-locale copy for its "limit reached" local
  /// notification. The DeviceActivityMonitor extension cannot read Flutter's
  /// translations, so the app writes them into the shared App Group and the
  /// extension reads them back (falling back to English if absent).
  Future<void> setLocalizedNotificationCopy({
    required String title,
    required String body,
  });

  /// Reads and clears the App Group buffer of signals the Monitor extension
  /// has written since the last drain.
  Future<List<ScreenTimeSignal>> drainSignals();
}
