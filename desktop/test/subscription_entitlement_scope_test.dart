// The Pro entitlement must not cross accounts on the same Mac.
//
// `desktopSubscriptionControllerProvider` is never autoDisposed and nothing
// invalidates it on sign-out, so its offline-first seed is the only thing
// standing between the previous account's Pro and the next one that signs in.
// The seed itself is deliberate — a paying user launching offline keeps Pro —
// so these tests pin the direction it has to fail in: keep Pro for the account
// that paid, never hand it to another.
//
// RevenueCat is unconfigured under `flutter test` (no API key dart-define), so
// `refresh()` short-circuits in `_canUseRevenueCat()` and no plugin channel is
// touched — the same shape as the offline case this guards.
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _user(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00.000Z',
);

/// Stands in for the real controller, which needs a live Supabase client.
class _FakeAuthController extends DesktopAuthController {
  _FakeAuthController(this._initialUser);

  final User? _initialUser;

  @override
  DesktopAuthState build() => DesktopAuthState(user: _initialUser);

  void signInAs(User? user) => state = DesktopAuthState(user: user);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, _FakeAuthController)> containerFor(
    Map<String, Object> prefsValues, {
    User? signedInAs,
  }) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    final auth = _FakeAuthController(signedInAs);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        desktopAuthControllerProvider.overrideWith(() => auth),
      ],
    );
    addTearDown(container.dispose);
    return (container, auth);
  }

  test('the paying account keeps Pro when it seeds offline', () async {
    final (container, _) = await containerFor({
      'pref_is_pro_user-a': true,
    }, signedInAs: _user('user-a'));

    expect(
      container.read(desktopSubscriptionControllerProvider).isPro,
      isTrue,
      reason: 'offline-first hydration for the account that paid is deliberate',
    );

    // Let the seeding refresh() settle before teardown disposes the container:
    // RevenueCat is configured via the default key, so it fires and would
    // otherwise write state post-dispose. It has no store plugin under test,
    // fails in the catch, and — by design — leaves the seeded isPro untouched.
    await pumpEventQueue();
    expect(container.read(desktopSubscriptionControllerProvider).isPro, isTrue);
  });

  test('a second account does not inherit the first account\'s cached Pro', () async {
    final (container, _) = await containerFor({
      'pref_is_pro_user-a': true,
    }, signedInAs: _user('user-b'));

    expect(container.read(desktopSubscriptionControllerProvider).isPro, isFalse);
    await pumpEventQueue();
  });

  test('the unscoped legacy flag never seeds Pro, and is dropped', () async {
    final (container, _) = await containerFor({
      'pref_is_pro': true,
    }, signedInAs: _user('user-b'));

    expect(container.read(desktopSubscriptionControllerProvider).isPro, isFalse);

    await pumpEventQueue();
    expect(
      (await SharedPreferences.getInstance()).getBool('pref_is_pro'),
      isNull,
    );
  });

  test('no signed-in account means no seeded entitlement', () async {
    final (container, _) = await containerFor({'pref_is_pro_user-a': true});

    expect(container.read(desktopSubscriptionControllerProvider).isPro, isFalse);
    await pumpEventQueue();
  });

  test('sign-out drops Pro instead of carrying it into the next session', () async {
    final (container, auth) = await containerFor({
      'pref_is_pro_user-a': true,
    }, signedInAs: _user('user-a'));

    expect(container.read(desktopSubscriptionControllerProvider).isPro, isTrue);

    auth.signInAs(null);
    await pumpEventQueue();

    expect(container.read(desktopSubscriptionControllerProvider).isPro, isFalse);
  });

  test('signing in as another account after Pro signs out grants no Pro', () async {
    final (container, auth) = await containerFor({
      'pref_is_pro_user-a': true,
    }, signedInAs: _user('user-a'));

    expect(container.read(desktopSubscriptionControllerProvider).isPro, isTrue);

    auth.signInAs(null);
    await pumpEventQueue();
    auth.signInAs(_user('user-b'));
    await pumpEventQueue();

    expect(
      container.read(desktopSubscriptionControllerProvider).isPro,
      isFalse,
      reason: 'user B must stay free even though RevenueCat never resolves here',
    );
  });
}
