import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;


import '../models/chat_message.dart';
import 'openrouter_config.dart';
import 'app_logger.dart';

class OpenRouterService {
  /// Genera una risposta dall'LLM tramite Open Router.
  /// Prende in input lo storico dei messaggi per mantenere il contesto.
  static Future<String> generateResponse(List<ChatMessage> history, {String? systemPrompt}) async {
    // Verifica se la chiave API è stata inserita
    if (OpenRouterConfig.apiKey == 'YOUR_OPENROUTER_API_KEY' || OpenRouterConfig.apiKey.isEmpty) {
      return "⚠️ Errore: Chiave API di Open Router non configurata.\n\nPer favore, inserisci la tua chiave API nel file `lib/core/openrouter_config.dart`.";
    }

    final url = Uri.parse('${OpenRouterConfig.baseUrl}/chat/completions');
    
    // Convertiamo lo storico nel formato richiesto da Open Router (OpenAI style)
    final messages = history.map((msg) {
      return {
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
      };
    }).toList();

    // Usiamo il system prompt fornito o quello di default
    final finalSystemPrompt = systemPrompt ?? 'Sei il "Coach di Disciplina", un assistente virtuale focalizzato sull\'aiutare l\'utente a mantenere la disciplina, raggiungere i propri obiettivi e costruire abitudini sane. Sii motivante ma concreto, diretto e pratico. Usa un tono professionale ma amichevole.';

    messages.insert(0, {
      'role': 'system',
      'content': finalSystemPrompt,
    });


    final body = jsonEncode({
      'model': OpenRouterConfig.defaultModel,
      'messages': messages,
      'temperature': 0.7,
    });

    try {
      AppLogger.info('[OpenRouter] Invio richiesta a ${OpenRouterConfig.defaultModel}');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${OpenRouterConfig.apiKey}',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/simo/mattioli.OS', // Richiesto da OpenRouter per il ranking
          'X-Title': 'Mattioli OS',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return content.toString().trim();
      } else {
        AppLogger.error('[OpenRouter] Errore API: ${response.statusCode} - ${response.body}', null, null);
        return "❌ Errore nella comunicazione con l'AI. (Codice: ${response.statusCode})";
      }
    } catch (e, stack) {
      AppLogger.error('[OpenRouter] Eccezione durante la chiamata', e, stack);
      return "❌ Errore di connessione. Assicurati di essere online e riprova.";
    }
  }

  static Stream<String> generateStreamResponse(List<ChatMessage> history, {String? systemPrompt}) async* {
    if (OpenRouterConfig.apiKey == 'YOUR_OPENROUTER_API_KEY' || OpenRouterConfig.apiKey.isEmpty) {
      yield "⚠️ Errore: Chiave API di Open Router non configurata.";
      return;
    }

    // Verifica preventiva della connessione a internet
    try {
      final result = await InternetAddress.lookup('openrouter.ai').timeout(const Duration(seconds: 5));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        yield "❌ Errore: Nessuna connessione a internet. Verifica la tua rete.";
        return;
      }
    } on SocketException catch (_) {
      yield "❌ Errore: Nessuna connessione a internet. Verifica la tua rete.";
      return;
    } on TimeoutException catch (_) {
      yield "❌ Errore: La verifica della connessione ha impiegato troppo tempo.";
      return;
    }

    final url = Uri.parse('${OpenRouterConfig.baseUrl}/chat/completions');

    
    final messages = history.map((msg) {
      return {
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
      };
    }).toList();

    final finalSystemPrompt = systemPrompt ?? 'Sei il "Coach di Disciplina", un assistente virtuale focalizzato sull\'aiutare l\'utente a mantenere la disciplina, raggiungere i propri obiettivi e costruire abitudini sane. Sii motivante ma concreto, diretto e pratico. Usa un tono professionale ma amichevole.';
    
    messages.insert(0, {
      'role': 'system',
      'content': finalSystemPrompt,
    });

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
      final response = await client.send(request).timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        AppLogger.error('[OpenRouter] Errore API streaming', 'Status: ${response.statusCode}, Body: $errorBody');
        
        if (response.statusCode == 400) {
          yield "⚠️ Limite di memoria superato o richiesta non valida. La conversazione potrebbe essere troppo lunga o complessa. Usa l'icona del cestino in alto per svuotare la chat e ricominciare!";
        } else {
          yield "❌ Errore API: ${response.statusCode} (Verifica Sentry per i dettagli)";
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
            AppLogger.warning('[OpenRouter] Errore parsing chunk JSON', e, null, {'dataStr': dataStr});
          }

        }
      }
    } on TimeoutException catch (e, stack) {
      AppLogger.error('[OpenRouter] Timeout streaming', e, stack);
      yield "❌ Errore: Il server sta impiegando troppo tempo a rispondere. Riprova.";
    } catch (e, stack) {
      AppLogger.error('[OpenRouter] Eccezione streaming', e, stack);
      yield "❌ Errore di connessione.";

    } finally {
      client.close();
    }
  }
}
