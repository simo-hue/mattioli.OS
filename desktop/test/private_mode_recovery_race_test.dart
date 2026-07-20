// Regression: the "Reset & start fresh" recovery (resetAndReopenPrivate) must
// delete + recreate the encrypted DB file INSIDE the sync engine's op chain, so
// an auto-sync opened on launch can't be mid-open over the file while it is
// deleted/recreated. That race surfaced on the owner's `flutter run` as a
// SQLCipher "out of memory" on BEGIN EXCLUSIVE, a duplicate "Message responses
// can be sent only once" warning, and TWO resets before the DB finally opened.
//
// The fake sync below mirrors CloudKitPrivateSyncService faithfully: runExclusive
// and enable() share ONE serialization chain (enable() = runExclusive(_enable)),
// so a wrong implementation that nested enable() inside the reset's runExclusive
// would DEADLOCK here too — this test would then hang rather than pass.

import 'dart:async';

import 'package:evolve_desktop/core/desktop_private_db.dart'
    show PrivateRecoveryStore;
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/features/auth/application/private_mode_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [PrivateSyncService] with a real single-op chain (like the production
/// `_runExclusive`/`_tail`). It records an ordered event log and exposes whether
/// the exclusion is currently held, so a test can prove the reset+reopen ran
/// inside it and that a concurrently-submitted op does not interleave.
class _ChainFakeSync implements PrivateSyncService {
  final List<String> log = [];

  Future<void> _tail = Future<void>.value();
  int _depth = 0;

  /// True while an action submitted through [runExclusive]/[enable] is running.
  bool get insideExclusive => _depth > 0;

  int enableCalls = 0;

  @override
  Future<T> runExclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final prev = _tail;
    // Later ops wait for this one to settle; swallow its error so one failure
    // doesn't poison the chain (mirrors the production _runExclusive).
    _tail = completer.future.then<void>((_) {}, onError: (_) {});
    () async {
      await prev;
      _depth++;
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        _depth--;
      }
    }();
    return completer.future;
  }

  // enable() takes the SAME lock internally, exactly like the real service
  // (`enable() => _runExclusive(_enable)`), so nesting it inside another
  // runExclusive body would deadlock.
  @override
  Future<PrivateSyncStatus> enable({bool force = false}) => runExclusive(() async {
        enableCalls++;
        log.add('enable');
        return const PrivateSyncStatus(
          isAvailable: true,
          isEnabled: true,
          hasKey: true,
          account: CloudAccountStatus.available,
        );
      });

  @override
  Future<PrivateSyncStatus> probe() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> status() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> disable() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> syncNow() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> requestFullReset() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<SyncDiagnostics?> diagnostics() async => null;

  @override
  Future<PrivateSyncStatus> resetSyncFromThisDevice() async =>
      const PrivateSyncStatus.localOnly();
}

/// A recovery store that yields inside reset/reopen (so an unserialized op could
/// interleave) and records, at call time, whether [sync] held the exclusion.
class _RecordingStore implements PrivateRecoveryStore {
  _RecordingStore(this.sync);

  final _ChainFakeSync sync;

  bool? resetInsideExclusive;
  bool? reopenInsideExclusive;

  @override
  Future<void> resetLockedDatabase() async {
    resetInsideExclusive = sync.insideExclusive;
    sync.log.add('reset-start');
    await Future<void>.delayed(Duration.zero);
    sync.log.add('reset-end');
  }

  @override
  Future<void> ensureReady() async {
    reopenInsideExclusive = sync.insideExclusive;
    sync.log.add('reopen-start');
    await Future<void>.delayed(Duration.zero);
    sync.log.add('reopen-end');
  }

  @override
  Future<bool> stashLockedDatabase() async => false;

  @override
  Future<void> restoreStashedDatabase() async {}

  @override
  Future<void> discardStashedDatabase() async {}
}

void main() {
  group('resetAndReopenPrivate — runs the reset+reopen inside the sync exclusion',
      () {
    test('reset + reopen both execute while the sync op-chain lock is held',
        () async {
      final sync = _ChainFakeSync();
      final store = _RecordingStore(sync);

      final ok = await resetAndReopenPrivate(sync, store: store);

      expect(ok, isTrue);
      // The heart of the fix: both file mutations ran INSIDE runExclusive. Revert
      // the fix (call resetLockedDatabase/ensureReady directly, outside
      // runExclusive) and these read false → this test goes RED.
      expect(store.resetInsideExclusive, isTrue,
          reason: 'resetLockedDatabase must run inside sync.runExclusive');
      expect(store.reopenInsideExclusive, isTrue,
          reason: 'ensureReady must run inside sync.runExclusive');
      // Nothing else was submitted, so the exclusive body is a contiguous block.
      expect(sync.log,
          ['reset-start', 'reset-end', 'reopen-start', 'reopen-end']);
    });

    test(
        'a concurrently-submitted sync op does not interleave with reset+reopen',
        () async {
      final sync = _ChainFakeSync();
      final store = _RecordingStore(sync);

      // Submit a competing op BEFORE the recovery. Both go through the ONE chain,
      // so the reset+reopen block must run entirely AFTER this op — never spliced
      // into it. If the reset ran outside the exclusion it would start before the
      // competing op finished (interleave), and this ordering assertion fails.
      final other = sync.runExclusive(() async {
        sync.log.add('other-start');
        await Future<void>.delayed(Duration.zero);
        sync.log.add('other-end');
      });
      final reset = resetAndReopenPrivate(sync, store: store);

      expect(await reset, isTrue);
      await other;

      expect(
        sync.log,
        [
          'other-start',
          'other-end',
          'reset-start',
          'reset-end',
          'reopen-start',
          'reopen-end',
        ],
        reason: 'the reset+reopen block must not interleave with the other op',
      );
    });

    test(
        'enableSync=true enables AFTER the exclusion and does not deadlock',
        () async {
      final sync = _ChainFakeSync();
      final store = _RecordingStore(sync);

      // enable() re-enters the same lock, so it must be sequenced AFTER the
      // reset's runExclusive, not nested inside it. A nested call would deadlock
      // and this awaited call would hang.
      final ok = await resetAndReopenPrivate(sync, store: store, enableSync: true)
          .timeout(const Duration(seconds: 5));

      expect(ok, isTrue);
      expect(sync.enableCalls, 1);
      expect(sync.log,
          ['reset-start', 'reset-end', 'reopen-start', 'reopen-end', 'enable'],
          reason: 'enable runs after the reset+reopen exclusion completes');
    });
  });
}
