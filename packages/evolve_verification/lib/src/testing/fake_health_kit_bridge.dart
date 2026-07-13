import '../health_kit_bridge.dart';
import '../verification_provider.dart';

/// In-memory [HealthKitBridge] for unit tests (mirrors evolve_sync's fake
/// pattern). Program daily quantities per type + day; unprogrammed days return
/// null (→ the couldn't-verify / pending path).
class FakeHealthKitBridge implements HealthKitBridge {
  FakeHealthKitBridge({this.available = true});

  bool available;

  /// `typeIdentifier -> (date-only -> quantity)`. A null value (or a missing
  /// entry) models "no data / can't determine".
  final Map<String, Map<DateTime, double?>> quantities = {};

  /// `typeIdentifier -> hasRecentData` answer for the Watch probe.
  final Map<String, bool> recentData = {};

  /// Records every set of types authorization was requested for.
  final List<Set<String>> authorizationRequests = [];

  void setQuantity(String typeIdentifier, DateTime day, double? value) {
    final d = DateTime(day.year, day.month, day.day);
    (quantities[typeIdentifier] ??= {})[d] = value;
  }

  @override
  Future<bool> isHealthDataAvailable() async => available;

  @override
  Future<void> requestAuthorization(Set<String> typeIdentifiers) async {
    authorizationRequests.add(typeIdentifiers);
  }

  @override
  Future<double?> dailyQuantity({
    required String typeIdentifier,
    required VerificationAggregation aggregation,
    required DateTime day,
  }) async {
    final d = DateTime(day.year, day.month, day.day);
    final byDay = quantities[typeIdentifier];
    if (byDay == null || !byDay.containsKey(d)) return null;
    return byDay[d];
  }

  @override
  Future<bool> hasRecentData({
    required String typeIdentifier,
    required int withinDays,
  }) async =>
      recentData[typeIdentifier] ?? false;
}
