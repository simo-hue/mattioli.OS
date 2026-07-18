import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../i18n/translations.g.dart';
import '../models/chat_message.dart';
import 'app_logger.dart';
import 'coach_endpoint.dart';
import 'secure_storage_utils.dart';

/// Non-secret OpenRouter endpoint constants.
///
/// There is deliberately no API-key constant here: the coach is BYOK, and a
/// compile-time key (a literal or `String.fromEnvironment`) would be baked into
/// the AOT snapshot and recoverable from a shipped IPA with `strings`. The
/// user's own key lives in the Keychain — see [OpenRouterKeyStore].
const String kOpenRouterBaseUrl = 'https://openrouter.ai/api/v1';

/// The model BYOK sends. Sent ONLY on the BYOK path (`endpoint.sendModel`); the
/// Standard proxy names no model — the Edge Function pins one server-side.
///
/// A **free** OpenRouter model, on purpose. BYOK bills the user's own account,
/// so a free model makes the coach genuinely $0 for anyone who connects a key.
/// Free-tier trade-offs (a ~50/day per-account cap, and a provider that may
/// train on the data) live entirely on the user's side of the line — which is
/// exactly what BYOK's consent copy already discloses ("OpenRouter routes it
/// under your account settings").
///
/// The Standard proxy now runs the SAME free model (2026-07-17 product
/// decision), via `google-ai-studio` rather than Vertex, with the free-tier data
/// posture disclosed in the Standard consent copy and the privacy policy. See
/// `migrations/20260717_add_ai_coach_proxy.sql`.
const String kOpenRouterDefaultModel = 'nvidia/nemotron-3-nano-30b-a3b:free';

/// Keychain-backed home of the user's own OpenRouter API key (BYOK).
///
/// Uses `flutter_secure_storage` — never SharedPreferences, which is a
/// plaintext plist that lands in iCloud/iTunes backups. It is absent from every
/// export/backup path (those read the database, not the Keychain) and is never
/// logged: nothing between [read]/[write] and the Authorization header prints
/// the value.
class OpenRouterKeyStore {
  const OpenRouterKeyStore();

  /// Keychain item name. Uses the general (non device-local) tier, matching how
  /// mobile stores its other non-Private-Mode secrets.
  static const String storageKey = 'openrouter_api_key';

  /// The stored key, or null when unset. Whitespace-only counts as unset so a
  /// stray paste can't masquerade as a configured key.
  Future<String?> read() async {
    final value = (await SecureStorageUtils.read(storageKey))?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Persists [key] (trimmed — pasted keys routinely carry a trailing newline).
  /// Throws when the Keychain write fails, so callers can surface it.
  Future<void> write(String key) => SecureStorageUtils.write(
    storageKey,
    key.trim(),
    context: 'OpenRouterKeyStore',
  );

  Future<void> clear() => SecureStorageUtils.delete(storageKey);
}

/// The user's own OpenRouter API key. Null means the AI Coach isn't configured
/// yet, which is what the chat's setup state and the Settings row key off.
final openRouterApiKeyProvider =
    AsyncNotifierProvider<OpenRouterApiKeyController, String?>(
      OpenRouterApiKeyController.new,
    );

class OpenRouterApiKeyController extends AsyncNotifier<String?> {
  static const OpenRouterKeyStore _store = OpenRouterKeyStore();

  @override
  Future<String?> build() => _store.read();

  /// Stores [key] and publishes it. Returns false (leaving the previous state
  /// intact) when the Keychain write fails, so the UI can say so rather than
  /// pretend the key was saved. Never logs [key].
  Future<bool> save(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return false;
    try {
      await _store.write(trimmed);
    } catch (_) {
      // SecureStorageUtils has already logged the failure (by item name only).
      return false;
    }
    state = AsyncValue.data(trimmed);
    return true;
  }

  Future<void> clear() async {
    await _store.clear();
    state = const AsyncValue.data(null);
  }
}

class OpenRouterService {
  // No key store here any more: the service does not read credentials, it is
  // HANDED one. `CoachEndpoint.authorization` resolves the right credential for
  // the right mode — the Keychain for BYOK, the live session JWT for Standard —
  // per send. Reading the Keychain here is what made the removed
  // `generateResponse` BYOK-only by construction.

