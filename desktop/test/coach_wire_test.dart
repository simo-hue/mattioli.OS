// Pure-logic coverage for the OpenAI-compatible wire helpers shared by the
// cloud and local coach backends: request-body shaping, SSE line parsing, and
// model-list parsing (OpenAI + Ollama-native shapes).
import 'package:evolve_desktop/features/ai_coach/data/coach_wire.dart';
import 'package:evolve_desktop/features/ai_coach/domain/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _user(String text) =>
    ChatMessage(text: text, isUser: true, timestamp: DateTime(2026));
ChatMessage _assistant(String text) =>
    ChatMessage(text: text, isUser: false, timestamp: DateTime(2026));

void main() {
  group('buildChatRequestBody', () {
    test('prepends the system prompt and maps roles', () {
      final body = buildChatRequestBody(
        history: [_user('hi'), _assistant('hello'), _user('help')],
        systemPrompt: 'You are a coach.',
        model: 'llama3.1:8b',
        temperature: 0.7,
        stream: true,
      );

      expect(body['model'], 'llama3.1:8b');
      expect(body['temperature'], 0.7);
      expect(body['stream'], true);

      final messages = body['messages'] as List;
      expect(messages.first, {'role': 'system', 'content': 'You are a coach.'});
      expect(messages[1], {'role': 'user', 'content': 'hi'});
      expect(messages[2], {'role': 'assistant', 'content': 'hello'});
      expect(messages[3], {'role': 'user', 'content': 'help'});
    });

    test('omits the stream flag when false', () {
      final body = buildChatRequestBody(
        history: const [],
        systemPrompt: 's',
        model: 'm',
        temperature: 1.0,
        stream: false,
      );
      expect(body.containsKey('stream'), isFalse);
    });
  });

  group('parseOpenAiSseLine', () {
    test('extracts delta content', () {
      final chunk = parseOpenAiSseLine(
        'data: {"choices":[{"delta":{"content":"Hel"}}]}',
      );
      expect(chunk.content, 'Hel');
      expect(chunk.done, isFalse);
      expect(chunk.hasContent, isTrue);
    });

    test('handles the no-space data: prefix', () {
      final chunk = parseOpenAiSseLine(
        'data:{"choices":[{"delta":{"content":"lo"}}]}',
      );
      expect(chunk.content, 'lo');
    });

    test('recognises the [DONE] sentinel', () {
      final chunk = parseOpenAiSseLine('data: [DONE]');
      expect(chunk.done, isTrue);
      expect(chunk.content, isNull);
    });

    test('ignores non-data / keep-alive / blank lines', () {
      expect(parseOpenAiSseLine('').hasContent, isFalse);
      expect(parseOpenAiSseLine(': keep-alive').hasContent, isFalse);
      expect(parseOpenAiSseLine('event: message').done, isFalse);
      expect(parseOpenAiSseLine('data: ').hasContent, isFalse);
    });

    test('swallows malformed JSON without throwing', () {
      final chunk = parseOpenAiSseLine('data: {not json');
      expect(chunk.hasContent, isFalse);
      expect(chunk.done, isFalse);
    });

    test('falls back to message.content (non-stream final frame)', () {
      final chunk = parseOpenAiSseLine(
        'data: {"choices":[{"message":{"content":"full"}}]}',
      );
      expect(chunk.content, 'full');
    });

    test('empty-content delta yields no content (role-only opener)', () {
      final chunk = parseOpenAiSseLine(
        'data: {"choices":[{"delta":{"role":"assistant"}}]}',
      );
      expect(chunk.hasContent, isFalse);
    });
  });

  group('parseModelsResponse', () {
    test('parses the OpenAI /models shape (LM Studio, Ollama /v1)', () {
      final models = parseModelsResponse(
        '{"object":"list","data":[{"id":"llama3.1:8b"},{"id":"qwen2.5:7b"}]}',
      );
      expect(models.map((m) => m.id), ['llama3.1:8b', 'qwen2.5:7b']);
    });

    test('parses the Ollama-native /api/tags shape', () {
      final models = parseModelsResponse(
        '{"models":[{"name":"llama3.1:8b"},{"name":"phi3:mini"}]}',
      );
      expect(models.map((m) => m.id), ['llama3.1:8b', 'phi3:mini']);
    });

    test('skips entries without a string id/name', () {
      final models = parseModelsResponse(
        '{"data":[{"id":"ok"},{"nope":1},{"id":42}]}',
      );
      expect(models.map((m) => m.id), ['ok']);
    });

    test('returns empty on malformed / unexpected bodies', () {
      expect(parseModelsResponse('not json'), isEmpty);
      expect(parseModelsResponse('{}'), isEmpty);
      expect(parseModelsResponse('[]'), isEmpty);
    });
  });
}
