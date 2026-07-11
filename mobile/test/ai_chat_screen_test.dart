// Regression test for the AI Coach screen (Bug 2).
//
// `_AIChatScreenState.initState()` used to seed the first message via
// `_addInitialMessages()`, which reads `context.t` — the slang translations
// InheritedWidget (`InheritedLocaleData<AppLocale, Translations>`). Reading an
// inherited widget during `initState` is illegal in Flutter and threw:
//   "dependOnInheritedWidgetOfExactType<InheritedLocaleData<...>>() ... was
//    called before _AIChatScreenState.initState() completed."
// so the screen crashed the moment it was opened. The seeding now runs from
// `didChangeDependencies` (guarded to run exactly once), where inherited lookups
// are legal, so the screen builds cleanly and shows the seeded greeting.

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
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/ai_chat_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'support/fake_private_data_store.dart';

/// No-op notifications platform so any provider that transitively touches the
/// notifications plugin doesn't explode on the unset instance. See the same
/// shim in `settings_separation_test.dart` / `icloud_sync_screen_test.dart`.
class _NoopNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancelAll() async {}
}

/// Pumps [AIChatScreen] in Private mode so the goal/habit/profile providers load
/// from the faked on-device store and never reach for Supabase.
Future<void> _pumpChat(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith(
          (ref) => FakePrivateDataStore(),
        ),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const AIChatScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    LocaleSettings.setLocaleSync(AppLocale.en);
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
  });

  testWidgets('opens without throwing and seeds the coach greeting',
      (tester) async {
    await _pumpChat(tester);

    // The old initState() inherited-widget read threw here; the fix makes this
    // a clean build.
    expect(tester.takeException(), isNull);
    expect(find.byType(AIChatScreen), findsOneWidget);
    // Greeting is seeded from didChangeDependencies and rendered via Markdown.
    expect(
      find.textContaining('Discipline Coach', findRichText: true),
      findsWidgets,
    );
  });
}
