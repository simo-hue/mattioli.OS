// The AI Coach's "{app} isn't running / Start {app}" banner — and the 3-second
// localhost re-probe that keeps it fresh — keyed off the PERSISTED backend
// (`config.backend`) instead of the effective one.
//
// `effectiveCoachBackend` resolves to Standard in account mode: a stored
// Cloud/Local choice is preserved for a return to Private mode but does not
// serve there. So a user who configured Ollama in Private mode (or took the
// account-mode "Use local" nudge, which persists coach_backend='local') and
// then signed in got a permanent amber offline banner over a chat the Supabase
// proxy was answering perfectly — plus a localhost probe every 3 seconds for as
// long as the page stayed open.
//
// Both sibling banners already read `effectiveCoachBackendProvider`, and the
// provider's own doc says every gate must.
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/ai_coach/application/coach_controllers.dart';
import 'package:evolve_desktop/features/ai_coach/application/local_server_start_controller.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_config.dart';
import 'package:evolve_desktop/features/ai_coach/presentation/ai_coach_page.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseUrl = 'http://localhost:11434/v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => LocaleSettings.setLocale(AppLocale.it));

  /// Pumps the coach page with Ollama persisted as the backend and its server
  /// unreachable. [dataMode] decides whether that persisted choice is also the
  /// EFFECTIVE one. Returns a counter of localhost reachability probes.
  Future<int Function()> pumpCoach(
    WidgetTester tester, {
    required String dataMode,
  }) async {
    SharedPreferences.setMockInitialValues({
      'active_data_mode': dataMode,
      'coach_backend': CoachBackendKind.local.code,
      'coach_local_base_url': _baseUrl,
    });
    final prefs = await SharedPreferences.getInstance();

    var probes = 0;

    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localLauncherSupportedProvider.overrideWithValue(true),
          localAppInstalledProvider(
            LocalServerPreset.ollama,
          ).overrideWith((ref) async => true),
          coachLocalReachableProvider(_baseUrl).overrideWith((ref) async {
            probes++;
            return false; // server down
          }),
        ],
        child: MaterialApp(
          theme: EvolveTheme.dark(),
          home: const Scaffold(body: AiCoachPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => probes;
  }

  String offlineTitle() =>
      t.coachSettings.localServerOfflineTitle(app: 'Ollama');

  testWidgets(
    'account mode with a persisted local backend shows no offline banner',
    (tester) async {
      final probes = await pumpCoach(tester, dataMode: 'supabase');

      expect(
        find.text(offlineTitle()),
        findsNothing,
        reason:
            'the Supabase proxy is what actually answers here — the persisted '
            'local choice does not serve in account mode',
      );

      // …and the 3-second re-probe must stay idle too.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      expect(
        probes(),
        0,
        reason: 'no localhost probe may fire when local is not effective',
      );
    },
  );

  testWidgets('private mode still shows the banner when the server is down', (
    tester,
  ) async {
    await pumpCoach(tester, dataMode: 'private');

    expect(
      find.text(offlineTitle()),
      findsOneWidget,
      reason: 'here local IS the effective backend and it is unreachable',
    );
  });
}
