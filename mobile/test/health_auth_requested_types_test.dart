import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/verification_providers.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer(
      Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('seeds requested types from SharedPreferences', () async {
    final c = await makeContainer({
      HealthAuthRequestedTypesNotifier.prefsKey: <String>['stepCount'],
    });
    expect(c.read(healthAuthRequestedTypesProvider), {'stepCount'});
  });

  test('markRequested adds, persists, and is idempotent', () async {
    final c = await makeContainer({});
    expect(c.read(healthAuthRequestedTypesProvider), isEmpty);

    await c
        .read(healthAuthRequestedTypesProvider.notifier)
        .markRequested('stepCount');
    expect(c.read(healthAuthRequestedTypesProvider), {'stepCount'});

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList(HealthAuthRequestedTypesNotifier.prefsKey),
      ['stepCount'],
    );

    // A second call for the same type is a no-op.
    await c
        .read(healthAuthRequestedTypesProvider.notifier)
        .markRequested('stepCount');
    expect(c.read(healthAuthRequestedTypesProvider), {'stepCount'});

    // A different type accumulates.
    await c
        .read(healthAuthRequestedTypesProvider.notifier)
        .markRequested('sleepAnalysis');
    expect(c.read(healthAuthRequestedTypesProvider),
        {'stepCount', 'sleepAnalysis'});
  });
}
