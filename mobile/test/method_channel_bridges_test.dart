import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/method_channel_health_kit_bridge.dart';
import 'package:mattioli_os/core/method_channel_screen_time_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  MethodCall? lastCall;

  void mock(MethodChannel channel, Object? Function(MethodCall call) responder) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      lastCall = call;
      return responder(call);
    });
  }

  void unregister(MethodChannel channel) =>
      messenger.setMockMethodCallHandler(channel, null);

  setUp(() => lastCall = null);

  group('MethodChannelHealthKitBridge', () {
    const bridge = MethodChannelHealthKitBridge();
    const channel = MethodChannelHealthKitBridge.channel;
    tearDown(() => unregister(channel));

    test('isHealthDataAvailable maps bool; missing plugin → false', () async {
      mock(channel, (_) => true);
      expect(await bridge.isHealthDataAvailable(), isTrue);
      unregister(channel);
      expect(await bridge.isHealthDataAvailable(), isFalse);
    });

    test('dailyQuantity sends type/aggregation + a local day window', () async {
      mock(channel, (_) => 12043.0);
      final day = DateTime(2026, 7, 13);
      final v = await bridge.dailyQuantity(
        typeIdentifier: 'stepCount',
        aggregation: VerificationAggregation.sum,
        day: day,
      );
      expect(v, 12043.0);
      final args = lastCall!.arguments as Map;
      expect(args['type'], 'stepCount');
      expect(args['aggregation'], 'sum');
      expect(args['startMs'], DateTime(2026, 7, 13).millisecondsSinceEpoch);
      expect(args['endMs'], DateTime(2026, 7, 14).millisecondsSinceEpoch);
    });

    test('dailyQuantity coerces an int NSNumber to double', () async {
      mock(channel, (_) => 12); // e.g. a whole stand-hours count
      final v = await bridge.dailyQuantity(
        typeIdentifier: 'appleStandHour',
        aggregation: VerificationAggregation.count,
        day: DateTime(2026, 7, 13),
      );
      expect(v, 12.0);
    });

    test('dailyQuantity: null (no data) and missing plugin both → null',
        () async {
      mock(channel, (_) => null);
      expect(
        await bridge.dailyQuantity(
            typeIdentifier: 'stepCount',
            aggregation: VerificationAggregation.sum,
            day: DateTime(2026, 7, 13)),
        isNull,
      );
      unregister(channel);
      expect(
        await bridge.dailyQuantity(
            typeIdentifier: 'stepCount',
            aggregation: VerificationAggregation.sum,
            day: DateTime(2026, 7, 13)),
        isNull,
      );
    });

    test('requestAuthorization forwards the type set', () async {
      mock(channel, (_) => null);
      await bridge.requestAuthorization({'stepCount', 'sleepAnalysis'});
      expect(lastCall!.method, 'requestAuthorization');
      expect(
        ((lastCall!.arguments as Map)['types'] as List).toSet(),
        {'stepCount', 'sleepAnalysis'},
      );
    });

    test('hasRecentData forwards args and maps bool', () async {
      mock(channel, (_) => true);
      final has = await bridge.hasRecentData(
          typeIdentifier: 'appleStandHour', withinDays: 7);
      expect(has, isTrue);
      final args = lastCall!.arguments as Map;
      expect(args['type'], 'appleStandHour');
      expect(args['withinDays'], 7);
    });
  });

  group('MethodChannelScreenTimeBridge', () {
    const bridge = MethodChannelScreenTimeBridge();
    const channel = MethodChannelScreenTimeBridge.channel;
    tearDown(() => unregister(channel));

    test('authorizationStatus maps wire strings; unknown/missing → notDetermined',
        () async {
      mock(channel, (_) => 'approved');
      expect(await bridge.authorizationStatus(),
          ScreenTimeAuthorizationStatus.approved);
      mock(channel, (_) => 'denied');
      expect(await bridge.authorizationStatus(),
          ScreenTimeAuthorizationStatus.denied);
      mock(channel, (_) => 'weird');
      expect(await bridge.authorizationStatus(),
          ScreenTimeAuthorizationStatus.notDetermined);
      unregister(channel);
      expect(await bridge.authorizationStatus(),
          ScreenTimeAuthorizationStatus.notDetermined);
    });

    test('syncMonitoredGoals encodes each spec', () async {
      mock(channel, (_) => null);
      await bridge.syncMonitoredGoals([
        const ScreenTimeGoalSpec(
            goalId: 'g1', thresholdMinutes: 120, activeWeekdays: {1, 3, 5}),
      ]);
      final goals = (lastCall!.arguments as Map)['goals'] as List;
      final g = goals.single as Map;
      expect(g['goalId'], 'g1');
      expect(g['thresholdMinutes'], 120);
      expect(g['weekdays'], [1, 3, 5]);
    });

    test('syncMonitoredGoals maps a monitor_limit error to the typed exception',
        () async {
      mock(channel, (_) {
        throw PlatformException(
            code: 'monitor_limit', details: {'attempted': 21, 'limit': 20});
      });
      expect(
        () => bridge.syncMonitoredGoals(const []),
        throwsA(isA<ScreenTimeMonitorLimitException>()
            .having((e) => e.attempted, 'attempted', 21)
            .having((e) => e.limit, 'limit', 20)),
      );
    });

    test('syncMonitoredGoals missing plugin → no-op', () async {
      unregister(channel);
      await bridge.syncMonitoredGoals(const [
        ScreenTimeGoalSpec(goalId: 'g', thresholdMinutes: 60),
      ]); // must not throw
    });

    test('drainSignals decodes signals and skips malformed rows', () async {
      mock(channel, (_) => [
            {'goalId': 'g1', 'date': '2026-07-12', 'kind': 'reachedThreshold'},
            {'goalId': 'g1', 'date': '2026-07-11', 'kind': 'stayedUnder'},
            {'goalId': 'g1', 'date': '2026-07-10', 'kind': 'garbage'}, // dropped
            {'date': '2026-07-09', 'kind': 'stayedUnder'}, // no goalId → dropped
          ]);
      final signals = await bridge.drainSignals();
      expect(signals, hasLength(2));
      expect(signals[0].goalId, 'g1');
      expect(signals[0].day, DateTime(2026, 7, 12));
      expect(signals[0].kind, ScreenTimeSignalKind.reachedThreshold);
      expect(signals[1].kind, ScreenTimeSignalKind.stayedUnder);
    });

    test('drainSignals missing plugin → empty', () async {
      unregister(channel);
      expect(await bridge.drainSignals(), isEmpty);
    });

    test('requestIndividualAuthorization invokes the method', () async {
      mock(channel, (_) => null);
      await bridge.requestIndividualAuthorization();
      expect(lastCall!.method, 'requestIndividualAuthorization');
    });
  });
}
