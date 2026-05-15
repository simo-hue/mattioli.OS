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
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      hasSentryConsent: hasSentryConsent ?? this.hasSentryConsent,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
    );
  }
}

class ConsentNotifier extends Notifier<ConsentState> {
  static const _keyCompleted = 'has_completed_consent';
  static const _keySentry = 'has_sentry_consent';
  static const _keyTerms = 'has_accepted_terms';

  @override
  ConsentState build() {
    final prefs = ref.read(sharedPrefsProvider);
    return ConsentState(
      hasCompletedOnboarding: prefs.getBool(_keyCompleted) ?? false,
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

final consentProvider = NotifierProvider<ConsentNotifier, ConsentState>(ConsentNotifier.new);
