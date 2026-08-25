import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared_prefs_provider.dart';

class ConsentState {
  final bool hasCompletedOnboarding;
  final bool hasSentryConsent;
  final bool hasAcceptedTerms;

  ConsentState({
    required this.hasCompletedOnboarding,
    required this.hasSentryConsent,
    required this.hasAcceptedTerms,
  });

  ConsentState copyWith({
    bool? hasCompletedOnboarding,
    bool? hasSentryConsent,
    bool? hasAcceptedTerms,
  }) {
    return ConsentState(
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      hasSentryConsent: hasSentryConsent ?? this.hasSentryConsent,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
    );
  }
}

/// The prefs key recording that the consent question has been ANSWERED.
///
/// Public because several places outside this file gate on it — `main()`'s
/// Sentry and Supabase startup gates, `data_mode.dart`'s late Sentry init, and
/// the notification background isolate's Supabase gate. Each of the first three
/// was carrying its own string literal. Renaming the private field while
/// leaving those literals behind would silently re-open the pre-consent
/// initialisation bug in every one of them.
const String kHasCompletedConsentPrefKey = 'has_completed_consent';

class ConsentNotifier extends Notifier<ConsentState> {
  static const _keyCompleted = kHasCompletedConsentPrefKey;
  static const _keySentry = 'has_sentry_consent';
  static const _keyTerms = 'has_accepted_terms';

  @override
  ConsentState build() {
    final prefs = ref.read(sharedPrefsProvider);
    return ConsentState(
      hasCompletedOnboarding: prefs.getBool(_keyCompleted) ?? false,
      // Absent means UNANSWERED, which is not consent (Guideline 5.1.2).
      // `shouldRun` already refuses to start the SDK before the consent screen
      // has been completed, but this value is also what the Privacy Settings
      // switch renders — and a switch showing ON for a permission nobody gave
      // is its own misstatement.
      hasSentryConsent: prefs.getBool(_keySentry) ?? false,
      hasAcceptedTerms: prefs.getBool(_keyTerms) ?? false,
    );
  }

  Future<void> setConsent({
    required bool acceptedTerms,
    required bool sentryConsent,
    required bool completed,
  }) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool(_keyTerms, acceptedTerms);
    await prefs.setBool(_keySentry, sentryConsent);
    await prefs.setBool(_keyCompleted, completed);

    state = state.copyWith(
      hasAcceptedTerms: acceptedTerms,
      hasSentryConsent: sentryConsent,
      hasCompletedOnboarding: completed,
    );
  }
}

final consentProvider = NotifierProvider<ConsentNotifier, ConsentState>(
  ConsentNotifier.new,
);
