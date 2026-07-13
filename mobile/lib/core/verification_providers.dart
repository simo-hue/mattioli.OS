import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../providers/shared_prefs_provider.dart';
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

/// The HealthKit sample identifiers the user has already been prompted to
/// authorize. iOS deliberately never reports read-authorization grant status,
/// so "has the permission sheet been shown for this type" is the honest signal
/// for hiding the proactive "Grant Health access" button. Device-local
/// (SharedPreferences); persists across sessions.
final healthAuthRequestedTypesProvider =
    NotifierProvider<HealthAuthRequestedTypesNotifier, Set<String>>(
  HealthAuthRequestedTypesNotifier.new,
);

class HealthAuthRequestedTypesNotifier extends Notifier<Set<String>> {
  static const String prefsKey = 'health_auth_requested_types';

  @override
  Set<String> build() =>
      ref.read(sharedPrefsProvider).getStringList(prefsKey)?.toSet() ??
      <String>{};

  /// Record that the Health authorization prompt has been shown for [typeId].
  /// Idempotent; persists the updated set.
  Future<void> markRequested(String typeId) async {
    if (state.contains(typeId)) return;
    final next = {...state, typeId};
    state = next;
    await ref.read(sharedPrefsProvider).setStringList(prefsKey, next.toList());
  }
}

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
    version: 2,
    onCreate: (db, _) => SqfliteVerificationStateStore.createTable(db),
    onUpgrade: (db, oldVersion, _) async {
      // v1 → v2 added the `nudged_at` column (couldn't-verify nudge de-dup).
      if (oldVersion < 2) await SqfliteVerificationStateStore.migrateToV2(db);
    },
  );
  // Idempotent — also creates the table for a DB opened at an existing version.
  await SqfliteVerificationStateStore.createTable(db);
  return SqfliteVerificationStateStore(db);
});