  // `generateResponse` (non-streaming, BYOK-only) was removed on 2026-07-17. It
  // had zero production call sites — only a test — and it read the Keychain
  // directly, bypassing `coachEndpointProvider` entirely: it could only ever
  // reach OpenRouter with the user's own key, never the Pro-funded proxy. Any
  // future caller would therefore have silently bypassed the Guideline 3.1.1
  // fix. `generateStreamResponse` is the only way to talk to the coach.

  /// Streams a coach reply over [endpoint].
  ///
  /// [endpoint] decides both where this goes and how it authenticates — our
  /// Supabase proxy for Pro subscribers (Guideline 3.1.1: the IAP unlocks the
  /// coach, not a pasted key), or the user's own OpenRouter key. Null means
  /// nothing is configured, which is the BYOK-with-no-key case.
  static Stream<String> generateStreamResponse(
    List<ChatMessage> history, {
    String? systemPrompt,
    CoachEndpoint? endpoint,
  }) async* {
    // Checked before the connectivity probe: a user with nothing configured
    // needs the setup message, not "you're offline".
    if (endpoint == null) {
      yield t.ai.openRouter.apiKeyMissingShort;
      return;
    }
    final authorization = await endpoint.authorization();
    if (authorization == null) {
      yield t.ai.openRouter.apiKeyMissingShort;
      return;
    }

    // Probe the host we are ACTUALLY dialling. This used to be hardcoded to
    // openrouter.ai, which in Standard mode tests a server we never talk to —
    // and would report "you're offline" to someone whose connection is fine, or
    // wave through a request to a Supabase project that is down.
    try {
      final result = await InternetAddress.lookup(
        endpoint.host,
      ).timeout(const Duration(seconds: 5));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        yield t.ai.openRouter.noInternet;
        return;
      }
    } on SocketException catch (_) {
      yield t.ai.openRouter.noInternet;
      return;
    } on TimeoutException catch (_) {
      yield t.ai.openRouter.connectionCheckTimeout;
      return;
    }

    final messages = history.map((msg) {
      return {'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text};
    }).toList();

    final finalSystemPrompt =
        systemPrompt ?? t.ai.openRouter.defaultSystemPrompt;

    messages.insert(0, {'role': 'system', 'content': finalSystemPrompt});

    final body = jsonEncode({
      // Standard mode names no model: the server picks it AND pins the provider
      // that serves it. Letting the client choose would hand it our bill and
      // break the recipient list our privacy policy commits to.
      if (endpoint.sendModel) 'model': kOpenRouterDefaultModel,
      if (endpoint.sendModel) 'temperature': 0.7,
      'messages': messages,
      'stream': true,
    });

    final client = http.Client();
    final request = http.Request('POST', endpoint.url)
      ..headers['Authorization'] = 'Bearer $authorization'
      ..headers['Content-Type'] = 'application/json'
      ..body = body;
    if (endpoint.mode == CoachMode.byok) {
      // Attribution headers, and only OpenRouter understands them. They list the
      // app in OpenRouter's public rankings, so they have no business on a
      // request to our own function.
      request.headers['HTTP-Referer'] = 'https://github.com/simo-hue/mattioli.OS';
      request.headers['X-Title'] = 'Evolve';
    }

    try {
      // Timeout di 15 secondi per stabilire la connessione
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        AppLogger.error(
          '[${endpoint.mode.name}] Errore API streaming',
          'Status: ${response.statusCode}, Body: $errorBody',
        );
        yield _errorMessage(endpoint.mode, response.statusCode, errorBody);
        client.close();
        return;
      }

      // Timeout di 10 secondi tra un chunk e l'altro
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 10));

      await for (final line in stream) {
        if (line.isEmpty) continue;
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6);
          if (dataStr == '[DONE]') break;

