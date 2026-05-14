import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../models/macro_goal.dart';
import '../../providers/goal_provider.dart';
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
  bool _showPrompts = true;

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
    HapticFeedback.mediumImpact();

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

    // Variable delay for natural feel (1-3s)
    final delay = 1000 + (text.length * 20).clamp(0, 2000);
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      HapticFeedback.lightImpact();
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
    final goals = ref.read(macroGoalsProvider).goals;
    final habits = ref.read(goalsProvider);
    final habitLogs = ref.read(habitLogsProvider);
    final userName = ref.read(userProfileProvider).firstName ?? 'utente';

    // Compute real stats
    final activeGoals = goals.where((g) => g.status == GoalStatus.active).toList();
    final completedGoals = goals.where((g) => g.status == GoalStatus.completed).length;
    final todayKey = _todayKey();
    final todayLogs = habitLogs[todayKey] ?? {};
    final todayDone = todayLogs.values.where((s) => s == 'done').length;
    final todayTotal = habits.where((h) => h.isActiveOn(DateTime.now())).length;

    if (lower.contains('obiettivo') || lower.contains('obiettivi') || lower.contains('goal')) {
      if (activeGoals.isEmpty) {
        return "Non hai ancora obiettivi attivi, $userName. Vai alla sezione Macro Goals per crearne uno — avere una direzione chiara è il primo passo verso la disciplina.";
      }
      final titles = activeGoals.take(3).map((g) => '• ${g.title}').join('\n');
      return "Ecco i tuoi obiettivi attivi ($userName):\n\n$titles\n\n${activeGoals.length > 3 ? '...e altri ${activeGoals.length - 3}\n\n' : ''}Hai completato $completedGoals obiettivi in totale. Continua così! 💪";
    }

    if (lower.contains('oggi') || lower.contains('today') || lower.contains('giornata')) {
      if (todayTotal == 0) return "Non hai abitudini programmate per oggi. Approfitta per riflettere sui tuoi obiettivi a lungo termine!";
      final pct = todayTotal > 0 ? ((todayDone / todayTotal) * 100).round() : 0;
      String motivation;
      if (pct == 100) {
        motivation = "Sei una macchina, $userName! Tutte le abitudini completate. 🔥";
      } else if (pct >= 70) {
        motivation = "Ottimo progresso! Mancano solo ${todayTotal - todayDone} abitudini. Finisci forte! 💪";
      } else if (pct >= 30) {
        motivation = "Sei a buon punto. Non mollare adesso, la costanza paga! ⚡";
      } else {
        motivation = "La giornata non è ancora finita. Ogni piccola azione conta! 🌱";
      }
      return "Oggi hai completato $todayDone su $todayTotal abitudini ($pct%).\n\n$motivation";
    }

    if (lower.contains('statistiche') || lower.contains('stats') || lower.contains('grafici') || lower.contains('andamento')) {
      final last7 = _getLast7DaysRate(habitLogs, habits);
      return "📊 Ultimi 7 giorni: tasso di completamento del $last7%.\n\nHai $completedGoals obiettivi macro completati e ${activeGoals.length} ancora attivi.\n\nVai nella sezione Statistiche per un'analisi dettagliata di ogni abitudine!";
    }

    if (lower.contains('consiglio') || lower.contains('disciplina') || lower.contains('motivazione') || lower.contains('aiut')) {
      final tips = [
        "🧠 Regola dei 2 minuti: se qualcosa richiede meno di 2 minuti, fallo subito.",
        "🐸 Eat That Frog: affronta il compito più difficile per primo — il resto sembrerà facile.",
        "📐 Atomic Habits: non concentrarti sul risultato, ma sul sistema. L'1% ogni giorno fa la differenza.",
        "⏰ Tecnica del Pomodoro: 25 min di focus + 5 di pausa. La mente ha bisogno di ritmo.",
        "🎯 Identità prima dell'obiettivo: non dire 'voglio correre', dì 'sono un runner'. Il cambiamento parte dall'identità.",
        "🔄 Non rompere la catena: ogni giorno completato è un anello. Non spezzare la streak!",
        "🌙 Routine serale: prepara domani stasera. La mattina sarai già in vantaggio.",
      ];
      tips.shuffle();
      return "${tips.first}\n\n$userName, la disciplina non è talento — è una scelta quotidiana.";
    }

    if (lower.contains('abitudin') || lower.contains('habit')) {
      if (habits.isEmpty) return "Non hai ancora abitudini configurate. Creane una dalla dashboard per iniziare il tuo percorso! 🚀";
      final names = habits.take(5).map((h) => '• ${h.title}').join('\n');
      return "Le tue abitudini attive:\n\n$names\n\n${habits.length > 5 ? '...e altre ${habits.length - 5}\n\n' : ''}Oggi ne hai completate $todayDone su $todayTotal. Continua a costruire la tua routine! ⚡";
    }

    // Fallback intelligente
    final fallbacks = [
      "Ricevuto, $userName. Prova a chiedermi:\n\n• Come sta andando la mia giornata?\n• Dammi un consiglio sulla disciplina\n• Analizza le mie statistiche\n• Come vanno i miei obiettivi?",
      "Sono qui per aiutarti, $userName! Posso analizzare i tuoi obiettivi, darti consigli sulla disciplina, o fare il punto sulla tua giornata. Cosa preferisci?",
    ];
    fallbacks.shuffle();
    return fallbacks.first;
  }

  List<String> _getDynamicSuggestions() {
    final now = DateTime.now();
    final hour = now.hour;
    final List<String> pool = [];

    // 1. Time-based pool
    if (hour >= 5 && hour < 12) {
      pool.addAll([
        "🌅 Pianifica la mia giornata",
        "🎯 Su cosa dovrei concentrarmi oggi?",
        "🧘‍♂️ Esercizio di visualizzazione per oggi",
        "🔥 Dammi la carica per iniziare!",
      ]);
    } else if (hour >= 12 && hour < 18) {
      pool.addAll([
        "📊 Come sta andando la mia giornata?",
        "⚡ Ho un calo di energia, cosa faccio?",
        "📉 Verifica abitudini pomeridiane",
        "💪 Un consiglio per rimanere focalizzato",
      ]);
    } else {
      pool.addAll([
        "🌙 Facciamo la review della giornata",
        "📝 Riflessione sulla disciplina di oggi",
        "🛌 Come prepararsi per un domani produttivo?",
        "🕯️ Analisi dei fallimenti di oggi",
      ]);
    }

    // 2. Context-based pool
    final goals = ref.read(macroGoalsProvider).goals;
    final habits = ref.read(goalsProvider);
    final habitLogs = ref.read(habitLogsProvider);

    final activeGoals = goals.where((g) => g.status == GoalStatus.active).toList();
    final todayKey = _todayKey();
    final todayLogs = habitLogs[todayKey] ?? {};
    final todayDone = todayLogs.values.where((s) => s == 'done').length;
    final todayTotal = habits.where((h) => h.isActiveOn(DateTime.now())).length;

    if (activeGoals.isNotEmpty) {
      pool.add("🎯 Analizza i miei obiettivi attivi");
    }
    if (habits.isNotEmpty) {
      pool.add("📈 Come sta andando la mia costanza?");
      pool.add("📊 Le mie statistiche settimanali");
    }
    
    if (todayTotal > 0) {
      final pct = (todayDone / todayTotal) * 100;
      if (pct == 100) {
        pool.add("🚀 Come posso alzare l'asticella?");
      } else if (pct < 30 && hour > 14) {
        pool.add("🤕 Come recuperare se ho procrastinato?");
      }
    }

    // Always add some generic high-value ones if pool is small
    pool.addAll([
      "🔥 Consiglio sulla disciplina",
      "💡 Come creare una nuova abitudine?",
      "🧠 Come evitare le distrazioni?",
    ]);

    // Remove duplicates
    final uniquePool = pool.toSet().toList();

    // Deterministic selection based on message count to be stable per state
    final offset = _messages.length % uniquePool.length;
    final List<String> selected = [];
    for (int i = 0; i < 4; i++) {
      selected.add(uniquePool[(offset + i) % uniquePool.length]);
    }
    
    return selected;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _getLast7DaysRate(HabitLogsMap logs, List<Goal> habits) {
    int totalDone = 0;
    int totalExpected = 0;
    for (int i = 0; i < 7; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final activeCount = habits.where((h) => h.isActiveOn(d)).length;
      totalExpected += activeCount;
      final dayLogs = logs[key] ?? {};
      totalDone += dayLogs.values.where((s) => s == 'done').length;
    }
    return totalExpected > 0 ? ((totalDone / totalExpected) * 100).round() : 0;
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
    final userProfile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            // AI Avatar with gradient ring
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1), Color(0xFF3B82F6)],
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.background,
                ),
                child: Icon(LucideIcons.sparkles, size: 16, color: colors.foreground),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("AI Coach"),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF26C252),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Online per ${userProfile.displayName}",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_messages.length > 1)
            IconButton(
              icon: Icon(LucideIcons.trash2, size: 18, color: colors.mutedForeground),
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _messages.clear();
                  _addInitialMessages();
                });
              },
              tooltip: 'Nuova chat',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                  return _FadeInSlide(
                    key: ValueKey(message.timestamp.millisecondsSinceEpoch),
                    child: _buildMessageBubble(message, colors),
                  );
                },
              ),
            ),

            // Suggested Prompts & Coach Card
            // 1. Coach Card (only when empty)
            if (_messages.length == 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassCardDecoration(context, radius: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                          ),
                        ),
                        child: const Icon(LucideIcons.sparkles, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Coach Virtuale",
                              style: TextStyle(
                                color: colors.foreground,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Pronto ad aiutarti a mantenere la disciplina.",
                              style: TextStyle(
                                color: colors.mutedForeground,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 2. Suggested Prompts (Always active, collapsible)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showPrompts = !_showPrompts;
                      });
                      HapticFeedback.lightImpact();
                    },
                    child: Row(
                      children: [
                        Text(
                          "Suggerimenti",
                          style: TextStyle(
                            color: colors.mutedForeground,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showPrompts ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                          size: 14,
                          color: colors.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                  if (_showPrompts) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _getDynamicSuggestions().map((text) => _buildSuggestedPrompt(text, colors)).toList(),
                    ),
                  ],
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
                    onTap: _isTyping ? null : () => _sendMessage(_controller.text),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: _isTyping
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                              ),
                        color: _isTyping ? colors.muted : null,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.arrowUp,
                        size: 20,
                        color: _isTyping ? colors.mutedForeground : Colors.white,
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
      onTap: () {
        HapticFeedback.lightImpact();
        _sendMessage(text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.borderHover),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: colors.foreground,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, AppColorsExtension colors) {
    final isUser = message.isUser;
    final bubble = GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: message.text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Messaggio copiato",
              style: TextStyle(color: colors.foreground),
            ),
            backgroundColor: colors.cardElevated,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? null : colors.card.withValues(alpha: 0.8),
          gradient: isUser
              ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)])
              : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          border: isUser ? null : Border.all(color: colors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : colors.foreground,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
              style: TextStyle(
                color: isUser
                    ? Colors.white.withValues(alpha: 0.6)
                    : colors.mutedForeground,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: bubble,
        ),
      );
    }

    // AI message with avatar
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
              ),
            ),
            child: const Icon(LucideIcons.sparkles, size: 13, color: Colors.white),
          ),
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(AppColorsExtension colors) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          children: List.generate(3, (i) => _BouncingDot(delay: i * 200, color: colors.mutedForeground)),
        ),
      ),
    );
  }
}

/// Animated bouncing dot for the typing indicator
class _BouncingDot extends StatefulWidget {
  final int delay;
  final Color color;
  const _BouncingDot({required this.delay, required this.color});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: child,
      ),
      child: Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Animated wrapper for message entrance
class _FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<_FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<_FadeInSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

