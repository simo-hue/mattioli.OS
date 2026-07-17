// The Standard-mode error vocabulary — mobile must map the proxy's error codes
// as completely as desktop does over the SAME Edge Function.
//
// THE BUG THIS FIXES: mobile's map had no arm for the proxy's `unauthorized`
// code (a 401 = expired session), so it fell through to `standardNeedsPro`.
// A Pro user whose JWT lapsed mid-send was told "included with Evolve Pro" — buy
// the subscription they already hold. Server errors (500/502) rendered as a raw
// "API error: 502". Desktop got these right; mobile, the app Apple reviews, did
// not. This pins the parity.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/coach_endpoint.dart';
import 'package:mattioli_os/core/openrouter_service.dart';
import 'package:mattioli_os/i18n/translations.g.dart';

String _body(String code) => jsonEncode({
      'error': {'code': code, 'message': 'x'},
    });

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  group('Standard mode maps the proxy error codes', () {
    test('EXPIRED SESSION IS NOT "buy Pro"', () {
      // The regression. unauthorized (401) must read as "sign in again", never
      // as a pitch for a subscription the user already has.
      final msg = errorMessageFor(CoachMode.standard, 401, _body('unauthorized'));
      expect(msg, t.ai.coachModes.standardSessionExpired);
      expect(msg, isNot(t.ai.coachModes.standardNeedsPro));
    });

    test('not_subscribed is "buy Pro"', () {
      expect(
        errorMessageFor(CoachMode.standard, 403, _body('not_subscribed')),
        t.ai.coachModes.standardNeedsPro,
      );
    });

    test('server / upstream failures read as "on us", not a raw code', () {
      for (final code in [
        'not_configured',
        'server_error',
        'upstream_unavailable',
        'upstream_rate_limited',
        'upstream_error',
      ]) {
        expect(
          errorMessageFor(CoachMode.standard, 502, _body(code)),
          t.ai.coachModes.standardUnavailable,
          reason: '$code is our problem, not the user\'s',
        );
      }
    });

    test('rate_limited and context_too_long keep their own messages', () {
      expect(
        errorMessageFor(CoachMode.standard, 429, _body('rate_limited')),
        t.ai.coachModes.standardRateLimited,
      );
      expect(
        errorMessageFor(CoachMode.standard, 413, _body('context_too_long')),
        t.ai.openRouter.contextTooLong,
      );
    });

    test('falls back to the status when the body is not ours', () {
      // A Supabase gateway or ingress can answer before our code runs; the
      // actionable cases must still be separated by status.
      expect(errorMessageFor(CoachMode.standard, 401, 'gateway noise'),
          t.ai.coachModes.standardSessionExpired);
      expect(errorMessageFor(CoachMode.standard, 403, 'gateway noise'),
          t.ai.coachModes.standardNeedsPro);
      expect(errorMessageFor(CoachMode.standard, 503, 'gateway noise'),
          t.ai.coachModes.standardUnavailable);
    });
  });

  group('BYOK mode', () {
    test('a rejected key reads as "check your key", not "buy Pro"', () {
      // BYOK 401/403 means the user's OWN key is bad — never a subscription
      // prompt, which they are not on.
      final msg = errorMessageFor(CoachMode.byok, 401, '');
      expect(msg, t.ai.openRouter.apiKeyInvalid);
      expect(msg, isNot(t.ai.coachModes.standardNeedsPro));
    });
  });
}
