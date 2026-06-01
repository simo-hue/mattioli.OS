import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';

class AiCoachPage extends StatefulWidget {
  const AiCoachPage({super.key});

  @override
  State<AiCoachPage> createState() => _AiCoachPageState();
}

class _AiCoachPageState extends State<AiCoachPage> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      text:
          'Ho analizzato il tuo protocollo. La routine del mattino continua a essere il tuo abilitatore principale: nei giorni in cui la completi, il deep work sale sensibilmente.',
      fromCoach: true,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, fromCoach: false));
      _messages.add(
        const _ChatMessage(
          text:
              'Il collegamento al servizio AI condiviso con il mobile verra attivato nello strato repository. La UI desktop e gia pronta per ricevere risposte in streaming.',
          fromCoach: true,
        ),
      );
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopPage(
      title: 'AI Coach',
      subtitle:
          'Ragiona sui tuoi pattern con un coach contestuale, basato sui dati del tuo percorso.',
      trailing: const StatusPill(
        label: 'Evolve Pro',
        color: EvolveColors.amber,
        icon: Icons.auto_awesome_outlined,
      ),
      child: SizedBox(
        height: 680,
        child: EvolvePanel(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              const SizedBox(width: 250, child: _CoachSidebar()),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    const _CoachHeader(),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(22),
                        itemCount: _messages.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) =>
                            _MessageBubble(message: _messages[index]),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              onSubmitted: (_) => _send(),
                              decoration: const InputDecoration(
                                hintText:
                                    'Chiedi qualcosa sui tuoi progressi...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            onPressed: _send,
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                        ],
                      ),
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

class _CoachSidebar extends StatelessWidget {
  const _CoachSidebar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('CONVERSAZIONI', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 13),
          const _ConversationTile(label: 'Analisi settimanale', selected: true),
          const _ConversationTile(label: 'Obiettivi Q3'),
          const _ConversationTile(label: 'Routine del mattino'),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Nuova chat'),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? EvolveColors.violet.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? EvolveColors.violet : EvolveColors.muted,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _CoachHeader extends StatelessWidget {
  const _CoachHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Color(0x2210B981),
            child: Icon(
              Icons.auto_awesome_outlined,
              color: EvolveColors.primaryStrong,
              size: 17,
            ),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evolve Coach',
                style: TextStyle(
                  color: EvolveColors.foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Contesto aggiornato oggi',
                style: TextStyle(color: EvolveColors.subtle, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.fromCoach
          ? Alignment.centerLeft
          : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: message.fromCoach
                ? EvolveColors.panelRaised
                : EvolveColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: message.fromCoach
                  ? EvolveColors.border
                  : EvolveColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            message.text,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromCoach});

  final String text;
  final bool fromCoach;
}
