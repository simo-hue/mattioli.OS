import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/providers/tutorial_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('tutorial providers', () {
    test('keep Supabase and Private tutorial state separate', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(tutorialProvider), isFalse);

      await container.read(tutorialProvider.notifier).setTutorialSeen(true);
      expect(prefs.getBool('has_seen_tutorial_supabase'), isTrue);
      expect(container.read(tutorialProvider), isTrue);

      await container.read(activeDataModeProvider.notifier).enterPrivateMode();
      expect(container.read(tutorialProvider), isFalse);

      await container.read(tutorialProvider.notifier).setTutorialSeen(true);
      expect(prefs.getBool('has_seen_tutorial_private'), isTrue);
      expect(container.read(tutorialProvider), isTrue);

      await container.read(activeDataModeProvider.notifier).enterSupabaseMode();
      expect(container.read(tutorialProvider), isTrue);
    });

    test(
      'uses legacy Supabase keys without leaking them to Private mode',
      () async {
        SharedPreferences.setMockInitialValues({
          'has_seen_tutorial': true,
          'has_seen_goals_tutorial': true,
          'has_seen_stats_tutorial': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        expect(container.read(tutorialProvider), isTrue);
        expect(container.read(goalsTutorialProvider), isTrue);
        expect(container.read(statsTutorialProvider), isTrue);

        await container
            .read(activeDataModeProvider.notifier)
            .enterPrivateMode();

        expect(container.read(tutorialProvider), isFalse);
        expect(container.read(goalsTutorialProvider), isFalse);
        expect(container.read(statsTutorialProvider), isFalse);
      },
    );
  });
}