          try {
            final data = jsonDecode(dataStr);
            final content = data['choices'][0]['delta']['content'];
            if (content != null) {
              yield content.toString();
            }
          } catch (e) {
            // Invia un warning a Sentry per capire se l'API ha cambiato formato
            AppLogger.warning(
              '[OpenRouter] Errore parsing chunk JSON',
              e,
              null,
              {'dataStr': dataStr},
            );
          }
        }
      }
    } on TimeoutException catch (e, stack) {
      AppLogger.error('[OpenRouter] Timeout streaming', e, stack);
      yield t.ai.openRouter.serverTimeout;
    } catch (e, stack) {
      AppLogger.error('[OpenRouter] Eccezione streaming', e, stack);
      yield t.ai.openRouter.connectionErrorShort;
    } finally {
      client.close();
    }
  }
}

/// Whether [statusCode] means OpenRouter rejected the caller's credentials —
/// i.e. the user's own key is wrong, revoked, or out of credit. 403 is included
/// because OpenRouter returns it for a key that exists but isn't permitted.
bool isUnauthorized(int statusCode) => statusCode == 401 || statusCode == 403;

/// The user-facing message for a non-200, which depends on which transport
/// produced it. The same status means different things:
///
/// - BYOK 403: the user's own key is wrong, revoked or out of credit.
/// - Standard 403: our proxy says the subscription is not active. Telling that
///   user their "API key is invalid" would be nonsense — they never entered one.
///
/// The proxy sends a machine-readable `error.code` precisely so this never has
/// to guess from the status alone.
@visibleForTesting
String errorMessageFor(CoachMode mode, int statusCode, String body) =>
    _errorMessage(mode, statusCode, body);

String _errorMessage(CoachMode mode, int statusCode, String body) {
  if (mode == CoachMode.byok) {
    if (isUnauthorized(statusCode)) return t.ai.openRouter.apiKeyInvalid;
    if (statusCode == 400) return t.ai.openRouter.contextTooLong;
    return t.ai.openRouter.apiError(code: statusCode);
  }

  // Standard mode. Prefer the proxy's own code over the status: it knows why.
  String? code;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is Map) {
      final c = (decoded['error'] as Map)['code'];
      if (c is String) code = c;
    }
  } catch (_) {
    // A proxy that fell over may not answer in JSON; fall back to the status.
  }

  // Keyed on the proxy's own `error.code`, because the status alone is
  // ambiguous where it matters most: 401 `unauthorized` (session expired) and
  // 403 `not_subscribed` are both "the server said no", but one means *sign in
  // again* and the other means *this is what Pro buys*. Mapping them the same —
  // as this used to, collapsing both to standardNeedsPro via `isUnauthorized` —
  // tells a subscriber whose session lapsed to buy the subscription they hold.
  // Mirrors desktop's mapStandardCoachError so the two apps report the same
  // failure the same way over the same proxy.
  switch (code) {
    case 'unauthorized':
      return t.ai.coachModes.standardSessionExpired;
    case 'not_subscribed':
      return t.ai.coachModes.standardNeedsPro;
    case 'rate_limited':
      return t.ai.coachModes.standardRateLimited;
    case 'context_too_long':
      return t.ai.openRouter.contextTooLong;
    case 'not_configured':
    case 'server_error':
    case 'upstream_unavailable':
    case 'upstream_rate_limited':
    case 'upstream_error':
      // Our problem, not the user's — nothing for them to fix, so it must not
      // read like a misconfiguration on their side.
      return t.ai.coachModes.standardUnavailable;
  }
  // Body not ours to read (a Supabase gateway error, a truncated response): fall
  // back to the status, which still separates the cases the user can act on.
  if (statusCode == 413) return t.ai.openRouter.contextTooLong;
  if (statusCode == 429) return t.ai.coachModes.standardRateLimited;
  if (statusCode == 403) return t.ai.coachModes.standardNeedsPro;
  if (statusCode == 401) return t.ai.coachModes.standardSessionExpired;
  if (statusCode >= 500) return t.ai.coachModes.standardUnavailable;
  return t.ai.openRouter.apiError(code: statusCode);
}
