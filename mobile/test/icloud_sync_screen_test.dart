// Widget test for the iCloud Sync settings screen (Private Mode, iOS-only).
//
// Drives the screen against a fake [PrivateSyncService] so we can assert the
// UI wiring without a device: it renders the title, the enable toggle shows the
// end-to-end-encryption disclosure and (on confirm) calls `enable`, "Sync now"
// calls `syncNow`, and the status line reflects enabled/account state.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/core/private_sync_service.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/icloud_sync_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'support/fake_private_data_store.dart';

/// No-op notifications platform so building `settingsProvider` (which haptics
/// reads) doesn't explode on the unset plugin instance. See the same shim in
/// `settings_separation_test.dart` for the rationale.
class _NoopNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancelAll() async {}
}

/// In-memory [PrivateSyncService]: records each method call and returns a
/// configurable status. `enable`/`disable`/`syncNow` flip the status so the UI
/// reflects the change after the action settles.
class FakePrivateSyncService implements PrivateSyncService {
  FakePrivateSyncService({
    bool isAvailable = true,
    bool isEnabled = false,
    DateTime? lastSyncedAt,
    CloudAccountStatus? account = CloudAccountStatus.available,
    this.throwOnStatus = false,
    this.throwOnAction = false,
    this.diagnosticsResult,
    this.deferEnable = false,
    int undecryptableCount = 0,
  }) : _status = PrivateSyncStatus(
          isAvailable: isAvailable,
          isEnabled: isEnabled,
          lastSyncedAt: lastSyncedAt,
          account: account,
          undecryptableCount: undecryptableCount,
        );

  /// Models the key-mint guard firing: enable() refuses and reports keyPending.
  final bool deferEnable;

  /// When set, `status()` throws — simulates a Keychain/DB hiccup that must be
  /// swallowed rather than escaping as an unhandled async error (the reported
  /// crash class).
  final bool throwOnStatus;

  /// When set, `syncNow`/`enable`/`disable` throw — simulates a CloudKit/network
  /// failure mid-action, which the screen must catch (not crash on).
  final bool throwOnAction;

  PrivateSyncStatus _status;
  final List<String> calls = [];

  PrivateSyncStatus _copyWith({
    bool? isEnabled,
    DateTime? lastSyncedAt,
    bool keyPending = false,
  }) {
    return PrivateSyncStatus(
      isAvailable: _status.isAvailable,
      isEnabled: isEnabled ?? _status.isEnabled,
      lastSyncedAt: lastSyncedAt ?? _status.lastSyncedAt,
      account: _status.account,
      message: _status.message,
      keyPending: keyPending,
      undecryptableCount: _status.undecryptableCount,
    );
  }

  @override
  Future<PrivateSyncStatus> status() async {
    calls.add('status');
    if (throwOnStatus) throw StateError('status boom');
    return _status;
  }

  @override
  Future<PrivateSyncStatus> probe() async {
    calls.add('probe');
    return _status;
  }

  @override
  Future<PrivateSyncStatus> enable({bool force = false}) async {
    calls.add(force ? 'enable(force)' : 'enable');
    if (force) forceEnableCalls++;
    if (throwOnAction) throw StateError('enable boom');
    // A non-forced enable against a zone this device has no key for DEFERS.
    if (deferEnable && !force) {
      _status = _copyWith(isEnabled: false, keyPending: true);
      return _status;
    }
    _status = _copyWith(
      isEnabled: true,
      lastSyncedAt: DateTime.utc(2026, 6, 23, 10, 30),
    );
    return _status;
  }

  @override
  Future<PrivateSyncStatus> disable() async {
    calls.add('disable');
    if (throwOnAction) throw StateError('disable boom');
    _status = _copyWith(isEnabled: false);
    return _status;
  }

  @override
  Future<PrivateSyncStatus> syncNow() async {
    calls.add('syncNow');
    if (throwOnAction) throw StateError('syncNow boom');
    _status = _copyWith(lastSyncedAt: DateTime.utc(2026, 6, 23, 11, 0));
    return _status;
  }

