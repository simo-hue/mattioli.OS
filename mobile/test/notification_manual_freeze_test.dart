// Regression test for the notification provenance bug: tapping Done/Skip on a
// habit reminder must record the SAME D9 "manual freeze" that an in-app check-in
// (goal_provider.cycleStatus) records, so a later foreground verification
// reconcile treats it as user-resolved and never overwrites it with an auto
// verdict. Before the fix the notification write path skipped markManual, so an
// auto-verified habit's notification Done was silently reverted once the day
// passed.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/notifications.dart';
import 'package:mattioli_os/core/verification_state_store.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Minimal notifications platform so the Done/Skip response path never touches
/// the real plugin.
class _NoopNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const habitId = '8f14e45f-ceea-467a-9a1f-1b5c0b3a1234';
  const habitTitle = 'Meditate';

  late Database db;
  late SqfliteVerificationStateStore store;
  final defaultOpener = NotificationService.verificationStoreOpener;

  setUp(() async {
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    // In-memory verification store injected into the notification freeze path.
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await SqfliteVerificationStateStore.createTable(db);
    store = SqfliteVerificationStateStore(db);
    NotificationService.verificationStoreOpener = () async => store;

    // Private mode keeps the log write local (no Supabase) — the freeze runs
    // before it regardless.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_data_mode': 'private',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'Europe/Rome',
    );
  });

  tearDown(() async {
    NotificationService.verificationStoreOpener = defaultOpener;
    debugDefaultTargetPlatformOverride = null;
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      null,
    );
  });

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
    // Let the fire-and-forget handler run through the awaited freeze + write.
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  Future<bool> todayIsFrozen() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final res = await store.manualDays(
      goalIds: const [habitId],
      from: today.subtract(const Duration(days: 2)),
      to: today.add(const Duration(days: 1)),
    );
    return res[habitId]?.contains(today) ?? false;
  }

  test('Done from a notification records a manual freeze for today', () async {
    expect(await todayIsFrozen(), isFalse);
    await tapAction('action_done');
    expect(
      await todayIsFrozen(),
      isTrue,
      reason: 'a notification Done must freeze the day like an in-app check-in, '
          'so the verification reconcile cannot overwrite it',
    );
  });

  test('Skip from a notification also records a manual freeze for today',
      () async {
    await tapAction('action_skip');
    expect(await todayIsFrozen(), isTrue);
  });
}
