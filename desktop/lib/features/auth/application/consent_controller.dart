import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_sentry_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopConsentState {
  const DesktopConsentState({
    required this.hasCompletedOnboarding,
    required this.hasSentryConsent,
    required this.hasAcceptedTerms,
  });

  final bool hasCompletedOnboarding;
  final bool hasSentryConsent;
  final bool hasAcceptedTerms;

  DesktopConsentState copyWith({
    bool? hasCompletedOnboarding,
    bool? hasSentryConsent,
    bool? hasAcceptedTerms,
  }) {
    return DesktopConsentState(
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      hasSentryConsent: hasSentryConsent ?? this.hasSentryConsent,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
    );
  }
}

final desktopConsentControllerProvider =
    NotifierProvider<DesktopConsentController, DesktopConsentState>(
      DesktopConsentController.new,
    );

class DesktopConsentController extends Notifier<DesktopConsentState> {
  static const _keyCompleted = 'has_completed_consent';
  static const _keySentry = 'has_sentry_consent';
  static const _keyTerms = 'has_accepted_terms';

  @override
  DesktopConsentState build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return DesktopConsentState(
      hasCompletedOnboarding: preferences?.getBool(_keyCompleted) ?? false,
      // Absent means UNANSWERED, which is not consent (Guideline 5.1.2).
      // Defaulting this to `true` is what let diagnostics start before the
      // consent screen had been shown.
      hasSentryConsent: preferences?.getBool(_keySentry) ?? false,
      hasAcceptedTerms: preferences?.getBool(_keyTerms) ?? false,
    );
  }

  Future<void> setConsent({
    required bool acceptedTerms,
    required bool sentryConsent,
    required bool completed,
  }) async {
    final preferences = ref.read(sharedPreferencesProvider);
    await Future.wait([
      if (preferences != null) preferences.setBool(_keyTerms, acceptedTerms),
      if (preferences != null) preferences.setBool(_keySentry, sentryConsent),
      if (preferences != null) preferences.setBool(_keyCompleted, completed),
    ]);

    state = state.copyWith(
      hasAcceptedTerms: acceptedTerms,
      hasSentryConsent: sentryConsent,
      hasCompletedOnboarding: completed,
    );
    // Same predicate as cold start, so the answer given here and the answer
    // read back on the next launch can never disagree — and so Private mode
    // still wins over a stale `true` (mobile parity).
    await DesktopSentryService.setEnabled(
      DesktopSentryService.shouldRun(
        hasCompletedConsent: completed,
        hasSentryConsent: sentryConsent,
        isPrivateMode: ref.read(activeDesktopDataModeProvider).isPrivate,
      ),
    );
    await syncToProfile();
  }

  Future<void> syncToProfile() async {
    final client = ref.read(supabaseClientProvider);
    final user = client?.auth.currentUser;
    if (client == null || user == null || !state.hasAcceptedTerms) return;

    try {
      await client.from('profiles').upsert({
        'id': user.id,
        'terms_accepted_at': DateTime.now().toIso8601String(),
        'sentry_consent': state.hasSentryConsent,
      });
    } catch (error, stack) {
      AppLogger.error('Unable to sync consent to profiles', error, stack);
    }
  }
}
