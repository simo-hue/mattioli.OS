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
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'support/settings_navigation.dart';

class _FakeSyncService implements PrivateSyncService {
  _FakeSyncService([PrivateSyncStatus? initial, this.diagnosticsResult])
    : current =
          initial ??
          const PrivateSyncStatus(
            isAvailable: true,
            isEnabled: false,
            account: CloudAccountStatus.available,
          );

  /// Null ⇒ no local store to inspect, which must HIDE the details row rather
  /// than render it claiming everything is fine.
  final SyncDiagnostics? diagnosticsResult;

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
  Future<PrivateSyncStatus> enable({bool force = false}) async {
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
      account: CloudAccountStatus.available,
    );
    return current;
  }

  @override
  Future<PrivateSyncStatus> syncNow({String reason = 'manual'}) async {
    syncNowCalls++;
    return current;
  }

  @override
  Future<PrivateSyncStatus> requestFullReset() async {
    fullResetCalls++;
    current = const PrivateSyncStatus(
      isAvailable: true,
      isEnabled: false,
      account: CloudAccountStatus.available,
    );
    return current;
  }

  @override
  Future<SyncDiagnostics?> diagnostics() async => diagnosticsResult;

  int resetCalls = 0;

  @override
  Future<PrivateSyncStatus> resetSyncFromThisDevice() async {
    resetCalls++;
    return current;
  }

  @override
  Future<T> runExclusive<T>(Future<T> Function() action) => action();
}

/// A snapshot with [pending] macro goals stranded — the shape of the reported
/// bug (habits through, `long_term_goals` not).
SyncDiagnostics _diagnostics({
  int pending = 0,
  int errors = 0,
  int parked = 0,
}) => SyncDiagnostics(
  localRowsByTable: {'goals': 12, 'long_term_goals': pending},
  pendingByTable: pending > 0 ? {'long_term_goals': pending} : const {},
  pendingDeletesByTable: const {},
  errorsByReason: errors > 0 ? {'CKError 7 rate limited': errors} : const {},
  parkedByReason: parked > 0 ? {'row rejected by schema': parked} : const {},
  hasChangeToken: true,
  lastFullSyncAt: DateTime.utc(2026, 7, 20, 9),
);

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
  await openSettingsSection(tester, SettingsSection.dataBackup);
}

