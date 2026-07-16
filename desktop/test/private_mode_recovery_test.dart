// Recovery POLICY for a locked private DB (openOrRecoverPrivate) — desktop.
// Mirror of mobile/test/private_mode_recovery_test.dart.
//
// Focus: the auto-recover-from-cloud branch must NOT destroy the only local copy
// before the cloud re-pull is confirmed. It stashes the locked DB, runs enable(),
// and only claims "restored from iCloud" when records actually came back. A
// deferred (owner not yet synced) or blocked (iCloud unavailable) enable must
// restore the stash and surface the correct recovery state — never a false
// success over an empty DB.
//
// The fakes below mirror what CloudKitPrivateSyncService really returns: enable()
// reports isEnabled from the persisted per-device pref, which is already true on
// this branch, so it is true for the ran, deferred AND blocked cases alike. Only
// appliedChanges / lastSyncedAt distinguish them.

import 'package:evolve_desktop/core/desktop_private_db.dart'
    show PrivateRecoveryStore, PrivateDatabaseLockedException;
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/features/auth/application/private_mode_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

/// A store that reports LOCKED (ensureReady throws) until it's been stashed —
/// modelling the real flow where the stash mints a fresh, openable empty DB.
class _LockedFakeStore implements PrivateRecoveryStore {
  bool locked = true;
  bool stashed = false;
  final List<String> calls = [];

  @override
  Future<void> ensureReady() async {
    calls.add('ensureReady');
    if (locked) throw const PrivateDatabaseLockedException();
  }

  @override
  Future<void> resetLockedDatabase() async {
    calls.add('resetLockedDatabase');
    locked = false;
  }

  @override
  Future<bool> stashLockedDatabase() async {
    calls.add('stashLockedDatabase');
    stashed = true;
    locked = false;
    return true;
  }

  @override
  Future<void> restoreStashedDatabase() async {
    calls.add('restoreStashedDatabase');
    stashed = false;
    locked = true;
  }

  @override
  Future<void> discardStashedDatabase() async {
    calls.add('discardStashedDatabase');
    stashed = false;
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
}

void main() {
  group('openOrRecoverPrivate — autoRecoverFromCloud (desktop)', () {
    test('enable() RAN → ready + restoredFromCloud, stash discarded', () async {
      final store = _LockedFakeStore();
      final sync = _FakeSync(
        enableResult: PrivateSyncStatus(
          isAvailable: true,
          isEnabled: true,
          hasKey: true,
          account: CloudAccountStatus.available,
          // enable ran: the full re-pull applied records and stamped the fresh
          // DB's sync_meta.
          appliedChanges: 12,
          lastSyncedAt: DateTime.utc(2026, 7, 15),
        ),
      );

      final result = await openOrRecoverPrivate(sync, store: store);

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
          // ownerPending: enable did NOT run. The real service still reports the
          // pref as enabled here — nothing cleared it — and applied nothing.
          isEnabled: true,
          hasKey: true,
          account: CloudAccountStatus.available,
        ),
      );

      final result = await openOrRecoverPrivate(sync, store: store);

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
          isEnabled: true, // the per-device pref is untouched by a blocked enable
          hasKey: true,
          account: CloudAccountStatus.noAccount,
        ),
      );

      final result = await openOrRecoverPrivate(sync, store: store);

      expect(result.status, PrivateRecoveryStatus.needsUserChoice);
      expect(result.iCloudUnavailable, isTrue);
      expect(result.restoredFromCloud, isFalse);
      expect(store.calls, contains('restoreStashedDatabase'));
    });
  });
}
