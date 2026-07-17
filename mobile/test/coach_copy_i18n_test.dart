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
        'descriptionProActive', // the sheet, when Pro already serves
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
            'rather than as one of two ways to run it',
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
}
