// The notification-queue replay, and the day-scoped protection it now hands to
// the manual-target sweep.
//
// The queue holds habit-days the user DECIDED (a reminder Done/Skip) that the
// server has not been told about, so they are absent from the in-memory verdict
// map. Auto-fail must not read those days as untouched and write 'missed' over
// them. That was enforced with a single boolean — "is the queue empty?" — which
// switched auto-fail off for EVERY habit and EVERY day while it was not.
//
// Some entries never drain. `goal_logs.goal_id` is a foreign key onto
// `goals`, so a queued Done for a habit the user later DELETED is rejected on
// every replay, for the life of the install, with no retry cap and no expiry.
// One of those disabled auto-fail permanently. The queue is therefore handed
// over as DATA now, and protects exactly the days it names.
//
// This file deliberately NEVER calls `Supabase.initialize`, so any path that
// reached for `Supabase.instance` would throw — which is how the Private-mode
// case below proves it no longer does.

import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'pending_habit_logs';

  test('an empty queue is drained, with nothing to protect', () async {
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final res = await NotificationService().replayPendingHabitLogs();
    expect(res.drained, isTrue);
    expect(res.written, 0);
    expect(res.pending, isEmpty);
  });

  test('THE REGRESSION: a non-empty queue in Private mode returns its entries '
      'instead of throwing on an uninitialised Supabase', () async {
    // The queue is a cloud-only mechanism, but a user who queued something in
    // cloud mode and then moved to Private kept the entries. Reaching for the
    // client here threw, the catch-all reported the queue as unreadable, and
    // auto-fail was disabled for good.
    SharedPreferences.setMockInitialValues({
      'active_data_mode': 'private',
      key: <String>['g1|2026-07-22|done'],
    });

    final res = await NotificationService().replayPendingHabitLogs();

    expect(
      res.pending,
      isNotNull,
      reason:
          'null means "the queue could not be read", which is what an '
          'uninitialised-Supabase throw used to produce — and what disabled '
          'auto-fail permanently',
    );
    expect(res.pending, {
      '2026-07-22': {'g1': 'done'},
    });
    expect(res.drained, isFalse, reason: 'the entry is still queued');
    expect(res.written, 0);
  });

  test(
    'entries are keyed date → goal → status, and the latest wins per day',
    () async {
      SharedPreferences.setMockInitialValues({
        'active_data_mode': 'private',
        key: <String>[
          'g1|2026-07-22|done',
          'g2|2026-07-22|missed',
          'g1|2026-07-23|missed',
        ],
      });

      final res = await NotificationService().replayPendingHabitLogs();

      expect(res.pending, {
        '2026-07-22': {'g1': 'done', 'g2': 'missed'},
        '2026-07-23': {'g1': 'missed'},
      });
    },
  );

  test('a malformed entry is not a decided day', () async {
    // The replay skips these when writing; the verdict map must skip them too,
    // or a corrupt line would silently protect a day from auto-fail forever.
    SharedPreferences.setMockInitialValues({
      'active_data_mode': 'private',
      key: <String>['garbage', 'g1|2026-07-22', 'g1|2026-07-23|done'],
    });

    final res = await NotificationService().replayPendingHabitLogs();

    expect(res.pending, {
      '2026-07-23': {'g1': 'done'},
    });
  });

  test('the queue is left intact in Private mode — nothing is replayed and '
      'nothing is dropped', () async {
    SharedPreferences.setMockInitialValues({
      'active_data_mode': 'private',
      key: <String>['g1|2026-07-22|done'],
    });

    await NotificationService().replayPendingHabitLogs();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList(key),
      ['g1|2026-07-22|done'],
      reason:
          "these are a cloud account's decisions; Private mode must not "
          'replay them into the private DB, nor discard them',
    );
  });

  // THE CLOUD BRANCH. Before the two seams below, nothing in the suite could
  // reach it — every case stopped at the Private-mode short-circuit or the
  // null-session return. That is not a coverage nicety: this loop decides
  // whether a user's tapped Done is retried or DISCARDED, and inverting the
  // 23503 test (dropping the retryable errors instead of the unretryable one)
  // would have shipped green.
  group('the cloud replay loop', () {
    final upserted = <Map<String, Object?>>[];
    Object? throwOnUpsert;

    setUp(() {
      upserted.clear();
      throwOnUpsert = null;
      SharedPreferences.setMockInitialValues({
        'active_data_mode': 'supabase',
        key: <String>['g1|2026-07-22|done'],
      });
      NotificationService.currentUserId = () => 'user-1';
      NotificationService.logUpserter = (row) async {
        upserted.add(row);
        if (throwOnUpsert != null) throw throwOnUpsert!;
      };
    });

    tearDown(NotificationService.resetTestSeams);

    test('a clean write drains the queue and counts as written', () async {
      final res = await NotificationService().replayPendingHabitLogs();

      expect(upserted.single, {
        'user_id': 'user-1',
        'goal_id': 'g1',
        'date': '2026-07-22',
        'status': 'done',
      });
      expect(res.written, 1);
      expect(res.drained, isTrue);
      expect(res.pending, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(key), isEmpty);
    });

    test('a RETRYABLE failure keeps the entry — a tapped Done is never thrown '
        'away because the network was down', () async {
      throwOnUpsert = const PostgrestException(message: 'boom', code: '500');

      final res = await NotificationService().replayPendingHabitLogs();

      expect(res.written, 0);
      expect(res.drained, isFalse);
      expect(res.pending, {
        '2026-07-22': {'g1': 'done'},
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(key), ['g1|2026-07-22|done'],
          reason: 'it must survive in the queue for the next foreground');
    });

    test('a 23503 foreign-key violation DROPS the entry — the habit is gone, '
        'so it can never land, and retrying it forever disabled auto-fail',
        () async {
      throwOnUpsert = const PostgrestException(
          message: 'insert violates foreign key', code: '23503');

      final res = await NotificationService().replayPendingHabitLogs();

      expect(res.drained, isTrue);
      expect(res.pending, isEmpty);
      expect(res.written, 0,
          reason: 'dropped is not written — counting it would force a full '
              'goal_logs re-download for a write that never happened');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(key), isEmpty);
    });

    test('a MALFORMED entry is dropped without counting as written', () async {
      SharedPreferences.setMockInitialValues({
        'active_data_mode': 'supabase',
        key: <String>['garbage'],
      });

      final res = await NotificationService().replayPendingHabitLogs();

      expect(upserted, isEmpty);
      expect(res.written, 0);
      expect(res.drained, isTrue);
    });

    test('no session leaves the queue intact and reports it as pending',
        () async {
      NotificationService.currentUserId = () => null;

      final res = await NotificationService().replayPendingHabitLogs();

      expect(upserted, isEmpty);
      expect(res.drained, isFalse);
      expect(res.pending, {
        '2026-07-22': {'g1': 'done'},
      });
    });
  });
}
