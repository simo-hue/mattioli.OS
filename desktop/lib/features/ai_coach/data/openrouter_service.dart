import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import '../domain/chat_message.dart';
import 'openrouter_config.dart';

class OpenRouterService {
  /// Genera una risposta dall'LLM tramite Open Router.
  /// Prende in input lo storico dei messaggi per mantenere il contesto.
  static Future<String> generateResponse(
    List<ChatMessage> history, {
    String? systemPrompt,
  }) async {
    // Verifica se la chiave API è stata inserita
    if (OpenRouterConfig.apiKey == 'YOUR_OPENROUTER_API_KEY' ||
        OpenRouterConfig.apiKey.isEmpty) {
      return t.ai.openRouter.apiKeyMissingFull;
    }

    final url = Uri.parse('${OpenRouterConfig.baseUrl}/chat/completions');

    // Convertiamo lo storico nel formato richiesto da Open Router (OpenAI style)
    final messages = history.map((msg) {
      return {'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text};
    }).toList();

    // Usiamo il system prompt fornito o quello di default
    final finalSystemPrompt =
        systemPrompt ?? t.ai.openRouter.defaultSystemPrompt;

    messages.insert(0, {'role': 'system', 'content': finalSystemPrompt});

    final body = jsonEncode({
      'model': OpenRouterConfig.defaultModel,
      'messages': messages,
      'temperature': 0.7,
    });

    try {
      debugPrint(
        '[OpenRouter] Invio richiesta a ${OpenRouterConfig.defaultModel}',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${OpenRouterConfig.apiKey}',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/simo/mattioli.OS',
          'X-Title': 'Mattioli OS (Desktop)',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return content.toString().trim();
      } else {
        AppLogger.error(
          '[OpenRouter] Errore API: ${response.statusCode} - ${response.body}',
          Exception('API Error'),
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
    if (OpenRouterConfig.apiKey == 'YOUR_OPENROUTER_API_KEY' ||
        OpenRouterConfig.apiKey.isEmpty) {
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

    final url = Uri.parse('${OpenRouterConfig.baseUrl}/chat/completions');

    final messages = history.map((msg) {
      return {'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text};
    }).toList();

    final finalSystemPrompt =
        systemPrompt ?? t.ai.openRouter.defaultSystemPrompt;

    messages.insert(0, {'role': 'system', 'content': finalSystemPrompt});

    final body = jsonEncode({
      'model': OpenRouterConfig.defaultModel,
      'messages': messages,
      'temperature': 0.7,
      'stream': true,
    });

    final client = http.Client();
    final request = http.Request('POST', url)
      ..headers['Authorization'] = 'Bearer ${OpenRouterConfig.apiKey}'
      ..headers['Content-Type'] = 'application/json'
      ..headers['HTTP-Referer'] = 'https://github.com/simo/mattioli.OS'
      ..headers['X-Title'] = 'Mattioli OS (Desktop)'
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

        if (response.statusCode == 400) {
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
            debugPrint('[OpenRouter] Errore parsing chunk JSON: $e');
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
