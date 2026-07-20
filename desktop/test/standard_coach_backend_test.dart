// The Standard engine: our Edge Function, our OpenRouter key, unlocked by the
// Evolve Pro subscription.
//
// App Store Guideline 3.1.1 rejected the app for enabling paid functionality
// with a key the user pasted. This engine is the inverse — and the two things
// most likely to break it silently are pinned here:
//
//  1. The bearer token is the Supabase session JWT, which ROTATES. A transport
//     that captures it at construction 401s forever after the first refresh,
//     with no way back short of relaunching the app.
//  2. The function answers with machine-readable codes, and the OpenAI-dialect
//     heuristics are wrong for them: its 403 means "buy Pro", not "your key is
//     bad". Telling a free user to check an API key they do not have — for a
//     feature whose whole point is that it needs no key — is the rejected UX
//     wearing a different hat.
import 'dart:convert';

import 'package:evolve_desktop/features/ai_coach/data/openai_compatible_client.dart';
import 'package:evolve_desktop/features/ai_coach/data/standard_coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/domain/chat_message.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _apiError(int code) => 'API_$code';

const _errors = StandardCoachErrors(
  sessionExpired: 'SESSION_EXPIRED',
  needsPro: 'NEEDS_PRO',
  rateLimited: 'RATE_LIMITED',
  contextTooLong: 'CONTEXT_TOO_LONG',
  unavailable: 'UNAVAILABLE',
  apiError: _apiError,
);

/// A failure body in the Edge Function's own shape.
String _body(String code) =>
    jsonEncode({'error': {'code': code, 'message': 'whatever'}});

ChatMessage _user(String text) =>
    ChatMessage(text: text, isUser: true, timestamp: DateTime(2026));

/// The backend wired to a mocked transport, so nothing dials out.
StandardCoachBackend _backend({
  required http.Client mock,
  StandardCoachStatus status = StandardCoachStatus.ready,
  Future<String?> Function()? authorization,
}) {
  final auth = authorization ?? () async => 'jwt';
  return StandardCoachBackend(
    status: status,
    authorization: auth,
    errors: _errors,
    client: OpenAiCompatibleClient(
      baseUrl: 'https://example.supabase.co/functions/v1/ai-coach',
      chatPath: '',
      headers: const {},
      authorization: auth,
      errors: const CoachErrorMessages(
        preflightFailed: 'PREFLIGHT',
        modelNotFound: 'MODEL_NOT_FOUND',
        contextTooLong: 'CONTEXT_TOO_LONG',
        serverTimeout: 'TIMEOUT',
        connectionError: 'CONN_ERR',
        apiError: _apiError,
      ),
      errorMapper: (status, body) => mapStandardCoachError(status, body, _errors),
      clientFactory: () => mock,
    ),
  );
}

Future<String> _send(StandardCoachBackend backend) => backend
    .streamResponse(
      [_user('hi')],
      systemPrompt: 's',
      model: 'ignored',
      temperature: 0.7,
    )
    .join();

