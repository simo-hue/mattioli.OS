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
      // Default spec is Mode B (total usage), no selection.
      expect(g['mode'], 'total');
      expect(g['selection'], isNull);
    });

    test('syncMonitoredGoals encodes Mode A with mode=apps + selection blob',
        () async {
      mock(channel, (_) => null);
      await bridge.syncMonitoredGoals([
        const ScreenTimeGoalSpec(
          goalId: 'g1',
          thresholdMinutes: 60,
          mode: ScreenTimeMode.appsAndCategories,
          selectionBlob: 'B64',
        ),
      ]);
      final g = ((lastCall!.arguments as Map)['goals'] as List).single as Map;
      expect(g['mode'], 'apps');
      expect(g['selection'], 'B64');
    });

    test('presentActivityPicker decodes result and forwards initial + labels',
        () async {
      mock(channel, (_) => {'blob': 'B64', 'appCount': 3, 'categoryCount': 2});
      final result = await bridge.presentActivityPicker(
        initialSelectionBlob: 'PREV',
        pickerTitle: 'T',
        doneLabel: 'D',
        cancelLabel: 'C',
      );
      expect(result, isNotNull);
      expect(result!.blob, 'B64');
      expect(result.applicationCount, 3);
      expect(result.categoryCount, 2);
      expect(lastCall!.method, 'presentActivityPicker');
      final args = lastCall!.arguments as Map;
      expect(args['selection'], 'PREV');
      expect(args['title'], 'T');
      expect(args['done'], 'D');
      expect(args['cancel'], 'C');
    });

    test('presentActivityPicker null result → null (cancelled)', () async {
      mock(channel, (_) => null);
      expect(await bridge.presentActivityPicker(), isNull);
    });

    test('presentActivityPicker missing plugin → null', () async {
      unregister(channel);
      expect(await bridge.presentActivityPicker(), isNull);
    });

    test('setLocalizedNotificationCopy forwards title + body', () async {
      mock(channel, (_) => null);
      await bridge.setLocalizedNotificationCopy(title: 'Ti', body: 'Bo');
      expect(lastCall!.method, 'setLocalizedNotificationCopy');
      final args = lastCall!.arguments as Map;
      expect(args['title'], 'Ti');
      expect(args['body'], 'Bo');
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

    // The extension writes explicitly-Gregorian integer components; they are
    // authoritative because no calendar, locale or era survives in them.
    test('integer y/m/d components are preferred over the legacy date string',
        () async {
      final today = DateTime.now();
      mock(channel, (_) => [
            {
              'goalId': 'g1',
              'y': today.year,
              'm': today.month,
              'd': today.day,
              // A stale/corrupt string must not win over the components.
              'date': '2569-07-28',
              'kind': 'reachedThreshold',
            },
          ]);
      final signals = await bridge.drainSignals();
      expect(signals, hasLength(1));
      expect(signals.single.day, DateTime(today.year, today.month, today.day));
    });

    // The native drain is DESTRUCTIVE — it clears the App Group buffer before
    // replying — and DeviceActivity has no re-query API. Anything that escapes
    // the decode loop loses every signal in the batch, permanently. One bad row
    // must cost only itself.
    test('A MALFORMED ROW COSTS ONLY ITSELF, never the whole batch', () async {
      final ok = DateTime.now().subtract(const Duration(days: 1));
      mock(channel, (_) => [
            {'goalId': 'g1', 'date': 'not-a-date', 'kind': 'stayedUnder'},
            {'goalId': 'g2', 'date': '2026-07', 'kind': 'stayedUnder'},
            {'goalId': 'g3', 'date': '', 'kind': 'stayedUnder'},
            {'goalId': 'g4', 'date': '2026-02-31', 'kind': 'stayedUnder'},
            {'goalId': 'g5', 'kind': 'stayedUnder'}, // no day at all
            // A non-String date: an unguarded cast here used to throw and take
            // the whole already-destroyed batch with it.
            {'goalId': 'g6', 'date': 20260712, 'kind': 'stayedUnder'},
            {'goalId': 77, 'date': '2026-07-12', 'kind': 'stayedUnder'},
            {
              'goalId': 'g8',
              'y': ok.year,
              'm': ok.month,
              'd': ok.day,
              'kind': 'reachedThreshold',
            },
          ]);
      final signals = await bridge.drainSignals();
      expect(signals, hasLength(1));
      expect(signals.single.goalId, 'g8');
    });

    test('an unreadable reply returns empty instead of killing the pass',
        () async {
      mock(channel, (_) => 'not a list at all');
      expect(await bridge.drainSignals(), isEmpty);
    });

    // A lazily-cast list type-checks its elements during ITERATION, which is
    // outside the per-row guard — so a single non-map element used to discard
    // every good row decoded before it, permanently.
    test('A NON-MAP ELEMENT MID-LIST DOES NOT DISCARD THE ROWS AROUND IT',
        () async {
      final day = DateTime.now().subtract(const Duration(days: 1));
      Map<String, Object?> row(String id) => {
            'goalId': id,
            'y': day.year,
            'm': day.month,
            'd': day.day,
            'kind': 'stayedUnder',
          };
      mock(channel, (_) => [row('g1'), row('g2'), 'a stray scalar', row('g4')]);

      final signals = await bridge.drainSignals();
      expect(signals.map((s) => s.goalId), ['g1', 'g2', 'g4']);
    });

    // The legacy string is why the `date` field is still written: it is what an
    // OLDER extension left in the App Group before the integer components
    // existed, and those rows survive the app update.
    test('a legacy date-string-only row is still accepted', () async {
      final day = DateTime.now().subtract(const Duration(days: 1));
      final key = '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      mock(channel, (_) => [
            {'goalId': 'legacy', 'date': key, 'kind': 'reachedThreshold'},
          ]);

      final signals = await bridge.drainSignals();
      expect(signals, hasLength(1));
      expect(signals.single.day, DateTime(day.year, day.month, day.day));
      expect(signals.single.kind, ScreenTimeSignalKind.reachedThreshold);
    });

    // A non-Gregorian device calendar renders the year in its own era. Magnitude
    // cannot distinguish those from real years — Ethiopic renders 2026 as 2018,
    // which any "sane-looking year" bound waves straight through — so the guard
    // is by proximity to today instead.
    test('NON-GREGORIAN ERA YEARS ARE REJECTED, including Ethiopic 2018',
        () async {
      mock(channel, (_) => [
            {'goalId': 'buddhist', 'date': '2569-07-28', 'kind': 'stayedUnder'},
            {'goalId': 'japanese', 'date': '0008-07-28', 'kind': 'stayedUnder'},
            {'goalId': 'minguo', 'date': '0115-07-28', 'kind': 'stayedUnder'},
            {'goalId': 'hebrew', 'date': '5786-07-28', 'kind': 'stayedUnder'},
            {'goalId': 'islamic', 'date': '1447-02-13', 'kind': 'stayedUnder'},
            {'goalId': 'persian', 'date': '1405-05-06', 'kind': 'stayedUnder'},
            // The one a magnitude bound of 2000..2200 would have accepted.
            {'goalId': 'ethiopic', 'date': '2018-11-21', 'kind': 'stayedUnder'},
          ]);
      expect(await bridge.drainSignals(), isEmpty);
    });

    test('requestIndividualAuthorization invokes the method', () async {
      mock(channel, (_) => null);
      await bridge.requestIndividualAuthorization();
      expect(lastCall!.method, 'requestIndividualAuthorization');
    });
  });
}
