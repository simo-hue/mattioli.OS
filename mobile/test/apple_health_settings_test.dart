import 'dart:convert';
import 'dart:io';

// Guideline 2.5.1: "The app uses the HealthKit or CareKit APIs but does not
// clearly identify the HealthKit and CareKit functionality in the app's user
// interface."
//
// Before this, the ONLY mention of Health anywhere in the app was a button three
// levels deep inside the habit-creation modal, behind an Auto-verify switch that
// defaults off — and it hid itself permanently once tapped. Identification that
// can evaporate is not identification, and a reviewer who taps once can never
// see it again.
//
// So the properties worth pinning are about the surface being UNCONDITIONAL, not
// about how it looks: it must render with no habits, no permission ever
// requested, and on a device with no Health data at all.
import 'package:evolve_verification/evolve_verification.dart';
import 'package:evolve_verification/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/core/verification_providers.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/app_settings_screen.dart';
import 'package:mattioli_os/ui/widgets/apple_health_form.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_private_data_store.dart';

class _NoopNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancelAll() async {}
}

Future<FakeHealthKitBridge> _pumpSettings(
  WidgetTester tester, {
  bool healthAvailable = true,
  Set<String> alreadyRequested = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'active_data_mode': 'private',
    if (alreadyRequested.isNotEmpty)
      HealthAuthRequestedTypesNotifier.prefsKey: alreadyRequested.toList(),
  });
  final prefs = await SharedPreferences.getInstance();
  final bridge = FakeHealthKitBridge(available: healthAvailable);

  await tester.binding.setSurfaceSize(const Size(500, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith((ref) => FakePrivateDataStore()),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
        healthKitBridgeProvider.overrideWithValue(bridge),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const AppSettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return bridge;
}

Iterable<String> _visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data)
    .whereType<String>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
  });

  testWidgets('Settings identifies Apple Health with no habits and no permission', (
    tester,
  ) async {
    await _pumpSettings(tester);

    // Two taps from launch: Settings, then this. Nothing to create first.
    expect(find.text(t.settings.sections.appleHealth), findsOneWidget);
    expect(find.text(t.health.rowTitle), findsOneWidget);
    // Never claims a connection iOS refuses to report.
    expect(find.text(t.health.statusNotConnected), findsOneWidget);
  });

  testWidgets('the section does not hide once permission has been requested', (
    tester,
  ) async {
    // The old habit-modal button vanished for good after one tap, so a reviewer
    // replaying a build could never find it again. This one must not.
    await _pumpSettings(
      tester,
      alreadyRequested: {'stepCount', 'appleExerciseTime', 'sleepAnalysis'},
    );

    expect(find.text(t.settings.sections.appleHealth), findsOneWidget);
    expect(find.text(t.health.rowTitle), findsOneWidget);
    expect(find.text(t.health.statusConnected), findsOneWidget);
  });

  testWidgets('a device with no Health data says so instead of looking broken', (
    tester,
  ) async {
    // The reviewer was on an iPad Air. Every metric we read is recorded by an
    // iPhone or a Watch, so without one they all come back empty — the feature
    // looks broken rather than inapplicable.
    await _pumpSettings(tester, healthAvailable: false);

    expect(find.text(t.settings.sections.appleHealth), findsOneWidget);
    expect(find.text(t.health.statusUnavailable), findsOneWidget);

    await tester.tap(find.text(t.health.rowTitle));
    await tester.pumpAndSettle();
    expect(find.text(t.health.noData(app: t.health.appName)), findsOneWidget);
  });

  testWidgets('the sheet names every metric the app can read', (tester) async {
    await _pumpSettings(tester);
    await tester.tap(find.text(t.health.rowTitle));
    await tester.pumpAndSettle();

    // Derived from the same catalog the habit editor offers, so the disclosure
    // cannot drift from what we actually request.
    final healthKitTemplates =
        VerificationCatalog.all.where((x) => x.isHealthKit).toList();
    expect(healthKitTemplates, hasLength(8));
    expect(AppleHealthForm.readTemplates, healthKitTemplates);

    // Every one is named on screen, so adding a ninth metric to the catalog
    // cannot silently go undisclosed.
    for (final template in healthKitTemplates) {
      expect(
        AppleHealthForm.readTemplates, contains(template),
        reason: '${template.key} is read but not listed in the disclosure',
      );
    }

    expect(find.text(t.health.readsTitle), findsOneWidget);
    expect(
      find.text(t.health.readOnly(app: t.health.appName)),
      findsOneWidget,
      reason: 'read-only is the claim that makes the write-permission removal true',
    );
  });

  testWidgets('Allow access requests every readable type at once', (tester) async {
    final bridge = await _pumpSettings(tester);
    await tester.tap(find.text(t.health.rowTitle));
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.health.allowAccess));
    await tester.pumpAndSettle();

    expect(bridge.authorizationRequests, hasLength(1));
    expect(
      bridge.authorizationRequests.single,
      containsAll(<String>{'stepCount', 'appleExerciseTime', 'sleepAnalysis'}),
      reason: 'one prompt for the whole feature, not one per habit',
    );
  });

  testWidgets('the rendered sheet never says HealthKit', (tester) async {
    // The HIG is explicit: "Don't use the term HealthKit. HealthKit is a
    // developer-facing term." Apple's own rejection letter uses it; we must not
    // echo it back. This covers what renders; the i18n test below covers every
    // string in every locale, including ones this screen never shows.
    await _pumpSettings(tester);
    await tester.tap(find.text(t.health.rowTitle));
    await tester.pumpAndSettle();

    for (final s in _visibleText(tester)) {
      expect(
        s.toLowerCase(),
        isNot(contains('healthkit')),
        reason: 'user-visible copy names a developer-facing term: "$s"',
      );
    }
  });

  test('no locale ships the word HealthKit, and each names Health as Apple does', () {
    // Asserted against the i18n source rather than a pumped widget: slang
    // lazy-loads locales (setLocaleSync throws _DeferredNotLoadedError for ar),
    // and rendering only ever proves the handful of strings a screen happens to
    // show. The files are the source of truth.
    //
    // Apple's own localized name for the Health app, verified against Apple's
    // per-locale iPhone User Guide. The HIG says "Use the system-provided
    // translation of Health", so this differs per locale and is never built as
    // "Apple " + a translated word — there is no "Apple Salute".
    const expectedAppName = {
      'en': 'Apple Health',
      'it': 'Salute',
      'es': 'Salud',
      // Apple never translated the app name into German: its German user guide
      // says App „Health" throughout and App „Gesundheit" nowhere.
      'de': 'Apple Health',
      // NOT الصحة, which is what we shipped — Apple's Arabic Health app is صحتي.
      'ar': 'صحتي',
    };

    for (final entry in expectedAppName.entries) {
      final file = File('lib/i18n/${entry.key}.i18n.json');
      expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
      final raw = file.readAsStringSync();

      expect(
        raw.toLowerCase(),
        isNot(contains('healthkit')),
        reason: '${entry.key}.i18n.json ships a developer-facing term',
      );

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final health = json['health'] as Map<String, dynamic>;
      expect(
        health['appName'],
        entry.value,
        reason: 'the ${entry.key} copy must name Health the way Apple does',
      );
    }
  });
}
