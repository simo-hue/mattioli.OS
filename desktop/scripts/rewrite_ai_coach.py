import re

content = """import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:ui';

import '../domain/chat_message.dart';
import '../data/openrouter_service.dart';

class AiCoachPage extends ConsumerStatefulWidget {
  const AiCoachPage({super.key});

  @override
  ConsumerState<AiCoachPage> createState() => _AiCoachPageState();
}

class _AiCoachPageState extends ConsumerState<AiCoachPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _shareHabits = true;
  bool _shareGoals = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: 'Ciao! Sono Evolve AI Coach. Sono qui per aiutarti a ottimizzare il tuo protocollo e raggiungere i tuoi obiettivi. Come posso esserti utile oggi?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    _scrollToBottom();

    // Inietta contesto se abilitato
    final snapshot = ref.read(dashboardControllerProvider);
    String contextPrompt = "Sei Evolve AI Coach, un assistente virtuale per la disciplina personale.\\n";
    
    if (_shareHabits) {
      contextPrompt += "\\nABITUDINI ATTIVE:\\n";
      final habits = snapshot.habits;
      if (habits.isEmpty) {
        contextPrompt += "- Nessuna abitudine attiva.\\n";
      } else {
        for (final h in habits) {
          final done = snapshot.habitStatusFor(h.id, DateTime.now()) == 'done';
          contextPrompt += "- ${h.title} (Completata oggi: $done, Streak: ${h.streak})\\n";
        }
      }
    }

    if (_shareGoals) {
      contextPrompt += "\\nOBIETTIVI:\\n";
      final goals = snapshot.goals.where((g) => g.state == GoalState.active).toList();
      if (goals.isEmpty) {
        contextPrompt += "- Nessun obiettivo a lungo termine attivo.\\n";
      } else {
        for (final g in goals) {
          contextPrompt += "- ${g.title} (Scadenza: ${g.dueLabel})\\n";
        }
      }
    }

    // Risposta in streaming
    final stream = OpenRouterService.generateStreamResponse(
      _messages.where((m) => m.isUser).toList(),
      systemPrompt: contextPrompt,
    );

    // Placeholder per la risposta
    final responseIndex = _messages.length;
    setState(() {
      _messages.add(ChatMessage(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });

    String currentResponse = '';

    await for (final chunk in stream) {
      if (!mounted) return;
      currentResponse += chunk;
      setState(() {
        _messages[responseIndex] = ChatMessage(
          text: currentResponse,
          isUser: false,
          timestamp: DateTime.now(),
        );
      });
      _scrollToBottom();
    }

    setState(() {
      _isTyping = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.evolveColors.background,
          title: Text(
            'Contesto AI',
            style: TextStyle(
              color: context.evolveColors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scegli quali dati condividere con il Coach AI per ricevere consigli personalizzati.',
                style: TextStyle(color: context.evolveColors.foreground.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: Text('Abitudini Quotidiane', style: TextStyle(color: context.evolveColors.foreground)),
                subtitle: Text('Condivide le abitudini attive, le serie e lo stato di completamento di oggi.', style: TextStyle(color: context.evolveColors.foreground.withValues(alpha: 0.5), fontSize: 12)),
                value: _shareHabits,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) {
                  setDialogState(() => _shareHabits = val);
                  setState(() => _shareHabits = val);
                },
              ),
              SwitchListTile(
                title: Text('Obiettivi Macro', style: TextStyle(color: context.evolveColors.foreground)),
                subtitle: Text('Condivide i tuoi obiettivi attivi a lungo termine.', style: TextStyle(color: context.evolveColors.foreground.withValues(alpha: 0.5), fontSize: 12)),
                value: _shareGoals,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) {
                  setDialogState(() => _shareGoals = val);
                  setState(() => _shareGoals = val);
                },
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Salva e Chiudi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesktopPage(
      title: 'AI Coach',
      subtitle: 'Ragiona sui pattern con un coach contestuale basato sui dati del percorso.',
      trailing: PageActionButton(
        label: 'Contesto',
        icon: Icons.tune_rounded,
        onPressed: _showSettingsDialog,
      ),
      child: EvolvePanel(
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 230,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _MessageBubble(message: msg);
                  },
                ),
              ),
              if (_isTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'AI Coach sta scrivendo...',
                      style: TextStyle(
                        color: context.evolveColors.muted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: context.evolveColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: context.evolveColors.foreground),
                        decoration: InputDecoration(
                          hintText: 'Chiedi consigli al tuo Coach...',
                          hintStyle: TextStyle(color: context.evolveColors.muted),
                          filled: true,
                          fillColor: context.evolveColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      elevation: 0,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onPressed: _isTyping ? null : _sendMessage,
                      child: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser 
                    ? Theme.of(context).colorScheme.primary 
                    : context.evolveColors.background,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                  bottomLeft: !isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
                border: isUser ? null : Border.all(color: context.evolveColors.border),
              ),
              child: isUser 
                ? Text(
                    message.text, 
                    style: const TextStyle(color: Colors.white),
                  )
                : MarkdownBody(
                    data: message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: context.evolveColors.foreground),
                      h1: TextStyle(color: context.evolveColors.foreground, fontWeight: FontWeight.bold),
                      h2: TextStyle(color: context.evolveColors.foreground, fontWeight: FontWeight.bold),
                      h3: TextStyle(color: context.evolveColors.foreground, fontWeight: FontWeight.bold),
                      listBullet: TextStyle(color: context.evolveColors.foreground),
                      strong: TextStyle(color: context.evolveColors.foreground, fontWeight: FontWeight.bold),
                    ),
                  ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: context.evolveColors.background,
              child: Icon(Icons.person, color: context.evolveColors.foreground, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}
"""

with open('desktop/lib/features/ai_coach/presentation/ai_coach_page.dart', 'w') as f:
    f.write(content)
