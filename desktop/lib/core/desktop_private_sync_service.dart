import 'dart:io';

import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_bootstrap.dart';
import 'app_logger.dart';
import 'desktop_private_db.dart';
import 'desktop_sync_avatar_store.dart';
import 'desktop_sync_secret_store.dart';

/// The sync core (engine, service, crypto, bridge, schema) lives in the shared
/// `evolve_sync` package — single source of truth with the iOS mobile app.
/// This file provides only the desktop wiring: the Riverpod provider, the
/// AppLogger adapter, and the refresh-after-pull hook. Re-exported so callers
/// keep one import for the sync surface.
export 'package:evolve_sync/evolve_sync.dart';

/// Routes the shared sync core's logging through the desktop [AppLogger]
/// (Sentry off in Private mode; console in debug).
class DesktopSyncLogger extends SyncLogger {
  const DesktopSyncLogger();

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

/// The SharedPreferences key the sync core's [PrefsSyncEnabledStore] writes
/// (`enable`/`disable`). Kept identical to `PrefsSyncEnabledStore._key` in the
/// evolve_sync package.
const String kSyncEnabledPrefKey = 'private_sync_enabled_v1';

/// Reactive mirror of the per-device "iCloud sync enabled" flag. Reading the
/// SharedPreferences bool directly inside `build()` is NOT reactive (the
/// SharedPreferences instance identity never changes), so widgets that must
/// reflect the toggle — e.g. the data-loss `SyncOffBanner` — watch THIS provider
/// and the settings toggle calls [refreshDesktopSyncEnabled] to force a rebuild.
/// Mirrors mobile's `syncEnabledProvider`.
final desktopSyncEnabledProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs?.getBool(kSyncEnabledPrefKey) ?? false;
});

/// Re-read [desktopSyncEnabledProvider] after sync has been enabled/disabled so
/// any widget watching it rebuilds. Call from the settings iCloud-sync toggle.
void refreshDesktopSyncEnabled(WidgetRef ref) =>
    ref.invalidate(desktopSyncEnabledProvider);

final desktopPrivateSyncServiceProvider = Provider<PrivateSyncService>((ref) {
  // macOS-only: Windows/Linux Private mode is local-only (no CloudKit).
  if (!Platform.isMacOS) return const NoOpPrivateSyncService();
  // Overridden with the real instance at bootstrap; null only in tests that
  // don't override it — where sync must stay off anyway.
  final prefs = ref.read(sharedPreferencesProvider);
  if (prefs == null) return const NoOpPrivateSyncService();
  return CloudKitPrivateSyncService(
    bridge: const MethodChannelCloudKitBridge(),
    keys: SyncKeyStore(const DesktopSyncSecretStore()),
    crypto: SyncCrypto(),
    storeProvider: () => DesktopPrivateDb.instance.syncStore(),
    ownerProvider: () async => DesktopPrivateDb.instance.ownerId,
    ownerWriter: (id) => DesktopPrivateDb.instance.adoptOwner(id),
    enabledStore: PrefsSyncEnabledStore(prefs),
    avatarStore: const DesktopSyncAvatarStore(),
    logger: const DesktopSyncLogger(),
  );
});
