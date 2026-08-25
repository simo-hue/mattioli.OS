// A habit log written from a NOTIFICATION carries the same `streak` as one
// written from the foreground toggle.
//
// The Private branch of `_writeHabitLogFromNotification` computes it, via
// `PrivateLocalDatabase.setHabitLogWithStreak` — since `ee6777e` (2026-06-23),
// which fixed this same bug on that side. The cloud branch was left out of that
// fix. Both the direct write and the replay sent only
// `user_id/goal_id/date/status`, so a lock-screen Done INSERTed a row with no
// streak. That column is what the `habit_stats` view reads (schema.sql:124),
// and `runStreakRepairOnce` (main.dart) is Private-mode only, so nothing ever
// recomputed it for an account: the habit's statistics were degraded
// permanently, silently, by using the notification instead of the app.
//
// The null case is the safety property: `goalLogUpsertPayload` OMITS the key
// when the streak is null, so on the ON CONFLICT path a failed resolution
// leaves a stored streak alone rather than overwriting a correct value with a
// fabrication ("absence is not evidence", as the Private writer puts it). On a
// fresh INSERT the column takes its schema default of 0 — no better than before
// the resolver existed, and no worse.
//
// The direct-write test at the end covers the OTHER half of the change: the
// tap is queued BEFORE any network work and dropped only once the server has
// it, because resolving a streak is no longer free and the background isolate
// can be reclaimed mid-flight.
import 'dart:async';

