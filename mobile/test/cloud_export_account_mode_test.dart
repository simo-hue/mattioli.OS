// Regression tests for the Account-mode (cloud) export in
// `privacy_settings_screen.dart::_exportData`.
//
// F03 — macro goal categories were read from `macroGoalCategoriesProvider`
//   (`ref.read(...).value ?? const []`). That provider is an async notifier only
//   ever built by the Macro Goals screen, which is a lazy page of a PageView the
//   app does not start on: a cold launch straight to Settings > Privacy >
//   Export snapshots an EMPTY list into a local before any await, so the backup
//   ships `macroGoalCategories: []`. Restoring it with Replace then prunes every
//   category and nulls `category_id` on every macro goal.
//
// F06 — the paginated `goal_progress` read was wrapped in a catch that logged
//   and continued for ANY failure. A dropped connection or expired JWT on page 2
//   shipped a PARTIAL page set as a complete backup, and a Replace restore then
//   pruned every quantitative daily number the file was missing. Only the
//   documented pre-migration case (the table does not exist yet, nothing read)
//   may degrade to an empty block.
//
// Both live in a widget callback behind a Supabase client and the share sheet,
// so the tests drive the REAL screen against a MockClient backend, with a fake
// `SharePlatform` capturing the file that would have been shared.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/goal_provider.dart' show kGoalLogsSyncPageSize;
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/ui/screens/privacy_settings_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// SharePlatform (the seam that lets a test capture what would be shared) is not
// re-exported by share_plus, so the interface package is imported directly. It
// is pinned transitively by share_plus itself.
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Captures what the export would have shared instead of opening a share sheet.
class _FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

/// Reports logged-out so the screen's data providers skip their Supabase sync
/// during render. `_exportData` doesn't consult it — it reads the global
/// Supabase session — so the export still runs.
class _LoggedOutAuth extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(isLoggedIn: false, dataMode: AppDataMode.supabase);
}

/// A canned PostgREST failure for the Nth GET of a table (1-based).
typedef _Failure = ({int nth, int status, String code, String message});

late _FakeShare _share;

/// Rows the fake backend serves, keyed by table.
final Map<String, List<Map<String, dynamic>>> _store = {};

/// Injected failures, keyed by table.
final Map<String, _Failure> _failures = {};

/// GET counts per table, so a failure can target a specific page.
final Map<String, int> _gets = {};

http.Response _json(Object body, http.BaseRequest req, [int code = 200]) =>
    http.Response(jsonEncode(body), code,
        request: req, headers: {'content-type': 'application/json'});

MockClient _backend() => MockClient((req) async {
      if (req.method != 'GET') return _json(const <dynamic>[], req);
      final table = req.url.pathSegments.last;
      final n = (_gets[table] = (_gets[table] ?? 0) + 1);

      final fail = _failures[table];
      if (fail != null && fail.nth == n) {
        return _json({
          'code': fail.code,
          'message': fail.message,
          'details': null,
          'hint': null,
        }, req, fail.status);
      }

      var rows = List<Map<String, dynamic>>.of(_store[table] ?? const []);
      final params = req.url.queryParameters;
      final offset = int.tryParse(params['offset'] ?? '0') ?? 0;
      final limit = int.tryParse(params['limit'] ?? '1000') ?? 1000;
      if (offset >= rows.length) {
        rows = [];
      } else {
        rows = rows.sublist(offset, (offset + limit).clamp(0, rows.length));
      }
      return _json(rows, req);
    });

Future<void> _pumpAndExport(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_LoggedOutAuth.new),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const PrivacySettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final row = find.text(t.privacy.exportData);
  await tester.scrollUntilVisible(row, 200);
  await tester.tap(row);
  await tester.pumpAndSettle();
  // The export's awaits are not scheduled frames, so pumpAndSettle can return
  // before it finishes. Pump in small steps until it has either shared a file or
  // raised the failure toast — and stop there, so the 2s toast is still on
  // screen for the assertions.
  // The budget is a WALL-CLOCK deadline, not an iteration count: how much real
  // time a page-sized decode needs depends on how loaded the machine is, so a
  // fixed number of 20ms steps is a race the test loses under a full-suite run.
  bool finished() =>
      _share.lastParams != null ||
      find.text(t.privacy.errors.exportFailed).evaluate().isNotEmpty;
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (!finished() && DateTime.now().isBefore(deadline)) {
    // A page-sized response is decoded off the main isolate by the Supabase
    // client, which fake-async time alone never lets finish — runAsync hands it
    // real time.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
  expect(finished(), isTrue,
      reason: 'the export neither shared a file nor raised the failure toast '
          'within the wall-clock budget');
}

