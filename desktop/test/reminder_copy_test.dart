// Unit tests for target-aware habit-reminder copy selection
// (DesktopNotificationService.reminderBody). A LIMIT ("at most N") habit must
// never get achievement / "complete your habit" copy — on a day the user
// succeeds by consuming nothing, that nudge inverts the goal — so it uses
// restraint-framed copy instead. The branch ships DARK behind
// DesktopTargetsConfig.enabled; these tests drive it via the pure function's
// `featureEnabled` override so the enabled path is exercised without flipping
// the compile-time flag.

import 'package:evolve_desktop/features/settings/data/desktop_notification_service.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  test('feature ON + limit habit → restraint copy (not the default body)', () {
    final body = DesktopNotificationService.reminderBody(
      isLimit: true,
      featureEnabled: true,
    );
    expect(body, t.notif.limitReminderBody);
    expect(body, isNot(t.notif.habitReminderBody));
  });

  test('feature ON + non-limit habit → default achievement body', () {
    final body = DesktopNotificationService.reminderBody(
      isLimit: false,
      featureEnabled: true,
    );
    expect(body, t.notif.habitReminderBody);
  });

  test('feature OFF + limit habit → default body (dark path unchanged)', () {
    final body = DesktopNotificationService.reminderBody(
      isLimit: true,
      featureEnabled: false,
    );
    expect(body, t.notif.habitReminderBody);
  });

  test('limit body is non-empty and distinct from the default body', () {
    expect(t.notif.limitReminderBody.trim(), isNotEmpty);
    expect(t.notif.limitReminderBody, isNot(t.notif.habitReminderBody));
  });
}
