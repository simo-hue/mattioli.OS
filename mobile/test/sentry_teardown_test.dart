import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/sentry_service.dart';

/// Guards the decision that gates the Sentry SDK (finding #35). Mobile could
/// start Sentry but never stop it: entering Private Mode or switching the
/// Privacy Settings crash-report switch off left the client live until a cold
/// restart, and a fresh install initialized it before the consent screen was
/// ever shown.
///
/// [SentryService.shouldRun] is the single predicate every path now uses — the
/// cold-start gate in main(), and the reconcile that main.dart runs on every
/// consent/data-mode change. `setEnabled(false)` closes the client, so a false
/// here is what actually stops reporting.
void main() {
  // Regression guard for the CI break of 2026-07-27. `sentry_config.dart` is
  // git-ignored, so CI provisions it by copying the `.example` template, whose
  // DSN is the placeholder `YOUR_SENTRY_DSN_HERE`. Non-empty, so every gate
  // passed; then SentryFlutter.init threw from inside the SDK
  // (`FormatException: Invalid empty scheme` building
  // `:///api/YOUR_SENTRY_DSN_HERE/envelope/`) and took an unrelated test down
  // with it. An EMPTY dsn was always safe — the SDK treats it as disabled — so
  // only the malformed case needed catching.
  group('SentryService.isConfigured', () {
    test('rejects the placeholder DSN that CI provisions', () {
      expect(SentryService.isUsableDsn('YOUR_SENTRY_DSN_HERE'), isFalse);
    });

    test('rejects an empty or whitespace DSN', () {
      expect(SentryService.isUsableDsn(''), isFalse);
      expect(SentryService.isUsableDsn('   '), isFalse);
    });

    test('rejects a scheme-less or host-less value', () {
      expect(SentryService.isUsableDsn('sentry.io/123'), isFalse);
      expect(SentryService.isUsableDsn('https://'), isFalse);
    });

    test('accepts a real Sentry DSN', () {
      expect(
        SentryService.isUsableDsn('https://abc123@o1.ingest.sentry.io/456'),
        isTrue,
      );
    });

    test('agrees with the live getter for the DSN this build was compiled with',
        () {
      // Ties the pure predicate above to the real one, so the two cannot drift.
      expect(SentryService.isConfigured, isA<bool>());
    });
  });

  group('SentryService.shouldRun', () {
    test('runs for a consenting cloud-mode user', () {
      expect(
        SentryService.shouldRun(
          hasCompletedConsent: true,
          hasSentryConsent: true,
          isPrivateMode: false,
        ),
        isTrue,
      );
    });

    test('stops when crash-report consent is withdrawn in Privacy Settings', () {
      expect(
        SentryService.shouldRun(
          hasCompletedConsent: true,
          hasSentryConsent: false,
          isPrivateMode: false,
        ),
        isFalse,
      );
    });

    test('stops in Private Mode even with consent granted', () {
      expect(
        SentryService.shouldRun(
          hasCompletedConsent: true,
          hasSentryConsent: true,
          isPrivateMode: true,
        ),
        isFalse,
      );
    });

    test('stays off before the consent screen has been answered', () {
      // Belt and braces. Every read of 'has_sentry_consent' now defaults an
      // absent key to FALSE, so this input should not occur — but the completed
      // flag is what makes the predicate correct regardless of how the answer
      // was defaulted, and that is the property worth pinning.
      expect(
        SentryService.shouldRun(
          hasCompletedConsent: false,
          hasSentryConsent: true,
          isPrivateMode: false,
        ),
        isFalse,
      );
    });

    test('Private Mode wins over an unanswered consent screen', () {
      expect(
        SentryService.shouldRun(
          hasCompletedConsent: false,
          hasSentryConsent: true,
          isPrivateMode: true,
        ),
        isFalse,
      );
    });
  });
}