void main() {
  group('standardCoachErrorCode', () {
    test('reads the code out of our failure shape', () {
      expect(standardCoachErrorCode(_body('not_subscribed')), 'not_subscribed');
    });

    test('returns null for a body that is not ours, and never throws', () {
      // A Supabase gateway 502 is HTML; a truncated read is half a token. Both
      // land here, on an already-failing path, where an exception would replace
      // a specific message with a crash.
      for (final body in [
        '<html>502 Bad Gateway</html>',
        '',
        '{"error":',
        '{"error":"a string, not an object"}',
        '{"error":{"code":123}}',
        '{"error":{}}',
        'null',
        '[]',
      ]) {
        expect(
          standardCoachErrorCode(body),
          isNull,
          reason: 'must degrade to null, not throw, for: $body',
        );
      }
    });
  });

  group('mapStandardCoachError', () {
    test('401 and 403 are DIFFERENT problems with different fixes', () {
      // The bug this prevents: the OpenAI-dialect mapper collapses both into
      // "unauthorized", so a free user would be told to check an API key. The
      // whole selling point of this engine is that it needs no key.
      expect(
        mapStandardCoachError(401, _body('unauthorized'), _errors),
        'SESSION_EXPIRED',
      );
      expect(
        () => mapStandardCoachError(403, _body('not_subscribed'), _errors),
        throwsA(isA<CoachNotSubscribedException>()),
      );
    });

    test('maps every code the function can return', () {
      expect(
        mapStandardCoachError(429, _body('rate_limited'), _errors),
        'RATE_LIMITED',
      );
      expect(
        mapStandardCoachError(413, _body('context_too_long'), _errors),
        'CONTEXT_TOO_LONG',
      );
      expect(
        mapStandardCoachError(502, _body('upstream_unavailable'), _errors),
        'UNAVAILABLE',
      );
      expect(
        mapStandardCoachError(500, _body('not_configured'), _errors),
        'UNAVAILABLE',
      );
      expect(
        mapStandardCoachError(500, _body('server_error'), _errors),
        'UNAVAILABLE',
      );
    });

    test('falls back to the status when the body is not ours', () {
      // A Supabase gateway or an ingress can answer before our code runs. The
      // two cases the user can act on must still be separated.
      expect(mapStandardCoachError(401, 'gateway noise', _errors),
          'SESSION_EXPIRED');
      expect(() => mapStandardCoachError(403, 'gateway noise', _errors),
          throwsA(isA<CoachNotSubscribedException>()));
      expect(mapStandardCoachError(429, 'gateway noise', _errors),
          'RATE_LIMITED');
      expect(mapStandardCoachError(503, 'gateway noise', _errors), 'UNAVAILABLE');
      expect(mapStandardCoachError(418, 'gateway noise', _errors), 'API_418');
    });

    test('an unknown code falls through to the status, not to silence', () {
      expect(
        mapStandardCoachError(400, _body('some_future_code'), _errors),
        'API_400',
      );
    });
  });

  group('StandardCoachBackend', () {
    test('THE JWT IS RESOLVED PER SEND, never captured', () async {
      // The trap. `CloudCoachBackend` bakes its key into the headers at
      // construction, which is correct for a key that never changes and fatal
      // for a token that rotates hourly.
      var token = 'jwt-1';
      final seen = <String?>[];
      final mock = MockClient.streaming((request, _) async {
        seen.add(request.headers['Authorization']);
        return http.StreamedResponse(
          Stream.value(utf8.encode('data: [DONE]')),
          200,
        );
      });
      final backend = _backend(mock: mock, authorization: () async => token);

      await _send(backend);
      token = 'jwt-2-after-refresh';
      await _send(backend);

      expect(seen, ['Bearer jwt-1', 'Bearer jwt-2-after-refresh'],
          reason: 'the SAME backend must see the rotated token');
    });

    test('posts to the function URL itself, not an OpenAI /chat/completions',
        () async {
      // The Edge Function is mounted at its own URL and never reads the path.
      // Appending the OpenAI suffix would lean on Supabase sub-path routing that
      // no test here can exercise.
      Uri? url;
      final mock = MockClient.streaming((request, _) async {
        url = request.url;
        return http.StreamedResponse(
          Stream.value(utf8.encode('data: [DONE]')),
          200,
        );
      });
      await _send(_backend(mock: mock));

      expect(url.toString(), 'https://example.supabase.co/functions/v1/ai-coach');
    });

    test('sends the server-pinned model, not the caller\'s', () async {
      // The function ignores this field — it reads `ai_coach_limits.model`. So
      // echoing a user's BYOK preference here would put a model on the wire that
      // is not the one answering.
      Map<String, dynamic>? body;
      final mock = MockClient.streaming((request, bodyStream) async {
        body =
            jsonDecode(await bodyStream.bytesToString())
                as Map<String, dynamic>;
        return http.StreamedResponse(
          Stream.value(utf8.encode('data: [DONE]')),
          200,
        );
      });
      await _backend(mock: mock)
          .streamResponse(
            [_user('hi')],
            systemPrompt: 's',
            model: 'anthropic/claude-sonnet-4.5', // must NOT reach the wire
            temperature: 0.7,
          )
          .join();

      expect(body!['model'], kStandardCoachModel);
    });

    test('streams content back like any OpenAI-compatible server', () async {
      final mock = MockClient.streaming((request, _) async {
        final sse = [
          'data: {"choices":[{"delta":{"content":"Hel"}}]}',
          'data: {"choices":[{"delta":{"content":"lo"}}]}',
          'data: [DONE]',
        ].join('\n');
        return http.StreamedResponse(Stream.value(utf8.encode(sse)), 200);
      });
      expect(await _send(_backend(mock: mock)), 'Hello');
    });

    test('a free user is told to subscribe — WITHOUT a round trip', () async {
      // Answering locally matters twice: a cold start to be told "not
      // subscribed" is a slow way to deliver a message we already know, and on a
      // signed-out client the request would go out with no bearer at all.
      var called = false;
      final mock = MockClient.streaming((request, _) async {
        called = true;
        return http.StreamedResponse(const Stream.empty(), 200);
      });

      expect(
        await _send(_backend(mock: mock, status: StandardCoachStatus.needsPro)),
        'NEEDS_PRO',
      );
      expect(called, isFalse, reason: 'must not dial out to be refused');
    });

    test('every not-ready status says something specific, never blank', () {
      for (final status in StandardCoachStatus.values) {
        if (status == StandardCoachStatus.ready) continue;
        final mock = MockClient.streaming(
          (_, _) async => http.StreamedResponse(const Stream.empty(), 200),
        );
        expect(
          _send(_backend(mock: mock, status: status)),
          completion(isNotEmpty),
          reason: '$status must explain itself',
        );
      }
    });

    test('the server\'s 403 also maps to "buy Pro" mid-stream', () async {
      // Entitlement can lapse between the status resolve and the send; the
      // client-side check is an optimisation, and the server is the authority.
      final mock = MockClient.streaming(
        (request, _) async => http.StreamedResponse(
          Stream.value(utf8.encode(_body('not_subscribed'))),
          403,
        ),
      );
      expect(
        () => _send(_backend(mock: mock)),
        throwsA(isA<CoachNotSubscribedException>()),
      );
    });

    test('reachable reports entitlement, and listModels needs no network', () async {
      final mock = MockClient.streaming(
        (_, _) async => throw StateError('must not be called'),
      );
      expect(await _backend(mock: mock).reachable(), isTrue);
      expect(
        await _backend(mock: mock, status: StandardCoachStatus.needsPro)
            .reachable(),
        isFalse,
      );
      expect(
        (await _backend(mock: mock).listModels()).single.id,
        kStandardCoachModel,
      );
    });

    test('identifies as the standard engine', () {
      final mock = MockClient.streaming(
        (_, _) async => http.StreamedResponse(const Stream.empty(), 200),
      );
      expect(_backend(mock: mock).kind, CoachBackendKind.standard);
    });
  });
}
