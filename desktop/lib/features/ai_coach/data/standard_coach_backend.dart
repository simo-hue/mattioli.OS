import 'dart:convert';

import 'package:evolve_desktop/core/desktop_supabase_config.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/foundation.dart';

import '../domain/chat_message.dart';
import '../domain/coach_backend.dart';
import '../domain/coach_config.dart';
import 'openai_compatible_client.dart';

/// The Edge Function's URL, built from the same config `main.dart` initialises
/// Supabase with rather than reverse-engineered out of a REST URL.
String get standardCoachUrl =>
    '${DesktopSupabaseConfig.url.trim()}/functions/v1/ai-coach';

/// Localized messages for the failures only the proxy can produce.
///
/// A separate type from [CoachErrorMessages] because these are different
/// problems with different fixes, and collapsing them is how "not subscribed"
/// would come to read as "check your API key" — sending a user hunting a key
/// they do not have and do not need.
class StandardCoachErrors {
  const StandardCoachErrors({
    required this.sessionExpired,
    required this.needsPro,
    required this.rateLimited,
    required this.contextTooLong,
    required this.unavailable,
    required this.apiError,
  });

  /// HTTP 401 `unauthorized` — signed out, or the JWT expired mid-send.
  final String sessionExpired;

  /// HTTP 403 `not_subscribed` — a live session with no Evolve Pro entitlement.
  final String needsPro;

  /// HTTP 429 `rate_limited` — a fair-use window hit.
  final String rateLimited;

  /// HTTP 413 `context_too_long` — over `ai_coach_limits.max_input_chars`. The
  /// function rejects rather than truncating: silently dropping the middle of a
  /// conversation bills us to answer a question nobody asked.
  final String contextTooLong;

  /// HTTP 5xx / 502 `upstream_unavailable` / `not_configured` — our problem,
  /// not the user's. Nothing for them to fix, so it must not read like a
  /// misconfiguration on their side.
  final String unavailable;

  /// Anything unrecognised, given the status code.
  final String Function(int code) apiError;
}

/// The machine-readable `error.code` from an Edge Function failure body, or null
/// when the body is not ours (a Supabase gateway 502, an HTML error page, a
/// truncated read).
///
/// Never throws: this runs on an already-failing path, and an exception here
/// would replace a specific, actionable message with a crash.
@visibleForTesting
String? standardCoachErrorCode(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final error = decoded['error'];
    if (error is! Map) return null;
    final code = error['code'];
    return code is String && code.isNotEmpty ? code : null;
  } catch (_) {
    return null;
  }
}

/// Maps an Edge Function failure to the message that tells the user what to do.
///
/// Keyed on the `code` rather than the status, because the status alone is
/// ambiguous where it matters most: 401 and 403 are both "the server said no",
/// but one means *sign in again* and the other means *this is what Pro buys*.
/// Falls back to the status when the body is not ours to read.
@visibleForTesting
String mapStandardCoachError(int status, String body, StandardCoachErrors e) {
  return switch (standardCoachErrorCode(body)) {
    'unauthorized' => e.sessionExpired,
    'not_subscribed' => e.needsPro,
    'rate_limited' => e.rateLimited,
    'context_too_long' => e.contextTooLong,
    'upstream_unavailable' || 'not_configured' || 'server_error' =>
      e.unavailable,
    // Not our body. Fall back to the status, which still separates "you" from
    // "us" for the two cases a user can act on.
    _ => switch (status) {
      401 => e.sessionExpired,
      403 => e.needsPro,
      429 => e.rateLimited,
      413 => e.contextTooLong,
      >= 500 => e.unavailable,
      _ => e.apiError(status),
    },
  };
}

