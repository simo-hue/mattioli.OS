// Removing a habit's reminder must actually REACH the server in Account mode.
//
// `Goal.toJson` emits `reminder_time` only when it is non-null (it has to: the
// insert path and the offline cache both want a column-free payload for a habit
// that has no reminder). A PostgREST UPDATE leaves omitted columns untouched, so
// a payload built straight from `toJson` can never CLEAR the column — the old
// time survives on the server, `Goal.fromJson` reads it back on the next sync,
// and `syncNotifications` re-schedules the very notification the user deleted.
//
// `updateHabit` already force-writes `frequency_days`, the `verify_*` columns
// and `target` for exactly this reason; this file covers the reminder, and
// pins the setting case too so the force-write cannot regress into clearing a
// reminder the user actually kept.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'support/fake_private_data_store.dart';

const _userId = 'u1';

/// The reminder reschedule on the save path would otherwise reach the real
/// plugin and throw before any assertion runs. `cancel`/`cancelAll` are called
/// straight on the platform; the scheduling calls go through
/// `resolvePlatformSpecificImplementation`, which returns null for this generic
/// mock and is a no-op (hence the iOS platform override in `setUp` — the
/// Android branch dereferences that null with `!`).
class _NoopNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

/// Lets the test pin the data mode to Account without touching prefs plumbing.
class _ModeNotifier extends ActiveDataModeNotifier {
  _ModeNotifier(this._mode);
  final AppDataMode _mode;

  @override
  AppDataMode build() => _mode;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `Supabase.initialize` builds a process-wide singleton, so it is called once
  // for the whole file and told per test what the server holds.
  var serverRow = <String, dynamic>{};
  Map<String, dynamic>? updatePayload;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient((req) async {
        if (req.url.path.contains('/goals')) {
          if (req.method == 'PATCH') {
            updatePayload =
                jsonDecode(req.body) as Map<String, dynamic>;
            return http.Response('[]', 200,
                request: req, headers: {'content-type': 'application/json'});
          }
          return http.Response(jsonEncode([serverRow]), 200,
              request: req, headers: {'content-type': 'application/json'});
        }
        return http.Response('[]', 200,
            request: req, headers: {'content-type': 'application/json'});
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'not-a-jwt',
      'token_type': 'bearer',
      'user': {
        'id': _userId,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
      },
    }));
  });

  setUp(() {
    // `_nextInstanceOfTime` reads `tz.local`; initialise the DB so it resolves.
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    updatePayload = null;
    serverRow = <String, dynamic>{
      'id': 'g1',
      'title': 'Read',
      'color': '#3B82F6',
      'start_date': '2026-01-01T00:00:00.000Z',
      'reminder_time': '21:00',
    };
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Future<ProviderContainer> container() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        activeDataModeProvider
            .overrideWith(() => _ModeNotifier(AppDataMode.supabase)),
        privateLocalDatabaseProvider
            .overrideWith((ref) => FakePrivateDataStore()),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
        initialProgressProvider.overrideWithValue('{}'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// `updateHabit` fires the reminder reschedule unawaited; let it run inside
  /// the test, while the iOS platform override is still in force.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('THE GAP: removing a reminder writes an explicit null, so the server '
      'cannot resurrect it', () async {
    final c = await container();
    expect(await c.read(goalsProvider.notifier).ensureLoaded(), isTrue);
    final habit = c.read(goalsProvider).single;
    expect(habit.reminderTime, '21:00', reason: 'precondition');

    final ok = await c.read(goalsProvider.notifier).updateHabit(
          habit.copyWith(clearReminderTime: true),
        );

    expect(ok, isTrue);
    expect(updatePayload, isNotNull, reason: 'the UPDATE was sent');
    expect(
      updatePayload!.containsKey('reminder_time'),
      isTrue,
      reason: 'Goal.toJson omits the column when null and an UPDATE ignores '
          'omitted columns — without the force-write the deletion never leaves '
          'the device, and the next sync brings 21:00 back and re-schedules it',
    );
    expect(updatePayload!['reminder_time'], isNull);
  });

  test('setting a reminder still writes the time it was given', () async {
    final c = await container();
    expect(await c.read(goalsProvider.notifier).ensureLoaded(), isTrue);
    final habit = c.read(goalsProvider).single;

    await c
        .read(goalsProvider.notifier)
        .updateHabit(habit.copyWith(reminderTime: '07:30'));
    await settle();

    expect(updatePayload!['reminder_time'], '07:30');
  });

  test('an edit that does not touch the reminder keeps it', () async {
    final c = await container();
    expect(await c.read(goalsProvider.notifier).ensureLoaded(), isTrue);
    final habit = c.read(goalsProvider).single;

    await c
        .read(goalsProvider.notifier)
        .updateHabit(habit.copyWith(title: 'Read more', color: Colors.red));
    await settle();

    expect(updatePayload!['reminder_time'], '21:00',
        reason: 'the force-write must never clear a reminder the user kept');
  });
}
