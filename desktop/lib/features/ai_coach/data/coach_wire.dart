import 'dart:convert';

import '../domain/chat_message.dart';
import '../domain/coach_backend.dart';

/// Pure helpers for the OpenAI-compatible chat wire format shared by the cloud
/// (OpenRouter) and local (Ollama / LM Studio / llama.cpp / …) backends.
///
/// Kept free of any IO so the request shaping and the streaming/model parsers
/// can be unit-tested without a network or a running server.

/// Builds the JSON body for `POST {baseUrl}/chat/completions`.
///
/// The [systemPrompt] is prepended as the first `system` message, then the full
/// [history] (user + assistant turns) so follow-ups keep context. `stream` is
/// only emitted when true (some servers reject an explicit `stream: false`).
Map<String, dynamic> buildChatRequestBody({
  required List<ChatMessage> history,
  required String systemPrompt,
  required String model,
  required double temperature,
  required bool stream,
}) {
  return {
    'model': model,
    'messages': <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      for (final message in history)
        {
          'role': message.isUser ? 'user' : 'assistant',
          'content': message.text,
        },
    ],
    'temperature': temperature,
    if (stream) 'stream': true,
  };
}

/// The meaningful outcome of parsing one line of an OpenAI-style SSE stream.
class SseChunk {
  const SseChunk({this.content, this.done = false});

  /// A content delta to append to the assistant reply, if any.
  final String? content;

  /// True when the line signalled end-of-stream (`data: [DONE]`).
  final bool done;

  bool get hasContent => content != null && content!.isNotEmpty;
}

/// Parses a single SSE line from `/chat/completions?stream=true`.
///
/// Handles both `data:` and `data: ` prefixes, the `[DONE]` sentinel, and
/// malformed/keep-alive lines (returned as an empty, non-done chunk). Never
/// throws.
SseChunk parseOpenAiSseLine(String line) {
  if (!line.startsWith('data:')) return const SseChunk();

  final payload = line.substring(5).trimLeft();
  if (payload.isEmpty) return const SseChunk();
  if (payload == '[DONE]') return const SseChunk(done: true);

  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map) {
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          // Streaming responses carry the token under delta.content; some
          // servers (and the final non-stream frame) use message.content.
          final delta = first['delta'];
          final content = (delta is Map ? delta['content'] : null) ??
              (first['message'] is Map
                  ? (first['message'] as Map)['content']
                  : null);
          if (content is String) return SseChunk(content: content);
        }
      }
    }
  } catch (_) {
    // Partial/garbage frame — swallow and wait for the next line.
  }
  return const SseChunk();
}

/// Parses a `GET {baseUrl}/models` (or Ollama's native `/api/tags`) response
/// body into the list of available models. Tolerates both the OpenAI shape
/// (`{"data":[{"id":…}]}`) and the Ollama-native shape (`{"models":[{"name":…}]}`).
/// Returns an empty list on any parse failure.
List<CoachModel> parseModelsResponse(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final data = decoded['data'];
      if (data is List) {
        return [
          for (final entry in data)
            if (entry is Map && entry['id'] is String)
              CoachModel(id: entry['id'] as String),
        ];
      }
      final models = decoded['models'];
      if (models is List) {
        return [
          for (final entry in models)
            if (entry is Map && entry['name'] is String)
              CoachModel(id: entry['name'] as String),
        ];
      }
    }
  } catch (_) {
    // Not JSON / unexpected shape — treat as "no models discovered".
  }
  return const [];
}