/// The Standard engine: our Supabase Edge Function, holding our OpenRouter key,
/// funded by the Evolve Pro subscription.
///
/// This is the App Store Guideline 3.1.1 fix. The app was rejected for enabling
/// paid functionality with a user-supplied OpenRouter key; the compliant shape
/// is the inverse — we hold the key, the IAP unlocks it. The key exists ONLY in
/// the function's secrets: a compile-time constant in Dart is recoverable from a
/// shipped build with `strings`, which is why the previous one had to be revoked.
///
/// It reuses [OpenAiCompatibleClient] because the function is OpenAI-compatible
/// on purpose: it reads `messages`, ignores the model, and pipes OpenRouter's
/// SSE straight back. Only three things differ from talking to OpenRouter
/// directly — a rotating bearer token, a URL that is the endpoint rather than a
/// `/v1` base, and an error vocabulary of real codes instead of prose. All three
/// are injected, so the transport stays one implementation for all three engines.
class StandardCoachBackend implements CoachBackend {
  StandardCoachBackend({
    required this.status,
    required Future<String?> Function() authorization,
    StandardCoachErrors? errors,
    OpenAiCompatibleClient? client,
  }) : _errors = errors ?? _defaultErrors,
       _client =
           client ??
           OpenAiCompatibleClient(
             baseUrl: standardCoachUrl,
             // The base URL IS the endpoint; do not append the OpenAI path.
             chatPath: '',
             headers: const {},
             // Per send, never captured — the JWT rotates.
             authorization: authorization,
             // Generous: this waits on a possible Edge Function cold start, a
             // profiles + usage read, AND OpenRouter's time-to-first-token
             // before any header is flushed. The 20s that suits a warm
             // OpenRouter connection would false-fail a cold one and report a
             // timeout for a request that was about to succeed.
             firstTokenTimeout: const Duration(seconds: 45),
             interChunkTimeout: const Duration(seconds: 15),
             errors: CoachErrorMessages(
               preflightFailed: t.ai.openRouter.noInternet,
               modelNotFound: t.ai.openRouter.apiError(code: 404),
               contextTooLong: t.ai.openRouter.contextTooLong,
               serverTimeout: t.ai.openRouter.serverTimeout,
               connectionError: t.ai.openRouter.connectionErrorShort,
               apiError: (code) => t.ai.openRouter.apiError(code: code),
             ),
             errorMapper: (statusCode, body) => mapStandardCoachError(
               statusCode,
               body,
               errors ?? _defaultErrors,
             ),
           );

  /// Whether the proxy can serve, and if not, why.
  final StandardCoachStatus status;

  final StandardCoachErrors _errors;
  final OpenAiCompatibleClient _client;

  static StandardCoachErrors get _defaultErrors => StandardCoachErrors(
    sessionExpired: t.ai.standard.sessionExpired,
    needsPro: t.ai.standard.needsPro,
    rateLimited: t.ai.standard.rateLimited,
    contextTooLong: t.ai.openRouter.contextTooLong,
    unavailable: t.ai.standard.unavailable,
    apiError: (code) => t.ai.openRouter.apiError(code: code),
  );

  @override
  CoachBackendKind get kind => CoachBackendKind.standard;

  @override
  Stream<String> streamResponse(
    List<ChatMessage> history, {
    required String systemPrompt,
    required String model,
    required double temperature,
  }) async* {
    // Answer locally when we already know the server would refuse. A round trip
    // to be told "not subscribed" costs a cold start to deliver a message we
    // could have written here — and on a signed-out client it would go out with
    // no bearer at all.
    if (status != StandardCoachStatus.ready) {
      yield switch (status) {
        StandardCoachStatus.needsSignIn => _errors.sessionExpired,
        StandardCoachStatus.needsPro => _errors.needsPro,
        StandardCoachStatus.unavailablePrivate ||
        StandardCoachStatus.unavailableUnconfigured =>
          _errors.unavailable,
        StandardCoachStatus.ready => '',
      };
      return;
    }
    yield* _client.stream(
      history,
      systemPrompt: systemPrompt,
      // The server picks the model AND pins the provider that serves it; it
      // ignores this field. Sending the pinned id keeps the wire honest about
      // what will answer instead of echoing the user's BYOK preference.
      model: kStandardCoachModel,
      temperature: temperature,
    );
  }

  /// The one model the proxy runs. Reported without a round trip: `GET /models`
  /// is not a route the function serves, and discovery would only ever confirm
  /// what `ai_coach_limits.model` already decided.
  @override
  Future<List<CoachModel>> listModels() async => const [
    CoachModel(id: kStandardCoachModel, label: 'Gemma 4 (free)'),
  ];

  /// Entitlement, not connectivity — matching the cloud backend, whose
  /// `reachable()` reports whether a key exists. The question the status pill
  /// asks is "will this answer me", and for Standard the usual answer to "no"
  /// is a subscription rather than a network.
  @override
  Future<bool> reachable() async => status == StandardCoachStatus.ready;
}
