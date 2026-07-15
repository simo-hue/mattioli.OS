// iCloud Sync card in Settings → Privacy (P6 of desktop/ICLOUD_SYNC_PLAN.md):
// shown only in Private mode (tests run on macOS, so the platform gate is on),
// enable flows through the E2E disclosure dialog, cancel leaves sync off, the
// status line maps the service state, and delete-private-data becomes a full
// reset (requestFullReset before the local wipe) with the multi-device note.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_sync_service.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSyncService implements PrivateSyncService {
  _FakeSyncService([PrivateSyncStatus? initial])
      : current = initial ??
            const PrivateSyncStatus(
                isAvailable: true,
                isEnabled: false,
                account: CloudAccountStatus.available);

  PrivateSyncStatus current;
  int enableCalls = 0;
  int disableCalls = 0;
  int syncNowCalls = 0;
  int fullResetCalls = 0;

  @override
  Future<PrivateSyncStatus> status() async => current;

  @override
  Future<PrivateSyncStatus> probe() async => current;

  @override
  Future<PrivateSyncStatus> enable() async {
    enableCalls++;
    current = PrivateSyncStatus(
      isAvailable: true,
      isEnabled: true,
      account: CloudAccountStatus.available,
      lastSyncedAt: DateTime.utc(2026, 7, 6, 12),
    );
    return current;
  }

  @override
  Future<PrivateSyncStatus> disable() async {
    disableCalls++;
    current = const PrivateSyncStatus(
        isAvailable: true,
        isEnabled: false,
        account: CloudAccountStatus.available);
    return current;
  }

  @override
  Future<PrivateSyncStatus> syncNow() async {
    syncNowCalls++;
    return current;
  }

  @override
  Future<PrivateSyncStatus> requestFullReset() async {
    fullResetCalls++;
    current = const PrivateSyncStatus(
        isAvailable: true,
        isEnabled: false,
        account: CloudAccountStatus.available);
    return current;
  }
}

/// Pumps the settings page in Private mode with [fake] as the sync service and
/// navigates to the Privacy section.
Future<void> _pumpPrivacy(WidgetTester tester, _FakeSyncService fake) async {
  SharedPreferences.setMockInitialValues({
    'active_data_mode': DesktopDataMode.private.name,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      desktopPrivateSyncServiceProvider.overrideWithValue(fake),
    ],
  );
  addTearDown(container.dispose);

  await tester.binding.setSurfaceSize(const Size(1440, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          theme: EvolveTheme.dark(EvolveColors.primaryStrong),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en')],
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(t.settingsPage.sectionPrivacy).first);
  await tester.pumpAndSettle();
}

/// The enable toggle = the kit EvolveSwitch inside the row titled with
/// enableTitle (the row's ListTile itself has no onTap).
Finder _syncToggle() => find.descendant(
      of: find.widgetWithText(ListTile, t.icloudSync.enableTitle),
      matching: find.byType(EvolveSwitch),
    );

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('privacy section shows the iCloud Sync card in private mode',
      (tester) async {
    await _pumpPrivacy(tester, _FakeSyncService());

    expect(find.text(t.icloudSync.enableTitle), findsOneWidget);
    expect(find.text(t.icloudSync.syncNow), findsOneWidget);
    expect(find.text(t.icloudSync.statusOff), findsOneWidget);
    expect(find.text(t.icloudSync.lastSyncedNever), findsOneWidget);
  });

  testWidgets('enabling flows through the disclosure dialog', (tester) async {
    final fake = _FakeSyncService();
    await _pumpPrivacy(tester, fake);

    await tester.tap(_syncToggle());
    await tester.pumpAndSettle();
    expect(find.text(t.icloudSync.disclosureTitle), findsOneWidget);
    expect(fake.enableCalls, 0, reason: 'not before the user accepts');

    await tester.tap(find.text(t.settingsPage.confirm));
    await tester.pumpAndSettle();

    expect(fake.enableCalls, 1);
    expect(find.text(t.icloudSync.statusIdle), findsOneWidget);
    expect(find.textContaining('Last synced'), findsOneWidget);
  });

  testWidgets('cancelling the disclosure leaves sync off', (tester) async {
    final fake = _FakeSyncService();
    await _pumpPrivacy(tester, fake);

    await tester.tap(_syncToggle());
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settingsPage.cancel));
    await tester.pumpAndSettle();

    expect(fake.enableCalls, 0);
    expect(find.text(t.icloudSync.statusOff), findsOneWidget);
  });

  testWidgets('waiting-for-keychain state surfaces the iPhone-update hint',
      (tester) async {
    final fake = _FakeSyncService(
      const PrivateSyncStatus(
        isAvailable: true,
        isEnabled: true,
        account: CloudAccountStatus.available,
        hasKey: false,
      ),
    );
    await _pumpPrivacy(tester, fake);

    expect(find.text(t.icloudSync.statusWaitingKeychain), findsOneWidget);
  });

  testWidgets(
      'delete private data runs the full sync reset and mentions the '
      'multi-device caveat', (tester) async {
    final fake = _FakeSyncService(
      const PrivateSyncStatus(
          isAvailable: true,
          isEnabled: true,
          account: CloudAccountStatus.available),
    );
    await _pumpPrivacy(tester, fake);

    await tester.ensureVisible(find.text(t.settingsPage.deletePrivateData));
    await tester.tap(find.text(t.settingsPage.deletePrivateData));
    await tester.pumpAndSettle();

    // The confirm dialog carries the sync caveat when sync is enabled.
    expect(find.textContaining('run this on each device'), findsOneWidget);

    await tester.tap(find.text(t.settingsPage.confirm));
    await tester.pumpAndSettle();

    expect(fake.fullResetCalls, 1,
        reason: 'cloud wipe queued/performed before the local wipe');
  });
}
