class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? actionLabel;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.actionLabel,
  });
}
