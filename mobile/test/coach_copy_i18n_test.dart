// Guards the AI Coach copy that App Store Guideline 3.1.1 actually rejected.
//
// The reviewer, on an iPad Air, read "Aggiungi la tua chiave API di OpenRouter"
// and concluded the app "uses API keys to unlock or enable paid functionality".
// They were reading the words, not the architecture — so the words are the fix,
// and they are what this file pins.
//
// Two failure modes, both invisible at build time because slang's
// `fallback_strategy: base_locale` silently serves English for a missing key:
//
//  1. A locale left on the old framing while the others were reframed.
//  2. A locale missing the new keys entirely — which renders English copy to,
//     say, an Italian reviewer, and English is the one language where the old
//     string never looked wrong enough to notice.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['en', 'it', 'es', 'de', 'ar'];
const _baseLocale = 'en';

Map<String, dynamic> _loadLocale(String locale) =>
    jsonDecode(File('lib/i18n/$locale.i18n.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _block(Map<String, dynamic> root, List<String> path) {
  dynamic node = root;
  for (final key in path) {
    node = (node as Map<String, dynamic>)[key];
  }
  return node as Map<String, dynamic>;
}

void main() {
  group('the reframed coach copy exists natively in every locale', () {
    // Not "the key resolves" — slang would resolve it to English. This asserts
    // each locale DEFINES it, which is the only version of the question that
    // catches a missed translation.
    for (final block in [
      ['ai', 'apiKey'],
      ['ai', 'coachModes'],
    ]) {
      test(block.join('.'), () {
        final expected = _block(_loadLocale(_baseLocale), block).keys.toSet();
        for (final locale in _locales) {
          expect(
            _block(_loadLocale(locale), block).keys.toSet(),
            expected,
            reason:
                '$locale.$block drifted from $_baseLocale — a missing key here '
                'renders ENGLISH to that user, silently',
          );
        }
      });
    }
  });

  test('the new keys the reframe depends on are actually present', () {
    // A guard against this test passing vacuously: if the reframe were reverted
    // wholesale, the parity check above would still pass (all five locales
    // consistently old). Name the keys the new UI reads.
    final apiKey = _block(_loadLocale(_baseLocale), ['ai', 'apiKey']).keys;
    expect(
      apiKey,
      containsAll([
        // The sheet is Private-mode only (`if (isPrivate)` guards its one
        // caller), and Private never resolves to CoachMode.standard — so this
        // branch cannot currently render. Kept, and kept HONEST, because the
        // guard is one edit from moving.
        'descriptionProActive',
        'setupBodyPrivate', // the chat card, where Pro is not an option
      ]),
    );
    final modes = _block(_loadLocale(_baseLocale), ['ai', 'coachModes']).keys;
    expect(
      modes,
      containsAll(['activeRowTitle', 'byokShortName', 'notConfigured']),
    );
  });

  test('THE REJECTED STRING IS GONE, in the language it was rejected in', () {
    // Verbatim from the 2026-07-17 rejection. If this ever comes back, the app
    // is shipping the exact screen a reviewer already refused once.
    expect(
      _block(_loadLocale('it'), ['ai', 'apiKey'])['setupTitle'],
      isNot(contains('chiave API')),
      reason: 'the key must be presented as an account you connect, not a key '
          'that unlocks',
    );
    expect(
      _block(_loadLocale('en'), ['ai', 'apiKey'])['setupTitle'],
      isNot(contains('API key')),
    );
  });

  test('no locale claims the coach REQUIRES the user to bring a key', () {
    // The load-bearing claim. It was true when the coach was BYOK-only; with
    // the Pro-funded proxy it is false, and "you must supply a key to use the
    // paid feature" is precisely the sentence Guideline 3.1.1 forbids.
    //
    // Matched structurally rather than by translated prose: the old copy put
    // "AI Coach" and a possessive "your own …" in one sentence. English is the
    // source every other locale was written from, so pinning it pins the frame.
    final en = _block(_loadLocale('en'), ['ai', 'apiKey']);
    for (final key in ['setupTitle', 'setupBody']) {
      expect(
        en[key],
        isNot(matches(RegExp(r'runs on your own', caseSensitive: false))),
        reason: 'ai.apiKey.$key still frames BYOK as how the coach works, '
            'rather than as what Evolve Pro does for you',
      );
    }
  });

  test('the dead apiKeyMissingFull string is gone from every locale', () {
    // It belonged to `OpenRouterService.generateResponse`, removed 2026-07-17:
    // unused in production, and it bypassed `coachEndpointProvider` entirely, so
    // it could only ever reach OpenRouter on the user's own key — never the
    // Pro-funded proxy. A leftover string invites a leftover caller.
    for (final locale in _locales) {
      expect(
        _block(_loadLocale(locale), ['ai', 'openRouter']),
        isNot(contains('apiKeyMissingFull')),
        reason: '$locale still carries the removed string',
      );
    }
  });

  test('no account-mode surface offers BYOK, in any locale', () {
    // BYOK is Private-mode ONLY. `resolveCoachMode` (coach_endpoint.dart) is
    // explicit — "account mode is Standard-only and Pro-gated: a signed-in user
    // cannot bring their own key" — and the key-entry row in Settings is behind
    // `if (isPrivate)`, so there is no field to paste one into.
    //
    // These three strings render exclusively in account mode:
    //   * subscription.features.smartSuggestions        -> the paywall's feature
    //     list, built only in the `else if (!isPro)` branch;
    //   * subscription.advancedTrendAnalysisAndSmartAi  -> the Pro upsell modal;
    //   * ai.apiKey.setupBody                           -> the chat empty state,
    //     gated on `canUseStandardCoach`, which IS "not private".
    //
    // Each of them promised a free bring-your-own-key alternative that account
    // mode does not have. Two of the three are purchase surfaces, so the false
    // claim sat on the exact screen Guideline 3.1.2 is read against — on an app
    // already rejected twice over its paywall copy. Mentioning OpenRouter at
    // all here is the smell; nothing on these screens has any business naming
    // it, because nothing on these screens can use it.
    // The last two never render today — `standardNeedsPro` lost its caller when
    // `not_subscribed` started throwing to the Pro modal, and
    // `descriptionProActive` sits in a branch the Private-only sheet cannot
    // reach. They are pinned anyway, on this file's own stated principle: "a
    // leftover string invites a leftover caller". Both are one `return` from
    // shipping the exact claim this test exists to keep out, in five languages.
    const accountModeStrings = <List<String>>[
      ['subscription', 'features', 'smartSuggestions'],
      ['subscription', 'advancedTrendAnalysisAndSmartAi'],
      ['ai', 'apiKey', 'setupBody'],
      ['ai', 'apiKey', 'descriptionProActive'],
      ['ai', 'coachModes', 'standardNeedsPro'],
    ];
    for (final locale in _locales) {
      final root = _loadLocale(locale);
      for (final path in accountModeStrings) {
        final value =
            _block(root, path.sublist(0, path.length - 1))[path.last] as String;
        final lower = value.toLowerCase();
        expect(
          lower,
          isNot(contains('openrouter')),
          reason: '$locale ${path.join(".")} names OpenRouter on an '
              'account-mode surface, where the user cannot use their own key',
        );
        // The brand name is the obvious tell, but the claim survives a
        // paraphrase — "connect your own account for free" names no brand and
        // is the same lie. The offer is always a free one, so the price word is
        // the second tell, in each language the app actually ships.
        for (final freebie in const [
          'free', // en
          'gratis', // it / es / de
          'gratuit', // it / es — STEM: gratuita/gratuite evade 'gratuito'
          'kostenlos', // de
          'مجان', // ar (stem of مجانًا / مجاني)
        ]) {
          expect(
            lower,
            isNot(contains(freebie)),
            reason: '$locale ${path.join(".")} offers something "free" on a '
                'purchase surface — the BYOK claim reads exactly like this '
                'once the brand name is paraphrased away',
          );
        }
      }
    }
  });
}
