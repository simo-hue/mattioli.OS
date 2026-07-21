// Focus Mode on iOS.
//
// `_runNotificationSync` opens with `cancelAll()` and returns early whenever
// `settings.focusMode` is true — so this one flag suppresses every reminder the
// app schedules. macOS has always had a switch for it, and the value SYNCS.
// iOS had no UI for it anywhere (the only other mention was a key in the
// privacy-settings export JSON), which meant the Mac could permanently silence
// the iPhone with no visible cause and nothing on the phone able to undo it.
//
// The properties pinned here are therefore about the switch EXISTING, being
// reachable, and being honest:
//   * it renders on the notification settings screen;
//   * it reflects a value that arrived from the other device;
//   * tapping it moves the shared state AND persists through the per-key synced
//     store (so it travels back);
//   * turning it on actually stops the scheduling.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/settings_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/kit/evolve_switch.dart';
import 'package:mattioli_os/ui/screens/notification_settings_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'support/fake_private_data_store.dart';

/// Records `cancelAll` so the "focus mode actually silences things" property can
/// be observed without a platform notification plugin.
class _RecordingNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  int cancelAllCount = 0;

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
  }
}

Future<(ProviderContainer, FakePrivateDataStore)> _pumpNotificationSettings(
  WidgetTester tester, {
  Map<String, String?> storedSynced = const {},
}) async {
  SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
  final prefs = await SharedPreferences.getInstance();
  final fake = FakePrivateDataStore()
    ..syncedSettings = Map<String, String?>.from(storedSynced);

  await tester.binding.setSurfaceSize(const Size(500, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      privateLocalDatabaseProvider.overrideWith((ref) => fake),
      initialGoalsProvider.overrideWithValue('[]'),
      initialLogsProvider.overrideWithValue('{}'),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const NotificationSettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, fake);
}

/// Runs [body] with the target platform forced to iOS, and — crucially —
/// clears the override BEFORE the test ends. `testWidgets` asserts the
/// foundation debug vars are unset when the body returns, so a `tearDown` is too
/// late. The override matters only where a reminder is actually SCHEDULED: the
/// plugin facade's iOS branch is null-safe (`?.`) for a non-platform-specific
/// mock, while its Android branch uses a hard `!` and throws.
Future<void> _asIos(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// The switch belonging to the row whose title is [title].
Finder _switchFor(String title) => find.descendant(
      of: find.ancestor(
        of: find.text(title),
        matching: find.byType(Row),
      ).last,
      matching: find.byType(EvolveSwitch),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingNotificationsPlatform notifications;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    LocaleSettings.setLocaleSync(AppLocale.en);
    // Turning Focus Mode OFF re-schedules the briefs, and `_nextInstanceOfTime`
    // reads `tz.local` — unset, it throws and the failure path logs, which in a
    // widget test surfaces as a pending AppLogger timer rather than the real
    // cause. Initialise it so the OFF path runs for real.
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    notifications = _RecordingNotificationsPlatform();
    FlutterLocalNotificationsPlatform.instance = notifications;
  });

  testWidgets('Focus Mode has a switch on the notification settings screen',
      (tester) async {
    await _pumpNotificationSettings(tester);

    expect(find.text(t.notifications.focusHeader), findsOneWidget);
    expect(find.text(t.notifications.focusMode), findsOneWidget);
    expect(_switchFor(t.notifications.focusMode), findsOneWidget);
  });

  testWidgets('the row is the first thing on the screen, above what it mutes',
      (tester) async {
    // A person whose reminders stopped opens THIS screen. The switch that
    // explains the silence has to be above the switches it is overriding, not
    // under them.
    await _pumpNotificationSettings(tester);

    final focus = tester.getTopLeft(find.text(t.notifications.focusMode)).dy;
    final reminders =
        tester.getTopLeft(find.text(t.notifications.habitReminders)).dy;
    expect(focus, lessThan(reminders));
  });

  testWidgets('a value synced in from the Mac renders as ON', (tester) async {
    // This is the case that had no cure before: the Mac silenced the phone.
    final (container, _) = await _pumpNotificationSettings(
      tester,
      storedSynced: {'pref_focus_mode': '1'},
    );

    expect(container.read(settingsProvider).focusMode, isTrue);
    expect(
      tester.widget<EvolveSwitch>(_switchFor(t.notifications.focusMode)).value,
      isTrue,
    );
  });

  testWidgets('the phone can turn a Mac-set Focus Mode back off', (
    tester,
  ) async {
    final (container, fake) = await _pumpNotificationSettings(
      tester,
      storedSynced: {'pref_focus_mode': '1'},
    );

    // Turning it OFF re-schedules the briefs for real, so this one needs the
    // iOS plugin branch.
    await _asIos(() async {
      await tester.tap(_switchFor(t.notifications.focusMode));
      await tester.pumpAndSettle();
    });

    expect(container.read(settingsProvider).focusMode, isFalse);
    // ...and the OFF travels back, rather than being a local-only escape hatch
    // that the next sync would undo.
    expect(
      fake.syncedWrites.last,
      containsPair('pref_focus_mode', '0'),
    );
  });

  testWidgets('turning it on persists through the per-key synced store', (
    tester,
  ) async {
    final (container, fake) = await _pumpNotificationSettings(tester);

    await tester.tap(_switchFor(t.notifications.focusMode));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).focusMode, isTrue);
    expect(fake.syncedWrites.last, containsPair('pref_focus_mode', '1'));
    // One toggle, one key: the write must not drag the rest of the settings
    // along (see settings_clobber_test).
    expect(fake.syncedWrites.last.keys, ['pref_focus_mode']);
  });

  testWidgets('with Focus Mode on, the reminder sync cancels and stops', (
    tester,
  ) async {
    final (container, _) = await _pumpNotificationSettings(tester);
    final before = notifications.cancelAllCount;

    await tester.tap(_switchFor(t.notifications.focusMode));
    await tester.pumpAndSettle();

    // The toggle drives a notification re-sync, which cancels everything and —
    // because focus mode is now on — schedules nothing back.
    expect(notifications.cancelAllCount, greaterThan(before));
    expect(container.read(settingsProvider).focusMode, isTrue);
  });
}
