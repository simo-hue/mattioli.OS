// Snooze is deliberately the ONE reminder action without
// `DarwinNotificationActionOption.foreground`: it writes nothing, so it must
// not launch the app. That means it is handled entirely inside
// `notificationTapBackground`, a fresh isolate — and that isolate initialised
// timezones, prefs, the reporting flag and Supabase, but never the app
// language. slang therefore stayed on its `baseLocale` (en), so an Italian
// user who tapped "Posticipa" got the replacement reminder in English.
//
// `main()` does the equivalent cold-start step against the same prefs this
// isolate has already loaded.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/notifications.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const habitId = '5c1de2f0-9b41-4f1a-8a77-2e0b6c3d4411';
  const habitTitle = 'Meditare';

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  late List<MethodCall> calls;

  setUpAll(() {
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
      if (call.method == 'pendingNotificationRequests') return <Object?>[];
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'Europe/Rome',
    );
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(channel, null)
      ..setMockMethodCallHandler(const MethodChannel('flutter_timezone'), null);
    // The isolate entry point mutates slang's global locale; put it back so it
    // cannot leak into the next test.
    await LocaleSettings.setLocale(AppLocale.en);
  });

  Future<String> snoozeBody() async {
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
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return (calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
        as Map)['body'] as String;
  }

  List<String> bodiesOf(Translations tr) => <String>[
        tr.notifications.habitReminderMessage1(title: habitTitle),
        tr.notifications.habitReminderMessage2(title: habitTitle),
        tr.notifications.habitReminderMessage3(title: habitTitle),
        tr.notifications.habitReminderMessage4(title: habitTitle),
        tr.notifications.habitReminderMessage5(title: habitTitle),
        tr.notifications.habitReminderMessage6(title: habitTitle),
        tr.notifications.habitReminderMessage7(title: habitTitle),
        tr.notifications.habitReminderMessage8(title: habitTitle),
        tr.notifications.habitReminderMessage9(title: habitTitle),
        tr.notifications.habitReminderMessage10(title: habitTitle),
        tr.notifications.habitReminderMessage11(title: habitTitle),
        tr.notifications.habitReminderMessage12(title: habitTitle),
        tr.notifications.habitReminderMessage13(title: habitTitle),
        tr.notifications.habitReminderMessage14(title: habitTitle),
        tr.notifications.habitReminderMessage15(title: habitTitle),
      ];

  test('a snooze in the background isolate speaks the stored language',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_data_mode': 'private',
      // The Private-mode mirror `storedLanguageFor` reads first.
      'private_pref_language': 'it',
    });

    final body = await snoozeBody();

    expect(body, isIn(bodiesOf(await AppLocale.it.build())));
    expect(
      body,
      isNot(isIn(bodiesOf(await AppLocale.en.build()))),
      reason: 'slang falls back to its base locale (en) until the isolate '
          'sets the stored language',
    );
  });

  test('the cloud-mode language key is honoured too', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pref_language': 'it',
    });

    expect(await snoozeBody(), isIn(bodiesOf(await AppLocale.it.build())));
  });

  test('"system" and an unset language leave the isolate on the base locale',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_data_mode': 'private',
      'private_pref_language': 'system',
    });

    // The device locale under test is en_US, so "system" must resolve to
    // English — the fix must not force a language on a user who never picked
    // one.
    expect(await snoozeBody(), isIn(bodiesOf(await AppLocale.en.build())));
  });
}
