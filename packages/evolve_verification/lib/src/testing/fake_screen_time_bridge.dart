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
  Future<List<ScreenTimeSignal>> drainSignals() async {
    final drained = List<ScreenTimeSignal>.from(_buffer);
    _buffer.clear();
    return drained;
  }
}
