import 'dart:async';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/shared/widgets/coach_tutorial.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../application/coach_controllers.dart';
import '../domain/chat_message.dart';
import '../domain/coach_backend.dart';
import 'coach_model_chip.dart';

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
  bool _localNudgeDismissed = false;
  StreamSubscription<String>? _responseSub;

  // Coach segment of the continuous product tour (the FINAL segment). The
  // central [tourControllerProvider] owns whether this segment is active; the
  // page only owns the target keys and the step index within the segment.
  int _tourIndex = 0;
  final _modelKey = GlobalKey();
  final _contextKey = GlobalKey();
  final _suggestionsKey = GlobalKey();
  final _inputKey = GlobalKey();

  static const _kNudgeDismissed = 'coach_detect_nudge_dismissed';
  static const _kShareHabits = 'coach_share_habits';
  static const _kShareGoals = 'coach_share_goals';

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
    final prefs = ref.read(sharedPreferencesProvider);
    _localNudgeDismissed = prefs?.getBool(_kNudgeDismissed) ?? false;
    // Persisted so a data-sharing choice the user turned off survives tab
    // switches and restarts instead of silently reverting to the defaults.
    _shareHabits = prefs?.getBool(_kShareHabits) ?? true;
    _shareGoals = prefs?.getBool(_kShareGoals) ?? false;
  }

  void _dismissLocalNudge() {
    setState(() => _localNudgeDismissed = true);
    ref.read(sharedPreferencesProvider)?.setBool(_kNudgeDismissed, true);
  }

  void _setShareHabits(bool value) {
    setState(() => _shareHabits = value);
    ref.read(sharedPreferencesProvider)?.setBool(_kShareHabits, value);
  }

  void _setShareGoals(bool value) {
    setState(() => _shareGoals = value);
    ref.read(sharedPreferencesProvider)?.setBool(_kShareGoals, value);
  }

  @override
  void dispose() {
    _responseSub?.cancel();
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
    final granted = await showEvolveDialog<bool>(
      context: context,
      builder: (context) => EvolveAlertDialog(
        icon: LucideIcons.shield,
        title: Text(t.privateAi.consentTitle),
        content: Text(
          t.privateAi.consentBody,
          style: TextStyle(
            color: context.evolveColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.5,
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

    final coachConfig = ref.read(coachConfigProvider);
    final backend = ref.read(activeCoachBackendProvider);
    final isCloud = coachConfig.backend == CoachBackendKind.cloud;

    // Cloud sends leave the device, so in Private mode they require explicit
    // consent. Local sends never leave the device → no consent gate, no
    // internet check.
    if (isCloud && !await _ensurePrivateAiConsent()) return;
    // The consent dialog is async; bail if the page went away meanwhile.
    if (!mounted) return;

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
    // A user-authored system prompt (Advanced settings) replaces the default
    // coach persona; the personal context below is still appended.
    final persona = coachConfig.systemPromptOverride ?? t.aiCoach.systemPersona;
    String contextPrompt = "$persona\n";
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
    final stream = backend.streamResponse(
      List<ChatMessage>.from(_messages),
      systemPrompt: contextPrompt,
      model: coachConfig.activeModel,
      temperature: coachConfig.temperature,
    );

    // Placeholder per la risposta.
    final responseIndex = _messages.length;
    setState(() {
      _messages.add(
        ChatMessage(text: '', isUser: false, timestamp: DateTime.now()),
      );
    });

    var currentResponse = '';
    // Listen rather than await-for so the send can be cancelled mid-stream: the
    // Stop button cancels this subscription, which propagates to the backend's
    // async* generator and closes the HTTP client. A long cold local model load
    // (up to 60s) no longer locks the user out.
    _responseSub = stream.listen(
      (chunk) {
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
      },
      onError: (Object error) {
        if (!mounted) return;
        // Surface the failure in the current bubble and via a toast so the user
        // is never left staring at an empty/partial reply.
        final errorText = t.ai.openRouter.connectionErrorShort;
        setState(() {
          _messages[responseIndex] = ChatMessage(
            text: currentResponse.isEmpty
                ? errorText
                : '$currentResponse\n\n$errorText',
            isUser: false,
            timestamp: DateTime.now(),
          );
          _isTyping = false;
          _responseSub = null;
        });
        showEvolveToast(
          context,
          message: errorText,
          kind: EvolveToastKind.error,
        );
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isTyping = false;
          _responseSub = null;
        });
        _scrollToBottom();
      },
      cancelOnError: true,
    );
  }

  /// Cancels an in-flight response (Stop button). Cancelling the subscription
  /// propagates to the backend generator, closing the HTTP connection; whatever
  /// streamed so far stays in the bubble.
  void _stopStreaming() {
    _responseSub?.cancel();
    _responseSub = null;
    if (mounted) setState(() => _isTyping = false);
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
    showEvolveDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => EvolveAlertDialog(
          icon: LucideIcons.slidersHorizontal,
          title: Text(t.aiCoach.contextTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.aiCoach.contextBody,
                style: TextStyle(
                  color: context.evolveColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              _ContextSwitchRow(
                title: t.ai.dailyHabits,
                subtitle: t.aiCoach.shareHabitsDesc,
                value: _shareHabits,
                onChanged: (val) {
                  setDialogState(() => _shareHabits = val);
                  _setShareHabits(val);
                },
              ),
              const SizedBox(height: 10),
              _ContextSwitchRow(
                title: t.ai.macroGoals,
                subtitle: t.aiCoach.shareGoalsDesc,
                value: _shareGoals,
                onChanged: (val) {
                  setDialogState(() => _shareGoals = val);
                  _setShareGoals(val);
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
    final colors = context.evolveColors;

    final page = DesktopPage(
      pinned: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chat header: violet sparkles chip + heavy title (mobile app bar).
          Row(
            children: [
              const EvolveIconChip(
                icon: LucideIcons.sparkles,
                color: EvolveColors.violet,
                size: 44,
                iconSize: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.ai.coach,
                      style: TextStyle(
                        color: colors.foreground,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t.aiCoach.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.muted.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              KeyedSubtree(key: _modelKey, child: const CoachModelChip()),
              const SizedBox(width: 10),
              KeyedSubtree(
                key: _contextKey,
                child: PageActionButton(
                  label: t.aiCoach.contextButton,
                  icon: LucideIcons.brain,
                  onPressed: _showSettingsDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _LocalDetectedBanner(
            dismissed: _localNudgeDismissed,
            onDismiss: _dismissLocalNudge,
          ),
          // Pinned chat surface: the panel absorbs all remaining viewport
          // height (no page scroll). The thread scrolls internally and the
          // message column is centered at max 900 so bubbles never span an
          // ultra-wide window while the panel itself stays full width.
          Expanded(
            child: EvolvePanel(
              padding: EdgeInsets.zero,
              radius: 20,
              glowColor: EvolveColors.violet,
              child: Column(
                children: [
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollController,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
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
                      ),
                    ),
                  ),
                  // Bottom dock (fixed below the thread): typing status or
                  // suggestion pills, then the input bar — centered on the
                  // same 900 column as the messages.
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                    color: colors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          if (!_isTyping)
                            Builder(
                              builder: (context) {
                                final suggestions = _dynamicSuggestions();
                                if (suggestions.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return KeyedSubtree(
                                  key: _suggestionsKey,
                                  child: SizedBox(
                                    height: 42,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                            20,
                                            0,
                                            20,
                                            10,
                                          ),
                                      children: [
                                        for (final s in suggestions) ...[
                                          _SuggestionChip(
                                            label: s,
                                            onTap: () => _onSuggestionTap(s),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          // Input bar: translucent rounded card + circular send button.
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              20,
                              4,
                              20,
                              20,
                            ),
                            child: KeyedSubtree(
                              key: _inputKey,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: colors.panel.withValues(
                                          alpha: 0.4,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: colors.border.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: TextField(
                                        controller: _controller,
                                        style: TextStyle(
                                          color: colors.foreground,
                                          fontSize: 14,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: t.aiCoach.inputHint,
                                          filled: false,
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 18,
                                                vertical: 13,
                                              ),
                                        ),
                                        onSubmitted: (_) => _sendMessage(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _SendButton(
                                    isStreaming: _isTyping,
                                    onSend: _sendMessage,
                                    onStop: _stopStreaming,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final showTour = ref
        .watch(tourControllerProvider)
        .isSegmentActive(TourSegment.coach);

    return Stack(
      children: [
        page,
        if (showTour)
          CoachTutorialOverlay(
            steps: _coachTourSteps(),
            index: _tourIndex,
            onIndexChanged: (i) => setState(() => _tourIndex = i),
            // Final segment: finishing completes the whole tour and unlocks
            // navigation (see [_finishCoachTour]).
            onFinish: _finishCoachTour,
            backLabel: t.tour.back,
            nextLabel: t.tour.next,
            finishLabel: t.tour.finish,
          ),
      ],
    );
  }

  List<CoachStep> _coachTourSteps() => [
    // Orientation-first: a centered card (no spotlight) announcing the page.
    CoachStep(
      title: t.tour.coachOrientationTitle,
      description: t.tour.coachOrientationDesc,
    ),
    CoachStep(
      targetKey: _modelKey,
      title: t.tour.coachModelTitle,
      description: t.tour.coachModelDesc,
    ),
    CoachStep(
      targetKey: _contextKey,
      title: t.tour.coachContextTitle,
      description: t.tour.coachContextDesc,
    ),
    CoachStep(
      targetKey: _suggestionsKey,
      title: t.tour.coachSuggestionsTitle,
      description: t.tour.coachSuggestionsDesc,
    ),
    CoachStep(
      targetKey: _inputKey,
      title: t.tour.coachInputTitle,
      description: t.tour.coachInputDesc,
    ),
  ];

  /// Finishes the FINAL tour segment: marks the whole tour done (unlocking
  /// navigation), shows a completion dialog, then returns the user to Overview.
  Future<void> _finishCoachTour() async {
    await ref.read(tourControllerProvider.notifier).complete();
    if (!mounted) return;
    await showEvolveDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EvolveAlertDialog(
        icon: LucideIcons.sparkles,
        title: Text(t.tour.doneTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.tour.doneBody),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.tour.doneButton),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    ref
        .read(navigationControllerProvider.notifier)
        .select(DesktopSection.overview);
  }
}

/// Circular accent action button: sends the message when idle, and turns into a
/// Stop control while a reply is streaming (cancelling the in-flight response —
/// important given a cold local model can take up to 60s to first-token).
/// Labelled for screen readers.
class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.isStreaming,
    required this.onSend,
    required this.onStop,
  });

  final bool isStreaming;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = context.evolveAccent;
    final streaming = widget.isStreaming;
    final label = streaming
        ? t.coachSettings.stopResponse
        : t.coachSettings.sendMessage;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: InkWell(
            onTap: streaming ? widget.onStop : widget.onSend,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: _hovered ? 0.4 : 0.25),
                    blurRadius: _hovered ? 16 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                streaming ? LucideIcons.square : LucideIcons.send,
                size: streaming ? 14 : 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill suggestion chip: translucent track, muted label that lifts to
/// foreground on hover (desktop affordance).
class _SuggestionChip extends StatefulWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: colors.panel.withValues(alpha: _hovered ? 0.5 : 0.3),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: _hovered
                  ? colors.borderStrong
                  : colors.border.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? colors.foreground : colors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
    final colors = context.evolveColors;
    final accent = context.evolveAccent;
    final isUser = message.isUser;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? accent : colors.panel.withValues(alpha: 0.4),
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(18),
          topEnd: const Radius.circular(18),
          bottomStart: Radius.circular(isUser ? 18 : 6),
          bottomEnd: Radius.circular(isUser ? 6 : 18),
        ),
        border: isUser
            ? null
            : Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: isUser
          ? Text(
              message.text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            )
          : MarkdownBody(
              data: message.text,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: colors.foreground,
                  fontSize: 14,
                  height: 1.45,
                ),
                h1: TextStyle(
                  color: colors.foreground,
                  fontWeight: FontWeight.w800,
                ),
                h2: TextStyle(
                  color: colors.foreground,
                  fontWeight: FontWeight.w800,
                ),
                h3: TextStyle(
                  color: colors.foreground,
                  fontWeight: FontWeight.w800,
                ),
                listBullet: TextStyle(
                  color: colors.foreground,
                  fontSize: 14,
                  height: 1.45,
                ),
                strong: TextStyle(
                  color: colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _AvatarDot(
              icon: LucideIcons.sparkles,
              background: EvolveColors.violet.withValues(alpha: 0.12),
              iconColor: EvolveColors.violet,
            ),
            const SizedBox(width: 10),
          ],
          Flexible(child: bubble),
          if (isUser) ...[
            const SizedBox(width: 10),
            _AvatarDot(
              icon: LucideIcons.user,
              background: colors.panel,
              iconColor: colors.foreground,
              bordered: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Small circular avatar next to a chat bubble (violet sparkles for the coach,
/// bordered user chip for the person).
class _AvatarDot extends StatelessWidget {
  const _AvatarDot({
    required this.icon,
    required this.background,
    required this.iconColor,
    this.bordered = false,
  });

  final IconData icon;
  final Color background;
  final Color iconColor;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        border: bordered
            ? Border.all(color: context.evolveColors.border)
            : null,
      ),
      child: Icon(icon, size: 14, color: iconColor),
    );
  }
}

/// Context-sharing toggle row of the AI settings dialog: title + caption with
/// a kit [EvolveSwitch] (replaces the stock SwitchListTile).
class _ContextSwitchRow extends StatelessWidget {
  const _ContextSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.evolveColors.foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.evolveColors.muted.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: EvolveSwitch(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

/// First-run privacy nudge: when the coach is on Cloud and a local AI server is
/// detected on this machine, offer a one-tap switch to running 100% privately.
/// Only probes while it could actually show (Cloud + not yet dismissed).
class _LocalDetectedBanner extends ConsumerWidget {
  const _LocalDetectedBanner({
    required this.dismissed,
    required this.onDismiss,
  });

  final bool dismissed;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (dismissed) return const SizedBox.shrink();
    final backend = ref.watch(coachConfigProvider.select((c) => c.backend));
    if (backend != CoachBackendKind.cloud) return const SizedBox.shrink();
    final detected = ref.watch(coachLocalDetectionProvider).asData?.value;
    if (detected == null) return const SizedBox.shrink();

    final colors = context.evolveColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: EvolveColors.violet.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EvolveColors.violet.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const EvolveIconChip(
              icon: LucideIcons.cpu,
              color: EvolveColors.violet,
              size: 34,
              iconSize: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.coachSettings.detectedTitle,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.coachSettings.detectedBody,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: onDismiss,
              child: Text(
                t.coachSettings.detectedDismiss,
                style: TextStyle(color: colors.muted, fontSize: 12.5),
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: () {
                ref.read(coachConfigProvider.notifier).useLocalServer(detected);
                onDismiss();
              },
              child: Text(t.coachSettings.detectedAction),
            ),
          ],
        ),
      ),
    );
  }
}