import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mattioli_os/core/verification_state_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // `notificationTapBackground` calls `Supabase.initialize` itself when the
    // singleton is absent, using the REAL config and a Keychain-backed session
    // store — neither of which exists here. Standing one up first (dummy host,
    // mocked transport, no auto-refresh) makes its `Supabase.instance.client`
    // probe succeed so it skips that branch. Process-wide, so once per file.
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient((req) async => http.Response('[]', 200,
          request: req, headers: {'content-type': 'application/json'})),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
  });

  late List<Map<String, Object?>> written;
  late List<List<String>> resolverCalls;

  setUp(() {
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    written = [];
    resolverCalls = [];
    NotificationService.currentUserId = () => 'user-1';
    NotificationService.logUpserter = (row) async => written.add(row);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    NotificationService.resetTestSeams();
  });

  test('a replayed log carries the streak the resolver computed', () async {
    NotificationService.cloudStreakResolver = (goalId, dateKey, status) async {
      resolverCalls.add([goalId, dateKey, status]);
      return 7;
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingLogsKey: <String>['goal-1|2026-08-01|done'],
    });

    final r = await NotificationService().replayPendingHabitLogs();

    expect(r.written, 1);
    expect(resolverCalls, [
      ['goal-1', '2026-08-01', 'done'],
    ], reason: 'the streak is scored for the day and status being written');
    expect(written.single, {
      'user_id': 'user-1',
      'goal_id': 'goal-1',
      'date': '2026-08-01',
      'status': 'done',
      'streak': 7,
    }, reason: 'the notification write must match the foreground toggle, which '
        'goes through goalLogUpsertPayload with a computed streak');
  });

  test('past its budget the replay writes the status without a streak',
      () async {
    // The cap exists so a large queue cannot spend hundreds of round trips on
    // a cache while main.dart awaits the replay. Past it, entries revert to
    // exactly their pre-resolver behaviour — status written, streak omitted —
    // rather than being dropped or delayed.
    NotificationService.kReplayStreakBudget = Duration.zero;
    NotificationService.cloudStreakResolver = (goalId, dateKey, status) async {
      resolverCalls.add([goalId, dateKey, status]);
      return 7;
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingLogsKey: <String>['goal-1|2026-08-01|done'],
    });

    final r = await NotificationService().replayPendingHabitLogs();

    expect(r.written, 1, reason: 'the tap still lands');
    expect(resolverCalls, isEmpty,
        reason: 'no round trip is spent once the budget is gone');
    expect(written.single.containsKey('streak'), isFalse);
  });

  test('a stalled resolver degrades to no streak instead of eating the isolate',
      () async {
    // The operational failure this guards: iOS wakes the app in the background
    // for the action and the connection stalls. Unbounded, the resolver would
    // consume the whole budget and the isolate be suspended before the write —
    // no server row AND no queue entry, so the tap is gone. Bounded, the status
    // still lands.
    NotificationService.kStreakResolveTimeout = const Duration(milliseconds: 20);
    NotificationService.cloudStreakResolver =
        (_, _, _) => Completer<int?>().future; // never completes
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingLogsKey: <String>['goal-1|2026-08-01|done'],
    });

    final r = await NotificationService().replayPendingHabitLogs();

    expect(r.written, 1, reason: 'the tap lands despite the stall');
    expect(written.single.containsKey('streak'), isFalse);
  });

  test('a replay does not erase an entry queued while it was running',
      () async {
    // `pending` is a snapshot taken before a loop that does network I/O, and a
    // direct notification write queues its verdict BEFORE issuing its request.
    // Writing `remaining` blindly over the key would delete that entry — losing
    // the very tap the enqueue exists to protect. The upserter below stands in
    // for that concurrent write, deterministically.
    NotificationService.cloudStreakResolver = (_, _, _) async => 1;
    NotificationService.logUpserter = (row) async {
      written.add(row);
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_pendingLogsKey) ?? <String>[];
      await prefs.setStringList(
          _pendingLogsKey, [...current, 'goal-2|2026-08-02|missed']);
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingLogsKey: <String>['goal-1|2026-08-01|done'],
    });

    final r = await NotificationService().replayPendingHabitLogs();

    expect(r.written, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_pendingLogsKey), ['goal-2|2026-08-02|missed'],
        reason: 'the replay subtracts what IT handled; it does not overwrite '
            'the queue with a list computed from a stale snapshot');
  });

  test('a day queued mid-replay is reported as pending, not as drained',
      () async {
    // `pending` is what tells the caller which days the user has DECIDED, and
    // auto-fail withholds a write for those. A tap enqueued while the replay
    // runs is in the queue but not in this run's leftovers — report only the
    // leftovers and, once the clock passes midnight, that day is closed, its
    // verdict is on neither the server nor `pending`, and the reconcile writes
    // `missed` over the Done the user tapped.
    NotificationService.cloudStreakResolver = (_, _, _) async => 1;
    NotificationService.logUpserter = (row) async {
      written.add(row);
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getStringList(_pendingLogsKey) ?? <String>[];
      await prefs.setStringList(
          _pendingLogsKey, [...current, 'goal-2|2026-08-02|done']);
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingLogsKey: <String>['goal-1|2026-08-01|done'],
    });

    final r = await NotificationService().replayPendingHabitLogs();

    expect(r.drained, isFalse,
        reason: 'the queue is NOT empty — it holds the tap made mid-run');
    expect(r.pending, {
      '2026-08-02': {'goal-2': 'done'},
    }, reason: 'that day is decided, so auto-fail must not touch it');
  });

  test('an entry superseded mid-replay is not written from the stale snapshot',
      () async {
    // The queue held `done` from a failed earlier tap. Mid-replay the user taps
    // Skip; that direct write lands `missed` and dequeues itself. Upserting the
    // snapshotted `done` afterwards would overwrite the newer verdict with
    // nothing left queued to undo it.
    NotificationService.cloudStreakResolver = (_, _, _) async {
      // Stands in for the newer write landing during this entry's network work.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_pendingLogsKey, <String>[]);
      return 1;
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingLogsKey: <String>['goal-1|2026-08-01|done'],
    });

    final r = await NotificationService().replayPendingHabitLogs();

    expect(written, isEmpty,
        reason: 'the stale verdict must not reach the server');
    expect(r.written, 0);
  });

  test('an unresolvable streak omits the column rather than nulling it',
      () async {
    // The stored value is a CACHE of a pure function. If we cannot recompute it
    // — offline, deleted goal, unreadable history — sending null would replace
    // a correct value with a wrong one. Omitting the key leaves it alone.
    NotificationService.cloudStreakResolver = (_, _, _) async => null;
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingLogsKey: <String>['goal-1|2026-08-01|done'],
    });

    await NotificationService().replayPendingHabitLogs();

    expect(written.single.containsKey('streak'), isFalse);
    expect(written.single, {
      'user_id': 'user-1',
      'goal_id': 'goal-1',
      'date': '2026-08-01',
      'status': 'done',
    });
  });

  test('a resolver that throws keeps the tap queued rather than dropping it',
      () async {
    // `await cloudStreakResolver(...)` is an argument evaluated inside the
    // replay's own try, so a throw from it aborts the write for that entry.
    // That is acceptable ONLY because the entry stays queued and is retried —
    // the user's tap is deferred, never lost. In production this branch is
    // unreachable: `_defaultCloudStreak` catches everything and returns null.
    // Pinned so it stays that way.
    NotificationService.cloudStreakResolver =
        (_, _, _) async => throw StateError('offline');
    SharedPreferences.setMockInitialValues(<String, Object>{
      _pendingLogsKey: <String>['goal-1|2026-08-01|missed'],
    });

    final r = await NotificationService().replayPendingHabitLogs();

    expect(r.written, 0, reason: 'the entry did not land, so it is retryable');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(_pendingLogsKey), ['goal-1|2026-08-01|missed'],
        reason: "a failure here must keep the user's tap queued, not drop it");
  });

  group('the direct write (a tap while the app has a session)', () {
    const habitId = '8f14e45f-ceea-467a-9a1f-1b5c0b3a1234';
    late Database db;
    final defaultOpener = NotificationService.verificationStoreOpener;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SqfliteVerificationStateStore.createTable(db);
      final store = SqfliteVerificationStateStore(db);
      NotificationService.verificationStoreOpener = () async => store;
      // NOT private: this is the cloud branch.
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (call) async => 'Europe/Rome',
      );
    });

    tearDown(() async {
      NotificationService.verificationStoreOpener = defaultOpener;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        null,
      );
      await db.close();
    });

    Future<void> tapDone() async {
      notificationTapBackground(
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: habitId.hashCode,
          actionId: 'action_done',
          payload: 'habit|$habitId|Meditate',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    test('the tap is queued before the write and dropped once it lands',
        () async {
      NotificationService.cloudStreakResolver = (_, _, _) async => 4;

      await tapDone();

      expect(written, hasLength(1));
      expect(written.single['streak'], 4,
          reason: 'the direct write carries a streak too, not just the replay');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('pending_habit_logs') ?? const <String>[],
          isEmpty,
          reason: 'a write that landed must not leave a duplicate queued');
    });

    test('a later tap is not erased when the earlier write completes',
        () async {
      // Done tapped, its write slow. Skip tapped inside that window, replacing
      // the queued entry. Skip's own write fails, so it is relying on the
      // queue. Done's write then completes — and a status-blind dequeue would
      // delete the QUEUED SKIP: server has `done`, queue empty, Skip gone with
      // nothing left to replay it. The upserter stands in for that interleaving.
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      NotificationService.cloudStreakResolver = (_, _, _) async => 4;
      NotificationService.logUpserter = (row) async {
        written.add(row);
        final prefs = await SharedPreferences.getInstance();
        await prefs
            .setStringList('pending_habit_logs', ['$habitId|$today|missed']);
      };

      await tapDone();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('pending_habit_logs'),
          ['$habitId|$today|missed'],
          reason: 'the dequeue names the verdict it wrote, so a later and '
              'different one is left alone');
    });

    test('a write that never lands leaves the tap queued', () async {
      // The regression this guards: streak resolution added network work BEFORE
      // anything durable existed, so an isolate reclaimed mid-resolve lost the
      // tap outright — no server row, no queue entry. Queuing first is what
      // makes the tap survivable.
      NotificationService.cloudStreakResolver = (_, _, _) async => 4;
      NotificationService.logUpserter =
          (_) async => throw StateError('offline');

      await tapDone();

      final prefs = await SharedPreferences.getInstance();
      final queued = prefs.getStringList('pending_habit_logs');
      expect(queued, hasLength(1));
      expect(queued!.single, startsWith('$habitId|'));
      expect(queued.single, endsWith('|done'));
    });
  });
}
