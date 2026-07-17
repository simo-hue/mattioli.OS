/// Consent to send the conversation to a third party — App Store Guideline
/// 5.1.2(i), as amended 2025-11-13: personal data may not be shared with third
/// parties without the user's **explicit** permission, and the disclosure has to
/// say who is receiving it.
///
/// **Why this is per [CoachMode] and not one global switch.** The two modes have
/// different recipients under different agreements, and consenting to one is not
/// consenting to the other:
///
/// - [CoachMode.standard] — WE choose the recipients. The Edge Function holds
///   our key and pins `google-ai-studio` with fallbacks disabled, so the
///   receiving parties are exactly OpenRouter, Inc. and Google LLC (Google AI
///   Studio, the free tier). A closed list, nameable, and none of it the user's
///   choosing. The free tier may retain and learn from the data — disclosed in
///   the consent copy and the privacy policy.
/// - [CoachMode.byok] — the USER chose OpenRouter and holds the account. We
///   send no provider pin, so OpenRouter routes to whichever provider serves the
///   model under *their* account settings. We cannot enumerate that list, and it
///   is not ours to enumerate: the disclosure says OpenRouter and says the
///   routing is theirs.
///
/// Rolling those into one "AI consent" would take permission for a recipient the
/// user never agreed to — which is the thing the guideline forbids.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'coach_endpoint.dart';
import 'data_mode.dart';
import 'private_local_database.dart';
import '../providers/auth_provider.dart';
import '../providers/shared_prefs_provider.dart';

/// Who receives the conversation in a given mode. The copy is localized; this is
/// the machine-readable fact behind it, and the reason the two consents are
/// separate.
enum CoachDisclosure {
  /// OpenRouter, Inc. → Google LLC (Google AI Studio, free tier). Pinned
  /// server-side.
  standard,

  /// OpenRouter, Inc., routing on the user's own account.
  byok,
}

/// The disclosure a [mode] requires.
CoachDisclosure disclosureFor(CoachMode mode) => switch (mode) {
  CoachMode.standard => CoachDisclosure.standard,
  CoachMode.byok => CoachDisclosure.byok,
};

/// Where a granted consent is recorded, for a given data mode.
///
/// Private mode has no account, so it uses the private database's own column —
/// which is also the only store that stays on the device, as that mode promises.
/// It can only ever be BYOK (the proxy has no account to authenticate), so the
/// single column is a complete record there.
///
/// Cloud mode uses SharedPreferences, **scoped per account**. Unscoped would
/// hand the previous user's consent to whoever signs in next on the same
/// device — the same trap the Pro cache already fell into
/// (`desktop_subscription_controller.dart:80-89`), except that here the
/// consequence is transmitting a stranger's conversation to a third party on a
/// permission they never gave.
@visibleForTesting
String consentPrefKey(CoachDisclosure disclosure, String userId) =>
    'ai_consent_${disclosure.name}_$userId';

/// Reads and records coach consent for the active data mode.
class CoachConsentStore {
  const CoachConsentStore(this._ref);

  final Ref _ref;

  /// Whether [disclosure] has been consented to by the current user.
  ///
  /// Returns false — never true — when the answer cannot be established (no
  /// account yet, an unreadable private database). Failing closed here costs a
  /// redundant dialog; failing open sends someone's conversation to a third
  /// party on a permission we could not prove we had.
  Future<bool> has(CoachDisclosure disclosure) async {
    if (_ref.read(activeDataModeProvider).isPrivate) {
      // Private mode is BYOK by construction; the column records exactly that.
      final db = _ref.read(privateLocalDatabaseProvider);
      return db.hasPrivateAiExternalConsent();
    }
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return false;
    return _ref.read(sharedPrefsProvider).getBool(
          consentPrefKey(disclosure, userId),
        ) ??
        false;
  }

  /// Records [disclosure] as consented to. No-op when there is no account to
  /// attribute it to, so a consent can never be recorded against nobody.
  Future<void> grant(CoachDisclosure disclosure) async {
    if (_ref.read(activeDataModeProvider).isPrivate) {
      await _ref
          .read(privateLocalDatabaseProvider)
          .setPrivateAiExternalConsent(true);
      return;
    }
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    await _ref.read(sharedPrefsProvider).setBool(
          consentPrefKey(disclosure, userId),
          true,
        );
  }

  /// Withdraws every coach consent for the current user.
  ///
  /// Withdrawal must be as easy as granting (GDPR Art. 7(3); Simone is the named
  /// controller). Clears both disclosures rather than one: a user withdrawing
  /// from Settings means "stop sending my conversations", not "stop sending them
  /// via the mode I happen to be on".
  Future<void> revokeAll() async {
    if (_ref.read(activeDataModeProvider).isPrivate) {
      await _ref
          .read(privateLocalDatabaseProvider)
          .setPrivateAiExternalConsent(false);
      return;
    }
    final userId = _ref.read(authProvider).userId;
    if (userId == null) return;
    final prefs = _ref.read(sharedPrefsProvider);
    for (final disclosure in CoachDisclosure.values) {
      await prefs.remove(consentPrefKey(disclosure, userId));
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
  ref.watch(activeDataModeProvider);
  ref.watch(authProvider.select((s) => s.userId));
  final store = ref.read(coachConsentStoreProvider);
  for (final disclosure in CoachDisclosure.values) {
    if (await store.has(disclosure)) return true;
  }
  return false;
});
