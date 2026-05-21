import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import 'openrouter_config.dart';
import 'app_logger.dart';

class OpenRouterService {
  static AppLocalizations get _fallbackL10n {
    final locale = ui.PlatformDispatcher.instance.locale;
    try {
      return lookupAppLocalizations(locale);
    } catch (_) {
      return lookupAppLocalizations(const ui.Locale('en'));
    }
  }

  /// Genera una risposta dall'LLM tramite Open Router.
  /// Prende in input lo storico dei messaggi per mantenere il contesto.
  static Future<String> generateResponse(
    List<ChatMessage> history, {
    String? systemPrompt,
    AppLocalizations? l10n,
  }) async {
    final translations = l10n ?? _fallbackL10n;
    // Verifica se la chiave API è stata inserita
    if (OpenRouterConfig.apiKey == 'YOUR_OPENROUTER_API_KEY' ||
        OpenRouterConfig.apiKey.isEmpty) {
      return translations.openRouterApiKeyMissingFull;
    }

    final url = Uri.parse('${OpenRouterConfig.baseUrl}/chat/completions');

    // Convertiamo lo storico nel formato richiesto da Open Router (OpenAI style)
    final messages = history.map((msg) {
      return {'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text};
    }).toList();

    // Usiamo il system prompt fornito o quello di default
    final finalSystemPrompt =
        systemPrompt ?? translations.openRouterDefaultSystemPrompt;

    messages.insert(0, {'role': 'system', 'content': finalSystemPrompt});

    final body = jsonEncode({
      'model': OpenRouterConfig.defaultModel,
      'messages': messages,
      'temperature': 0.7,
    });

    try {
      AppLogger.info(
        '[OpenRouter] Invio richiesta a ${OpenRouterConfig.defaultModel}',
      );

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${OpenRouterConfig.apiKey}',
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
      } else {
        AppLogger.error(
          '[OpenRouter] Errore API: ${response.statusCode} - ${response.body}',
          null,
          null,
        );
        return translations.openRouterCommunicationError(response.statusCode);
      }
    } catch (e, stack) {
      AppLogger.error('[OpenRouter] Eccezione durante la chiamata', e, stack);
      return translations.openRouterConnectionError;
    }
  }

  static Stream<String> generateStreamResponse(
    List<ChatMessage> history, {
    String? systemPrompt,
    AppLocalizations? l10n,
  }) async* {
    final translations = l10n ?? _fallbackL10n;
    if (OpenRouterConfig.apiKey == 'YOUR_OPENROUTER_API_KEY' ||
        OpenRouterConfig.apiKey.isEmpty) {
      yield translations.openRouterApiKeyMissingShort;
      return;
    }

    // Verifica preventiva della connessione a internet
    try {
      final result = await InternetAddress.lookup(
        'openrouter.ai',
      ).timeout(const Duration(seconds: 5));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        yield translations.openRouterNoInternet;
        return;
      }
    } on SocketException catch (_) {
      yield translations.openRouterNoInternet;
      return;
    } on TimeoutException catch (_) {
      yield translations.openRouterConnectionCheckTimeout;
      return;
    }

    final url = Uri.parse('${OpenRouterConfig.baseUrl}/chat/completions');

    final messages = history.map((msg) {
      return {'role': msg.isUser ? 'user' : 'assistant', 'content': msg.text};
    }).toList();

    final finalSystemPrompt =
        systemPrompt ?? translations.openRouterDefaultSystemPrompt;

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

        if (response.statusCode == 400) {
          yield translations.openRouterContextTooLong;
        } else {
          yield translations.openRouterApiError(response.statusCode);
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
      yield translations.openRouterServerTimeout;
    } catch (e, stack) {
      AppLogger.error('[OpenRouter] Eccezione streaming', e, stack);
      yield translations.openRouterConnectionErrorShort;
    } finally {
      client.close();
    }
  }
}
