// F40 — the paywall branch in the chat screen was unreachable in production.
//
// `_errorMessage` throws `CoachNotSubscribedException` on the proxy's
// `not_subscribed` 403 precisely so `ai_chat_screen` can open the paywall
// instead of printing a text bubble. But it is called from INSIDE
// `generateStreamResponse`'s own `try`, and the only handlers after that body
// were `on TimeoutException` and an untyped `catch` — so the typed exception was
// caught by the catch-all, logged as "[OpenRouter] Eccezione streaming", and
// yielded to the subscriber as an ordinary "connection error" chunk. `onError`
// never fired, and `e is CoachNotSubscribedException` — the only consumer of
// that type — could never be true.
//
// Who hits it: an account-mode user whose local `isPro` is true but whose
// subscription the server does not see — lapsed, refunded, or a webhook not yet
// applied. They are told the connection failed, and offered nothing to do about
// it.
//
// Desktop's sibling client over the SAME proxy and the same error codes already
// has `} on CoachNotSubscribedException { rethrow; }` immediately before its
// untyped catch (881536a, "apple review fix"). `coach_error_message_test.dart`
// pins the throw itself, but calls `_errorMessage` directly and never exercises
// the stream — which is exactly where the swallowing happens.
//
// Driven through a real loopback HTTP server rather than a mocked client: the
// `http.Client` is constructed inside the method, and the transport is not the
// part under test — the exception's path out of the generator is.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/coach_endpoint.dart';
import 'package:mattioli_os/core/openrouter_service.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/chat_message.dart';

void main() {
  // NO `TestWidgetsFlutterBinding.ensureInitialized()` here. That binding
  // installs an HttpOverrides whose mock client answers every request with 400,
  // which would silently replace the proxy's 403 with a status this code maps to
  // a generic "API error: 400" — and the test would then pass for the wrong
  // reason once the throw was restored.

  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  late HttpServer server;
  late int status;
  late String responseBody;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(server.forEach((request) async {
      await request.drain<void>();
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(responseBody);
      await request.response.close();
    }));
  });

  tearDown(() => server.close(force: true));

  CoachEndpoint endpoint() => CoachEndpoint(
        mode: CoachMode.standard,
        url: Uri.parse('http://127.0.0.1:${server.port}/functions/v1/ai-coach'),
        // Loopback, so the preflight resolves without a DNS server.
        host: '127.0.0.1',
        authorization: () async => 'jwt',
        sendModel: false,
      );

  Stream<String> send() => OpenRouterService.generateStreamResponse(
        [
          ChatMessage(
            text: 'how am I doing?',
            isUser: true,
            timestamp: DateTime(2026, 9, 3),
          ),
        ],
        endpoint: endpoint(),
      );

  test('a Standard 403 not_subscribed reaches the subscriber as an error',
      () async {
    status = 403;
    responseBody = jsonEncode({
      'error': {'code': 'not_subscribed', 'message': 'Pro required'},
    });

    await expectLater(
      send(),
      emitsError(isA<CoachNotSubscribedException>()),
    );
  });

  test('not_subscribed does not arrive as a text chunk instead', () async {
    // The shape of the bug: the user saw a normal assistant bubble reading
    // "connection error", and the paywall never opened.
    status = 403;
    responseBody = jsonEncode({
      'error': {'code': 'not_subscribed', 'message': 'Pro required'},
    });

    final chunks = <String>[];
    await expectLater(
      send().listen(chunks.add).asFuture<void>(),
      throwsA(isA<CoachNotSubscribedException>()),
    );
    expect(chunks, isEmpty);
  });

  test('every other proxy error still arrives as a message, not a throw',
      () async {
    // The rethrow must be narrow. `rate_limited` has a localized string and no
    // paywall to open, so it must keep flowing to the chat as a chunk.
    status = 429;
    responseBody = jsonEncode({
      'error': {'code': 'rate_limited', 'message': 'slow down'},
    });

    expect(await send().toList(), [t.ai.coachModes.standardRateLimited]);
  });
}
