import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/openrouter_service.dart';
import 'package:mattioli_os/models/chat_message.dart';

void main() {
  test('generateStreamResponse returns a stream', () {
    final history = [
      ChatMessage(text: 'Hi', isUser: true, timestamp: DateTime.now()),
    ];
    
    final stream = OpenRouterService.generateStreamResponse(history);
    
    expect(stream, isA<Stream<String>>());
  });
}

