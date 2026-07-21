// Regression: the locked-DB auto-recovery must NEVER discard the stashed local
// copy (`.recovery-bak`) on a path where the cloud re-pull did not demonstrably
// run and restore data.
//
// The fakes here model CloudKitPrivateSyncService faithfully on THIS branch:
//   * enable() reports isEnabled from the persisted `private_sync_enabled_v1`
//     pref. openOrRecoverPrivate only reaches the auto-recover branch when
//     probe.isEnabled is true (decidePrivateModeRecovery), and neither the
//     ownerPending nor the blockedBy branch clears it — so isEnabled is TRUE for
//     the ran, deferred and blocked cases alike and cannot gate the discard.
//   * appliedChanges comes from SyncResult.applied, and both non-running
//     branches return before the engine's syncNow() — so it is 0 unless the
//     re-pull really applied records.
//   * lastSyncedAt is read from sync_meta INSIDE the DB, which stashLockedDatabase
//     just replaced with a fresh one (column default NULL); only a full sync that
//     ran stamps it.

import 'package:evolve_desktop/core/desktop_private_db.dart'
    show PrivateRecoveryStore, PrivateDatabaseLockedException;
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/features/auth/application/private_mode_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tracks the stashed copy as a value, so a test can assert the user's data
/// SURVIVED rather than just that a method was/wasn't called.
class _StashTrackingStore implements PrivateRecoveryStore {
  /// The live encrypted DB file, or null once stashed aside.
  String? localCopy = 'the-users-only-private-db';

  /// The `.recovery-bak` set — null when nothing is stashed.
  String? stash;

  bool locked = true;
  final List<String> calls = [];

  /// True once the stashed copy is gone for good AND nothing restored it.
  bool get localCopyDestroyed => stash == null && localCopy == null;

  @override
  Future<void> ensureReady() async {
    calls.add('ensureReady');
    if (locked) throw const PrivateDatabaseLockedException();
  }

  @override
  Future<void> resetLockedDatabase() async {
    calls.add('resetLockedDatabase');
    localCopy = null;
    stash = null;
    locked = false;
  }

  @override
  Future<bool> stashLockedDatabase() async {
    calls.add('stashLockedDatabase');
    stash = localCopy;
    localCopy = null; // a fresh, openable empty DB takes its place
    locked = false;
    return stash != null;
  }

  @override
  Future<void> restoreStashedDatabase() async {
    calls.add('restoreStashedDatabase');
    localCopy = stash;
    stash = null;
    locked = true; // restored copy is locked again — a later launch retries
  }

  @override
  Future<void> discardStashedDatabase() async {
    calls.add('discardStashedDatabase');
    stash = null; // permanent: the .bak is deleted
  }
}

class _FakeSync implements PrivateSyncService {
  _FakeSync({required this.enableResult});

  final PrivateSyncStatus enableResult;

  /// Sync ON + iCloud available + key present ⇒ autoRecoverFromCloud.
  static const _autoRecoverProbe = PrivateSyncStatus(
    isAvailable: true,
    isEnabled: true,
    hasKey: true,
    account: CloudAccountStatus.available,
  );

  @override
  Future<PrivateSyncStatus> probe() async => _autoRecoverProbe;

  @override
  Future<PrivateSyncStatus> enable({bool force = false}) async => enableResult;

  @override
  Future<PrivateSyncStatus> status() async => _autoRecoverProbe;

  @override
  Future<PrivateSyncStatus> disable() async => enableResult;

  @override
  Future<PrivateSyncStatus> syncNow({String reason = 'manual'}) async => enableResult;

  @override
  Future<PrivateSyncStatus> requestFullReset() async => enableResult;

  @override
  Future<SyncDiagnostics?> diagnostics() async => null;

  @override
  Future<PrivateSyncStatus> resetSyncFromThisDevice() async =>
      enableResult;

  @override
  Future<T> runExclusive<T>(Future<T> Function() action) => action();
}

