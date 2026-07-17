import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/notifications.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the notification calls the skip path makes, so a regression that
/// destroys the recurring reminder is caught.
class _RecordingNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  final List<int> cancelledIds = <int>[];
  bool cancelAllCalled = false;

  @override
  Future<void> cancel({required int id}) async => cancelledIds.add(id);

  @override
  Future<void> cancelAll() async => cancelAllCalled = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingNotificationsPlatform platform;

  const habitId = '8f14e45f-ceea-467a-9a1f-1b5c0b3a1234';
  const habitTitle = 'Take antidepressants';

  setUp(() {
    platform = _RecordingNotificationsPlatform();
    FlutterLocalNotificationsPlatform.instance = platform;
    // cancel() only routes through the shared platform instance off Android.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    // Private mode keeps the write local, so the skip path needs no Supabase.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_data_mode': 'private',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      // A real tzdata id: the production fallback path resolves 'UTC', which
      // the bundled timezone database does not carry.
      (call) async => 'Europe/Rome',
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      null,
    );
  });

  /// Drives the real notification-action entry point and lets the fire-and-
  /// forget response handler run to the point where it would have cancelled.
  Future<void> tapAction(String actionId) async {
    notificationTapBackground(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        id: habitId.hashCode,
        actionId: actionId,
        payload: 'habit|$habitId|$habitTitle',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  test('Skip does not cancel the habit\'s recurring reminder', () async {
    await tapAction('action_skip');

    // habitId.hashCode is the id scheduleHabitReminder registers the repeating
    // reminder under; cancelling it removes the whole recurring request.
    expect(
      platform.cancelledIds,
      isNot(contains(habitId.hashCode)),
      reason: 'Skip must dismiss only the current occurrence, never the '
          'recurring schedule',
    );
    expect(platform.cancelledIds, isEmpty);
    expect(platform.cancelAllCalled, isFalse);
  });

  test('Done does not cancel the habit\'s recurring reminder either', () async {
    await tapAction('action_done');

    expect(platform.cancelledIds, isEmpty);
    expect(platform.cancelAllCalled, isFalse);
  });

  test('cancelHabitReminder clears the daily id and every per-weekday id',
      () async {
    await NotificationService().cancelHabitReminder(habitId);

    // The every-day instance (habitId.hashCode) plus all 7 per-weekday
    // instances: the previously-scheduled day set isn't known at cancel time,
    // so every possible reminder id for this habit is cleared.
    final expected = <int>[
      habitId.hashCode,
      for (var weekday = 1; weekday <= 7; weekday++)
        '$habitId#wd$weekday'.hashCode,
    ];
    expect(platform.cancelledIds, expected);
  });
}
