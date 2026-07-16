import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/openrouter_service.dart';
import '../../core/app_logger.dart';
import '../../core/data_mode.dart';
import '../../core/private_local_database.dart';
import '../../core/rtl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/macro_goal.dart';
import '../../models/chat_message.dart';
import '../../providers/goal_provider.dart';
import '../../providers/macro_goals_provider.dart';
import '../../providers/user_provider.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_dialog.dart';
import '../kit/evolve_toast.dart';
import '../kit/evolve_sheet.dart';
import '../kit/evolve_switch.dart';
import '../../core/haptics.dart';
import 'app_settings_screen.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  /// Test seam for the coach's token stream. Production never reassigns this;
  /// the real call needs the network and the user's Keychain key, so a widget
  /// test that has to drive tokens one at a time swaps it (and restores it).
  @visibleForTesting
  static Stream<String> Function(
    List<ChatMessage> history, {
    String? systemPrompt,
  })
  streamFactory = OpenRouterService.generateStreamResponse;

  static Route route() {
    return MaterialPageRoute(builder: (context) => const AIChatScreen());
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
  StreamSubscription<String>? _responseSub;
  bool _shareHabits = true;
  bool _shareGoals = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seed the greeting here rather than in initState: it reads `context.t`
    // (the slang translations InheritedWidget) and inherited-widget lookups are
    // illegal during initState. Guarded so a later dependency change
    // (theme/locale) never re-seeds an already-populated conversation.
    if (_messages.isEmpty) _addInitialMessages();
  }

  void _addInitialMessages() {
    _messages.add(
      ChatMessage(
        text: context.t.tutorial.helloIMYourDisciplineCoach,
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );
  }

  void _showSettingsDialog() {
    showEvolveFormSheet<void>(
      context: context,
      title: context.t.tutorial.aiContextTitle,
      trailing: EvolveTextAction(
        label: context.t.common.actions.done,
        emphasized: true,
        onPressed: () => Navigator.pop(context),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      context.t.tutorial.aiContextDesc,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appColors.mutedForeground,
                      ),
                    ),
                  ),
                  EvolveListSection(
                    children: [
                      EvolveSwitchRow(
                        title: context.t.ai.dailyHabits,
                        subtitle: context.t.ai.todayCompletion,
                        value: _shareHabits,
                        onChanged: (val) {
                          setSheetState(() {});
                          setState(() => _shareHabits = val);
                        },
                      ),
                      EvolveSwitchRow(
                        title: context.t.ai.macroGoals,
                        subtitle: context.t.ai.activeCompletedGoals,
                        value: _shareGoals,
                        onChanged: (val) {
                          setSheetState(() {});
                          setState(() => _shareGoals = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Drops any in-flight response. `cancel()` stops event delivery at once, so
  /// callers never need to await it; awaiting it would also block on the
  /// generator's `finally`, which is where the HTTP client is closed.
  void _cancelResponseStream() {
    final sub = _responseSub;
    _responseSub = null;
    if (sub != null) unawaited(sub.cancel());
  }

  @override
  void dispose() {
    // Without this the SSE stream outlives the screen: the generator's
    // `finally { client.close(); }` only runs on completion or cancellation.
    _cancelResponseStream();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (!await _ensurePrivateAiConsent()) return;
    if (!mounted) return;

    // A previous response can still be streaming — `_isTyping` flips false on
    // its first token, and `onSubmitted` isn't gated at all — and its listener
    // writes to an index captured from the list we are about to grow. Drop it
    // before touching `_messages`.
    _cancelResponseStream();

    ref.hapticMedium();

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    // Chiamata all'API di Open Router in streaming
    final assistantMessageIndex = _messages.length;
    setState(() {
      _messages.add(
        ChatMessage(text: "", isUser: false, timestamp: DateTime.now()),
      );
    });

    final stream = AIChatScreen.streamFactory(
      _messages.sublist(0, assistantMessageIndex),
      systemPrompt: _getSystemPrompt(),
    );

    bool receivedFirstToken = false;

    _responseSub = stream.listen(
      (chunk) {
        if (!mounted) return;
        // Backstop: an event that outlives the list it was indexed against
        // would throw from inside onData, which Dart routes to the zone's
        // uncaught handler (never to `onError` below) — one global error modal
        // per remaining chunk.
        if (assistantMessageIndex >= _messages.length) return;
        if (!receivedFirstToken && chunk.trim().isNotEmpty) {
          receivedFirstToken = true;
          ref.hapticLight();
          setState(() {
            _isTyping = false;
          });
        }

        setState(() {
          _messages[assistantMessageIndex] = ChatMessage(
            text: '${_messages[assistantMessageIndex].text}$chunk',
            isUser: false,
            timestamp: _messages[assistantMessageIndex].timestamp,
          );
        });
        _scrollToBottom();
      },
      onError: (e, stack) {
        _responseSub = null;
        if (!mounted) return;
        AppLogger.error('[AIChatScreen] Errore stream listener', e, stack);
        if (assistantMessageIndex >= _messages.length) return;

        setState(() {
          _isTyping = false;
          _messages[assistantMessageIndex] = ChatMessage(
            text:
                '${_messages[assistantMessageIndex].text}\n\n${context.t.ai.streamingError}',
            isUser: false,
            timestamp: _messages[assistantMessageIndex].timestamp,
          );
        });
        _scrollToBottom();

        // Avvisa l'utente in modo esplicito
        showEvolveToast(
          context,
          message: context.t.ai.connectionIssues,
          kind: EvolveToastKind.error,
        );
      },

      onDone: () {
        _responseSub = null;
        if (!mounted) return;
        if (_isTyping) {
          setState(() {
            _isTyping = false;
          });
        }
      },
    );
  }

  Future<bool> _ensurePrivateAiConsent() async {
    if (ref.read(activeDataModeProvider) != AppDataMode.private) return true;

    final db = ref.read(privateLocalDatabaseProvider);
    if (await db.hasPrivateAiExternalConsent()) return true;
    if (!mounted) return false;

    final accepted = await showEvolveConfirm(
      context: context,
      title: context.t.ai.privateConsentTitle,
      message: context.t.ai.privateConsentBody,
      confirmLabel: context.t.ai.accept,
      ref: ref,
    );

    if (accepted) {
      await db.setPrivateAiExternalConsent(true);
      return true;
    }
    return false;
  }

  String _getSystemPrompt() {
    final goals = ref.read(macroGoalsProvider).goals;
    final habits = ref.read(goalsProvider);
    final habitLogs = ref.read(habitLogsProvider);
    final userName =
        ref.read(userProfileProvider).firstName ??
        context.t.ai.prompts.defaultUserName;

    final activeGoals = goals
        .where((g) => g.status == GoalStatus.active)
        .toList();
    final completedGoals = goals
        .where((g) => g.status == GoalStatus.completed)
        .length;
    final todayKey = _todayKey();
    final todayLogs = habitLogs[todayKey] ?? {};
    final todayDone = todayLogs.values.where((s) => s == 'done').length;
    final todayTotal = habits.where((h) => h.isActiveOn(DateTime.now())).length;

    final goalsList = activeGoals.isNotEmpty
        ? activeGoals.map((g) => '  • ${g.title}').join('\n')
        : '  • ${context.t.ai.prompts.noActiveGoals}';

    final contextBlock = StringBuffer()
      ..writeln(context.t.ai.prompts.contextHeader)
      ..writeln(context.t.ai.prompts.userName(userName: userName));

    if (_shareGoals) {
      contextBlock
        ..writeln(context.t.ai.prompts.activeGoals(count: activeGoals.length))
        ..writeln(goalsList)
        ..writeln(context.t.ai.prompts.completedGoals(count: completedGoals));
    }

    if (_shareHabits) {
      contextBlock.writeln(
        context.t.ai.prompts.habitsToday(
          completed: todayDone,
          total: todayTotal,
        ),
      );
    }

    return context.t.ai.prompts.coachSystemPrompt(
      userName: userName,
      contextBlock: contextBlock.toString(),
    );
  }

  List<String> _getDynamicSuggestions() {
    final now = DateTime.now();
    final hour = now.hour;
    final List<String> pool = [];

    // 1. Suggerimenti basati sull'orario (Generici)
    if (hour >= 5 && hour < 12) {
      pool.addAll([
        context.t.ai.suggestions.morningBoost,
        context.t.ai.suggestions.avoidDistractions,
      ]);
    } else if (hour >= 12 && hour < 18) {
      pool.addAll([
        context.t.ai.suggestions.lowEnergy,
        context.t.ai.suggestions.stayFocused,
      ]);
    } else {
      pool.addAll([
        context.t.ai.suggestions.prepareTomorrow,
        context.t.ai.suggestions.disciplineReflection,
      ]);
    }

    final goals = ref.read(macroGoalsProvider).goals;
    final habits = ref.read(goalsProvider);
    final habitLogs = ref.read(habitLogsProvider);

    final activeGoals = goals
        .where((g) => g.status == GoalStatus.active)
        .toList();
    final todayKey = _todayKey();
    final todayLogs = habitLogs[todayKey] ?? {};
    final todayDone = todayLogs.values.where((s) => s == 'done').length;
    final todayTotal = habits.where((h) => h.isActiveOn(DateTime.now())).length;

    // 2. Suggerimenti specifici in base agli switch attivi
    if (_shareGoals && !_shareHabits) {
      // SOLO OBIETTIVI
      if (activeGoals.isNotEmpty) {
        pool.add(context.t.ai.suggestions.analyzeActiveGoals);
      }
      pool.addAll([
        context.t.ai.suggestions.planMacroGoals,
        context.t.ai.suggestions.goalObstacles,
        context.t.ai.suggestions.reachMilestones,
      ]);
    } else if (!_shareGoals && _shareHabits) {
      // SOLO ABITUDINI
      pool.addAll([
        context.t.ai.suggestions.consistencyStatus,
        context.t.ai.suggestions.weeklyStats,
        context.t.ai.suggestions.planDay,
      ]);

      if (todayTotal > 0) {
        final pct = (todayDone / todayTotal) * 100;
        if (pct == 100) {
          pool.add(context.t.ai.suggestions.raiseBar);
        } else if (pct < 30 && hour > 14) {
          pool.add(context.t.ai.suggestions.recoverProcrastination);
        }
      }
    } else if (_shareGoals && _shareHabits) {
      // ENTRAMBI
      if (activeGoals.isNotEmpty) {
        pool.add(context.t.ai.suggestions.analyzeActiveGoals);
      }
      pool.addAll([
        context.t.ai.suggestions.consistencyStatus,
        context.t.ai.suggestions.connectHabitsGoals,
        context.t.ai.suggestions.reviewGoalsHabits,
      ]);
    } else {
      // NESSUNO (Fallback - Anche se l'utente non può inviare messaggi in questo stato, i suggerimenti mostrano l'errore)
      pool.addAll([
        context.t.ai.suggestions.disciplineAdvice,
        context.t.ai.suggestions.createNewHabit,
        context.t.ai.suggestions.avoidDistractions,
      ]);
    }

    // Rimuovi duplicati (se presenti)

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

  /// BYOK setup state: the app ships no OpenRouter key, so until the user adds
  /// their own, this card replaces the composer. Its only action opens
  /// Settings, so there is no button here that can fail (Guideline 2.1).
  Widget _buildApiKeySetupCard(AppColorsExtension colors) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassCardDecoration(context, radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.keyRound,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.t.ai.apiKey.setupTitle,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.t.ai.apiKey.setupBody,
              style: TextStyle(
                color: colors.mutedForeground,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref.hapticLight();
                  Navigator.push(context, AppSettingsScreen.route());
                },
                child: Text(context.t.ai.apiKey.setupAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final userProfile = ref.watch(userProfileProvider);
    // Cloud is BYOK. Treat a failed Keychain read as "no key" too: either way
    // there is nothing to authenticate with, so offer setup rather than a
    // composer whose every send would fail.
    final apiKeyState = ref.watch(openRouterApiKeyProvider);
    final needsApiKey =
        !apiKeyState.isLoading && apiKeyState.asData?.value == null;

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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF8B5CF6),
                    Color(0xFF6366F1),
                    Color(0xFF3B82F6),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.background,
                ),
                child: Icon(
                  LucideIcons.sparkles,
                  size: 16,
                  color: colors.foreground,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t.ai.coach),
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
                      "${context.t.ai.onlineFor} ${userProfile.displayName}",
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
              icon: Icon(
                LucideIcons.trash2,
                size: 18,
                color: colors.mutedForeground,
              ),
              onPressed: () async {
                ref.hapticLight();
                final confirmed = await showEvolveConfirm(
                  context: context,
                  title: context.t.tutorial.deleteChat,
                  message: context.t.tutorial.areYouSureYouWantTo,
                  confirmLabel: context.t.common.actions.delete,
                  cancelLabel: context.t.tutorial.cancel,
                  isDestructive: true,
                  ref: ref,
                );
                if (confirmed) {
                  // The trash button is live for the whole streaming window, so
                  // the reply being cleared may still be arriving. Cancelling
                  // means no onDone, hence the explicit `_isTyping` reset.
                  _cancelResponseStream();
                  setState(() {
                    _isTyping = false;
                    _messages.clear();
                    _addInitialMessages();
                  });
                }
              },

              tooltip: context.t.ai.newChat,
            ),
          IconButton(
            icon: Icon(
              LucideIcons.settings,
              size: 18,
              color: colors.mutedForeground,
            ),
            onPressed: _showSettingsDialog,
            tooltip: context.t.ai.contextSettings,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassCardDecoration(context, radius: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.sparkles,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t.tutorial.virtualCoach,
                              style: TextStyle(
                                color: colors.foreground,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.t.tutorial.readyToHelpYouStayDisciplined,
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

            // Without a key there is nothing to send to: the setup card
            // replaces the suggestions + composer entirely.
            if (needsApiKey)
              _buildApiKeySetupCard(colors)
            else ...[
              // 2. Suggested Prompts (Always active, collapsible)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showPrompts = !_showPrompts;
                        });
                        ref.hapticLight();
                      },
                      child: Row(
                        children: [
                          Text(
                            context.t.tutorial.suggestions,
                            style: TextStyle(
                              color: colors.mutedForeground,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showPrompts
                                ? LucideIcons.chevronDown
                                : directionalIcon(
                                    context,
                                    LucideIcons.chevronRight,
                                    LucideIcons.chevronLeft,
                                  ),
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
                        children: _getDynamicSuggestions()
                            .map((text) => _buildSuggestedPrompt(text, colors))
                            .toList(),
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
                  border: Border(top: BorderSide(color: colors.borderSubtle)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: AppTheme.glassCardDecoration(
                          context,
                          radius: 24,
                        ),
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(color: colors.foreground),
                          decoration: InputDecoration(
                            hintText: context.t.ai.ask,
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
                      onTap: (_isTyping || (!_shareHabits && !_shareGoals))
                          ? null
                          : () => _sendMessage(_controller.text),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient:
                              (_isTyping || (!_shareHabits && !_shareGoals))
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF8B5CF6),
                                    Color(0xFF6366F1),
                                  ],
                                ),
                          color: (_isTyping || (!_shareHabits && !_shareGoals))
                              ? colors.muted
                              : null,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.arrowUp,
                          size: 20,
                          color: (_isTyping || (!_shareHabits && !_shareGoals))
                              ? colors.mutedForeground
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedPrompt(String text, AppColorsExtension colors) {
    return GestureDetector(
      onTap: () {
        ref.hapticLight();

        // Rimuovi l'emoji iniziale se presente (tutto ciò che precede il primo spazio)
        String cleanText = text;
        final int firstSpace = text.indexOf(' ');
        if (firstSpace != -1) {
          cleanText = text.substring(firstSpace + 1);
        }

        if (!_shareHabits && !_shareGoals) {
          setState(() {
            _messages.add(
              ChatMessage(
                text: cleanText,
                isUser: true,
                timestamp: DateTime.now(),
              ),
            );
            _messages.add(
              ChatMessage(
                text: context.t.tutorial.pleaseSelectAtLeastOneContext,
                isUser: false,
                timestamp: DateTime.now().add(
                  const Duration(milliseconds: 100),
                ),
              ),
            );
          });
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
          return;
        }
        _sendMessage(cleanText);
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
        showEvolveToast(context, message: context.t.tutorial.messageCopied);
        ref.hapticLight();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? null : colors.card.withValues(alpha: 0.8),
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                )
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
            MarkdownBody(
              data: message.text,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: TextStyle(
                      color: isUser ? Colors.white : colors.foreground,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    strong: TextStyle(
                      color: isUser ? Colors.white : colors.foreground,
                      fontWeight: FontWeight.bold,
                    ),
                    listBullet: TextStyle(
                      color: isUser ? Colors.white : colors.foreground,
                    ),
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
        alignment: AlignmentDirectional.centerEnd,
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
            margin: const EdgeInsetsDirectional.only(end: 8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
              ),
            ),
            child: const Icon(
              LucideIcons.sparkles,
              size: 13,
              color: Colors.white,
            ),
          ),
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(AppColorsExtension colors) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
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
          children: List.generate(
            3,
            (i) => _BouncingDot(delay: i * 200, color: colors.mutedForeground),
          ),
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

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween(
      begin: 0.0,
      end: -6.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _ctrl.repeat(reverse: true);
      }
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
      builder: (_, child) =>
          Transform.translate(offset: Offset(0, _anim.value), child: child),
      child: Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Animated wrapper for message entrance
class _FadeInSlide extends StatefulWidget {
  final Widget child;

  const _FadeInSlide({super.key, required this.child});

  @override
  State<_FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<_FadeInSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
