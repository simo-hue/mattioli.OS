// Explicit consent before the conversation goes to a third party — App Store
// Guideline 5.1.2(i), as amended 2025-11-13.
//
// THE BUG THIS FIXES: `_ensurePrivateAiConsent` opened with
//
//     if (ref.read(activeDataModeProvider) != AppDataMode.private) return true;
//
// so the only users ever asked were the ones in the mode that keeps their data
// on the device. Every cloud user's message — name, habits, goals, whatever they
// typed — went to OpenRouter having been asked nothing at all. Private mode was
// never the case that needed the permission; it was the case someone remembered.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/coach_consent.dart';
import 'package:mattioli_os/core/coach_endpoint.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/core/private_data_store.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// `AuthState` is both gotrue's and the app's own; take only what is needed.
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class _FixedDataMode extends ActiveDataModeNotifier {
  _FixedDataMode(this._mode);

  final AppDataMode _mode;

  @override
  AppDataMode build() => _mode;
}

class _FixedAuth extends AuthNotifier {
  _FixedAuth(this._userId);

  final String? _userId;

  @override
  AuthState build() => AuthState(
    isLoggedIn: _userId != null,
    dataMode: AppDataMode.supabase,
    user: _userId == null
        ? null
        : User(
            id: _userId,
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: '2026-07-17T00:00:00.000Z',
          ),
  );
}

/// Records the private-mode consent column in memory. Only the two consent
/// members are reachable from [CoachConsentStore]; the rest of the store would
/// need SQLCipher and a Keychain.
class _FakePrivateDb extends Fake implements PrivateDataStore {
  bool consented = false;

  @override
  Future<bool> hasPrivateAiExternalConsent() async => consented;

  @override
  Future<void> setPrivateAiExternalConsent(bool value) async =>
      consented = value;
}

Future<ProviderContainer> _container({
  AppDataMode mode = AppDataMode.supabase,
  String? userId = 'user-1',
  Map<String, Object> seed = const {},
  _FakePrivateDb? db,
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      activeDataModeProvider.overrideWith(() => _FixedDataMode(mode)),
      authProvider.overrideWith(() => _FixedAuth(userId)),
      privateLocalDatabaseProvider.overrideWithValue(db ?? _FakePrivateDb()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('disclosureFor', () {
    test('each mode has its own disclosure — they are different recipients', () {
      // Standard: we pin google-vertex with fallbacks off, so the receiving
      // parties are exactly OpenRouter, Inc. and Google LLC, and none of it is
      // the user's choosing. BYOK: the user picked OpenRouter and holds the
      // account; we send no pin, so OpenRouter routes on their settings.
      // Consenting to one is not consenting to the other.
      expect(disclosureFor(CoachMode.standard), CoachDisclosure.standard);
      expect(disclosureFor(CoachMode.byok), CoachDisclosure.byok);
    });
  });

  group('consentPrefKey', () {
    test('IS SCOPED PER ACCOUNT', () {
      // The Pro cache already learned this the hard way
      // (desktop_subscription_controller.dart:80-89): an unscoped key hands the
      // previous account's answer to whoever signs in next on the same device.
      // There it leaked an entitlement. Here it would transmit a stranger's
      // conversation to a third party on a permission they never gave.
      expect(
        consentPrefKey(CoachDisclosure.standard, 'user-1'),
        isNot(consentPrefKey(CoachDisclosure.standard, 'user-2')),
      );
    });

    test('the two disclosures never share a key', () {
      expect(
        consentPrefKey(CoachDisclosure.standard, 'user-1'),
        isNot(consentPrefKey(CoachDisclosure.byok, 'user-1')),
      );
    });
  });

  group('CoachConsentStore in cloud mode', () {
    test('A CLOUD USER HAS NOT CONSENTED UNTIL THEY SAY SO', () async {
      // The regression. This is the exact state that used to return true.
      final container = await _container();
      final store = container.read(coachConsentStoreProvider);
      for (final disclosure in CoachDisclosure.values) {
        expect(
          await store.has(disclosure),
          isFalse,
          reason: '$disclosure must not be assumed for a cloud user',
        );
      }
    });

    test('granting one disclosure does not grant the other', () async {
      final container = await _container();
      final store = container.read(coachConsentStoreProvider);

      await store.grant(CoachDisclosure.standard);

      expect(await store.has(CoachDisclosure.standard), isTrue);
      expect(
        await store.has(CoachDisclosure.byok),
        isFalse,
        reason: 'allowing our proxy is not allowing their own OpenRouter key',
      );
    });

    test("one account's consent is not another's", () async {
      // Same device, two people. The second must be asked.
      final granted = await _container(userId: 'user-1');
      await granted.read(coachConsentStoreProvider).grant(
        CoachDisclosure.standard,
      );
      final prefs = await SharedPreferences.getInstance();

      final other = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          activeDataModeProvider.overrideWith(
            () => _FixedDataMode(AppDataMode.supabase),
          ),
          authProvider.overrideWith(() => _FixedAuth('user-2')),
          privateLocalDatabaseProvider.overrideWithValue(_FakePrivateDb()),
        ],
      );
      addTearDown(other.dispose);

      expect(
        await other.read(coachConsentStoreProvider).has(
          CoachDisclosure.standard,
        ),
        isFalse,
        reason: "user-2 inherited user-1's consent",
      );
    });

    test('signed out reads as no consent, and grants nothing', () async {
      // Fail closed. A consent recorded against nobody is a consent nobody gave.
      final container = await _container(userId: null);
      final store = container.read(coachConsentStoreProvider);

      expect(await store.has(CoachDisclosure.standard), isFalse);
      await store.grant(CoachDisclosure.standard);
      expect(
        await store.has(CoachDisclosure.standard),
        isFalse,
        reason: 'a grant with no account must not be recorded anywhere',
      );
    });

    test('revokeAll clears every disclosure, not just the active one', () async {
      // Someone withdrawing from Settings means "stop sending my conversations",
      // not "stop sending them via the mode I happen to be on today".
      final container = await _container();
      final store = container.read(coachConsentStoreProvider);
      await store.grant(CoachDisclosure.standard);
      await store.grant(CoachDisclosure.byok);

      await store.revokeAll();

      for (final disclosure in CoachDisclosure.values) {
        expect(await store.has(disclosure), isFalse, reason: '$disclosure');
      }
    });
  });

  group('CoachConsentStore in private mode', () {
    test('reads and writes the private database, not prefs', () async {
      // Private mode's whole promise is that nothing about it lives outside the
      // encrypted local database. Its consent included.
      final db = _FakePrivateDb();
      final container = await _container(mode: AppDataMode.private, db: db);
      final store = container.read(coachConsentStoreProvider);

      expect(await store.has(CoachDisclosure.byok), isFalse);
      await store.grant(CoachDisclosure.byok);
      expect(db.consented, isTrue);
      expect(await store.has(CoachDisclosure.byok), isTrue);

      await store.revokeAll();
      expect(db.consented, isFalse);
    });

    test('private mode consent works with no account at all', () async {
      // The cloud path bails without a userId; private mode has none by design,
      // so it must not be routed through that check.
      final db = _FakePrivateDb();
      final container = await _container(
        mode: AppDataMode.private,
        userId: null,
        db: db,
      );
      final store = container.read(coachConsentStoreProvider);

      await store.grant(CoachDisclosure.byok);
      expect(await store.has(CoachDisclosure.byok), isTrue);
    });
  });
}
