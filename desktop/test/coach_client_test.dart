// End-to-end coverage of the shared OpenAI-compatible transport using a mocked
// HTTP client (no real server): SSE assembly, [DONE] termination, HTTP-error →
// localized-string mapping, model discovery, and reachability.
import 'dart:convert';

import 'package:evolve_desktop/features/ai_coach/data/openai_compatible_client.dart';
import 'package:evolve_desktop/features/ai_coach/domain/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _apiError(int code) => 'API_$code';
const _errors = CoachErrorMessages(
  preflightFailed: 'PREFLIGHT',
  modelNotFound: 'MODEL_NOT_FOUND',
  contextTooLong: 'CONTEXT_TOO_LONG',
  serverTimeout: 'TIMEOUT',
  connectionError: 'CONN_ERR',
  apiError: _apiError,
);

OpenAiCompatibleClient _client(http.Client mock) => OpenAiCompatibleClient(
  baseUrl: 'http://localhost:11434/v1',
  headers: const {},
  errors: _errors,
  clientFactory: () => mock,
);

ChatMessage _user(String text) =>
    ChatMessage(text: text, isUser: true, timestamp: DateTime(2026));

void main() {
  test('assembles streamed content and stops at [DONE]', () async {
    final mock = MockClient.streaming((request, bodyStream) async {
      expect(request.url.path, '/v1/chat/completions');
      final sse = [
        'data: {"choices":[{"delta":{"role":"assistant"}}]}',
        'data: {"choices":[{"delta":{"content":"Hel"}}]}',
        'data: {"choices":[{"delta":{"content":"lo"}}]}',
        'data: [DONE]',
        'data: {"choices":[{"delta":{"content":"IGNORED"}}]}',
      ].join('\n');
      return http.StreamedResponse(Stream.value(utf8.encode(sse)), 200);
    });

    final out = await _client(mock)
        .stream(
          [_user('hi')],
          systemPrompt: 's',
          model: 'm',
          temperature: 0.7,
        )
        .join();
    expect(out, 'Hello');
  });

  test('maps HTTP 400 to context-too-long only when the body says so', () async {
    final ctx = MockClient.streaming(
      (request, bodyStream) async => http.StreamedResponse(
        Stream.value(utf8.encode('maximum context length exceeded')),
        400,
      ),
    );
    expect(
      await _client(ctx)
          .stream(const [], systemPrompt: 's', model: 'm', temperature: 0.7)
          .join(),
      'CONTEXT_TOO_LONG',
    );

    // A 400 that isn't about context falls through to the coded error.
    final other = MockClient.streaming(
      (request, bodyStream) async =>
          http.StreamedResponse(Stream.value(utf8.encode('bad request')), 400),
    );
    expect(
      await _client(other)
          .stream(const [], systemPrompt: 's', model: 'm', temperature: 0.7)
          .join(),
      'API_400',
    );
  });

  test('maps a 404 / model-not-found body to modelNotFound', () async {
    final byStatus = MockClient.streaming(
      (request, bodyStream) async =>
          http.StreamedResponse(Stream.value(utf8.encode('nope')), 404),
    );
    expect(
      await _client(byStatus)
          .stream(const [], systemPrompt: 's', model: 'm', temperature: 0.7)
          .join(),
      'MODEL_NOT_FOUND',
    );

    final byBody = MockClient.streaming(
      (request, bodyStream) async => http.StreamedResponse(
        Stream.value(utf8.encode('{"error":"model \\"x\\" not found"}')),
        400,
      ),
    );
    expect(
      await _client(byBody)
          .stream(const [], systemPrompt: 's', model: 'm', temperature: 0.7)
          .join(),
      'MODEL_NOT_FOUND',
    );
  });

  test('maps other HTTP errors through apiError(code)', () async {
    final mock = MockClient.streaming(
      (request, bodyStream) async =>
          http.StreamedResponse(Stream.value(utf8.encode('boom')), 503),
    );
    final out = await _client(mock)
        .stream(const [], systemPrompt: 's', model: 'm', temperature: 0.7)
        .join();
    expect(out, 'API_503');
  });

  test('listModels parses the discovered models', () async {
    final mock = MockClient((request) async {
      expect(request.url.path, '/v1/models');
      return http.Response('{"data":[{"id":"llama3.1:8b"}]}', 200);
    });
    final models = await _client(mock).listModels();
    expect(models.single.id, 'llama3.1:8b');
  });

  test('reachable is true on a 200 /models and false on error', () async {
    final up = MockClient((request) async => http.Response('{}', 200));
    expect(await _client(up).reachable(), isTrue);

    final down = MockClient(
      (request) async => throw const _FakeSocketError(),
    );
    expect(await _client(down).reachable(), isFalse);
  });
}

class _FakeSocketError implements Exception {
  const _FakeSocketError();
}
