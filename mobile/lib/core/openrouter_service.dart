import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../i18n/translations.g.dart';
import '../models/chat_message.dart';
import 'app_logger.dart';
import 'secure_storage_utils.dart';

/// Non-secret OpenRouter endpoint constants.
///
/// There is deliberately no API-key constant here: the coach is BYOK, and a
/// compile-time key (a literal or `String.fromEnvironment`) would be baked into
/// the AOT snapshot and recoverable from a shipped IPA with `strings`. The
/// user's own key lives in the Keychain — see [OpenRouterKeyStore].
const String kOpenRouterBaseUrl = 'https://openrouter.ai/api/v1';
const String kOpenRouterDefaultModel = 'google/gemini-2.5-flash';

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
  static const OpenRouterKeyStore _keyStore = OpenRouterKeyStore();

  /// Genera una risposta dall'LLM tramite Open Router.
  /// Prende in input lo storico dei messaggi per mantenere il contesto.
  static Future<String> generateResponse(
    List<ChatMessage> history, {
    String? systemPrompt,
  }) async {
    // BYOK: without the user's own key there is nothing to authenticate with.
    final apiKey = await _keyStore.read();
    if (apiKey == null) return t.ai.openRouter.apiKeyMissingFull;

    final url = Uri.parse('$kOpenRouterBaseUrl/chat/completions');

    // Convertiamo lo storico nel formato richiesto da Open Router (OpenAI style)
    final messages = history.map((msg) {
      return {'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text};
    }).toList();

    // Usiamo il system prompt fornito o quello di default
    final finalSystemPrompt =
        systemPrompt ?? t.ai.openRouter.defaultSystemPrompt;

    messages.insert(0, {'role': 'system', 'content': finalSystemPrompt});

    final body = jsonEncode({
      'model': kOpenRouterDefaultModel,
      'messages': messages,
      'temperature': 0.7,
    });

    try {
      AppLogger.info('[OpenRouter] Invio richiesta a $kOpenRouterDefaultModel');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer':
              'https://github.com/simo/mattioli.OS', // Richiesto da OpenRouter per il ranking
          'X-Title': 'Mattioli OS',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return content.toString().trim();
      } else if (isUnauthorized(response.statusCode)) {
        // The user's key is wrong / revoked / out of credit — actionable, and
        // not the generic "the AI broke" message.
        return t.ai.openRouter.apiKeyInvalid;
      } else {
        AppLogger.error(
          '[OpenRouter] Errore API: ${response.statusCode} - ${response.body}',
          null,
          null,
        );
        return t.ai.openRouter.communicationError(code: response.statusCode);
      }
    } catch (e, stack) {
      AppLogger.error('[OpenRouter] Eccezione durante la chiamata', e, stack);
      return t.ai.openRouter.connectionError;
    }
  }

  static Stream<String> generateStreamResponse(
    List<ChatMessage> history, {
    String? systemPrompt,
  }) async* {
    // Checked before the connectivity probe: a user with no key needs the setup
    // message, not "you're offline".
    final apiKey = await _keyStore.read();
    if (apiKey == null) {
      yield t.ai.openRouter.apiKeyMissingShort;
      return;
    }

    // Verifica preventiva della connessione a internet
    try {
      final result = await InternetAddress.lookup(
        'openrouter.ai',
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

    final url = Uri.parse('$kOpenRouterBaseUrl/chat/completions');

    final messages = history.map((msg) {
      return {'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text};
    }).toList();

    final finalSystemPrompt =
        systemPrompt ?? t.ai.openRouter.defaultSystemPrompt;

    messages.insert(0, {'role': 'system', 'content': finalSystemPrompt});

    final body = jsonEncode({
      'model': kOpenRouterDefaultModel,
      'messages': messages,
      'temperature': 0.7,
      'stream': true,
    });

    final client = http.Client();
    final request = http.Request('POST', url)
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..headers['Content-Type'] = 'application/json'
      ..headers['HTTP-Referer'] = 'https://github.com/simo/mattioli.OS'
      ..headers['X-Title'] = 'Mattioli OS'
      ..body = body;

    try {
      // Timeout di 15 secondi per stabilire la connessione
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        AppLogger.error(
          '[OpenRouter] Errore API streaming',
          'Status: ${response.statusCode}, Body: $errorBody',
        );

        if (isUnauthorized(response.statusCode)) {
          yield t.ai.openRouter.apiKeyInvalid;
        } else if (response.statusCode == 400) {
          yield t.ai.openRouter.contextTooLong;
        } else {
          yield t.ai.openRouter.apiError(code: response.statusCode);
        }
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
