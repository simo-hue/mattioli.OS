// Regression guard for the all-columns settings clobber.
//
// The bug, precisely: `AppSettingsNotifier.build()` seeds state SYNCHRONOUSLY
// from `_defaultSettings()` while `_loadPrivateSettings()` is still in flight,
// and the old `_saveToPrivate()` wrote a ~20-key map covering EVERY settings
// column on ANY single toggle. So a settings change made in that window wrote
// DEFAULTS across every column — silently reverting, on this phone AND on the
// Mac after the next sync, settings that only macOS even has UI for
// (`pref_glass_effects`, `pref_start_week_on_monday`, `pref_show_weekend`).
//
// The fix chosen is DIFF-BASED per-key writes rather than gating writes behind a
// completed load: a write now carries only the keys that actually moved,
// whatever else the in-memory snapshot happens to hold. Gating would have been
// the weaker fix — it drops or defers a tap the user already made, and it does
// nothing about the second, subtler source of the same damage: a write issued
// long AFTER the load that still re-stamps every unrelated column and pushes it.
//
// The properties pinned here:
//   1. one toggle writes exactly one key — before the load, and after it;
//   2. keys iOS has no field for are NEVER written at all;
//   3. an edit made before the load resolves survives the load;
//   4. an unrelated setting that arrived from the Mac survives an iOS toggle;
//   5. a no-op write emits nothing (so nothing is pushed to other devices).

import 'dart:async';

import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/coach_consent.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/settings_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'support/fake_private_data_store.dart';

class _NoopNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancelAll() async {}
}

/// A store whose `loadSyncedSettings` only completes when the test says so, so
/// the pre-load window can be entered deliberately instead of hoped for.
///
/// [gate] is re-armable (assign a fresh `Completer`) so a test can park a SECOND
/// load while the first is still outstanding — the situation a sync-triggered
/// `ref.invalidate(settingsProvider)` creates in production.
class _GatedPrivateDataStore extends FakePrivateDataStore {
  Completer<void> gate = Completer<void>();

  @override
  Future<Map<String, String?>> loadSyncedSettings() async {
    // Snapshot at CALL time, not after the gate. A real load reads the DB and
    // returns what was there; snapshotting afterwards would let a write issued
    // DURING the load leak into that same load's result, so the settings would
    // appear to survive without `_preloadEdits` doing anything at all. That
    // would make every test in this file pass for the wrong reason.
    final snapshot = Map<String, String?>.from(syncedSettings);
    await gate.future;
    return snapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Future<(ProviderContainer, T)> privateContainer<T extends FakePrivateDataStore>(
    T fake,
  ) async {
    SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith((ref) => fake),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
      ],
    );
    addTearDown(container.dispose);
    return (container, fake);
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// Everything a settings write is allowed to touch. Anything outside this is
  /// either device-local or a macOS-only setting iOS must never author.
  const iosOwnedKeys = {
    'language',
    'theme_mode',
    'accent_color',
    'pref_default_calendar_view',
    'pref_haptic_feedback',
    'pref_time_format_24h',
    'pref_ai_suggestions',
    'pref_focus_mode',
    'pref_milestones',
    'pref_deep_work_insights',
    'notif_habit_reminders',
    'notif_goal_deadlines',
    'notif_ai_insights',
    'notif_weekly_reports',
    'notif_evening_review',
    'morning_brief_time',
    'evening_review_time',
  };

