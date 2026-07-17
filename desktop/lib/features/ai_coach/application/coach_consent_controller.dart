import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/coach_consent.dart';

/// The private database's consent column, behind a seam.
///
/// `DesktopPrivateDb.instance` is a singleton that needs SQLCipher and the
/// Keychain, so a test that touches it needs a real encrypted database. Only two
/// methods matter here; injecting them keeps the consent rules testable.
abstract interface class PrivateConsentStore {
  Future<bool> read();
  Future<void> write(bool granted);
}

class _RealPrivateConsentStore implements PrivateConsentStore {
  const _RealPrivateConsentStore();

  @override
  Future<bool> read() => DesktopPrivateDb.instance.hasPrivateAiExternalConsent();

  @override
  Future<void> write(bool granted) =>
      DesktopPrivateDb.instance.setPrivateAiExternalConsent(granted);
}

final privateConsentStoreProvider = Provider<PrivateConsentStore>(
  (_) => const _RealPrivateConsentStore(),
);

/// Reads and records coach consent for the active data mode.
class CoachConsentStore {
  const CoachConsentStore(this._ref);

  final Ref _ref;

  /// Whether [disclosure] has been consented to by the current user.
  ///
  /// Returns false — never true — when the answer cannot be established (no
  /// account, an unreadable private database). Failing closed costs a redundant
  /// dialog; failing open sends someone's conversation to a third party on a
  /// permission we could not prove we had.
  Future<bool> has(CoachDisclosure disclosure) async {
    if (_ref.read(activeDesktopDataModeProvider).isPrivate) {
      try {
        return await _ref.read(privateConsentStoreProvider).read();
      } catch (_) {
        // A locked-out SQLCipher key throws here. Unknown means not granted.
        return false;
      }
    }
    final userId = _ref.read(desktopAuthControllerProvider).user?.id;
    if (userId == null) return false;
    return _ref
            .read(sharedPreferencesProvider)
            ?.getBool(consentPrefKey(disclosure, userId)) ??
        false;
  }

  /// Records [disclosure] as consented to. No-op without an account, so a
  /// consent can never be recorded against nobody.
  Future<void> grant(CoachDisclosure disclosure) async {
    if (_ref.read(activeDesktopDataModeProvider).isPrivate) {
      await _ref.read(privateConsentStoreProvider).write(true);
      return;
    }
    final userId = _ref.read(desktopAuthControllerProvider).user?.id;
    if (userId == null) return;
    await _ref
        .read(sharedPreferencesProvider)
        ?.setBool(consentPrefKey(disclosure, userId), true);
  }

  /// Withdraws every coach consent for the current user.
  ///
  /// Withdrawal must be as easy as granting (GDPR Art. 7(3); Simone is the named
  /// controller). Clears both disclosures rather than one: withdrawing means
  /// "stop sending my conversations", not "stop sending them via the engine I
  /// happen to be on".
  Future<void> revokeAll() async {
    if (_ref.read(activeDesktopDataModeProvider).isPrivate) {
      await _ref.read(privateConsentStoreProvider).write(false);
      return;
    }
    final userId = _ref.read(desktopAuthControllerProvider).user?.id;
    if (userId == null) return;
    final prefs = _ref.read(sharedPreferencesProvider);
    for (final disclosure in CoachDisclosure.values) {
      await prefs?.remove(consentPrefKey(disclosure, userId));
    }
  }
}

final coachConsentStoreProvider = Provider<CoachConsentStore>(
  CoachConsentStore.new,
);

/// Whether the user has consented to ANY coach disclosure — drives the Settings
/// row that lets them take it back.
final hasAnyCoachConsentProvider = FutureProvider<bool>((ref) async {
  // Rebuilds when the mode or the account changes, so the row cannot go on
  // reporting the previous user's answer.
  ref.watch(activeDesktopDataModeProvider);
  ref.watch(desktopAuthControllerProvider.select((s) => s.user?.id));
  final store = ref.read(coachConsentStoreProvider);
  for (final disclosure in CoachDisclosure.values) {
    if (await store.has(disclosure)) return true;
  }
  return false;
});