void main() {
  group('openOrRecoverPrivate — the stash outlives an unconfirmed re-pull', () {
    test(
        'enable() DEFERRED (ownerPending) with the pref still enabled → the '
        'local copy survives and no false "restored from iCloud"', () async {
      final store = _StashTrackingStore();
      final sync = _FakeSync(
        // Exactly what the real service returns on ownerPending: the pref was
        // never cleared, the engine never reached syncNow.
        enableResult: const PrivateSyncStatus(
          isAvailable: true,
          isEnabled: true,
          hasKey: true,
          account: CloudAccountStatus.available,
        ),
      );

      final result = await openOrRecoverPrivate(sync, store: store);

      expect(store.localCopyDestroyed, isFalse);
      expect(store.localCopy, 'the-users-only-private-db');
      expect(store.calls, isNot(contains('discardStashedDatabase')));
      expect(store.locked, isTrue, reason: 'a later launch must retry recovery');
      expect(result.status, PrivateRecoveryStatus.waitingForICloudKey);
      expect(result.restoredFromCloud, isFalse);
    });

    test(
        'enable() BLOCKED (iCloud unavailable) with the pref still enabled → '
        'the local copy survives', () async {
      final store = _StashTrackingStore();
      final sync = _FakeSync(
        enableResult: const PrivateSyncStatus(
          isAvailable: false,
          isEnabled: true,
          hasKey: true,
          account: CloudAccountStatus.noAccount,
        ),
      );

      final result = await openOrRecoverPrivate(sync, store: store);

      expect(store.localCopyDestroyed, isFalse);
      expect(store.localCopy, 'the-users-only-private-db');
      expect(store.calls, isNot(contains('discardStashedDatabase')));
      expect(result.status, PrivateRecoveryStatus.needsUserChoice);
      expect(result.iCloudUnavailable, isTrue);
      expect(result.restoredFromCloud, isFalse);
    });

    test(
        'enable() RAN but the zone was empty → nothing was recovered, so the '
        'local copy survives and the user gets the choice', () async {
      final store = _StashTrackingStore();
      final sync = _FakeSync(
        enableResult: PrivateSyncStatus(
          isAvailable: true,
          isEnabled: true,
          hasKey: true,
          account: CloudAccountStatus.available,
          appliedChanges: 0, // nothing in CloudKit to restore
          lastSyncedAt: DateTime.utc(2026, 7, 15), // ...but the sync did run
        ),
      );

      final result = await openOrRecoverPrivate(sync, store: store);

      expect(store.localCopyDestroyed, isFalse);
      expect(store.localCopy, 'the-users-only-private-db');
      expect(store.calls, isNot(contains('discardStashedDatabase')));
      expect(result.status, PrivateRecoveryStatus.needsUserChoice);
      expect(result.restoredFromCloud, isFalse,
          reason: 'an empty zone must never be reported as a restore');
    });

    test(
        'enable() RAN and applied records → recovery confirmed, stash committed',
        () async {
      final store = _StashTrackingStore();
      final sync = _FakeSync(
        enableResult: PrivateSyncStatus(
          isAvailable: true,
          isEnabled: true,
          hasKey: true,
          account: CloudAccountStatus.available,
          appliedChanges: 42,
          lastSyncedAt: DateTime.utc(2026, 7, 15),
        ),
      );

      final result = await openOrRecoverPrivate(sync, store: store);

      expect(result.status, PrivateRecoveryStatus.ready);
      expect(result.restoredFromCloud, isTrue);
      expect(store.calls, contains('discardStashedDatabase'));
      expect(store.calls, isNot(contains('restoreStashedDatabase')));
      expect(store.stash, isNull);
    });

    test('a mid-recovery throw restores the stash', () async {
      final store = _StashTrackingStore();
      final sync = _ThrowingSync();

      final result = await openOrRecoverPrivate(sync, store: store);

      expect(result.status, PrivateRecoveryStatus.error);
      expect(store.localCopyDestroyed, isFalse);
      expect(store.localCopy, 'the-users-only-private-db');
      expect(store.calls, isNot(contains('discardStashedDatabase')));
    });
  });
}

/// probe() succeeds into the auto-recover branch, then enable() blows up.
class _ThrowingSync extends _FakeSync {
  _ThrowingSync()
      : super(
          enableResult: const PrivateSyncStatus(
            isAvailable: true,
            isEnabled: true,
            hasKey: true,
          ),
        );

  @override
  Future<PrivateSyncStatus> enable({bool force = false}) async => throw StateError('keychain blew up');
}
