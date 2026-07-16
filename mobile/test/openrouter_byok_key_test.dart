// BYOK regression coverage. The shipped IPA carries no OpenRouter key, so the
// chat must stay inert (and point at Settings) until the user supplies one —
// never call out with an empty bearer token — and the key must live in the
// Keychain, never in SharedPreferences.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/openrouter_service.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/chat_message.dart';

void main() {
  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('with no key the stream yields the setup message and stops', () async {
    final history = [
      ChatMessage(text: 'Hi', isUser: true, timestamp: DateTime(2026)),
    ];

    // Must not reach the network: the key gate is checked before the
    // connectivity probe, so a keyless user is told to add a key rather than
    // that they're offline.
    expect(
      await OpenRouterService.generateStreamResponse(history).toList(),
      [t.ai.openRouter.apiKeyMissingShort],
    );
  });

  test('with no key generateResponse returns the setup message', () async {
    expect(
      await OpenRouterService.generateResponse(const []),
      t.ai.openRouter.apiKeyMissingFull,
    );
  });

  test('isUnauthorized covers the credential-rejection codes only', () {
    expect(isUnauthorized(401), isTrue);
    expect(isUnauthorized(403), isTrue);
    expect(isUnauthorized(400), isFalse);
    expect(isUnauthorized(404), isFalse);
    expect(isUnauthorized(500), isFalse);
  });

  group('OpenRouterKeyStore', () {
    test('reads null until a key is stored', () async {
      expect(await const OpenRouterKeyStore().read(), isNull);
    });

    test('round-trips a key, trimming a pasted trailing newline', () async {
      const store = OpenRouterKeyStore();
      await store.write('  sk-or-v1-pasted\n');
      expect(await store.read(), 'sk-or-v1-pasted');
    });

    test('a whitespace-only stored value reads as unset', () async {
      FlutterSecureStorage.setMockInitialValues({
        OpenRouterKeyStore.storageKey: '   ',
      });
      expect(await const OpenRouterKeyStore().read(), isNull);
    });

    test('clear removes the key', () async {
      const store = OpenRouterKeyStore();
      await store.write('sk-or-v1-abc');
      await store.clear();
      expect(await store.read(), isNull);
    });
  });
}
