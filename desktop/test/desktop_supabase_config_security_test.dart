import 'dart:io';

import 'package:evolve_desktop/core/desktop_supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop Supabase config is provided by build-time defines', () {
    expect(DesktopSupabaseConfig.isConfigured, isTrue);
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
