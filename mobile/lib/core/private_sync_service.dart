import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_prefs_provider.dart';
import 'cloudkit_bridge.dart';
import 'cloudkit_bridge_method_channel.dart';
import 'cloudkit_private_sync_service.dart';
import 'private_local_database.dart';
import 'sync_crypto.dart';
import 'sync_key_store.dart';

class PrivateSyncStatus {
  final bool isAvailable;
  final bool isEnabled;
  final DateTime? lastSyncedAt;

  /// Raw account status for richer UI messaging (null for the no-op service).
  final CloudAccountStatus? account;
  final String? message;

  const PrivateSyncStatus({
    required this.isAvailable,
    required this.isEnabled,
    this.lastSyncedAt,
    this.account,
    this.message,
  });

  const PrivateSyncStatus.localOnly()
      : isAvailable = false,
        isEnabled = false,
        lastSyncedAt = null,
        account = null,
        message = 'iCloud sync is not available on this platform.';
}

abstract class PrivateSyncService {
  Future<PrivateSyncStatus> status();
  Future<PrivateSyncStatus> enable();
  Future<PrivateSyncStatus> disable();
  Future<PrivateSyncStatus> syncNow();

  /// Full reset for "delete private data": wipe the CloudKit zone, delete the
  /// shared key + canonical owner from iCloud Keychain, and turn sync off
  /// (offline → queued and finished on the next sync). The LOCAL wipe is done
  /// separately by [PrivateLocalDatabase.deleteAllPrivateData].
  Future<PrivateSyncStatus> requestFullReset();
}

/// Used on Android (sync is iOS-only) and anywhere sync isn't wired.
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

final privateSyncServiceProvider = Provider<PrivateSyncService>((ref) {
  // iOS-only: Android Private mode is local-only forever.
  if (!Platform.isIOS) return const NoOpPrivateSyncService();
  final prefs = ref.read(sharedPrefsProvider);
  return CloudKitPrivateSyncService(
    bridge: const MethodChannelCloudKitBridge(),
    keys: SyncKeyStore(const KeychainSyncSecretStore()),
    crypto: SyncCrypto(),
    storeProvider: () => PrivateLocalDatabase().syncStore(),
    ownerProvider: () => PrivateLocalDatabase().ownerId(),
    enabledStore: PrefsSyncEnabledStore(prefs),
  );
});
