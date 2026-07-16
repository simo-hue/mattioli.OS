// BYOK regression coverage. The shipped build carries no OpenRouter key, so:
//  - the cloud backend must stay inert (and say why) until the user supplies
//    one, rather than calling out with an empty bearer token, and
//  - a key OpenRouter rejects must surface as "check your API key" instead of a
//    generic "request failed", which would send the user hunting the wrong bug.
import 'dart:convert';

import 'package:evolve_desktop/features/ai_coach/data/cloud_coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/data/openai_compatible_client.dart';
import 'package:evolve_desktop/features/ai_coach/data/openrouter_key_store.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _apiError(int code) => 'API_$code';

/// The transport under test, wired with a mocked HTTP client. [unauthorized] is
/// null for the local backend (no key of its own) and set for cloud.
OpenAiCompatibleClient _client(http.Client mock, {String? unauthorized}) =>
    OpenAiCompatibleClient(
      baseUrl: 'https://openrouter.ai/api/v1',
      headers: const {},
      errors: CoachErrorMessages(
        preflightFailed: 'PREFLIGHT',
        modelNotFound: 'MODEL_NOT_FOUND',
        unauthorized: unauthorized,
        contextTooLong: 'CONTEXT_TOO_LONG',
        serverTimeout: 'TIMEOUT',
        connectionError: 'CONN_ERR',
        apiError: _apiError,
      ),
      clientFactory: () => mock,
    );

http.Client _respondingWith(int status, String body) => MockClient.streaming(
  (request, bodyStream) async =>
      http.StreamedResponse(Stream.value(utf8.encode(body)), status),
);

Future<String> _streamOf(OpenAiCompatibleClient client) => client
    .stream(const [], systemPrompt: 's', model: 'm', temperature: 0.7)
    .join();

void main() {
  setUp(() {
    LocaleSettings.setLocale(AppLocale.en);
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('with no key the cloud backend is inert and explains itself', () async {
    final backend = CloudCoachBackend(apiKey: '');

    expect(backend.hasApiKey, isFalse);
    expect(await backend.reachable(), isFalse);
    expect(
      await backend
          .streamResponse(
            const [],
            systemPrompt: 's',
            model: 'm',
            temperature: 0.7,
          )
          .join(),
      t.ai.openRouter.apiKeyMissingShort,
    );
  });

  test('a whitespace-only key never counts as configured', () {
    expect(CloudCoachBackend(apiKey: '   \n ').hasApiKey, isFalse);
    expect(CloudCoachBackend(apiKey: ' sk-or-v1-abc ').hasApiKey, isTrue);
  });

  test('HTTP 401 maps to the check-your-key message, not a coded error', () async {
    final mock = _respondingWith(
      401,
      '{"error":{"message":"No auth credentials found"}}',
    );
    expect(
      await _streamOf(_client(mock, unauthorized: 'UNAUTHORIZED')),
      'UNAUTHORIZED',
    );
  });

  test('HTTP 403 maps to the check-your-key message too', () async {
    final mock = _respondingWith(403, '{"error":{"message":"Forbidden"}}');
    expect(
      await _streamOf(_client(mock, unauthorized: 'UNAUTHORIZED')),
      'UNAUTHORIZED',
    );
  });

  test('a 401 body mentioning the model is not mistaken for model-not-found', () async {
    // OpenRouter's auth errors routinely name the model; the status must win.
    final mock = _respondingWith(
      401,
      '{"error":{"message":"model google/gemini-2.5-flash not found for this key"}}',
    );
    expect(
      await _streamOf(_client(mock, unauthorized: 'UNAUTHORIZED')),
      'UNAUTHORIZED',
    );
  });

  test('without an unauthorized message a 401 falls back to the coded error', () async {
    // The local backend's shape: no key of its own, so nothing better to say.
    final mock = _respondingWith(401, 'nope');
    expect(await _streamOf(_client(mock)), 'API_401');
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
