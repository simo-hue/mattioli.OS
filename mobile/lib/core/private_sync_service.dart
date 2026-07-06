import 'dart:io';

import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_prefs_provider.dart';
import 'app_logger.dart';
import 'keychain_sync_secret_store.dart';
import 'private_local_database.dart';

/// The sync core (engine, service, crypto, bridge, schema) lives in the shared
/// `evolve_sync` package — single source of truth with the macOS desktop app.
/// This file provides only the mobile wiring: the Riverpod provider, the
/// AppLogger adapter, and (via [KeychainSyncSecretStore]) the iCloud-Keychain
/// secret store. Re-exported so callers keep one import for the sync surface.
export 'package:evolve_sync/evolve_sync.dart';

/// Routes the shared sync core's logging through the app's [AppLogger]
/// (Sentry breadcrumbs + privacy sanitization).
class AppSyncLogger extends SyncLogger {
  const AppSyncLogger();

  @override
  void info(String message, {Map<String, dynamic>? extras}) =>
      AppLogger.info(message, extras: extras);

  @override
  void error(
    String message,
    dynamic error, [
    StackTrace? stackTrace,
    Map<String, dynamic>? extras,
  ]) =>
      AppLogger.error(message, error, stackTrace, extras);
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
    ownerWriter: (id) => PrivateLocalDatabase().adoptOwner(id),
    enabledStore: PrefsSyncEnabledStore(prefs),
    logger: const AppSyncLogger(),
  );
});
