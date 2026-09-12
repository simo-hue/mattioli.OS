// F45, the wiring half: native reports a third count and the app carries it.
//
// The rule lives in `evolve_verification`
// (`screen_time_web_selection_test.dart` pins `isEmpty`); this pins the two
// mobile-side hops that feed it — the `webCount` key coming off the method
// channel, and the count surviving the SharedPreferences round trip that the
// habit editor's "{count} selected" summary reads back.
//
// Native encodes a valid `FamilyActivitySelection` for a websites-only pick, so
// dropping the count here was enough to make the whole selection disappear.
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/method_channel_screen_time_bridge.dart';
import 'package:mattioli_os/core/verification_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bridge = MethodChannelScreenTimeBridge();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(
        MethodChannelScreenTimeBridge.channel, null);
  });

  test('a websites-only picker result survives the method channel', () async {
    messenger.setMockMethodCallHandler(
      MethodChannelScreenTimeBridge.channel,
      (call) async {
        expect(call.method, 'presentActivityPicker');
        return <Object?, Object?>{
          'blob': 'base64-blob',
          'appCount': 0,
          'categoryCount': 0,
          'webCount': 3,
        };
      },
    );

    final result = await bridge.presentActivityPicker();

    expect(result, isNotNull);
    expect(result!.webDomainCount, 3);
    expect(result.isEmpty, isFalse,
        reason: 'the editor nulls the selection and shows selectionEmpty');
  });

  test('a native build that does not report webCount still decodes', () async {
    messenger.setMockMethodCallHandler(
      MethodChannelScreenTimeBridge.channel,
      (call) async => <Object?, Object?>{
        'blob': 'base64-blob',
        'appCount': 2,
        'categoryCount': 1,
      },
    );

    final result = await bridge.presentActivityPicker();

    expect(result!.webDomainCount, 0);
    expect(result.totalCount, 3);
  });

  test('the stored entry keeps the web count across a round trip', () {
    const entry = ScreenTimeSelectionEntry(
      blob: 'base64-blob',
      applicationCount: 0,
      categoryCount: 0,
      webDomainCount: 3,
    );

    final restored = ScreenTimeSelectionEntry.fromJson(entry.toJson());

    expect(restored.webDomainCount, 3);
    expect(restored.totalCount, 3);
  });

  test('an entry stored before web counts existed reads back as zero', () {
    final restored = ScreenTimeSelectionEntry.fromJson(const {
      'blob': 'base64-blob',
      'apps': 2,
      'categories': 1,
    });

    expect(restored.webDomainCount, 0);
    expect(restored.totalCount, 3);
  });
}
