// Which transport the AI Coach uses, and why the order of the checks matters.
//
// App Store Guideline 3.1.1 rejected the app because a user-supplied OpenRouter
// key unlocked paid functionality. The fix is two transports: Standard (our Edge
// Function, our key, unlocked by the IAP) and BYOK (the user's own key, free).
// This file pins the routing between them.
//
// The sharp edge is private mode, for two independent reasons:
//
//  1. It force-injects `isPro: true` — in the sync seed
//     (settings_provider.dart:220-230), the async row load (:544), AND at the DB
//     layer on every settings write (private_local_database.dart:833-843). The
//     `isPro` the client reads and the `profiles.is_pro` the proxy checks are
//     different facts that happen to share a name.
//  2. `Supabase.initialize` is skipped entirely in private mode
//     (main.dart:72-77), so `Supabase.instance.client` does not return null
//     there — it THROWS.
//
// So reading entitlement before data mode is not a 401. It is a crash, for a
// subscription the user was told they had.
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/coach_endpoint.dart';

void main() {
  group('resolveCoachMode', () {
    test('a Pro user with a session gets Standard — our key, no setup', () {
      expect(
        resolveCoachMode(
          isPrivate: false,
          isPro: true,
          hasSession: true,
          hasKey: false,
        ),
        CoachMode.standard,
      );
    });

    test('PRIVATE MODE NEVER GETS STANDARD, whatever else is true', () {
      // The reason this function exists. Private mode reports isPro: true and
      // may well have a session-shaped value lying around; neither may route it
      // at a proxy that cannot serve it.
      for (final hasSession in [true, false]) {
        for (final hasKey in [true, false]) {
          final mode = resolveCoachMode(
            isPrivate: true,
            isPro: true, // as private mode ALWAYS reports
            hasSession: hasSession,
            hasKey: hasKey,
          );
          expect(
            mode,
            hasKey ? CoachMode.byok : null,
            reason: 'private mode must never reach Standard '
                '(hasSession: $hasSession, hasKey: $hasKey)',
          );
        }
      }
    });

    test('a free cloud user gets BYOK — the coach is not Pro-only any more', () {
      // Guideline 3.1.1: the coach used to be Pro-only AND require your own key,
      // so the key stacked on top of the purchase as a second unlock. Now
      // nothing is unlocked by a key, because nothing is locked.
      expect(
        resolveCoachMode(
          isPrivate: false,
          isPro: false,
          hasSession: true,
          hasKey: true,
        ),
        CoachMode.byok,
      );
    });

    test('a Pro user mid-refresh falls back to BYOK rather than failing', () {
      // currentSession is null while the token refreshes. Standard picks up
      // again on the next resolve; meanwhile a usable key should still work.
      expect(
        resolveCoachMode(
          isPrivate: false,
          isPro: true,
          hasSession: false,
          hasKey: true,
        ),
        CoachMode.byok,
      );
    });

    test('nothing configured means setup, not a silent failure', () {
      expect(
        resolveCoachMode(
          isPrivate: false,
          isPro: false,
          hasSession: true,
          hasKey: false,
        ),
        isNull,
      );
      expect(
        resolveCoachMode(
          isPrivate: true,
          isPro: true,
          hasSession: false,
          hasKey: false,
        ),
        isNull,
      );
    });

    test('a subscriber keeps Standard even with a key of their own stored', () {
      // They paid for "no setup"; an old key must not silently bill them for
      // what their subscription already covers.
      expect(
        resolveCoachMode(
          isPrivate: false,
          isPro: true,
          hasSession: true,
          hasKey: true,
        ),
        CoachMode.standard,
      );
    });
  });

  group('CoachEndpoint', () {
    test('Standard resolves its token per send and never captures it', () async {
      // A header frozen at construction 401s forever after the first refresh,
      // with no way back short of restarting the app.
      var current = 'jwt-1';
      final endpoint = CoachEndpoint(
        mode: CoachMode.standard,
        url: Uri.parse('https://example.supabase.co/functions/v1/ai-coach'),
        host: 'example.supabase.co',
        authorization: () async => current,
        sendModel: false,
      );

      expect(await endpoint.authorization(), 'jwt-1');
      current = 'jwt-2-after-refresh';
      expect(
        await endpoint.authorization(),
        'jwt-2-after-refresh',
        reason: 'the same endpoint must see the rotated token',
      );
    });

    test('Standard names no model; BYOK does', () {
      // Standard must not: the server picks the model AND pins the provider that
      // serves it. Letting the client choose would hand it our bill and break
      // the recipient list our privacy policy commits to under 5.1.2(i).
      final standard = CoachEndpoint(
        mode: CoachMode.standard,
        url: Uri.parse('https://example.supabase.co/functions/v1/ai-coach'),
        host: 'example.supabase.co',
        authorization: () async => 'jwt',
        sendModel: false,
      );
      final byok = CoachEndpoint(
        mode: CoachMode.byok,
        url: Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        host: 'openrouter.ai',
        authorization: () async => 'sk-or-mine',
        sendModel: true,
      );

      expect(standard.sendModel, isFalse);
      expect(byok.sendModel, isTrue, reason: 'BYOK pays for its own model');
    });

    test('each mode probes the host it actually dials', () {
      // The preflight was hardcoded to openrouter.ai, so in Standard mode it
      // tested a server we never talk to — reporting "you're offline" to someone
      // whose connection was fine.
      final standard = CoachEndpoint(
        mode: CoachMode.standard,
        url: Uri.parse('https://example.supabase.co/functions/v1/ai-coach'),
        host: 'example.supabase.co',
        authorization: () async => 'jwt',
        sendModel: false,
      );
      expect(standard.host, standard.url.host);
      expect(standard.host, isNot('openrouter.ai'));
    });
  });
}