  group('a settings write carries only what changed', () {
    test('one toggle after the load writes exactly one key', () async {
      final (container, fake) = await privateContainer(FakePrivateDataStore());
      container.read(settingsProvider.notifier);
      await settle();

      container.read(settingsProvider.notifier).updateSettings(
            container.read(settingsProvider).copyWith(hapticFeedback: false),
          );

      expect(fake.syncedWrites, hasLength(1));
      expect(fake.syncedWrites.single, {'pref_haptic_feedback': '0'});
    });

    test('one toggle BEFORE the load resolves still writes exactly one key',
        () async {
      // This is the exact window the bug lived in.
      final gated = _GatedPrivateDataStore();
      final (container, fake) = await privateContainer(gated);
      container.read(settingsProvider.notifier);
      // Deliberately NOT settled: the load is parked on the gate.

      container.read(settingsProvider.notifier).updateSettings(
            container.read(settingsProvider).copyWith(hapticFeedback: false),
          );

      expect(fake.syncedWrites, hasLength(1));
      expect(fake.syncedWrites.single, {'pref_haptic_feedback': '0'});
      // Nothing resembling "every column, at its default" went out.
      expect(fake.syncedWrites.single.keys.length, lessThan(iosOwnedKeys.length));

      gated.gate.complete();
      await settle();
    });

    test('never writes a key iOS has no field for', () async {
      final (container, fake) = await privateContainer(FakePrivateDataStore());
      container.read(settingsProvider.notifier);
      await settle();

      // Drive one of every kind of change.
      final notifier = container.read(settingsProvider.notifier);
      notifier.updateSettings(
        container.read(settingsProvider).copyWith(themeMode: 'light'),
      );
      notifier.updateSettings(
        container.read(settingsProvider).copyWith(language: 'de'),
      );
      notifier.setAccentColor(const Color(0xFF10B981));
      notifier.toggleAi(true);
      notifier.updateSettings(
        container.read(settingsProvider).copyWith(morningBriefTime: '07:30'),
      );

      final written = {
        for (final w in fake.syncedWrites) ...w.keys,
      };
      expect(written, isNotEmpty);
      expect(written.difference(iosOwnedKeys), isEmpty,
          reason: 'iOS authored a setting it has no UI for — a macOS value '
              'would be overwritten with an invented default');
      // Named explicitly because these are the ones macOS owns alone.
      for (final macOnly in const [
        'pref_glass_effects',
        'pref_start_week_on_monday',
        'pref_show_weekend',
        'tutorial_completed',
      ]) {
        expect(written, isNot(contains(macOnly)));
      }
    });

    test('a device-local write carries a synced settings key', () async {
      // `settingsRowWrites` records every `updateSettingsRow` payload — the
      // LEGACY `profiles` columns, written whole-row. Anything that must travel
      // per-key has to go through `writeSyncedSettings` instead: a synced value
      // written into the profiles row is subject to row-level last-write-wins,
      // which is exactly how a preference the Mac owns gets reverted by an iOS
      // default. The recorder existed for this and nothing asserted it.
      final (container, fake) = await privateContainer(FakePrivateDataStore());
      container.read(settingsProvider.notifier);
      await settle();

      // One change of every kind, plus the one device-local column iOS writes.
      final notifier = container.read(settingsProvider.notifier);
      notifier.updateSettings(
        container.read(settingsProvider).copyWith(themeMode: 'light'),
      );
      notifier.updateSettings(
        container.read(settingsProvider).copyWith(language: 'de'),
      );
      notifier.setAccentColor(const Color(0xFF10B981));
      notifier.toggleAi(true);
      notifier.updateSettings(
        container.read(settingsProvider).copyWith(morningBriefTime: '07:30'),
      );
      notifier.updateSettings(
        container.read(settingsProvider).copyWith(biometricLock: true),
      );
      await settle();

      final localKeys = {for (final w in fake.settingsRowWrites) ...w.keys};
      expect(localKeys, isNotEmpty,
          reason: 'precondition: the biometric flip did reach the profiles row, '
              'so an empty intersection below is not vacuous');
      // Derived from the shared schema rather than hardcoded, so the test tracks
      // the product decision instead of duplicating it. Read-only: this must
      // never widen `syncedSettingKeys`.
      expect(
        localKeys.intersection(PrivateDbSchema.syncedSettingKeys.toSet()),
        isEmpty,
        reason: 'a setting that must travel per-key was written into the legacy '
            'profiles row, where row-level last-write-wins can revert it',
      );
    });

    test('an unrelated toggle bumps the whole profiles row', () async {
      // `updateSettingsRow` re-stamps `is_pro`/`sentry_consent` and bumps
      // `updated_at`, which marks the ENTIRE profiles row dirty for sync. So
      // calling it for a toggle that did not move `biometric_lock` is pure noise
      // on the wire, on every unrelated tap. settings_provider.dart guards this
      // with an early return; nothing asserted the guard.
      final (container, fake) = await privateContainer(FakePrivateDataStore());
      container.read(settingsProvider.notifier);
      await settle();

      container.read(settingsProvider.notifier).updateSettings(
            container.read(settingsProvider).copyWith(hapticFeedback: false),
          );
      await settle();

      expect(fake.settingsRowWrites, isEmpty);
      expect(fake.calls, isNot(contains('updateSettingsRow')));

      // The other half: the guard must SUPPRESS the write, not disable it.
      // Asserting emptiness alone would pass just as happily if the write had
      // been deleted outright.
      container.read(settingsProvider.notifier).updateSettings(
            container.read(settingsProvider).copyWith(biometricLock: true),
          );
      await settle();

      expect(fake.settingsRowWrites, hasLength(1));
      expect(fake.settingsRowWrites.single, {'biometric_lock': 1});
    });

    test('a no-op update writes nothing at all', () async {
      final (container, fake) = await privateContainer(FakePrivateDataStore());
      container.read(settingsProvider.notifier);
      await settle();

      container
          .read(settingsProvider.notifier)
          .updateSettings(container.read(settingsProvider));

      // Nothing moved, so nothing is stamped — and nothing is pushed to the
      // user's other devices. The old whole-row write bumped `updated_at` on
      // every settings column regardless.
      expect(fake.syncedWrites, isEmpty);
    });
  });

