// "Restore defaults" must not downgrade a paying subscriber.
//
// The reset sweeps every SharedPreferences key starting with `pref_` or
// `notif_`, and the offline entitlement cache is called `pref_is_pro_$userId`
// — so it was swept too. On the next cold start with no network (or during a
// transient RevenueCat failure) `DesktopSubscriptionController.build` seeds
// `isPro` from that very key and `refresh()` deliberately leaves the seed alone
// when it throws: the AI Coach section disappears, the accent picker locks and
// the statistics gate fires for someone who is still paying.
//
// The cache is account-scoped and is deliberately NOT cleared on sign-out; a
// settings reset is not a claim about the subscription either.
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/settings/application/settings_form_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => LocaleSettings.setLocale(AppLocale.it));

  test(
    'resetSettingsToDefaults keeps the offline Pro entitlement cache',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pref_is_pro_user-a': true,
        // Ordinary settings that MUST still be swept, so the test cannot pass by
        // the reset having stopped clearing anything at all.
        'pref_focus_mode': true,
        'notif_habit_reminders': false,
      });
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsFormControllerProvider.notifier)
          .resetSettingsToDefaults();

      expect(
        prefs.getBool('pref_is_pro_user-a'),
        isTrue,
        reason: 'a settings reset says nothing about whether the user pays',
      );
      expect(
        prefs.getBool('pref_focus_mode'),
        isNull,
        reason: 'the reset still clears the settings it owns',
      );
      expect(prefs.getBool('notif_habit_reminders'), isNull);
    },
  );
}