  @override
  Future<PrivateSyncStatus> requestFullReset() async {
    calls.add('requestFullReset');
    _status = _copyWith(isEnabled: false);
    return _status;
  }

  /// Null ⇒ no local store to inspect, which must HIDE the details row rather
  /// than render it empty.
  final SyncDiagnostics? diagnosticsResult;

  int forceEnableCalls = 0;
  int resetCalls = 0;

  @override
  Future<PrivateSyncStatus> resetSyncFromThisDevice() async {
    calls.add('resetSyncFromThisDevice');
    resetCalls++;
    return _status;
  }

  @override
  Future<SyncDiagnostics?> diagnostics() async {
    calls.add('diagnostics');
    return diagnosticsResult;
  }

  @override
  Future<T> runExclusive<T>(Future<T> Function() action) => action();
}

/// A diagnostics snapshot with [pending] macro goals stranded — the shape of
/// the reported bug (habits through, `long_term_goals` not).
SyncDiagnostics _diagnostics({
  int pending = 0,
  int errors = 0,
  int parked = 0,
}) =>
    SyncDiagnostics(
      localRowsByTable: {'goals': 12, 'long_term_goals': pending},
      pendingByTable: pending > 0 ? {'long_term_goals': pending} : const {},
      pendingDeletesByTable: const {},
      errorsByReason:
          errors > 0 ? {'CKError 7 rate limited': errors} : const {},
      parkedByReason: parked > 0 ? {'row rejected by schema': parked} : const {},
      hasChangeToken: true,
      lastFullSyncAt: DateTime.utc(2026, 7, 20, 9),
    );

Future<void> _pumpScreen(
  WidgetTester tester,
  FakePrivateSyncService fake, {
  bool settle = true,
}) async {
  // Private mode: `authProvider`/`settingsProvider` (read by `ref.hapticLight`)
  // short-circuit without Supabase, and the on-device store is faked.
  SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateSyncServiceProvider.overrideWithValue(fake),
        privateLocalDatabaseProvider.overrideWith(
          (ref) => FakePrivateDataStore(),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const IcloudSyncScreen(),
        ),
      ),
    ),
  );
  if (settle) {
    // Let the initState status() future resolve.
    await tester.pumpAndSettle();
  } else {
    // The status() future fails/hangs (screen stays on an infinite loading
    // spinner), so pumpAndSettle would time out. Pump fixed frames instead and
    // advance past AppLogger's 2s debounce so no timer outlives the test.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
  }
}

