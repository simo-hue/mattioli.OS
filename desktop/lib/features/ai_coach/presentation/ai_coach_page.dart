import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../domain/chat_message.dart';
import '../data/openrouter_service.dart';

/// Pure prompt-suggestion selection (time of day + which context switches are
/// on), extracted for testing. Returns up to four unique suggestions, chosen
/// deterministically by [messageCount] so they stay stable within a state.
List<String> buildAiSuggestions({
  required int hour,
  required bool shareGoals,
  required bool shareHabits,
  required bool hasActiveGoals,
  required int todayDone,
  required int todayTotal,
  required int messageCount,
}) {
  final pool = <String>[];
  if (hour >= 5 && hour < 12) {
    pool.addAll([
      t.ai.suggestions.morningBoost,
      t.ai.suggestions.avoidDistractions,
    ]);
  } else if (hour >= 12 && hour < 18) {
    pool.addAll([t.ai.suggestions.lowEnergy, t.ai.suggestions.stayFocused]);
  } else {
    pool.addAll([
      t.ai.suggestions.prepareTomorrow,
      t.ai.suggestions.disciplineReflection,
    ]);
  }

  if (shareGoals && !shareHabits) {
    if (hasActiveGoals) pool.add(t.ai.suggestions.analyzeActiveGoals);
    pool.addAll([
      t.ai.suggestions.planMacroGoals,
      t.ai.suggestions.goalObstacles,
      t.ai.suggestions.reachMilestones,
    ]);
  } else if (!shareGoals && shareHabits) {
    pool.addAll([
      t.ai.suggestions.consistencyStatus,
      t.ai.suggestions.weeklyStats,
      t.ai.suggestions.planDay,
    ]);
    if (todayTotal > 0) {
      final pct = todayDone / todayTotal * 100;
      if (pct == 100) {
        pool.add(t.ai.suggestions.raiseBar);
      } else if (pct < 30 && hour > 14) {
        pool.add(t.ai.suggestions.recoverProcrastination);
      }
    }
  } else if (shareGoals && shareHabits) {
    if (hasActiveGoals) pool.add(t.ai.suggestions.analyzeActiveGoals);
    pool.addAll([
      t.ai.suggestions.consistencyStatus,
      t.ai.suggestions.connectHabitsGoals,
      t.ai.suggestions.reviewGoalsHabits,
    ]);
  } else {
    pool.addAll([
      t.ai.suggestions.disciplineAdvice,
      t.ai.suggestions.createNewHabit,
      t.ai.suggestions.avoidDistractions,
    ]);
  }

  final unique = pool.toSet().toList();
  if (unique.isEmpty) return const [];
  final count = unique.length < 4 ? unique.length : 4;
  final offset = messageCount % unique.length;
  return [for (var i = 0; i < count; i++) unique[(offset + i) % unique.length]];
}

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
        text: t.aiCoach.greeting,
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

  /// In Private mode, never send personal context to the external AI provider
  /// without explicit, persisted consent (mirrors the mobile client). Returns
  /// true if the send may proceed.
  Future<bool> _ensurePrivateAiConsent() async {
    final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
    if (!isPrivate) return true;
    final db = DesktopPrivateDb.instance;
    if (await db.hasPrivateAiExternalConsent()) return true;
    if (!mounted) return false;
    final granted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.evolveColors.background,
        title: Text(
          t.privateAi.consentTitle,
          style: TextStyle(
            color: context.evolveColors.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          t.privateAi.consentBody,
          style: TextStyle(
            color: context.evolveColors.foreground.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.privateAi.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.privateAi.accept),
          ),
        ],
      ),
    );
    if (granted == true) {
      await db.setPrivateAiExternalConsent(true);
      return true;
    }
    return false;
  }

  void _sendMessage() async {
    // Guard against concurrent sends: the chat TextField's onSubmitted is not
    // gated like the FAB, so pressing Enter mid-stream could start a second
    // run that captures an overlapping responseIndex and corrupts bubbles.
    if (_isTyping) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Private mode: require explicit consent before any external AI send.
    if (!await _ensurePrivateAiConsent()) return;

    _controller.clear();
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });

    _scrollToBottom();

    // Inietta contesto se abilitato
    final snapshot = ref.read(dashboardControllerProvider);
    final now = DateTime.now();
    final userName = _userName();
    String contextPrompt = "${t.aiCoach.systemPersona}\n";
    // Always personalize with the user's name.
    contextPrompt += "${t.aiCoach.userNameLine(userName: userName)}\n";

    if (_shareHabits) {
      contextPrompt += "\n${t.aiCoach.habitsHeader}\n";
      final habits = snapshot.habits;
      if (habits.isEmpty) {
        contextPrompt += "- ${t.aiCoach.noActiveHabits}\n";
      } else {
        for (final h in habits) {
          final done = snapshot.habitStatusFor(h.id, now) == 'done';
          contextPrompt +=
              "- ${t.aiCoach.habitLine(title: h.title, done: done, streak: h.streak)}\n";
        }
      }
      final activeToday = habits.where((h) => h.isActiveOn(now)).toList();
      final todayDone = activeToday
          .where((h) => snapshot.habitStatusFor(h.id, now) == 'done')
          .length;
      contextPrompt +=
          "${t.aiCoach.todayCompletion(completed: todayDone, total: activeToday.length)}\n";
    }

    if (_shareGoals) {
      contextPrompt += "\n${t.aiCoach.goalsHeader}\n";
      final goals = snapshot.goals
          .where((g) => g.state == GoalState.active)
          .toList();
      if (goals.isEmpty) {
        contextPrompt += "- ${t.aiCoach.noActiveGoals}\n";
      } else {
        for (final g in goals) {
          contextPrompt +=
              "- ${t.aiCoach.goalLine(title: g.title, due: g.dueLabel)}\n";
        }
      }
      final completed = snapshot.goals
          .where((g) => g.state == GoalState.completed)
          .length;
      contextPrompt += "${t.aiCoach.activeGoalsCount(count: goals.length)}\n";
      contextPrompt += "${t.aiCoach.completedGoalsCount(count: completed)}\n";
    }

    // Risposta in streaming — send the FULL conversation (user + assistant
    // turns) so follow-ups keep context, not just the user's messages.
    final stream = OpenRouterService.generateStreamResponse(
      List<ChatMessage>.from(_messages),
      systemPrompt: contextPrompt,
    );

    // Placeholder per la risposta
    final responseIndex = _messages.length;
    setState(() {
      _messages.add(
        ChatMessage(text: '', isUser: false, timestamp: DateTime.now()),
      );
    });

    String currentResponse = '';

    try {
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

      if (!mounted) return;
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      // Surface the failure both in the current assistant bubble and via a
      // SnackBar so the user is never left staring at an empty/partial reply.
      final errorText = t.ai.openRouter.connectionErrorShort;
      setState(() {
        _messages[responseIndex] = ChatMessage(
          text: currentResponse.isEmpty
              ? errorText
              : '$currentResponse\n\n$errorText',
          isUser: false,
          timestamp: DateTime.now(),
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorText)));
    } finally {
      // Always release the typing lock so the input/FAB are re-enabled even
      // if the stream threw.
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    }
  }

  /// The user's first name (private profile or cloud metadata), for the coach
  /// context. Falls back to a generic default.
  String _userName() {
    final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
    String? name;
    if (isPrivate) {
      name = ref.read(privateProfileProvider).value?.fullName;
    } else {
      final meta = ref.read(desktopAuthControllerProvider).user?.userMetadata;
      name = (meta?['full_name'] ?? meta?['name']) as String?;
    }
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return t.aiCoach.defaultUserName;
    return trimmed.split(' ').first;
  }

  /// Time- and context-aware prompt suggestions (mirrors mobile's
  /// `_getDynamicSuggestions`). Reads live state, then delegates the selection
  /// to the pure, testable [buildAiSuggestions].
  List<String> _dynamicSuggestions() {
    final now = DateTime.now();
    final snapshot = ref.read(dashboardControllerProvider);
    final hasActiveGoals = snapshot.goals.any(
      (g) => g.state == GoalState.active,
    );
    final activeToday = snapshot.habits
        .where((h) => h.isActiveOn(now))
        .toList();
    final todayDone = activeToday
        .where((h) => snapshot.habitStatusFor(h.id, now) == 'done')
        .length;
    return buildAiSuggestions(
      hour: now.hour,
      shareGoals: _shareGoals,
      shareHabits: _shareHabits,
      hasActiveGoals: hasActiveGoals,
      todayDone: todayDone,
      todayTotal: activeToday.length,
      messageCount: _messages.length,
    );
  }

  void _onSuggestionTap(String suggestion) {
    if (_isTyping) return;
    _controller.text = suggestion;
    _sendMessage();
  }

  Widget _suggestionChip(String text) {
    return InkWell(
      onTap: () => _onSuggestionTap(text),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: context.evolveColors.panelSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.evolveColors.border),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: context.evolveColors.foreground,
            fontSize: 12,
          ),
        ),
      ),
    );
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
            t.aiCoach.contextTitle,
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
                t.aiCoach.contextBody,
                style: TextStyle(
                  color: context.evolveColors.foreground.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: Text(
                  t.ai.dailyHabits,
                  style: TextStyle(color: context.evolveColors.foreground),
                ),
                subtitle: Text(
                  t.aiCoach.shareHabitsDesc,
                  style: TextStyle(
                    color: context.evolveColors.foreground.withValues(
                      alpha: 0.5,
                    ),
                    fontSize: 12,
                  ),
                ),
                value: _shareHabits,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) {
                  setDialogState(() => _shareHabits = val);
                  setState(() => _shareHabits = val);
                },
              ),
              SwitchListTile(
                title: Text(
                  t.ai.macroGoals,
                  style: TextStyle(color: context.evolveColors.foreground),
                ),
                subtitle: Text(
                  t.aiCoach.shareGoalsDesc,
                  style: TextStyle(
                    color: context.evolveColors.foreground.withValues(
                      alpha: 0.5,
                    ),
                    fontSize: 12,
                  ),
                ),
                value: _shareGoals,
                activeThumbColor: Theme.of(context).colorScheme.primary,
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
              child: Text(t.aiCoach.saveClose),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesktopPage(
      title: t.ai.coach,
      subtitle: t.aiCoach.subtitle,
      trailing: PageActionButton(
        label: t.aiCoach.contextButton,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      t.aiCoach.typing,
                      style: TextStyle(
                        color: context.evolveColors.muted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              if (!_isTyping)
                Builder(
                  builder: (context) {
                    final suggestions = _dynamicSuggestions();
                    if (suggestions.isEmpty) return const SizedBox.shrink();
                    return SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          24,
                          0,
                          24,
                          8,
                        ),
                        children: [
                          for (final s in suggestions) ...[
                            _suggestionChip(s),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
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
                        style: TextStyle(
                          color: context.evolveColors.foreground,
                        ),
                        decoration: InputDecoration(
                          hintText: t.aiCoach.inputHint,
                          hintStyle: TextStyle(
                            color: context.evolveColors.muted,
                          ),
                          filled: true,
                          fillColor: context.evolveColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      elevation: 0,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onPressed: _isTyping ? null : _sendMessage,
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
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
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                  bottomLeft: !isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: context.evolveColors.border),
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
                        h1: TextStyle(
                          color: context.evolveColors.foreground,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: context.evolveColors.foreground,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: TextStyle(
                          color: context.evolveColors.foreground,
                          fontWeight: FontWeight.bold,
                        ),
                        listBullet: TextStyle(
                          color: context.evolveColors.foreground,
                        ),
                        strong: TextStyle(
                          color: context.evolveColors.foreground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: context.evolveColors.background,
              child: Icon(
                Icons.person,
                color: context.evolveColors.foreground,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
