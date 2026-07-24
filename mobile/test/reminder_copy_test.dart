// Unit tests for target-aware habit-reminder copy selection
// (NotificationService.reminderBody). A LIMIT ("at most N") habit must never get
// achievement / "do it!" copy — on a day the user succeeds by consuming nothing,
// that nudge inverts the goal — so it uses restraint-framed copy instead. The
// branch ships DARK behind TargetsConfig.enabled; these tests drive it via the
// pure function's `featureEnabled` override so the enabled path is exercised
// without flipping the compile-time flag.

import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/notifications.dart';
import 'package:mattioli_os/i18n/translations.g.dart';

void main() {
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  const title = 'Coffee';

  List<String> limitMessages() => [
        t.notifications.limitReminderMessage1(title: title),
        t.notifications.limitReminderMessage2(title: title),
        t.notifications.limitReminderMessage3(title: title),
      ];

  List<String> motivationalMessages() => [
        for (var i = 1; i <= 15; i++)
          // Build the full motivational rotation by cycling the pure function
          // over every seed with the feature off (its production default).
          NotificationService.reminderBody(
            title,
            isLimit: false,
            rotationSeed: i - 1,
            featureEnabled: false,
          ),
      ];

  test('feature ON + limit habit → restraint copy, never motivational', () {
    final limit = limitMessages().toSet();
    final motivational = motivationalMessages().toSet();

    // Every rotation slot of a limit habit must be one of the restraint lines
    // and never leak into the motivational pool.
    for (var seed = 0; seed < 9; seed++) {
      final body = NotificationService.reminderBody(
        title,
        isLimit: true,
        rotationSeed: seed,
        featureEnabled: true,
      );
      expect(limit, contains(body));
      expect(motivational, isNot(contains(body)));
    }
  });

  test('feature ON + non-limit (count/duration) habit → motivational copy', () {
    final motivational = motivationalMessages().toSet();
    final body = NotificationService.reminderBody(
      title,
      isLimit: false,
      rotationSeed: 3,
      featureEnabled: true,
    );
    expect(motivational, contains(body));
  });

  test('feature OFF + limit habit → motivational copy (dark path unchanged)', () {
    // With the flag dark (production default), a limit habit is indistinguishable
    // from any other: it keeps the existing motivational rotation.
    final motivational = motivationalMessages().toSet();
    for (var seed = 0; seed < 15; seed++) {
      final body = NotificationService.reminderBody(
        title,
        isLimit: true,
        rotationSeed: seed,
        featureEnabled: false,
      );
      expect(motivational, contains(body));
    }
  });

  test('selection is deterministic for a given seed', () {
    final a = NotificationService.reminderBody(
      title,
      isLimit: true,
      rotationSeed: 42,
      featureEnabled: true,
    );
    final b = NotificationService.reminderBody(
      title,
      isLimit: true,
      rotationSeed: 42,
      featureEnabled: true,
    );
    expect(a, b);
  });

  test('negative seed (hash can be negative) is handled without throwing', () {
    final body = NotificationService.reminderBody(
      title,
      isLimit: true,
      rotationSeed: -7,
      featureEnabled: true,
    );
    expect(limitMessages(), contains(body));
  });

  test('the three limit messages are distinct and non-empty', () {
    final msgs = limitMessages();
    expect(msgs.toSet().length, 3);
    for (final m in msgs) {
      expect(m.trim(), isNotEmpty);
      expect(m, contains(title));
    }
  });
}
