// `replayPendingHabitLogs` reports how many queued entries it actually WROTE.
//
// That return value is load-bearing, not informational: the foreground handler
// in main.dart reloads the verdict map only when it is > 0. While the method
// returned void, the only honest reaction was "assume it wrote something", so
// every single resume invalidated `habitLogsProvider` — a full re-download of
// goal_logs (or a full SQLCipher read), every calendar repainted empty for a
// frame, and, offline, the map re-seeded from the blob frozen at app launch,
// silently reverting every check-in made since.
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/notifications.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

const _pendingLogsKey = 'pending_habit_logs';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('an empty queue replays nothing — the common resume', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    final r = await NotificationService().replayPendingHabitLogs();
    expect(r.written, 0,
        reason: 'the overwhelming majority of foregrounds have an empty queue '
            'and must not trigger a reload');
    expect(r.drained, isTrue,
        reason: 'an empty queue hides nothing, so auto-fail may run');
  });

  test('a queue that cannot be written reports 0 and keeps its entries',
      () async {
    // No Supabase session in this harness, so nothing can land. The contract
    // that matters: report 0 (so the caller does NOT reload) and leave the
    // entries queued for the next foreground, rather than dropping them.
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingLogsKey: <String>['goal-1|2026-08-01|done'],
    });

    final r = await NotificationService().replayPendingHabitLogs();
    expect(r.written, 0);
    expect(r.drained, isFalse,
        reason: 'the queue still holds a day the user DECIDED; auto-fail must '
            'not read that day as untouched and overwrite it');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_pendingLogsKey), ['goal-1|2026-08-01|done'],
        reason: 'an entry that never reached the server must survive to be '
            'retried — dropping it loses the user\'s tap');
  });

  test('concurrent callers share one replay', () async {
    // Both the lifecycle observer and the manual-target sweep replay on the
    // same resume. They used to race on the pending-logs key; they now share a
    // single in-flight run.
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    final results = await Future.wait([
      NotificationService().replayPendingHabitLogs(),
      NotificationService().replayPendingHabitLogs(),
    ]);

    expect(results.map((r) => r.written), [0, 0]);
    expect(results.map((r) => r.drained), [true, true]);
  });
}
