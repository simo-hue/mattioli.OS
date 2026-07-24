import 'dart:convert';

import 'package:evolve_verification/evolve_verification.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_prefs_provider.dart';
import 'method_channel_health_kit_bridge.dart';
import 'verification_config.dart';
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

/// Whether this device has Apple Health at all.
///
/// `HealthKitBridge.isHealthDataAvailable()` has existed — declared, bridged to
/// `HKHealthStore.isHealthDataAvailable()`, faked and unit-tested — with no
/// production caller. It matters now: the app is universal, and on a device
/// with no paired iPhone or Watch every one of our eight types returns empty.
/// The reviewer who rejected us under Guideline 2.5.1 was on an iPad Air, so an
/// honest "there is no Health data here, and here is why" is the difference
/// between a feature that looks broken and one that explains itself.
final healthDataAvailableProvider = FutureProvider<bool>((ref) async {
  if (!VerificationConfig.healthKitEnabled) return false;
  return ref.read(healthKitBridgeProvider).isHealthDataAvailable();
});

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

/// FamilyControls authorization state for the Settings opt-in surface.
///
/// Unlike HealthKit reads, Screen Time authorization IS directly queryable (D9),
/// so the opt-in can honestly render notDetermined/denied/approved. Returns
/// `notDetermined` when the feature is dark. Invalidate after requesting
/// authorization to pick up the new state.
final screenTimeAuthStatusProvider =
    FutureProvider<ScreenTimeAuthorizationStatus>((ref) async {
  if (!VerificationConfig.screenTimeEnabled) {
    return ScreenTimeAuthorizationStatus.notDetermined;
  }
  
  final listener = AppLifecycleListener(
    onResume: ref.invalidateSelf,
  );
  ref.onDispose(listener.dispose);

  return ref.read(screenTimeBridgeProvider).authorizationStatus();
});

/// One stored Mode-A selection: the opaque base64 `FamilyActivitySelection` plus
/// the app/category counts (so the habit editor can show "N selected" without
/// re-decoding the blob natively).
class ScreenTimeSelectionEntry {
  final String blob;
  final int applicationCount;
  final int categoryCount;

  const ScreenTimeSelectionEntry({
    required this.blob,
    required this.applicationCount,
    required this.categoryCount,
  });

  int get totalCount => applicationCount + categoryCount;

  Map<String, Object?> toJson() => {
        'blob': blob,
        'apps': applicationCount,
        'categories': categoryCount,
      };

  factory ScreenTimeSelectionEntry.fromJson(Map<String, Object?> j) =>
      ScreenTimeSelectionEntry(
        blob: j['blob'] as String,
        applicationCount: (j['apps'] as num?)?.toInt() ?? 0,
        categoryCount: (j['categories'] as num?)?.toInt() ?? 0,
      );
}

/// The per-goal `FamilyActivitySelection`s (Mode A), keyed by goalId and stored
/// device-local in SharedPreferences as a single JSON map.
///
/// NEVER synced: the tokens are device-scoped, so a Mode-A goal restored on a
/// new device has no entry here and the reconcile treats it as couldn't-verify
/// (never a silent pass) until the user re-picks. Mirrors the device-local,
/// unsynced pattern of [healthAuthRequestedTypesProvider].
final screenTimeSelectionsProvider = NotifierProvider<
    ScreenTimeSelectionsNotifier, Map<String, ScreenTimeSelectionEntry>>(
  ScreenTimeSelectionsNotifier.new,
);

class ScreenTimeSelectionsNotifier
    extends Notifier<Map<String, ScreenTimeSelectionEntry>> {
  static const String prefsKey = 'screen_time_selections';

  @override
  Map<String, ScreenTimeSelectionEntry> build() {
    final raw = ref.read(sharedPrefsProvider).getString(prefsKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries)
          if (e.value is Map)
            e.key: ScreenTimeSelectionEntry.fromJson(
                Map<String, Object?>.from(e.value as Map)),
      };
    } catch (_) {
      return const {}; // corrupt map → behave as "no selections"
    }
  }

  /// The stored selection blob for [goalId], or null if none is resolvable.
  String? blobFor(String goalId) => state[goalId]?.blob;

  Future<void> setSelection(String goalId, ScreenTimeSelectionEntry entry) async {
    state = {...state, goalId: entry};
    await _persist();
  }

  Future<void> remove(String goalId) async {
    if (!state.containsKey(goalId)) return;
    state = {...state}..remove(goalId);
    await _persist();
  }

  Future<void> _persist() => ref.read(sharedPrefsProvider).setString(
      prefsKey,
      jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}));
}

/// Set by the foreground reconcile when DeviceActivity rejects a sync for
/// exceeding Apple's 20-activity cap (D10). The UI watches it to prompt the user
/// to remove a Screen Time habit, then clears it. Null = no outstanding limit.
final screenTimeMonitorLimitProvider = NotifierProvider<
    ScreenTimeMonitorLimitNotifier, ScreenTimeMonitorLimitException?>(
  ScreenTimeMonitorLimitNotifier.new,
);

class ScreenTimeMonitorLimitNotifier
    extends Notifier<ScreenTimeMonitorLimitException?> {
  @override
  ScreenTimeMonitorLimitException? build() => null;

  void report(ScreenTimeMonitorLimitException e) => state = e;
  void clear() => state = null;
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
  // Shared opener (also used by the notification manual-freeze path) so the two
  // callers can never disagree about the DB's version/migrations/schema.
  return SqfliteVerificationStateStore.open();
});
