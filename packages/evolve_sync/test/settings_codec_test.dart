// One shared parser per wire format. These tests pin the two disagreements that
// existed when each app had its own: `theme_mode` resolving in opposite
// directions, and `'italiano'` meaning different things on the two platforms.
import 'package:evolve_sync/evolve_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('theme_mode', () {
    test('unknown input follows the device instead of guessing', () {
      // Desktop used to resolve not-'light' to DARK and mobile not-'dark' to
      // LIGHT, so one stored value rendered a dark Mac and a light iPhone.
      expect(SettingsCodec.resolveIsDark('system', platformIsDark: true), isTrue);
      expect(SettingsCodec.resolveIsDark('system', platformIsDark: false), isFalse);
      expect(SettingsCodec.resolveIsDark(null, platformIsDark: false), isFalse);
      expect(SettingsCodec.resolveIsDark('nonsense', platformIsDark: true), isTrue);
    });

    test('explicit modes ignore the platform', () {
      expect(SettingsCodec.resolveIsDark('dark', platformIsDark: false), isTrue);
      expect(SettingsCodec.resolveIsDark('light', platformIsDark: true), isFalse);
    });

    test('both platforms now agree for every legal column value', () {
      for (final v in SettingsCodec.themeModes) {
        final a = SettingsCodec.resolveIsDark(v, platformIsDark: true);
        final b = SettingsCodec.resolveIsDark(v, platformIsDark: true);
        expect(a, b);
      }
      expect(SettingsCodec.normalizeThemeMode('DARK'), 'dark');
      expect(SettingsCodec.normalizeThemeMode('true'), 'dark');
    });
  });

  group('language', () {
    test('legacy display labels map to their real code on BOTH platforms', () {
      // 'italiano' used to mean 'it' on macOS and 'system' on iOS.
      expect(SettingsCodec.normalizeLanguage('italiano'), 'it');
      expect(SettingsCodec.normalizeLanguage('english'), 'en');
      expect(SettingsCodec.normalizeLanguage('spagnolo'), 'es');
      expect(SettingsCodec.normalizeLanguage('tedesco'), 'de');
      expect(SettingsCodec.normalizeLanguage('arabo'), 'ar');
    });

    test('canonical codes and locale variants round-trip', () {
      for (final c in SettingsCodec.languageCodes) {
        expect(SettingsCodec.normalizeLanguage(c), c);
      }
      expect(SettingsCodec.normalizeLanguage('en_GB'), 'en');
      expect(SettingsCodec.normalizeLanguage(null), 'system');
      expect(SettingsCodec.normalizeLanguage('klingon'), 'system');
    });
  });

  group('time of day', () {
    test('defaults match the schema, not desktop\'s old field initialisers', () {
      // Desktop said 08:00/20:30, which moved the iPhone's briefs earlier.
      expect(SettingsCodec.defaultMorningBriefTime, '09:00');
      expect(SettingsCodec.defaultEveningReviewTime, '21:00');
    });

    test('malformed times are rejected rather than silently rescheduled', () {
      expect(SettingsCodec.normalizeTimeOfDay('9:05'), '09:05');
      expect(SettingsCodec.normalizeTimeOfDay('23:59'), '23:59');
      expect(SettingsCodec.normalizeTimeOfDay('24:00'), isNull);
      expect(SettingsCodec.normalizeTimeOfDay('9.05'), isNull);
      expect(SettingsCodec.normalizeTimeOfDay(''), isNull);
    });
  });

  group('accent colour', () {
    test('accepts both apps\' spellings and normalises to #RRGGBB', () {
      expect(SettingsCodec.normalizeAccentColor('#ff9500'), '#FF9500');
      expect(SettingsCodec.normalizeAccentColor('FF9500'), '#FF9500');
      expect(SettingsCodec.normalizeAccentColor('#FFFF9500'), '#FF9500');
      expect(SettingsCodec.normalizeAccentColor('nope'), isNull);
    });
  });
}
