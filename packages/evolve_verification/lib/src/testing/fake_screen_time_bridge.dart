import '../screen_time_bridge.dart';

/// In-memory [ScreenTimeBridge] for unit tests. Queue signals with [addSignal];
/// [drainSignals] returns and clears them, exactly like the App Group buffer.
class FakeScreenTimeBridge implements ScreenTimeBridge {
  FakeScreenTimeBridge({
    this.status = ScreenTimeAuthorizationStatus.approved,
    this.monitorLimit = 20,
  });

  ScreenTimeAuthorizationStatus status;
  int monitorLimit;

  final List<ScreenTimeSignal> _buffer = [];

  /// The most recent argument passed to [syncMonitoredGoals].
  List<ScreenTimeGoalSpec> lastSyncedSpecs = const [];
  int syncCallCount = 0;
  int requestAuthorizationCount = 0;

  /// What [presentActivityPicker] returns; defaults to null (cancelled).
  ScreenTimeSelectionResult? nextPickerResult;
  int presentPickerCount = 0;
  String? lastPickerInitialBlob;

  /// The most recent localized notification copy handed to the extension.
  ({String title, String body})? lastNotificationCopy;

  void addSignal(ScreenTimeSignal signal) => _buffer.add(signal);

  @override
  Future<ScreenTimeAuthorizationStatus> authorizationStatus() async => status;

  @override
  Future<void> requestIndividualAuthorization() async {
    requestAuthorizationCount++;
    status = ScreenTimeAuthorizationStatus.approved;
  }

  @override
  Future<void> syncMonitoredGoals(List<ScreenTimeGoalSpec> specs) async {
    if (specs.length > monitorLimit) {
      throw ScreenTimeMonitorLimitException(specs.length, limit: monitorLimit);
    }
    syncCallCount++;
    lastSyncedSpecs = List.unmodifiable(specs);
  }

  @override
  Future<ScreenTimeSelectionResult?> presentActivityPicker({
    String? initialSelectionBlob,
    String? pickerTitle,
    String? doneLabel,
    String? cancelLabel,
  }) async {
    presentPickerCount++;
    lastPickerInitialBlob = initialSelectionBlob;
    return nextPickerResult;
  }

  @override
  Future<void> setLocalizedNotificationCopy({
    required String title,
    required String body,
  }) async {
    lastNotificationCopy = (title: title, body: body);
  }

  /// How many times [drainSignals] has been called. The drain is DESTRUCTIVE,
  /// so "was it called at all, and exactly once" is a correctness property, not
  /// a statistic.
  int drainCallCount = 0;

  @override
  Future<List<ScreenTimeSignal>> drainSignals() async {
    drainCallCount++;
    final drained = List<ScreenTimeSignal>.from(_buffer);
    _buffer.clear();
    return drained;
  }
}
