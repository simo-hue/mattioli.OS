// Explicit consent before the conversation goes to a third party — App Store
// Guideline 5.1.2(i), as amended 2025-11-13.
//
// THE BUG THIS FIXES: `_ensurePrivateAiConsent` opened with
//
//     final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
//     if (!isPrivate) return true;
//
// so the only users ever asked were the ones in the mode that keeps their data
// on the device. Every cloud user's message — name, habits, goals, whatever they
// typed — went to OpenRouter having been asked nothing at all. Private mode was
// never the case that needed the permission; it was the case someone remembered.
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/ai_coach/application/coach_consent_controller.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_consent.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class _FixedDataMode extends ActiveDesktopDataModeNotifier {
  _FixedDataMode(this._mode);

  final DesktopDataMode _mode;

  @override
  DesktopDataMode build() => _mode;
}

class _FixedAuth extends DesktopAuthController {
  _FixedAuth(this._userId);

  final String? _userId;

  @override
  DesktopAuthState build() => DesktopAuthState(
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

/// Records the private-mode consent column in memory.
class _FakePrivateConsent implements PrivateConsentStore {
  _FakePrivateConsent({this.throws = false});

  bool granted = false;

  /// Stands in for a locked-out SQLCipher key, which throws from the private
  /// database's `database` getter.
  final bool throws;

  @override
  Future<bool> read() async {
    if (throws) throw StateError('private database locked');
    return granted;
  }

  @override
  Future<void> write(bool value) async => granted = value;
}

Future<ProviderContainer> _container({
  DesktopDataMode mode = DesktopDataMode.supabase,
  String? userId = 'user-1',
  Map<String, Object> seed = const {},
  PrivateConsentStore? privateStore,
}) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      activeDesktopDataModeProvider.overrideWith(() => _FixedDataMode(mode)),
      desktopAuthControllerProvider.overrideWith(() => _FixedAuth(userId)),
      privateConsentStoreProvider.overrideWithValue(
        privateStore ?? _FakePrivateConsent(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('disclosureFor', () {
    test('LOCAL NEEDS NO CONSENT — nothing leaves the device', () {
      // Asking permission to send to a third party, for a transmission that
      // never happens, would be a dialog that teaches users to dismiss dialogs.
      expect(disclosureFor(CoachBackendKind.local), isNull);
    });

    test('each remote engine has its own disclosure', () {
      // Standard: we pin google-vertex with fallbacks off, so the receiving
      // parties are exactly OpenRouter, Inc. and Google LLC, and none of it is
      // the user's choosing. Cloud/BYOK: the user picked OpenRouter and holds
      // the account; we send no pin, so OpenRouter routes on their settings.
      expect(disclosureFor(CoachBackendKind.standard), CoachDisclosure.standard);
      expect(disclosureFor(CoachBackendKind.cloud), CoachDisclosure.byok);
    });
  });

  group('consentPrefKey', () {
    test('IS SCOPED PER ACCOUNT', () {
      // The Pro cache already learned this the hard way
      // (desktop_subscription_controller.dart:80-89): an unscoped key hands the
      // previous account's answer to whoever signs in next on the same Mac.
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
      // Same Mac, two people. The second must be asked.
      final first = await _container(userId: 'user-1');
      await first.read(coachConsentStoreProvider).grant(
        CoachDisclosure.standard,
      );
      final prefs = await SharedPreferences.getInstance();

      final second = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activeDesktopDataModeProvider.overrideWith(
            () => _FixedDataMode(DesktopDataMode.supabase),
          ),
          desktopAuthControllerProvider.overrideWith(() => _FixedAuth('user-2')),
          privateConsentStoreProvider.overrideWithValue(_FakePrivateConsent()),
        ],
      );
      addTearDown(second.dispose);

      expect(
        await second.read(coachConsentStoreProvider).has(
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
      // not "stop sending them via the engine I happen to be on today".
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
      final db = _FakePrivateConsent();
      final container = await _container(
        mode: DesktopDataMode.private,
        privateStore: db,
      );
      final store = container.read(coachConsentStoreProvider);

      expect(await store.has(CoachDisclosure.byok), isFalse);
      await store.grant(CoachDisclosure.byok);
      expect(db.granted, isTrue);

      await store.revokeAll();
      expect(db.granted, isFalse);
    });

    test('A LOCKED PRIVATE DATABASE READS AS NO CONSENT, not as consent', () {
      // The key-guard lockout is a real state on this app (a rotated Keychain
      // access-group prefix). An unreadable ledger must never resolve to "yes":
      // the cost of failing closed is one redundant dialog, and the cost of
      // failing open is transmitting to a third party on a permission we could
      // not read.
      return _container(
        mode: DesktopDataMode.private,
        privateStore: _FakePrivateConsent(throws: true),
      ).then((container) async {
        expect(
          await container.read(coachConsentStoreProvider).has(
            CoachDisclosure.byok,
          ),
          isFalse,
        );
      });
    });

    test('private mode consent works with no account at all', () async {
      // The cloud path bails without a userId; private mode has none by design,
      // so it must not be routed through that check.
      final db = _FakePrivateConsent();
      final container = await _container(
        mode: DesktopDataMode.private,
        userId: null,
        privateStore: db,
      );
      final store = container.read(coachConsentStoreProvider);

      await store.grant(CoachDisclosure.byok);
      expect(await store.has(CoachDisclosure.byok), isTrue);
    });
  });
}
