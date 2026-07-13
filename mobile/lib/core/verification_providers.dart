import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'method_channel_health_kit_bridge.dart';
import 'method_channel_screen_time_bridge.dart';
import 'verification_state_store.dart';

/// Riverpod wiring for auto-verified habits. Kept free of `goal_provider` so it
/// can be imported from both the check-in path and the reconcile orchestration
/// without an import cycle. Tests override these with fakes / an in-memory store.

/// The native HealthKit bridge (degrades to no-op when the plugin is absent).
final healthKitBridgeProvider = Provider<HealthKitBridge>(
  (_) => const MethodChannelHealthKitBridge(),
);

/// The native Screen Time bridge (degrades to no-op when the plugin is absent).
final screenTimeBridgeProvider = Provider<ScreenTimeBridge>(
  (_) => const MethodChannelScreenTimeBridge(),
);

/// The pure reconcile/verdict engine, composed over the two bridges.
final verificationServiceProvider = Provider<VerificationService>(
  (ref) => VerificationService(
    health: ref.watch(healthKitBridgeProvider),
    screenTime: ref.watch(screenTimeBridgeProvider),
  ),
);

/// The local, unsynced verification bookkeeping store, backed by a dedicated
/// on-device database (`verification_state.db`) that exists in BOTH data modes
/// (D8). Opened lazily; tests override this provider with an in-memory store.
final verificationStateStoreProvider =
    FutureProvider<VerificationStateStore>((ref) async {
  final path = p.join(await getDatabasesPath(), 'verification_state.db');
  final db = await openDatabase(
    path,
    version: 1,
    onCreate: (db, _) => SqfliteVerificationStateStore.createTable(db),
  );
  // Idempotent — also creates the table for a DB opened at an existing version.
  await SqfliteVerificationStateStore.createTable(db);
  return SqfliteVerificationStateStore(db);
});