/// Runs [body] with the target platform forced to iOS for its whole duration.
///
/// Tapping an action reads `settingsProvider` (via `ref.hapticLight`), whose
/// async private load schedules notifications. The plugin's `zonedSchedule`
/// hard-`!`s the Android branch but is null-safe on iOS, so we keep the
/// override active across the entire body — then reset it before the body
/// returns so `testWidgets`' foundation-vars invariant check passes.
Future<void> _withIosPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    LocaleSettings.setLocaleSync(AppLocale.en);
    // `settingsProvider` build (read transitively by `ref.hapticLight`) touches
    // the notifications plugin; keep that plumbing from throwing.
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
  });

  testWidgets('renders the title and loads initial status', (tester) async {
    await _withIosPlatform(() async {
      final fake = FakePrivateSyncService();
      await _pumpScreen(tester, fake);

      expect(find.text('iCloud Sync'), findsOneWidget);
      expect(find.text('Enable iCloud Sync'), findsOneWidget);
      expect(fake.calls, contains('status'));
      // Sync is off by default -> "Sync is off" status line.
      expect(find.text('Sync is off'), findsOneWidget);
    });
  });

  testWidgets('enabling shows the disclosure and confirming calls enable',
      (tester) async {
    await _withIosPlatform(() async {
      final fake = FakePrivateSyncService();
      await _pumpScreen(tester, fake);

      // Flip the switch ON.
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();

      // Disclosure dialog appears.
      expect(find.text('End-to-end encrypted'), findsWidgets);
      expect(fake.calls, isNot(contains('enable')));

      // Confirm via the "Enable" button.
      await tester.tap(find.text('Enable'));
      await tester.pumpAndSettle();

      expect(fake.calls, contains('enable'));
      // Status flips to "Up to date" once enabled + available.
      expect(find.text('Up to date'), findsOneWidget);
    });
  });

  testWidgets('cancelling the disclosure does not enable', (tester) async {
    await _withIosPlatform(() async {
      final fake = FakePrivateSyncService();
      await _pumpScreen(tester, fake);

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fake.calls, isNot(contains('enable')));
      expect(find.text('Sync is off'), findsOneWidget);
    });
  });

  testWidgets('Sync now calls syncNow when enabled and available',
      (tester) async {
    await _withIosPlatform(() async {
      final fake = FakePrivateSyncService(
        isEnabled: true,
        lastSyncedAt: DateTime.utc(2026, 6, 20, 9, 0),
      );
      await _pumpScreen(tester, fake);

      expect(find.text('Up to date'), findsOneWidget);

      await tester.tap(find.text('Sync now'));
      await tester.pumpAndSettle();

      expect(fake.calls, contains('syncNow'));
    });
  });

  testWidgets('status reflects a missing iCloud account', (tester) async {
    await _withIosPlatform(() async {
      final fake = FakePrivateSyncService(
        isEnabled: true,
        account: CloudAccountStatus.noAccount,
      );
      await _pumpScreen(tester, fake);

      expect(find.text('Sign in to iCloud to sync'), findsOneWidget);
    });
  });

  testWidgets('a failing status() on load is swallowed (no crash)',
      (tester) async {
    await _withIosPlatform(() async {
      // initState -> _refresh() -> status() throws. Before the guard this was an
      // unhandled async error at the global handler; now it is caught.
      final fake = FakePrivateSyncService(throwOnStatus: true);
      await _pumpScreen(tester, fake, settle: false);

      expect(tester.takeException(), isNull);
      // The screen stays on the loading state rather than crashing.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  testWidgets('a failing sync action is caught and does not crash',
      (tester) async {
    await _withIosPlatform(() async {
      // Action throws (CloudKit/network), then the catch-path refresh runs.
      // Neither must escape as an unhandled exception.
      final fake = FakePrivateSyncService(isEnabled: true, throwOnAction: true);
      await _pumpScreen(tester, fake);

      await tester.tap(find.text('Sync now'));
      await tester.pump(); // start the async action + its rejection
      await tester.pump(const Duration(seconds: 3)); // catch + refresh + logger

      expect(tester.takeException(), isNull);
      expect(fake.calls, contains('syncNow'));
      // Still on the screen (its title is present).
      expect(find.text('iCloud Sync'), findsOneWidget);
    });
  });

  group('sync details', () {
    testWidgets('reports stranded records instead of only "Up to date"',
        (tester) async {
      await _withIosPlatform(() async {
        // The reported bug: sync ran, the status line says it is fine, and
        // thousands of macro goals never left the device.
        final fake = FakePrivateSyncService(
          isEnabled: true,
          lastSyncedAt: DateTime.utc(2026, 7, 20, 9),
          diagnosticsResult: _diagnostics(pending: 5000),
        );
        await _pumpScreen(tester, fake);

        expect(find.text('Sync details'), findsOneWidget);
        expect(find.text('5000 items waiting to upload'), findsOneWidget);
      });
    });

    testWidgets('failures outrank a pending count — retrying is not what is '
        'missing', (tester) async {
      await _withIosPlatform(() async {
        final fake = FakePrivateSyncService(
          isEnabled: true,
          diagnosticsResult: _diagnostics(pending: 10, errors: 3, parked: 2),
        );
        await _pumpScreen(tester, fake);

        expect(find.text('5 items failed to upload'), findsOneWidget);
        expect(find.text('10 items waiting to upload'), findsNothing);
      });
    });

    testWidgets('claims everything is uploaded only when nothing is stranded',
        (tester) async {
      await _withIosPlatform(() async {
        final fake = FakePrivateSyncService(
          isEnabled: true,
          diagnosticsResult: _diagnostics(),
        );
        await _pumpScreen(tester, fake);

        expect(find.text('Everything uploaded'), findsOneWidget);
      });
    });

    testWidgets('the row is hidden when there is no store to inspect',
        (tester) async {
      await _withIosPlatform(() async {
        // diagnostics() == null (no-op service / DB unopenable): showing a row
        // reading "Everything uploaded" here would be a lie.
        final fake = FakePrivateSyncService(isEnabled: true);
        await _pumpScreen(tester, fake);

        expect(find.text('Sync details'), findsNothing);
      });
    });

    testWidgets('the report names the table that is stuck', (tester) async {
      await _withIosPlatform(() async {
        final fake = FakePrivateSyncService(
          isEnabled: true,
          diagnosticsResult: _diagnostics(pending: 5000),
        );
        await _pumpScreen(tester, fake);

        await tester.tap(find.text('Sync details'));
        await tester.pumpAndSettle();

        // The per-table breakdown is the whole diagnostic value: an aggregate
        // count cannot tell you WHICH data never made it across.
        expect(find.textContaining('long_term_goals'), findsOneWidget);
      });
    });
  });

  group('key split', () {
    testWidgets('a key mismatch is never reported as "Up to date"',
        (tester) async {
      await _withIosPlatform(() async {
        // The failure that hid for weeks: sync runs, reports success, applies
        // nothing, because the zone was sealed with another device's key.
        final fake = FakePrivateSyncService(
          isEnabled: true,
          lastSyncedAt: DateTime.utc(2026, 7, 20, 9),
          undecryptableCount: 3485,
        );
        await _pumpScreen(tester, fake);

        expect(find.text("Some iCloud data can't be read"), findsWidgets);
        expect(find.text('Up to date'), findsNothing);
        expect(find.text('Reset sync from this device'), findsOneWidget);
      });
    });

    testWidgets('resetting requires an explicit confirmation', (tester) async {
      await _withIosPlatform(() async {
        final fake = FakePrivateSyncService(
          isEnabled: true,
          undecryptableCount: 10,
        );
        await _pumpScreen(tester, fake);

        await tester.tap(find.text('Reset sync from this device'));
        await tester.pumpAndSettle();
        // Destructive and unrecoverable — it must never fire on one tap.
        expect(fake.resetCalls, 0);
        expect(find.textContaining('erases everything'), findsOneWidget);
      });
    });

    testWidgets('confirming runs the reset', (tester) async {
      await _withIosPlatform(() async {
        final fake = FakePrivateSyncService(
          isEnabled: true,
          undecryptableCount: 10,
        );
        await _pumpScreen(tester, fake);

        await tester.tap(find.text('Reset sync from this device'));
        await tester.pumpAndSettle();
        // The confirm button carries the same label; take the dialog's copy.
        await tester.tap(find.text('Reset sync from this device').last);
        await tester.pumpAndSettle();

        expect(fake.resetCalls, 1);
        expect(fake.calls, contains('resetSyncFromThisDevice'));
      });
    });

    testWidgets('a deferred enable offers the start-fresh override rather than '
        'silently failing', (tester) async {
      await _withIosPlatform(() async {
        // The guard fired: the zone has data but this device has no key.
        final fake = FakePrivateSyncService(deferEnable: true);
        await _pumpScreen(tester, fake);

        await tester.tap(find.byType(CupertinoSwitch));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enable')); // disclosure
        await tester.pumpAndSettle();

        // Deferred, NOT enabled, and the user is told why + offered the way out.
        expect(find.text('Start fresh from this device'), findsOneWidget);
        expect(fake.forceEnableCalls, 0, reason: 'never automatic');
      });
    });

    testWidgets('start-fresh only mints after the user confirms it',
        (tester) async {
      await _withIosPlatform(() async {
        final fake = FakePrivateSyncService(deferEnable: true);
        await _pumpScreen(tester, fake);

        await tester.tap(find.byType(CupertinoSwitch));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enable'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start fresh'));
        await tester.pumpAndSettle();

        expect(fake.forceEnableCalls, 1);
        expect(fake.calls, contains('enable(force)'));
      });
    });
  });
}
