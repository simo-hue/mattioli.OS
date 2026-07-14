import 'chat_message.dart';

/// Default cap on how many trailing messages are sent to the model per request.
const int kMaxHistoryMessages = 20;

/// Caps the conversation history sent to the model to the last [maxMessages]
/// messages, so a long chat stops growing unboundedly into the model's
/// context-length limit. The system prompt is built separately and is not part
/// of this; only the user/assistant turns are trimmed. The most recent messages
/// (including the just-sent user message) are always kept.
List<ChatMessage> trimHistory(
  List<ChatMessage> messages, {
  int maxMessages = kMaxHistoryMessages,
}) {
  if (maxMessages <= 0 || messages.length <= maxMessages) {
    return List<ChatMessage>.from(messages);
  }
  return messages.sublist(messages.length - maxMessages);
}

/// Whether the scroll position is close enough to the bottom that new streamed
/// content should keep it pinned — as opposed to the user having scrolled up to
/// re-read history, in which case we must NOT yank them back down.
bool isNearBottom(
  double offset,
  double maxScrollExtent, {
  double threshold = 120,
}) {
  return maxScrollExtent - offset <= threshold;
}