/// The enable toggle = the kit EvolveSwitch inside the row titled with
/// enableTitle (the row's ListTile itself has no onTap).
Finder _syncToggle() => find.descendant(
  of: find.widgetWithText(ListTile, t.icloudSync.enableTitle),
  matching: find.byType(EvolveSwitch),
);

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.en));

  testWidgets('privacy section shows the iCloud Sync card in private mode', (
    tester,
  ) async {
    await _pumpPrivacy(tester, _FakeSyncService());

    expect(find.text(t.icloudSync.enableTitle), findsOneWidget);
    expect(find.text(t.icloudSync.syncNow), findsOneWidget);
    expect(find.text(t.icloudSync.statusOff), findsOneWidget);
    // Was `lastSyncedNever`. "Sync now" is disabled while sync is off — it
    // used to render fully tappable and then return early in exactly this
    // state — so its help slot states the reason instead.
    expect(find.text(t.icloudSync.syncNowNeedsSync), findsOneWidget);
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

  testWidgets('waiting-for-keychain state surfaces the iPhone-update hint', (
    tester,
  ) async {
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

  testWidgets('delete private data runs the full sync reset and mentions the '
      'multi-device caveat', (tester) async {
    final fake = _FakeSyncService(
      const PrivateSyncStatus(
        isAvailable: true,
        isEnabled: true,
        account: CloudAccountStatus.available,
      ),
    );
    await _pumpPrivacy(tester, fake);

    await tester.ensureVisible(find.text(t.settingsPage.deletePrivateData));
    await tester.tap(find.text(t.settingsPage.deletePrivateData));
    await tester.pumpAndSettle();

    // The confirm dialog carries the sync caveat when sync is enabled.
    expect(find.textContaining('run this on each device'), findsOneWidget);

    await tester.tap(find.text(t.settingsPage.confirm));
    // Confirm shows an (indefinite) loading spinner and then runs the REAL
    // on-device wipe — DesktopPrivateDb + notification re-sync — which are hard
    // singletons that can't complete in the headless harness (and whose logic is
    // covered by sync_bookkeeping_test / the DB tests). So we don't pumpAndSettle
    // (the spinner never settles); we pump a few frames to let requestFullReset()
    // run — it's awaited BEFORE the local wipe — and assert the card's contract:
    // the cloud reset is queued/performed ahead of the local wipe.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(
      fake.fullResetCalls,
      1,
      reason: 'cloud wipe queued/performed before the local wipe',
    );
  });

  testWidgets('the details row reports stranded records', (tester) async {
    // The reported bug on the receiving Mac: sync ran, "last synced" looks
    // healthy, and the macro goals never arrived.
    final fake = _FakeSyncService(
      const PrivateSyncStatus(
        isAvailable: true,
        isEnabled: true,
        account: CloudAccountStatus.available,
      ),
      _diagnostics(pending: 5000),
    );
    await _pumpPrivacy(tester, fake);
    // The sync report moved to Advanced, beside App Logs.
    await openSettingsSection(tester, SettingsSection.advanced);

    expect(find.text(t.icloudSync.detailsTitle), findsOneWidget);
    expect(find.text(t.icloudSync.detailsPending(count: 5000)), findsOneWidget);
  });

  testWidgets('the details row is hidden when there is no store to inspect', (
    tester,
  ) async {
    final fake = _FakeSyncService(
      const PrivateSyncStatus(
        isAvailable: true,
        isEnabled: true,
        account: CloudAccountStatus.available,
      ),
    );
    await _pumpPrivacy(tester, fake);
    await openSettingsSection(tester, SettingsSection.advanced);

    expect(find.text(t.icloudSync.detailsTitle), findsNothing);
  });

  // A1. `last_full_sync_at` was stamped even when every record in a push had
  // failed, and this status line read it straight out and said "Up to date".
  // `SyncDiagnostics.isFullySynced` is documented as the ONLY condition under
  // which a UI may make that claim.
  group('the status line must not claim "Up to date" over stranded rows', () {
    const healthy = PrivateSyncStatus(
      isAvailable: true,
      isEnabled: true,
      account: CloudAccountStatus.available,
    );

    testWidgets('a pending backlog is never reported as "Up to date"', (
      tester,
    ) async {
      final fake = _FakeSyncService(healthy, _diagnostics(pending: 5000));
      await _pumpPrivacy(tester, fake);

      expect(
        find.text(t.icloudSync.statusIdle),
        findsNothing,
        reason: '5000 macro goals never left the device',
      );
      expect(find.text(t.icloudSync.statusNotSynced), findsOneWidget);
    });

    testWidgets('records that FAILED to upload are never reported as '
        '"Up to date"', (tester) async {
      final fake = _FakeSyncService(healthy, _diagnostics(errors: 3));
      await _pumpPrivacy(tester, fake);

      expect(find.text(t.icloudSync.statusIdle), findsNothing);
      expect(find.text(t.icloudSync.statusNotSynced), findsOneWidget);
    });

    testWidgets('records PARKED forever are never reported as "Up to date"', (
      tester,
    ) async {
      final fake = _FakeSyncService(healthy, _diagnostics(parked: 2));
      await _pumpPrivacy(tester, fake);

      expect(
        find.text(t.icloudSync.statusIdle),
        findsNothing,
        reason: 'nothing will retry a parked record on its own',
      );
    });

    testWidgets('"Up to date" still shows when genuinely nothing is stranded', (
      tester,
    ) async {
      final fake = _FakeSyncService(healthy, _diagnostics());
      await _pumpPrivacy(tester, fake);

      expect(
        find.text(t.icloudSync.statusIdle),
        findsOneWidget,
        reason: 'the fix must not be a blanket refusal to report success',
      );
    });
  });

  // The receiving side of a key split: records in iCloud were sealed with a
  // different E2E key, so this device cannot read them. Mobile has covered this
  // for a while; desktop's key-split card + status override had no test at all,
  // so a settings_page refactor could silently drop the only Mac-side recovery
  // affordance and reintroduce the invisible "data just missing" failure.
  group('a key split surfaces the warning and the recovery action', () {
    const split = PrivateSyncStatus(
      isAvailable: true,
      isEnabled: true,
      account: CloudAccountStatus.available,
      undecryptableCount: 3485,
    );

    testWidgets('the status line names the split instead of "Up to date"', (
      tester,
    ) async {
      await _pumpPrivacy(tester, _FakeSyncService(split));

      expect(find.text(t.icloudSync.keySplitTitle), findsOneWidget);
      expect(
        find.text(t.icloudSync.statusIdle),
        findsNothing,
        reason: 'no amount of syncing makes an unreadable record readable',
      );
      expect(
        find.text(t.icloudSync.resetFromDevice),
        findsOneWidget,
        reason: 'the reset-from-this-device recovery row must be offered',
      );
    });

    testWidgets('the reset row runs resetSyncFromThisDevice after confirming', (
      tester,
    ) async {
      final fake = _FakeSyncService(split);
      await _pumpPrivacy(tester, fake);

      await tester.ensureVisible(find.text(t.icloudSync.resetFromDevice));
      await tester.tap(find.text(t.icloudSync.resetFromDevice));
      await tester.pumpAndSettle();

      // Destructive: nothing runs until the user accepts the confirmation.
      expect(
        find.textContaining('erases everything currently stored in iCloud'),
        findsOneWidget,
      );
      expect(fake.resetCalls, 0);

      await tester.tap(find.text(t.settingsPage.confirm));
      await tester.pumpAndSettle();

      expect(
        fake.resetCalls,
        1,
        reason: 'the iPhone-authoritative zone re-key must actually run',
      );
    });
  });
}
