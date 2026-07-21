// iOS must parse shared settings values the SAME way macOS does.
//
// Both apps used to carry their own parsers and they disagreed on real inputs:
// `theme_mode` resolved dark-vs-light by opposite defaults, and the legacy
// language label `'italiano'` meant `'it'` on macOS but `'system'` here. One
// stored value, two different apps on screen. `SettingsCodec` is now the single
// parser; these tests pin iOS to it, including the constants iOS seeds from.

import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/providers/settings_provider.dart';

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}';

void main() {
  group('AppLanguagePreference delegates to the shared codec', () {
    test('legacy labels resolve the way macOS resolves them', () {
      // The divergence that started this: iOS sent 'italiano' to system.
      expect(AppLanguagePreference.normalize('italiano'), 'it');
      expect(AppLanguagePreference.normalize('Italiano'), 'it');
      expect(AppLanguagePreference.normalize('deutsch'), 'de');
      expect(AppLanguagePreference.normalize('español'), 'es');
      expect(AppLanguagePreference.normalize('arabic'), 'ar');
      expect(AppLanguagePreference.normalize('english'), 'en');
    });

    test('codes, locale tags, empties and junk all agree with the codec', () {
      for (final input in const [
        null,
        '',
        'system',
        'it',
        'it_IT',
        'EN_us',
        'de',
        'es_ES',
        'ar_SA',
        'iphone',
        'macos',
        'klingon',
      ]) {
        expect(
          AppLanguagePreference.normalize(input),
          SettingsCodec.normalizeLanguage(input),
          reason: 'diverged on "$input"',
        );
      }
    });

    test('localeOverrideFor still returns null only for system', () {
      expect(AppLanguagePreference.localeOverrideFor('system'), isNull);
      expect(AppLanguagePreference.localeOverrideFor('nonsense'), isNull);
      expect(
        AppLanguagePreference.localeOverrideFor('italiano')?.languageCode,
        'it',
      );
    });
  });

  group('accent seed parity', () {
    test('the Dart seed IS SettingsCodec.defaultAccentColor', () {
      // The DB seeded #FFFFFF while the Dart default was #FAFAFA, so an
      // untouched profile hydrated to a different colour depending on which
      // side supplied the value.
      expect(
        _hex(AppSettingsNotifier.defaultAccentColor),
        SettingsCodec.defaultAccentColor,
      );
      expect(
        AppSettingsNotifier.premiumAccentColors.first,
        AppSettingsNotifier.defaultAccentColor,
      );
    });
  });

  group('readableAccent substitutes only when the accent is invisible', () {
    // The hazard: this used to run on every THEME CHANGE and persist its result,
    // so flipping the theme for a moment replaced the user's chosen colour and
    // pushed the replacement to all their devices. It is now paint-time only —
    // but it must also stop firing for colours that are perfectly legible.
    const palette = {
      'amber': Color(0xFFEAB308),
      'blue': Color(0xFF3B82F6),
      'emerald': Color(0xFF10B981),
      'violet': Color(0xFF8B5CF6),
      'pink': Color(0xFFEC4899),
      'orange': Color(0xFFF97316),
    };

    test('every non-white palette colour is left alone in BOTH themes', () {
      for (final entry in palette.entries) {
        for (final mode in const ['dark', 'light', 'system']) {
          for (final platformIsDark in const [true, false]) {
            expect(
              AppSettingsNotifier.readableAccent(
                entry.value,
                mode,
                platformIsDark: platformIsDark,
              ),
              entry.value,
              reason: '${entry.key} was rewritten for mode=$mode '
                  '(platformIsDark=$platformIsDark)',
            );
          }
        }
      }
    });

    test('white is substituted on light and kept on dark', () {
      const white = AppSettingsNotifier.defaultAccentColor;
      expect(
        AppSettingsNotifier.readableAccent(
          white,
          'light',
          platformIsDark: true,
        ),
        isNot(white),
      );
      expect(
        AppSettingsNotifier.readableAccent(white, 'dark', platformIsDark: false),
        white,
      );
    });

    test('black is substituted on dark and kept on light', () {
      const black = Color(0xFF000000);
      expect(
        AppSettingsNotifier.readableAccent(black, 'dark', platformIsDark: false),
        isNot(black),
      );
      expect(
        AppSettingsNotifier.readableAccent(black, 'light', platformIsDark: true),
        black,
      );
    });

    test("'system' follows the platform, not a hard-coded default", () {
      const white = AppSettingsNotifier.defaultAccentColor;
      // The old resolver read anything that was not 'dark' as light, so a
      // system-themed device on a dark OS got the wrong answer here.
      expect(
        AppSettingsNotifier.readableAccent(
          white,
          'system',
          platformIsDark: true,
        ),
        white,
      );
      expect(
        AppSettingsNotifier.readableAccent(
          white,
          'system',
          platformIsDark: false,
        ),
        isNot(white),
      );
    });
  });
}
