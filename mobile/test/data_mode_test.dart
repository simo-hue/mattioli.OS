import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/app_logger.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The reporting flag is a process-global static that build()/setMode() mutate.
  // Reset it before each test so assertions about the side effect are
  // independent of execution order.
  setUp(() {
    AppLogger.externalReportingDisabled = false;
  });

  Future<ProviderContainer> containerWith(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AppDataMode enum', () {
    test('isPrivate reflects the variant', () {
      expect(AppDataMode.private.isPrivate, isTrue);
      expect(AppDataMode.supabase.isPrivate, isFalse);
    });
  });

  group('ActiveDataModeNotifier default mode', () {
    test('defaults to Supabase when no pref is set', () async {
      final container = await containerWith({});

      expect(container.read(activeDataModeProvider), AppDataMode.supabase);
    });

    test('reads Private when the pref is preset', () async {
      final container = await containerWith({'active_data_mode': 'private'});

      expect(container.read(activeDataModeProvider), AppDataMode.private);
    });

    test('an unrecognised pref value falls back to Supabase', () async {
      final container = await containerWith({'active_data_mode': 'garbage'});

      expect(container.read(activeDataModeProvider), AppDataMode.supabase);
    });
  });

  group('ActiveDataModeNotifier transitions', () {
    test('enterPrivateMode persists the pref and flips state', () async {
      final container = await containerWith({});
      final prefs = container.read(sharedPrefsProvider);

      // build() ran for the Supabase default -> reporting stays enabled.
      expect(container.read(activeDataModeProvider), AppDataMode.supabase);

      await container.read(activeDataModeProvider.notifier).enterPrivateMode();

      expect(container.read(activeDataModeProvider), AppDataMode.private);
      expect(prefs.getString('active_data_mode'), 'private');
    });

    test('enterSupabaseMode reverses a Private start', () async {
      // has_sentry_consent:false keeps setMode() from late-initializing Sentry
      // when it leaves Private Mode.
      final container = await containerWith({
        'active_data_mode': 'private',
        'has_sentry_consent': false,
      });
      final prefs = container.read(sharedPrefsProvider);

      expect(container.read(activeDataModeProvider), AppDataMode.private);

      await container.read(activeDataModeProvider.notifier).enterSupabaseMode();

      expect(container.read(activeDataModeProvider), AppDataMode.supabase);
      expect(prefs.getString('active_data_mode'), 'supabase');
    });
  });

  group('ActiveDataModeNotifier reporting side effect', () {
    test('Supabase default leaves external reporting enabled', () async {
      final container = await containerWith({});

      // Force first read so build() runs and sets the flag.
      expect(container.read(activeDataModeProvider), AppDataMode.supabase);
      expect(AppLogger.externalReportingDisabled, isFalse);
    });

    test('Private start disables external reporting from build()', () async {
      final container = await containerWith({'active_data_mode': 'private'});

      expect(container.read(activeDataModeProvider), AppDataMode.private);
      expect(AppLogger.externalReportingDisabled, isTrue);
    });

    test('enterPrivateMode disables external reporting', () async {
      final container = await containerWith({});

      // Materialize the Supabase default first (flag false).
      expect(container.read(activeDataModeProvider), AppDataMode.supabase);
      expect(AppLogger.externalReportingDisabled, isFalse);

      await container.read(activeDataModeProvider.notifier).enterPrivateMode();

      expect(AppLogger.externalReportingDisabled, isTrue);
    });

    test('enterSupabaseMode re-enables external reporting', () async {
      final container = await containerWith({
        'active_data_mode': 'private',
        'has_sentry_consent': false,
      });

      // Private start disabled it.
      expect(container.read(activeDataModeProvider), AppDataMode.private);
      expect(AppLogger.externalReportingDisabled, isTrue);

      await container.read(activeDataModeProvider.notifier).enterSupabaseMode();

      expect(AppLogger.externalReportingDisabled, isFalse);
    });
  });
}
