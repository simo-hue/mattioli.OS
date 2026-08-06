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
}