  group('the fake records what the real store would write', () {
    // `settingsRowWrites` is only a guard if it actually observes every
    // `updateSettingsRow` the production code performs. It did not: the fake
    // stubbed `setPrivateAiExternalConsent` out entirely, while the real
    // PrivateLocalDatabase routes that write through `updateSettingsRow`. So a
    // whole production write was invisible to every assertion in this file.
    test('granting AI consent is invisible to the device-local recorder',
        () async {
      final (container, fake) = await privateContainer(FakePrivateDataStore());

      // The path production takes from the coach consent sheet.
      await container.read(coachConsentStoreProvider).grant(CoachDisclosure.byok);

      expect(
        fake.settingsRowWrites,
        hasLength(1),
        reason: 'the real store writes this through updateSettingsRow, so the '
            'recorder that is meant to police device-local writes must see it',
      );
      expect(
        fake.settingsRowWrites.single,
        {'private_ai_external_consent': 1},
      );
      // And it is a device-local column, not something that travels.
      expect(fake.syncedWrites, isEmpty);
    });
  });

  group('the async load does not destroy or get destroyed by an edit', () {
    test('a setting only macOS has UI for survives an iOS toggle', () async {
      final fake = FakePrivateDataStore()
        ..syncedSettings = {
          'pref_show_weekend': '0', // macOS-only
          'pref_start_week_on_monday': '0', // macOS-only
          'theme_mode': 'light',
        };
      final (container, _) = await privateContainer(fake);
      container.read(settingsProvider.notifier);
      await settle();

      container.read(settingsProvider.notifier).updateSettings(
            container.read(settingsProvider).copyWith(hapticFeedback: false),
          );

      // The stored values the Mac owns are untouched...
      expect(fake.syncedSettings['pref_show_weekend'], '0');
      expect(fake.syncedSettings['pref_start_week_on_monday'], '0');
      // ...and so is the one iOS shares but did not change.
      expect(fake.syncedSettings['theme_mode'], 'light');
    });

    test('an edit made before the load resolves is not snapped back', () async {
      final gated = _GatedPrivateDataStore()
        ..syncedSettings = {
          // What the store holds: haptics ON, plus a language from the Mac.
          'pref_haptic_feedback': '1',
          'language': 'de',
        };
      final (container, _) = await privateContainer(gated);
      container.read(settingsProvider.notifier);

      // The user turns haptics off while the load is still parked.
      container.read(settingsProvider.notifier).updateSettings(
            container.read(settingsProvider).copyWith(hapticFeedback: false),
          );
      expect(container.read(settingsProvider).hapticFeedback, isFalse);

      gated.gate.complete();
      await settle();
      await settle();

      // The load must not resurrect the stored `1` over the tap the user just
      // made — the write already went out, so the UI snapping back would mean
      // the visible state and the stored state disagree.
      expect(container.read(settingsProvider).hapticFeedback, isFalse);
      // Everything the user did NOT touch still arrives from the store.
      expect(container.read(settingsProvider).language, 'de');
    });

    test('an edit made before a post-sync RELOAD resolves is snapped back',
        () async {
      // Same hazard as the test above, but reached the way a real user reaches
      // it. `_privateLoaded` latches true in the first load's `finally` and
      // nothing ever clears it, while the notifier object survives a rebuild
      // (riverpod's `invalidateSelf` runs onDispose callbacks, not `dispose()`,
      // so `classListenable.result ??=` hands back the same instance). So every
      // load after the first one has the pre-load-edit machinery switched off.
      //
      // The trigger is not a data-mode flip — it is `ref.invalidate(
      // settingsProvider)` in sync_refresh.dart, which main.dart's
      // `_syncAndRefresh` fires after EVERY sync that applied remote changes:
      // the 60s poll, app resume, a debounced write, a CloudKit push. On a
      // two-device user this is routine.
      final gated = _GatedPrivateDataStore()
        ..syncedSettings = {
          'pref_haptic_feedback': '1',
          'language': 'de',
        };
      final (container, fake) = await privateContainer(gated);
      container.read(settingsProvider.notifier);
      gated.gate.complete();
      await settle();
      await settle();
      expect(container.read(settingsProvider).hapticFeedback, isTrue);

      // A sync applied remote changes, so the providers are invalidated and a
      // SECOND load starts. Settle once so it gets past `loadSettingsRow` and
      // parks on the gate holding a snapshot of the STORED values — without
      // this the load would not read the DB until after the edit below, and it
      // would see the edit's own write and appear to preserve it.
      gated.gate = Completer<void>();
      container.invalidate(settingsProvider);
      container.read(settingsProvider);
      await settle();

      // The user turns haptics off inside that window.
      container.read(settingsProvider.notifier).updateSettings(
            container.read(settingsProvider).copyWith(hapticFeedback: false),
          );
      expect(container.read(settingsProvider).hapticFeedback, isFalse);
      expect(fake.syncedWrites.last, {'pref_haptic_feedback': '0'},
          reason: 'precondition: the tap really was persisted');

      gated.gate.complete();
      await settle();
      await settle();

      expect(
        container.read(settingsProvider).hapticFeedback,
        isFalse,
        reason: 'the reload resurrected the stored value over a tap that was '
            'already written — the switch flips back under the user while the '
            'private DB holds the opposite value',
      );
      // ...and the load is still applied for keys the user did not touch, so
      // this is not passing by simply ignoring the load.
      expect(container.read(settingsProvider).language, 'de');
    });

    test("a load abandoned by a reload overwrites the reload's state", () async {
      // Why resetting the latch is not enough on its own. Two loads can be in
      // flight at once (a debounced write flushes -> syncNow -> invalidate,
      // while the previous load is still awaiting the DB). The abandoned load
      // still runs `state = loaded` and still clears `_preloadEdits` in its
      // `finally` — so it lands on the NEW session and re-opens the same
      // snap-back through a different door.
      final gated = _GatedPrivateDataStore()
        ..syncedSettings = {'pref_haptic_feedback': '1'};
      final (container, _) = await privateContainer(gated);
      container.read(settingsProvider.notifier);
      await settle(); // load #1 has read the row and parks holding '1'
      final firstLoadGate = gated.gate;

      container.read(settingsProvider.notifier).updateSettings(
            container.read(settingsProvider).copyWith(hapticFeedback: false),
          );
      expect(container.read(settingsProvider).hapticFeedback, isFalse);

      // A second load starts while the first is still outstanding, and reads
      // the DB AFTER the write — so it holds the correct '0'.
      gated.gate = Completer<void>();
      final secondLoadGate = gated.gate;
      container.invalidate(settingsProvider);
      container.read(settingsProvider);
      await settle();

      // The live load resolves first and lands the right value...
      secondLoadGate.complete();
      await settle();
      await settle();
      expect(container.read(settingsProvider).hapticFeedback, isFalse);

      // ...and then the abandoned load #1 resolves LATE, carrying the stale
      // snapshot it took before the user's tap.
      firstLoadGate.complete();
      await settle();
      await settle();

      expect(
        container.read(settingsProvider).hapticFeedback,
        isFalse,
        reason: 'a load belonging to an abandoned generation wrote its stale '
            "result over the live session's state",
      );
    });

    test('the load applies stored values over the synchronous defaults',
        () async {
      final fake = FakePrivateDataStore()
        ..syncedSettings = {
          'theme_mode': 'light',
          'language': 'es',
          'notif_evening_review': '0',
          'morning_brief_time': '06:15',
          'accent_color': '#10B981',
        };
      final (container, _) = await privateContainer(fake);
      container.read(settingsProvider.notifier);

      // Before the load: the synchronous default seed.
      expect(container.read(settingsProvider).themeMode, 'dark');

      await settle();

      final s = container.read(settingsProvider);
      expect(s.themeMode, 'light');
      expect(s.language, 'es');
      expect(s.eveningReview, isFalse);
      expect(s.morningBriefTime, '06:15');
      expect(s.accentColor, const Color(0xFF10B981));
      // Private mode still reports Pro unlocked locally.
      expect(s.isPro, isTrue);
    });
  });
}
