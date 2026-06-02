import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AiCoachPage extends StatefulWidget {
  const AiCoachPage({super.key});

  @override
  State<AiCoachPage> createState() => _AiCoachPageState();
}

class _AiCoachPageState extends State<AiCoachPage> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[_welcomeMessage];
  bool _shareHabits = true;
  bool _shareGoals = true;
  bool _typing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send([String? prompt]) async {
    final text = (prompt ?? _controller.text).trim();
    if (text.isEmpty || _typing) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, fromCoach: false));
      _controller.clear();
      _typing = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          text:
              'Ho preparato il contesto desktop con ${_shareHabits ? 'le abitudini' : 'le abitudini escluse'} e ${_shareGoals ? 'gli obiettivi' : 'gli obiettivi esclusi'}. La risposta streaming reale verra attivata tramite l\'adapter OpenRouter condiviso dopo la configurazione sicura delle credenziali.',
          fromCoach: true,
        ),
      );
      _typing = false;
    });
  }

  void _newConversation() {
    setState(() {
      _messages
        ..clear()
        ..add(_welcomeMessage);
      _typing = false;
    });
  }

  void _clearConversation() {
    setState(() {
      _messages.clear();
      _typing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DesktopPage(
      title: 'AI Coach',
      subtitle:
          'Ragiona sui pattern con un coach contestuale basato sui dati del percorso.',
      trailing: const StatusPill(
        label: 'Evolve Pro',
        color: EvolveColors.amber,
        icon: Icons.auto_awesome_outlined,
      ),
      child: SizedBox(
        height: 720,
        child: EvolvePanel(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              SizedBox(
                width: 275,
                child: _CoachSidebar(
                  shareHabits: _shareHabits,
                  shareGoals: _shareGoals,
                  onHabitsChanged: (value) {
                    setState(() => _shareHabits = value);
                  },
                  onGoalsChanged: (value) {
                    setState(() => _shareGoals = value);
                  },
                  onNewConversation: _newConversation,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _CoachHeader(onClear: _clearConversation),
                    const Divider(height: 1),
                    Expanded(
                      child: _messages.isEmpty
                          ? const _EmptyConversation()
                          : ListView.separated(
                              padding: const EdgeInsets.all(22),
                              itemCount: _messages.length + (_typing ? 1 : 0),
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                if (index == _messages.length) {
                                  return const _TypingIndicator();
                                }
                                return _MessageBubble(
                                  message: _messages[index],
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1),
                    _Composer(controller: _controller, onSend: _send),
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
  const _CoachSidebar({
    required this.shareHabits,
    required this.shareGoals,
    required this.onHabitsChanged,
    required this.onGoalsChanged,
    required this.onNewConversation,
  });

  final bool shareHabits;
  final bool shareGoals;
  final ValueChanged<bool> onHabitsChanged;
  final ValueChanged<bool> onGoalsChanged;
  final VoidCallback onNewConversation;

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
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          Text(
            'CONTESTO CONDIVISO',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Abitudini'),
            value: shareHabits,
            onChanged: onHabitsChanged,
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Obiettivi'),
            value: shareGoals,
            onChanged: onGoalsChanged,
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onNewConversation,
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
  const _CoachHeader({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: context.evolveAccent.withValues(alpha: 0.13),
            child: Icon(
              Icons.auto_awesome_outlined,
              color: context.evolveAccent,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
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
                  'Contesto selettivo · streaming adapter pending',
                  style: TextStyle(color: EvolveColors.subtle, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Pulisci conversazione',
            onPressed: onClear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final Future<void> Function([String? prompt]) onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final prompt in const [
                'Dove sto perdendo consistenza?',
                'Riassumi la settimana',
                'Quale obiettivo richiede attenzione?',
              ])
                ActionChip(
                  label: Text(prompt),
                  onPressed: () => onSend(prompt),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Chiedi qualcosa sui tuoi progressi...',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: onSend,
                icon: const Icon(Icons.arrow_upward_rounded),
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
        constraints: const BoxConstraints(maxWidth: 660),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: message.fromCoach
                ? context.evolveColors.panelRaised
                : context.evolveAccent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: message.fromCoach
                  ? context.evolveColors.border
                  : context.evolveAccent.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  message.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (message.fromCoach) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Copia messaggio',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                  },
                  icon: const Icon(Icons.copy_outlined, size: 16),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: StatusPill(
        label: 'Evolve Coach sta preparando la risposta...',
        color: EvolveColors.violet,
        icon: Icons.more_horiz_rounded,
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'La conversazione e vuota. Scrivi una domanda o usa un prompt rapido.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromCoach});

  final String text;
  final bool fromCoach;
}

const _welcomeMessage = _ChatMessage(
  text:
      'Ho analizzato il protocollo. La routine del mattino continua a essere il tuo abilitatore principale: nei giorni in cui la completi, il deep work sale sensibilmente.',
  fromCoach: true,
);
