import 'dart:io';

import 'package:evolve_desktop/core/desktop_supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop Supabase config is provided by build-time defines', () {
    // Deliberately environment-dependent: `isConfigured` reads
    // String.fromEnvironment('EVOLVE_SUPABASE_*'), which is empty unless the
    // defines are compiled in. That is the point — it proves the credentials
    // come from the build, not from a committed fallback, so it must NOT be
    // relaxed to pass a bare `flutter test`. Run the suite the documented way:
    //   flutter test \
    //     --dart-define=EVOLVE_SUPABASE_URL=… \
    //     --dart-define=EVOLVE_SUPABASE_PUBLISHABLE_KEY=…
    expect(
      DesktopSupabaseConfig.isConfigured,
      isTrue,
      reason:
          'Supabase config is missing. Pass EVOLVE_SUPABASE_URL and '
          'EVOLVE_SUPABASE_PUBLISHABLE_KEY via --dart-define (dummy values are '
          'fine for tests).',
    );
  });

  test('desktop Supabase config does not contain checked-in credentials', () {
    final source = File(
      'lib/core/desktop_supabase_config.dart',
    ).readAsStringSync();

    expect(
      source,
      isNot(contains(RegExp(r'https://[a-z0-9-]+\.supabase\.co'))),
    );
    expect(
      source,
      isNot(
        contains(RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+')),
      ),
    );
  });
}
