import 'cloudkit_bridge.dart';

class PrivateSyncStatus {
  final bool isAvailable;
  final bool isEnabled;
  final DateTime? lastSyncedAt;

  /// Raw account status for richer UI messaging (null for the no-op service).
  final CloudAccountStatus? account;
  final String? message;

  /// How many remote records the just-finished sync applied locally. Lets a
  /// caller know whether to refresh the in-memory data providers (>0). 0 for
  /// status() / no-op.
  final int appliedChanges;

  const PrivateSyncStatus({
    required this.isAvailable,
    required this.isEnabled,
    this.lastSyncedAt,
    this.account,
    this.message,
    this.appliedChanges = 0,
  });

  const PrivateSyncStatus.localOnly()
      : isAvailable = false,
        isEnabled = false,
        lastSyncedAt = null,
        account = null,
        message = 'iCloud sync is not available on this platform.',
        appliedChanges = 0;
}

abstract class PrivateSyncService {
  Future<PrivateSyncStatus> status();
  Future<PrivateSyncStatus> enable();
  Future<PrivateSyncStatus> disable();
  Future<PrivateSyncStatus> syncNow();

  /// Full reset for "delete private data": wipe the CloudKit zone, delete the
  /// shared key + canonical owner from the iCloud Keychain, and turn sync off
  /// (offline → queued and finished on the next sync). The LOCAL wipe is done
  /// separately by the app's private store (`deleteAllPrivateData`).
  Future<PrivateSyncStatus> requestFullReset();
}

/// Used wherever CloudKit sync isn't available (Android; Windows/Linux
/// desktop; Supabase mode) and anywhere sync isn't wired.
class NoOpPrivateSyncService implements PrivateSyncService {
  const NoOpPrivateSyncService();

  @override
  Future<PrivateSyncStatus> status() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> enable() async =>
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
}
