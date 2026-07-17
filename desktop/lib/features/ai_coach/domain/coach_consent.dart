/// Consent to send the conversation to a third party — App Store Guideline
/// 5.1.2(i), as amended 2025-11-13: personal data may not be shared with third
/// parties without the user's **explicit** permission, and the disclosure has to
/// name who receives it.
///
/// The pure half: who receives what, and where a granted permission is recorded.
/// The store lives in `application/coach_consent_controller.dart`.
library;

import 'coach_backend.dart';

/// Who receives the conversation for a given engine. The copy is localized;
/// this is the machine-readable fact behind it, and the reason there is more
/// than one consent.
///
/// The two are separate because the recipients genuinely differ, and consenting
/// to one is not consenting to the other:
///
/// - [standard] — WE choose the recipients. The Edge Function holds our key and
///   pins `google-ai-studio` with fallbacks disabled, so the receiving parties
///   are exactly OpenRouter, Inc. and Google LLC (Google AI Studio, the free
///   tier). A closed list, nameable, and none of it the user's choosing. The
///   free tier may retain and learn from the data — disclosed in the consent
///   copy and the privacy policy.
/// - [byok] — the USER chose OpenRouter and holds the account. We send no
///   provider pin, so OpenRouter routes to whichever provider serves the model
///   under *their* account settings. We cannot enumerate that list, and it is
///   not ours to enumerate.
///
/// Rolling them into one "AI consent" would take permission for a recipient the
/// user never agreed to, which is the thing the guideline forbids.
enum CoachDisclosure { standard, byok }

/// The disclosure [kind] requires, or **null** when nothing leaves the device.
///
/// [CoachBackendKind.local] returns null and that is the whole point of it: a
/// loopback model receives nothing, so asking permission to send it to a third
/// party would be asking about a transmission that never happens.
CoachDisclosure? disclosureFor(CoachBackendKind kind) => switch (kind) {
  CoachBackendKind.standard => CoachDisclosure.standard,
  CoachBackendKind.cloud => CoachDisclosure.byok,
  CoachBackendKind.local => null,
};

/// Where a cloud-mode consent is recorded.
///
/// **Scoped per account.** Unscoped would hand the previous user's consent to
/// whoever signs in next on the same Mac — the trap the Pro cache already fell
/// into (`desktop_subscription_controller.dart:80-89`), except that here the
/// consequence is transmitting a stranger's conversation to a third party on a
/// permission they never gave.
///
/// Private mode does not use this: it has no account, and its consent belongs in
/// the encrypted local database like everything else that mode promises to keep
/// on the device.
String consentPrefKey(CoachDisclosure disclosure, String userId) =>
    'ai_consent_${disclosure.name}_$userId';
