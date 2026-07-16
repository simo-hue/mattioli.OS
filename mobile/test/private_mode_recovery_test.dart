// Recovery POLICY for a locked private DB (openOrRecoverPrivate).
//
// Focus: the auto-recover-from-cloud branch must NOT destroy the only local
// copy before the cloud re-pull is confirmed. It stashes the locked DB, runs
// enable(), and only claims "restored from iCloud" when enable actually RAN.
// A deferred (owner not yet synced) or blocked (iCloud unavailable) enable must
// restore the stash and surface the correct recovery state — never a false
// success over an empty DB.

import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart'
    show PrivateDatabaseLockedException;
import 'package:mattioli_os/core/private_mode_recovery.dart';
import 'package:mattioli_os/core/private_sync_service.dart';

import 'support/fake_private_data_store.dart';

/// A store that reports LOCKED (ensureReady throws) until it's been stashed —
/// modelling the real flow where the stash mints a fresh, openable empty DB.
class _LockedFakeStore extends FakePrivateDataStore {
  _LockedFakeStore() {
    locked = true;
  }

  @override
  Future<void> ensureReady() async {
    calls.add('ensureReady');
    if (locked) throw const PrivateDatabaseLockedException();
  }
}

/// A [PrivateSyncService] whose enable() returns a configurable status so we can
/// drive the ran / deferred / blocked branches. probe() reports the
/// autoRecover-triggering state (enabled + available + key present).
class _FakeSync implements PrivateSyncService {
  _FakeSync({required this.enableResult});

  final PrivateSyncStatus enableResult;
  final List<String> calls = [];

  static const _autoRecoverProbe = PrivateSyncStatus(
    isAvailable: true,
    isEnabled: true,
    hasKey: true,
    account: CloudAccountStatus.available,
  );

  @override
  Future<PrivateSyncStatus> probe() async {
    calls.add('probe');
    return _autoRecoverProbe;
  }

  @override
  Future<PrivateSyncStatus> enable() async {
    calls.add('enable');
    return enableResult;
  }

  @override
  Future<PrivateSyncStatus> status() async => _autoRecoverProbe;

  @override
  Future<PrivateSyncStatus> disable() async => enableResult;

  @override
  Future<PrivateSyncStatus> syncNow() async => enableResult;

  @override
  Future<PrivateSyncStatus> requestFullReset() async => enableResult;

  @override
  Future<T> runExclusive<T>(Future<T> Function() action) => action();
}

void main() {
  group('openOrRecoverPrivate — autoRecoverFromCloud', () {
    test('enable() RAN → ready + restoredFromCloud, stash discarded', () async {
      final store = _LockedFakeStore();
      final sync = _FakeSync(
        enableResult: const PrivateSyncStatus(
          isAvailable: true,
          isEnabled: true, // enable ran and pulled
          hasKey: true,
          account: CloudAccountStatus.available,
        ),
      );

      final result = await openOrRecoverPrivate(store: store, sync: sync);

      expect(result.status, PrivateRecoveryStatus.ready);
      expect(result.restoredFromCloud, isTrue);
      expect(store.calls, contains('stashLockedDatabase'));
      expect(store.calls, contains('discardStashedDatabase'));
      expect(store.calls, isNot(contains('restoreStashedDatabase')));
    });

    test(
        'enable() DEFERRED (owner not synced) → waitingForICloudKey, stash '
        'restored, NOT a false "restored" result', () async {
      final store = _LockedFakeStore();
      final sync = _FakeSync(
        enableResult: const PrivateSyncStatus(
          isAvailable: true,
          isEnabled: false, // ownerPending: enable did NOT run
          hasKey: true,
          account: CloudAccountStatus.available,
        ),
      );

      final result = await openOrRecoverPrivate(store: store, sync: sync);

      expect(result.status, PrivateRecoveryStatus.waitingForICloudKey);
      expect(result.restoredFromCloud, isFalse);
      expect(store.calls, contains('stashLockedDatabase'));
      expect(store.calls, contains('restoreStashedDatabase'));
      expect(store.calls, isNot(contains('discardStashedDatabase')));
      // The store is LOCKED again (restored), so a later retry re-recovers.
      expect(store.locked, isTrue);
    });

    test(
        'enable() BLOCKED (iCloud went unavailable) → needsUserChoice + '
        'iCloudUnavailable, stash restored', () async {
      final store = _LockedFakeStore();
      final sync = _FakeSync(
        enableResult: const PrivateSyncStatus(
          isAvailable: false, // iCloud flipped unavailable in the gap
          isEnabled: false,
          hasKey: true,
          account: CloudAccountStatus.noAccount,
        ),
      );

      final result = await openOrRecoverPrivate(store: store, sync: sync);

      expect(result.status, PrivateRecoveryStatus.needsUserChoice);
      expect(result.iCloudUnavailable, isTrue);
      expect(result.restoredFromCloud, isFalse);
      expect(store.calls, contains('restoreStashedDatabase'));
    });
  });
}
