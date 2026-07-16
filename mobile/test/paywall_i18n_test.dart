// Guards the two ways the paywall can lie to a non-Eurozone user, both of
// which slang's `fallback_strategy: base_locale` hides at build time:
//
//  1. A locale silently missing a whole block (the Arabic `icloudSync` gap:
//     the E2E-encryption consent dialog rendered in English).
//  2. A price baked into a translation or a Dart literal instead of coming
//     from StoreKit's already-localized `StoreProduct.priceString`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = ['en', 'it', 'es', 'de', 'ar'];
const _baseLocale = 'en';

Map<String, dynamic> _loadLocale(String locale) =>
    jsonDecode(File('lib/i18n/$locale.i18n.json').readAsStringSync())
        as Map<String, dynamic>;

/// Flattens the nested JSON into dotted leaf paths, e.g. `subscription.proName`.
Set<String> _leafKeys(dynamic node, [String prefix = '']) {
  if (node is! Map<String, dynamic>) return {prefix};
  return node.entries
      .expand(
        (e) => _leafKeys(e.value, prefix.isEmpty ? e.key : '$prefix.${e.key}'),
      )
      .toSet();
}

/// A currency symbol next to a digit. `\$e` (escaped Dart interpolation, which
/// appears in real strings) must not match, so `$` requires a following digit.
final _currencyAmount = RegExp(r'[€£¥₹]\s*\d|\d\s*[€£¥₹]|\$\d');

Iterable<String> _leafValues(dynamic node) sync* {
  if (node is String) {
    yield node;
  } else if (node is Map<String, dynamic>) {
    for (final v in node.values) {
      yield* _leafValues(v);
    }
  }
}

void main() {
  group('locale key parity', () {
    final baseKeys = _leafKeys(_loadLocale(_baseLocale));

    for (final locale in _locales.where((l) => l != _baseLocale)) {
      test('$locale defines every key the base locale defines', () {
        final keys = _leafKeys(_loadLocale(locale));

        expect(
          baseKeys.difference(keys),
          isEmpty,
          reason:
              '$locale is missing keys present in $_baseLocale. '
              'fallback_strategy: base_locale makes this render in English '
              'instead of failing the build.',
        );
        expect(
          keys.difference(baseKeys),
          isEmpty,
          reason: '$locale defines keys $_baseLocale does not.',
        );
      });
    }

    test('every locale carries the iCloud E2E-encryption consent block', () {
      for (final locale in _locales) {
        final icloudSync = _loadLocale(locale)['icloudSync'];

        expect(
          icloudSync,
          isA<Map<String, dynamic>>(),
          reason: '$locale has no icloudSync block',
        );
        // The disclosure gates enabling cloud sync and carries the
        // irreversible iCloud-Keychain data-loss warning.
        for (final key in [
          'disclosureTitle',
          'disclosureBody',
          'disclosureAccept',
        ]) {
          expect(
            (icloudSync as Map<String, dynamic>)[key],
            isA<String>(),
            reason: '$locale is missing icloudSync.$key',
          );
        }
      }
    });
  });

  group('no fabricated prices', () {
    test('no subscription string hardcodes a currency amount', () {
      for (final locale in _locales) {
        final offenders = _leafValues(
          _loadLocale(locale)['subscription'],
        ).where(_currencyAmount.hasMatch).toList();

        expect(
          offenders,
          isEmpty,
          reason:
              '$locale hardcodes a price in the subscription strings. Prices '
              'must come from StoreProduct.priceString, which is already '
              'localized and storefront-correct.',
        );
      }
    });

    test('the paywall surfaces hardcode no currency amount', () {
      for (final path in [
        'lib/ui/screens/subscription_screen.dart',
        'lib/ui/widgets/pro_features_modal.dart',
      ]) {
        expect(
          _currencyAmount.hasMatch(File(path).readAsStringSync()),
          isFalse,
          reason:
              '$path contains a hardcoded currency amount. A missing price is '
              'acceptable; a wrong one is not.',
        );
      }
    });
  });
}
