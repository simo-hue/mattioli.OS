// Pure coverage for the chat helpers: history trimming (context-length guard)
// and the near-bottom predicate (smart stick-to-bottom).
import 'package:evolve_desktop/features/ai_coach/domain/chat_message.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_chat_logic.dart';
import 'package:flutter_test/flutter_test.dart';

List<ChatMessage> _msgs(int n) => [
  for (var i = 0; i < n; i++)
    ChatMessage(text: 'm$i', isUser: i.isEven, timestamp: DateTime(2026, 1, 1, 0, i)),
];

void main() {
  group('trimHistory', () {
    test('returns all messages when under the cap', () {
      final all = _msgs(5);
      expect(trimHistory(all, maxMessages: 20).map((m) => m.text), [
        'm0',
        'm1',
        'm2',
        'm3',
        'm4',
      ]);
    });

    test('keeps only the last N when over the cap', () {
      final trimmed = trimHistory(_msgs(30), maxMessages: 20);
      expect(trimmed.length, 20);
      expect(trimmed.first.text, 'm10'); // dropped the oldest 10
      expect(trimmed.last.text, 'm29'); // most recent always kept
    });

    test('returns a copy (never the same instance)', () {
      final all = _msgs(3);
      final out = trimHistory(all, maxMessages: 20);
      expect(identical(out, all), isFalse);
      expect(out.length, all.length);
    });

    test('maxMessages <= 0 is treated as no trimming', () {
      expect(trimHistory(_msgs(5), maxMessages: 0).length, 5);
    });
  });

  group('isNearBottom', () {
    test('true at/near the bottom', () {
      expect(isNearBottom(1000, 1000), isTrue); // exactly at bottom
      expect(isNearBottom(920, 1000), isTrue); // 80px up, within 120
    });

    test('false when scrolled well up', () {
      expect(isNearBottom(500, 1000), isFalse); // 500px up
      expect(isNearBottom(879, 1000), isFalse); // 121px up, just outside
    });

    test('honors a custom threshold', () {
      expect(isNearBottom(950, 1000, threshold: 40), isFalse);
      expect(isNearBottom(970, 1000, threshold: 40), isTrue);
    });
  });
}
