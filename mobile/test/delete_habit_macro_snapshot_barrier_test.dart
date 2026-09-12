// Deleting a habit must WAIT for the macro-goals loaders before deciding that
// no macro goal is linked to it.
//
// `GoalsNotifier.deleteHabit` gates the delete-time snapshot on
// `ref.read(macroGoalsProvider).goals.any((g) => g.linkedGoalId == id)`. Since
// the macro-goals cache seed became owner-gated it awaits a Keychain round
// trip, so `build()` returns an EMPTY state synchronously and fills it in
// later — and `ref.read` on a provider nobody has built yet runs `build()` and
// takes exactly that synchronous value.
//
// Nobody has usually built it: MacroGoalsScreen is index 2 of a lazy PageView,
// so a session that never opened the Goals tab reaches the delete with the
// provider cold. The empty list then reads as "nothing is linked", the snapshot
// is skipped, the habit DELETE cascades its `goal_progress` rows away and the
// `ON DELETE SET NULL` FK un-links the macro goal — a "500 km" goal that had
// reached 320 collapses to 0 with nothing left to re-derive it from.
//
// `MacroTargetsConfig.enabled` is false on both apps today, but
// macro_targets_config.dart states the domain layer — "the delete-time
// snapshot" included — is deliberately NOT gated, so a `target_amount` synced
// from a device where the flag IS live still round-trips safely. This test
// pins that guard against being silently turned into a no-op.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/macro_goals_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'support/fake_private_data_store.dart';

const _userId = 'user-a';
const _habitId = 'h1';

/// The delete path cancels the habit's reminder, which reaches the plugin.
class _NoopNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancel({required int id}) async {}

  @override
  Future<void> cancelAll() async {}
}

class _TestAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        isLoggedIn: true,
        user: Supabase.instance.client.auth.currentUser,
        dataMode: AppDataMode.supabase,
      );
}

/// One habit, with no logs and no progress — so `deleteHabit` takes the HARD
/// delete branch, which is the only one that reaches the macro-goal snapshot.
String _goalsBody() => jsonEncode([
      {
        'id': _habitId,
        'title': 'Correre',
        'color': '#3B82F6',
        'start_date': '2026-01-01T00:00:00.000Z',
      },
    ]);

/// The macro goal that habit feeds: "500 km", already at 320.
String _macroBlob() => jsonEncode([
      {
        'id': 'macro-1',
        'title': '500 km',
        'status': 'active',
        'type': 'lifetime',
        'linked_goal_id': _habitId,
        'created_at': '2026-01-01T00:00:00.000Z',
      },
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Set when the snapshot's `linked_goal_id=eq.h1` lookup is issued — i.e.
  /// when `snapshotCloudLinkedMacroGoals` actually ran.
  var snapshotRequested = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'anon-key',
      httpClient: MockClient((req) async {
        http.Response json(String body) => http.Response(body, 200,
            request: req, headers: {'content-type': 'application/json'});

        final path = req.url.path;
        if (path.endsWith('/long_term_goals')) {
          if (req.url.query.contains('linked_goal_id=eq.$_habitId')) {
            snapshotRequested = true;
            return json(jsonEncode([
              {'id': 'macro-1', 'type': 'lifetime'}
            ]));
          }
          return json(_macroBlob());
        }
        if (path.endsWith('/goals')) {
          return json(req.method == 'DELETE' ? '[]' : _goalsBody());
        }
        // goal_logs / goal_progress: no history, so the habit is hard-deleted.
        return json('[]');
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      debug: false,
    );
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'not-a-jwt',
      'token_type': 'bearer',
      'user': {
        'id': _userId,
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
      },
    }));
  });

  setUp(() {
    snapshotRequested = false;
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<ProviderContainer> boot() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      // The offline mirror this account owns. Present so the seed leg has real
      // work to do — the same leg whose Keychain round trip opens the window.
      'macro_goals_cache': _macroBlob(),
    });
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      kCacheOwnerKey: _userId,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      authProvider.overrideWith(_TestAuth.new),
      privateLocalDatabaseProvider.overrideWith((ref) => FakePrivateDataStore()),
      initialGoalsProvider.overrideWithValue('[]'),
      initialLogsProvider.overrideWithValue('{}'),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test(
      'THE GAP: a session that never opened the Goals tab still snapshots the '
      'linked macro goal before deleting the habit', () async {
    final c = await boot();
    // Deliberately NOT reading `macroGoalsProvider` first: this is the lazy
    // PageView session, so the provider is cold when `deleteHabit` reaches it.
    expect(await c.read(goalsProvider.notifier).ensureLoaded(), isTrue);
    expect(c.read(goalsProvider).map((g) => g.id), [_habitId]);

    await c.read(goalsProvider.notifier).deleteHabit(_habitId);

    expect(snapshotRequested, isTrue,
        reason: 'the delete-time snapshot must run: skipping it lets the '
            'cascade + ON DELETE SET NULL collapse the linked macro goal');
  });

  test('the barrier reports the loaders, and the seeded state, as settled',
      () async {
    final c = await boot();

    expect(await c.read(macroGoalsProvider.notifier).ensureLoaded(), isTrue);
    expect(c.read(macroGoalsProvider).goals.map((g) => g.id), ['macro-1']);
  });
}
