// A LIMIT habit's reminder ("at most 20 cigarettes") deliberately carries
// restraint copy — `reminderBody`'s own doc records why: on a day the user is
// succeeding by consuming nothing, a motivational "time to act on it" nudge
// inverts the goal.
//
// Every scheduler threads `isLimit` into the body. The snooze writer did not:
// the reminder's payload was only `habit|$id|$title`, so the background handler
// rebuilt the body with `isLimit` at its default of false and re-sent the very
// motivational line the limit branch exists to prevent — ten minutes after the
// correct one.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const habitId = '3f2a9c10-2c0e-4a3f-8f4d-0d6b1e7c9a55';
  const habitTitle = 'Sigarette';

  late List<MethodCall> calls;

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  setUpAll(() {
    // `scheduleHabitReminder` computes its seed date against `tz.local`, which
    // only the app's own init would have set.
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));
  });

  setUp(() {
    calls = <MethodCall>[];
    FlutterLocalNotificationsPlatform.instance =
        IOSFlutterLocalNotificationsPlugin();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      // `pendingNotificationRequests` feeds the 64-item cap guard; an empty
      // list means "plenty of headroom", so nothing is skipped.
      if (call.method == 'pendingNotificationRequests') return <Object?>[];
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      // A real tzdata id: the production fallback resolves 'UTC', which the
      // bundled timezone database does not carry.
      (call) async => 'Europe/Rome',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_data_mode': 'private',
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(const MethodChannel('flutter_timezone'), null);
  });

  final limitBodies = <String>[
    for (var seed = 0; seed < 3; seed++)
      NotificationService.reminderBody(habitTitle,
          isLimit: true, rotationSeed: seed, featureEnabled: true),
  ];
  final motivationalBodies = <String>[
    for (var seed = 0; seed < 15; seed++)
      NotificationService.reminderBody(habitTitle,
          isLimit: false, rotationSeed: seed, featureEnabled: true),
  ];

  /// Schedules the recurring reminder exactly as the app does and hands back
  /// the payload the OS would carry on the delivered notification.
  Future<String> scheduleLimitReminder() async {
    await NotificationService()
        .scheduleHabitReminder(habitId, habitTitle, '09:00', isLimit: true);
    final scheduled = calls.lastWhere((c) => c.method == 'zonedSchedule');
    return (scheduled.arguments as Map)['payload'] as String;
  }

  test('the recurring limit reminder itself carries restraint copy', () async {
    await scheduleLimitReminder();
    final scheduled = calls.lastWhere((c) => c.method == 'zonedSchedule');
    expect((scheduled.arguments as Map)['body'], isIn(limitBodies));
  });

  test('snoozing a limit reminder re-sends restraint copy, not "do it!"',
      () async {
    final payload = await scheduleLimitReminder();
    calls.clear();

    notificationTapBackground(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        id: habitId.hashCode,
        actionId: 'action_snooze',
        payload: payload,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final snoozed = calls.singleWhere((c) => c.method == 'zonedSchedule');
    final args = snoozed.arguments as Map;

    expect(args['id'], habitId.hashCode + 1000,
        reason: 'the snooze reschedules under its own id');
    expect(
      args['body'],
      isIn(limitBodies),
      reason: 'the user is trying to consume LESS; the ten-minute repeat must '
          'not tell them to go and do it',
    );
    expect(args['body'], isNot(isIn(motivationalBodies)));
  });

  test('the snoozed notification keeps the flag, so snoozing twice holds',
      () async {
    final payload = await scheduleLimitReminder();
    calls.clear();

    Future<String> snooze(String withPayload) async {
      calls.clear();
      notificationTapBackground(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: habitId.hashCode,
          actionId: 'action_snooze',
          payload: withPayload,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return (calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
          as Map)['payload'] as String;
    }

    final second = await snooze(await snooze(payload));
    calls.clear();
    notificationTapBackground(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        id: habitId.hashCode,
        actionId: 'action_snooze',
        payload: second,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final args =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments as Map;
    expect(args['body'], isIn(limitBodies));
  });

  test('a payload from a build that predates the flag still snoozes', () async {
    // Notifications already pending on device carry the three-field payload.
    // They must keep working — defaulting to the motivational copy is the
    // behaviour those reminders were scheduled with.
    calls.clear();
    notificationTapBackground(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        id: habitId.hashCode,
        actionId: 'action_snooze',
        payload: 'habit|$habitId|$habitTitle',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final args =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments as Map;
    expect(args['body'], isIn(motivationalBodies));
  });
}
