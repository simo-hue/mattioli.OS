// SyncWriteDebouncer: burst coalescing, timer restart on new writes, error
// swallowing, dispose semantics (P3 of desktop/ICLOUD_SYNC_PLAN.md).
import 'package:evolve_sync/evolve_sync.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a burst of writes flushes exactly once after the quiet period', () {
    fakeAsync((async) {
      var flushes = 0;
      final d = SyncWriteDebouncer(
        onFlush: () async => flushes++,
        delay: const Duration(seconds: 3),
      );

      d.notifyWrite();
      async.elapse(const Duration(seconds: 1));
      d.notifyWrite();
      async.elapse(const Duration(seconds: 1));
      d.notifyWrite();
      expect(flushes, 0, reason: 'still inside the quiet window');

      async.elapse(const Duration(seconds: 3));
      expect(flushes, 1, reason: 'the burst coalesced into one sync');

      async.elapse(const Duration(minutes: 5));
      expect(flushes, 1, reason: 'no writes → no further flushes');
      d.dispose();
    });
  });

  test('each write restarts the quiet timer', () {
    fakeAsync((async) {
      var flushes = 0;
      final d = SyncWriteDebouncer(
        onFlush: () async => flushes++,
        delay: const Duration(seconds: 3),
      );

      d.notifyWrite();
      async.elapse(const Duration(seconds: 2));
      expect(flushes, 0);
      d.notifyWrite(); // restart at t=2
      async.elapse(const Duration(seconds: 2));
      expect(flushes, 0, reason: 'only 2s since the last write');
      async.elapse(const Duration(seconds: 1));
      expect(flushes, 1);
      d.dispose();
    });
  });

  test('a second burst after a flush schedules a new flush', () {
    fakeAsync((async) {
      var flushes = 0;
      final d = SyncWriteDebouncer(
        onFlush: () async => flushes++,
        delay: const Duration(seconds: 3),
      );

      d.notifyWrite();
      async.elapse(const Duration(seconds: 3));
      expect(flushes, 1);

      d.notifyWrite();
      async.elapse(const Duration(seconds: 3));
      expect(flushes, 2);
      d.dispose();
    });
  });

  test('flush errors are swallowed and do not break later flushes', () {
    fakeAsync((async) {
      var calls = 0;
      final d = SyncWriteDebouncer(
        onFlush: () async {
          calls++;
          throw StateError('sync failed');
        },
        delay: const Duration(seconds: 3),
      );

      d.notifyWrite();
      async.elapse(const Duration(seconds: 3));
      expect(calls, 1);

      d.notifyWrite();
      async.elapse(const Duration(seconds: 3));
      expect(calls, 2, reason: 'a failed flush must not kill the debouncer');
      d.dispose();
    });
  });

  test('dispose cancels the pending flush and ignores later writes', () {
    fakeAsync((async) {
      var flushes = 0;
      final d = SyncWriteDebouncer(
        onFlush: () async => flushes++,
        delay: const Duration(seconds: 3),
      );

      d.notifyWrite();
      expect(d.isPending, isTrue);
      d.dispose();
      expect(d.isPending, isFalse);

      d.notifyWrite(); // after dispose — ignored
      async.elapse(const Duration(minutes: 1));
      expect(flushes, 0);
    });
  });
}