/// AppLogger schedules a bare 2s flush timer on the error path and the toast
/// auto-dismisses on its own timer; drain both so nothing outlives the tree.
Future<void> _drainTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _share = _FakeShare();
    SharePlatform.instance = _share;
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: _backend(),
      debug: false,
    );
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'not-a-jwt',
      'token_type': 'bearer',
      'user': {
        'id': 'u1',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
      },
    }));
  });

  setUp(() {
    _store.clear();
    _failures.clear();
    _gets.clear();
    _share.lastParams = null;
    _store['goals'] = [];
    _store['goal_logs'] = [];
    _store['goal_progress'] = [];
    _store['long_term_goals'] = [];
    _store['daily_moods'] = [];
    _store['macro_goal_categories'] = [];
  });

  Future<Map<String, dynamic>> exportedJson(WidgetTester tester) async {
    await _pumpAndExport(tester);
    await _drainTimers(tester);
    final params = _share.lastParams;
    expect(params, isNotNull, reason: 'the export produced no file to share');
    final bytes = await params!.files!.single.readAsBytes();
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  testWidgets(
      'F03: categories come from the table, not from a provider that may never '
      'have been built', (tester) async {
    // macroGoalCategoriesProvider is deliberately NOT built here — exactly the
    // cold-launch-straight-to-Privacy case. The account still holds categories.
    _store['macro_goal_categories'] = [
      {
        'id': 'cat-1',
        'user_id': 'u1',
        'name': 'Salute',
        'color': '#10B981',
        'created_at': '2026-01-01T00:00:00.000Z',
        'archived_at': null,
      },
      {
        'id': 'cat-2',
        'user_id': 'u1',
        'name': 'Lavoro',
        'color': '#3B82F6',
        'created_at': '2026-02-01T00:00:00.000Z',
        'archived_at': '2026-03-01T00:00:00.000Z',
      },
    ];

    final data = await exportedJson(tester);
    final cats = (data['macroGoalCategories'] as List)
        .cast<Map<String, dynamic>>();
    expect(cats, hasLength(2),
        reason: 'an empty block here wipes every category on a Replace restore');
    expect(cats.map((c) => c['id']), containsAll(['cat-1', 'cat-2']));
    expect(cats.firstWhere((c) => c['id'] == 'cat-1')['name'], 'Salute');
    expect(cats.firstWhere((c) => c['id'] == 'cat-2')['archived_at'],
        '2026-03-01T00:00:00.000Z');
    expect(cats.first.containsKey('created_at'), isTrue,
        reason: 'the raw row carries created_at; the provider-derived map did '
            'not');
  });

  testWidgets('F06: a failed goal_progress page aborts the export', (tester) async {
    // Page 1 succeeds and is full, so the loop asks for page 2 — which dies on a
    // dropped connection. Shipping page 1 as a complete backup means a Replace
    // restore prunes every daily number past it.
    _store['goal_progress'] = List.generate(
      kGoalLogsSyncPageSize,
      (i) => {
        'id': 'goal-1:2026-01-01',
        'user_id': 'u1',
        'goal_id': 'goal-1',
        'date': '2026-01-01',
        'amount': i,
        'source': 'manual',
      },
    );
    _failures['goal_progress'] =
        (nth: 2, status: 500, code: '57P01', message: 'connection lost');

    await _pumpAndExport(tester);

    expect(_share.lastParams, isNull,
        reason: 'a partial page set must never be shared as a backup');
    expect(find.text(t.privacy.errors.exportFailed), findsOneWidget);
    await _drainTimers(tester);
  });

  testWidgets('F06: a first-page failure aborts the export too', (tester) async {
    _failures['goal_progress'] =
        (nth: 1, status: 500, code: '57P01', message: 'connection lost');

    await _pumpAndExport(tester);

    expect(_share.lastParams, isNull);
    expect(find.text(t.privacy.errors.exportFailed), findsOneWidget);
    await _drainTimers(tester);
  });

  testWidgets(
      'F06: the documented pre-migration case still degrades to an empty block',
      (tester) async {
    // The v9 migration lands before the targets flag flips, so a table that does
    // not exist yet must NOT fail the whole export.
    _failures['goal_progress'] = (
      nth: 1,
      status: 404,
      code: '42P01',
      message: 'relation "public.goal_progress" does not exist',
    );

    final data = await exportedJson(tester);
    expect(data['habitProgress'], isEmpty);
  });
}
