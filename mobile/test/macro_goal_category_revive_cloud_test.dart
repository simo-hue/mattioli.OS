// F25 — Account mode could not re-create a category whose name was archived.
//
// `macro_goal_categories` is UNIQUE(user_id, name) and delete is a SOFT archive
// that keeps the row in that uniqueness slot forever, so the bare insert raised
// 23505; addCategory caught it, showed the generic error and returned null. The
// picker filters out archived categories, so there was no un-archive surface
// either — the name was gone for good. The private branch already revives the
// archived row (see PrivateLocalDatabase.addMacroGoalCategory's comment); this
// is the cloud branch catching up.
//
// A LIVE same-name row stays a genuine duplicate: it must still fall through to
// the insert so the UNIQUE violation surfaces as an error.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/macro_goal_categories_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

typedef _Req = ({String method, String query, Object? body});

/// Every request the fake PostgREST saw.
final List<_Req> _requests = [];

/// Rows the fake backend serves for macro_goal_categories.
List<Map<String, dynamic>> _rows = [];

class _SignedInAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isLoggedIn: true,
        user: User(
          id: 'u1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00.000Z',
        ),
      );
}

http.Response _json(Object body, http.BaseRequest req, [int code = 200]) =>
    http.Response(jsonEncode(body), code,
        request: req, headers: {'content-type': 'application/json'});

MockClient _backend() => MockClient((req) async {
      _requests.add((
        method: req.method,
        query: req.url.query,
        body: req.body.isEmpty ? null : jsonDecode(req.body),
      ));
      if (req.method == 'GET') {
        // The name lookup and the post-write refetch both land here; serving the
        // whole set is enough for either.
        return _json(_rows, req);
      }
      if (req.method == 'POST') {
        // `.select('id').single()` wants a bare object back.
        return _json({'id': 'new-id'}, req);
      }
      return _json(const <dynamic>[], req);
    });

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    authProvider.overrideWith(_SignedInAuth.new),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: _backend(),
      debug: false,
    );
  });

  setUp(() {
    _requests.clear();
    _rows = [];
  });

  test('an archived same-name category is revived, not re-inserted', () async {
    _rows = [
      {
        'id': 'cat-archived',
        'user_id': 'u1',
        'name': 'Fitness',
        'color': '#10B981',
        'created_at': '2026-01-01T00:00:00.000Z',
        'archived_at': '2026-02-01T00:00:00.000Z',
      },
    ];

    final container = await _container();
    // Build the notifier before asserting on the wire, so its own fetch is not
    // mistaken for the add's lookup.
    await container.read(macroGoalCategoriesProvider.future);
    _requests.clear();

    final id = await container
        .read(macroGoalCategoriesProvider.notifier)
        .addCategory('Fitness', '#3B82F6');

    expect(id, 'cat-archived',
        reason: 'the archived row owns the UNIQUE(user_id, name) slot; the '
            'create must revive it rather than fail');
    final patches = _requests.where((r) => r.method == 'PATCH').toList();
    expect(patches, hasLength(1));
    expect((patches.single.body as Map)['archived_at'], isNull);
    expect((patches.single.body as Map)['color'], '#3B82F6');
    expect(_requests.where((r) => r.method == 'POST'), isEmpty,
        reason: 'an insert here is the 23505 that made the create silently fail');
  });

  test('a LIVE same-name category still falls through to the insert', () async {
    _rows = [
      {
        'id': 'cat-live',
        'user_id': 'u1',
        'name': 'Fitness',
        'color': '#10B981',
        'created_at': '2026-01-01T00:00:00.000Z',
        'archived_at': null,
      },
    ];

    final container = await _container();
    await container.read(macroGoalCategoriesProvider.future);
    _requests.clear();

    await container
        .read(macroGoalCategoriesProvider.notifier)
        .addCategory('Fitness', '#3B82F6');

    expect(_requests.where((r) => r.method == 'POST'), hasLength(1),
        reason: 'a live duplicate must still reach the server and be rejected');
    expect(_requests.where((r) => r.method == 'PATCH'), isEmpty);
  });
}
