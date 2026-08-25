// An ARCHIVED habit never gets its reminder re-armed.
//
// `deleteHabit` archives a habit that has history (stamping `end_date`) rather
// than destroying it, and cancels its reminder on the way out. But the habit
// stays in `goalsProvider` — that is what keeps its history reachable — and
// `_runNotificationSync` re-registers reminders by looping that list.
//
// That loop begins with `cancelAll()`, so whatever it skips stays cancelled and
// whatever it includes comes BACK. Unfiltered, the one-off cancel in
// `_persistArchive` was undone by the very next settings change, and a habit the
// user had removed went on notifying them — indefinitely, from no screen they
// could reach, because the manage sheet hides it and that is the only place a
// reminder can be cleared.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/models/goal.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/settings_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/fake_private_data_store.dart';

class _Store extends FakePrivateDataStore {
  _Store(this.goals);
  final List<Goal> goals;

  @override
  Future<List<Goal>> loadGoals() async => goals;
}

Goal _goal(String id, {DateTime? endDate}) => Goal(
      id: id,
      title: 'Habit $id',
      color: const Color(0xFF3B82F6),
      startDate: DateTime(2026, 1, 1),
      endDate: endDate,
      reminderTime: '07:30',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<String> scheduledTitles;

  setUp(() {
    // The REAL iOS plugin over a mocked method channel, not a fake platform.
    // `zonedSchedule` resolves the implementation by casting
    // `FlutterLocalNotificationsPlatform.instance` to
    // `IOSFlutterLocalNotificationsPlugin`; a plain fake fails that cast, the
    // call silently no-ops, and this test would "pass" having scheduled nothing
    // at all — the negative assertion below would be vacuous.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    // `zonedSchedule` seeds from `tz.local`, which `NotificationService.init()`
    // would normally set. Nothing here calls init, so set it explicitly —
    // otherwise the sweep dies on a LateInitializationError and schedules
    // nothing, which would make the negative assertion below vacuous.
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    scheduledTitles = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'zonedSchedule') {
        final args = (call.arguments as Map).cast<dynamic, dynamic>();
        final title = args['title'];
        if (title is String) scheduledTitles.add(title);
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'Europe/Rome',
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'), null);
  });

  test('the reschedule sweep skips a habit whose active range has ended',
      () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 2));
    final store = _Store([
      _goal('live'),
      _goal('archived', endDate: yesterday),
    ]);
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      privateLocalDatabaseProvider.overrideWith((ref) => store),
      initialGoalsProvider.overrideWithValue('[]'),
      initialLogsProvider.overrideWithValue('{}'),
    ]);
    addTearDown(container.dispose);
    await container.read(goalsProvider.notifier).ensureLoaded();

    // Fire-and-forget in production (a settings write does not wait on the
    // scheduler), so let the sweep drain before asserting.
    container.read(settingsProvider.notifier).syncNotifications();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(
      scheduledTitles.where((t) => t.contains('Habit archived')),
      isEmpty,
      reason: 'a removed habit must not be re-armed by the next settings '
          'change — the user has no screen left on which to cancel it',
    );
    expect(
      scheduledTitles.where((t) => t.contains('Habit live')),
      isNotEmpty,
      reason: 'the filter must not silence the habits that are still running',
    );
  });
}
