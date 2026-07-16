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
      // A fresh install: 'has_sentry_consent' is absent and reads back as true,
      // so only the completed flag keeps the cold start silent.
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
