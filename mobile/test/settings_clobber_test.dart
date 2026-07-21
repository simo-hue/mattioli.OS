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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
class _GatedPrivateDataStore extends FakePrivateDataStore {
  final Completer<void> gate = Completer<void>();

  @override
  Future<Map<String, String?>> loadSyncedSettings() async {
    await gate.future;
    return Map<String, String?>.from(syncedSettings);
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
