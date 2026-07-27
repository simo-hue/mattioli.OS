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

  group('a server profile merge coerces live values to defaults', () {
    // The failure: `_syncFromSupabase` layers the `profiles` row onto the
    // settings the device is already showing, and three of those assignments
    // bypass `SettingsCodec` — which exists precisely so that an unparseable
    // value falls back instead of being invented. `profiles` has no CHECK
    // constraint on any of them (migrations/20260623_add_profiles.sql), so
    // nothing upstream guarantees they parse.
    //
    // This is the LIVE site. The same shape in `_applySyncedSettings` is inert:
    // its base is always `_privateBaseSettings()` -> `_defaultSettings()`, whose
    // accent is already `defaultAccentColor`, so "coerce to default" and "leave
    // base standing" produce the identical Color there and nothing is ever
    // written back (the private write path diffs). Here the base is the user's
    // real, chosen value.

    AppSettings live({
      Color accent = const Color(0xFFEAB308), // Amber
      String morning = '09:00',
    }) =>
        AppSettings(
          themeMode: 'dark',
          accentColor: accent,
          defaultCalendarView: 'settimana',
          hapticFeedback: true,
          language: 'en',
          timeFormat24h: true,
          aiSuggestions: false,
          isPro: true,
          habitReminders: true,
          goalDeadlines: true,
          aiInsights: false,
          weeklyReports: false,
          focusMode: false,
          milestones: true,
          deepWorkInsights: false,
          biometricLock: false,
          eveningReview: true,
          verificationNudges: true,
          verificationCelebrations: false,
          verificationFailureSummary: false,
          morningBriefTime: morning,
          eveningReviewTime: '21:00',
          statsHabitFilter: 'active',
        );

    test('an unparseable server accent repaints the user accent white', () {
      final merged = AppSettingsNotifier.mergeServerProfile(
        live(),
        {'accent_color': 'nope', 'is_pro': true},
      );

      expect(
        merged.accentColor,
        const Color(0xFFEAB308),
        reason: 'the accent the user picked was replaced with the seed white, '
            'and the caller persists this to pref_accent_color and pushes it '
            'back up — so the loss survives restarts and reaches every device',
      );
      // The exact string that would be written to `pref_accent_color` and sent
      // back to `profiles.accent_color`.
      expect(_hex(merged.accentColor), '#EAB308');
    });

    test('an unparseable server brief time reaches the reminder scheduler', () {
      final merged = AppSettingsNotifier.mergeServerProfile(
        live(),
        {'morning_brief_time': 'garbage', 'is_pro': true},
      );

      expect(
        merged.morningBriefTime,
        '09:00',
        reason: 'a malformed time reaches scheduleDailyHabitReminder, whose '
            'int.parse throws inside the try block that has already run '
            'cancelAll() — so every reminder and both briefs are cancelled and '
            'none are rescheduled, with only a log line to show for it',
      );
      expect(
        SettingsCodec.normalizeTimeOfDay(merged.morningBriefTime),
        isNotNull,
        reason: 'whatever survives the merge must be schedulable',
      );
    });

    test('two devices holding different accents disagree on one stored value',
        () {
      // The parity property. One `profiles` row, two phones that happen to be
      // showing different colours. Whatever the row says, the outcome must
      // depend on the STORED value alone — never on which device read it, and
      // never on the seed white.
      const deviceA = Color(0xFFEAB308); // Amber
      const deviceB = Color(0xFF3B82F6); // Blue

      // A value both can decode: they converge on it.
      expect(
        AppSettingsNotifier.mergeServerProfile(
          live(accent: deviceA),
          {'accent_color': '#10B981', 'is_pro': true},
        ).accentColor,
        AppSettingsNotifier.mergeServerProfile(
          live(accent: deviceB),
          {'accent_color': '#10B981', 'is_pro': true},
        ).accentColor,
      );

      // A value neither can decode: each keeps what it had. Coercing to the
      // default would make them "agree" — on white, having thrown away both
      // users' colours. Agreement is not the property; not inventing a value
      // is.
      expect(
        AppSettingsNotifier.mergeServerProfile(
          live(accent: deviceA),
          {'accent_color': '#GGGGGG', 'is_pro': true},
        ).accentColor,
        deviceA,
      );
      expect(
        AppSettingsNotifier.mergeServerProfile(
          live(accent: deviceB),
          {'accent_color': '#GGGGGG', 'is_pro': true},
        ).accentColor,
        deviceB,
      );
    });

    test('a valid server value still wins, and an absent one changes nothing',
        () {
      // The over-correction guard: "never trust the server" would pass the
      // tests above and break syncing outright.
      final applied = AppSettingsNotifier.mergeServerProfile(
        live(),
        {
          'accent_color': '#3B82F6',
          'morning_brief_time': '07:30',
          'theme_mode': 'light',
          'is_pro': true,
        },
      );
      expect(applied.accentColor, const Color(0xFF3B82F6));
      expect(applied.morningBriefTime, '07:30');
      expect(applied.themeMode, 'light');

      final untouched =
          AppSettingsNotifier.mergeServerProfile(live(), {'is_pro': true});
      expect(untouched.accentColor, const Color(0xFFEAB308));
      expect(untouched.morningBriefTime, '09:00');
      expect(untouched.themeMode, 'dark');
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
