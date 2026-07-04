// WS2 — Pro unlock in Private mode.
//
// Verifies the single entitlement provider: in Private mode `desktopIsProProvider`
// is true (every feature unlocked) without touching the RevenueCat/subscription
// path — the private branch short-circuits before it.
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerForMode(String mode) async {
    SharedPreferences.setMockInitialValues({'active_data_mode': mode});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('Private mode is entitled — desktopIsProProvider is true', () async {
    final container = await containerForMode('private');
    expect(container.read(desktopIsProProvider), isTrue);
  });
}
