import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/macro_goals_provider.dart';
import '../../providers/user_provider.dart';

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

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  static Route route() {
    return MaterialPageRoute(
      builder: (context) => const AIChatScreen(),
    );
  }

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _addInitialMessages();
  }

  void _addInitialMessages() {
    _messages.add(
      ChatMessage(
        text: "Ciao! Sono il tuo Coach di Disciplina. Come posso aiutarti oggi?",
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    // Simula risposta dell'AI
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            text: _generateResponse(text),
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();
    });
  }

  String _generateResponse(String input) {
    final lower = input.toLowerCase();
    if (lower.contains('obiettivo') || lower.contains('obiettivi')) {
      return "Ho analizzato i tuoi obiettivi attivi. Quello su cui ti stai concentrando di più è la costanza. Vuoi vedere un report dettagliato?";
    } else if (lower.contains('statistiche') || lower.contains('grafici')) {
      return "Le tue statistiche mostrano un miglioramento del 12% nella disciplina mattutina rispetto alla scorsa settimana. Continua così!";
    } else if (lower.contains('consiglio') || lower.contains('disciplina')) {
      return "Il mio consiglio per oggi: affronta la tarefa più difficile per prima (Eat that frog!). Questo libererà la tua mente per il resto della giornata.";
    }
    return "Ricevuto. Sto elaborando i tuoi dati per darti la risposta migliore nel contesto della tua disciplina.";
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final goalsState = ref.watch(macroGoalsProvider);
    final userProfile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Smart AI Coach"),
            Text(
              "In linea per ${userProfile.displayName}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.sparkles),
            onPressed: () {
              // Effetto visivo o info
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Quick Actions (Goals Pills)
            if (goalsState.goals.isNotEmpty)
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: goalsState.goals.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final goal = goalsState.goals[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(goal.title),
                        avatar: Icon(LucideIcons.target, size: 14, color: colors.foreground),
                        onPressed: () {
                          _sendMessage("Come sto andando con l'obiettivo: '${goal.title}'?");
                        },
                        backgroundColor: colors.card.withValues(alpha: 0.5),
                        side: BorderSide(color: colors.borderSubtle),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 2. Chat Area
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _buildTypingIndicator(colors);
                  }
                  final message = _messages[index];
                  return _buildMessageBubble(message, colors);
                },
              ),
            ),

            // Suggested Prompts
            if (_messages.length == 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _buildSuggestedPrompt(
                      "📊 Analizza le mie statistiche di questa settimana",
                      colors,
                    ),
                    const SizedBox(height: 8),
                    _buildSuggestedPrompt(
                      "🔥 Dammi un consiglio per la disciplina",
                      colors,
                    ),
                  ],
                ),
              ),

            // 3. Input Area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.background,
                border: Border(
                  top: BorderSide(color: colors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: AppTheme.glassCardDecoration(context, radius: 24),
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: colors.foreground),
                        decoration: InputDecoration(
                          hintText: "Fai una domanda...",
                          hintStyle: TextStyle(color: colors.mutedForeground),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _sendMessage(_controller.text),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.foreground,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.arrowUp,
                        size: 20,
                        color: colors.background,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedPrompt(String text, AppColorsExtension colors) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: AppTheme.glassCardDecoration(context, radius: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: colors.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, AppColorsExtension colors) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? colors.foreground
              : colors.card.withValues(alpha: 0.8),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(color: colors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? colors.background : colors.foreground,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
              style: TextStyle(
                color: isUser
                    ? colors.background.withValues(alpha: 0.7)
                    : colors.mutedForeground,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(AppColorsExtension colors) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(colors),
            const SizedBox(width: 4),
            _buildDot(colors),
            const SizedBox(width: 4),
            _buildDot(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(AppColorsExtension colors) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: colors.mutedForeground,
        shape: BoxShape.circle,
      ),
    );
  }
}
