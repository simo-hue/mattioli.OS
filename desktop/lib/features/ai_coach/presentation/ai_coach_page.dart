import 'dart:async';
import 'dart:math' as math;

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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/coach_controllers.dart';
import '../application/ollama_start_controller.dart';
import '../domain/chat_message.dart';
import '../domain/coach_backend.dart';
import '../domain/coach_chat_logic.dart';
import '../domain/coach_config.dart';
import 'coach_model_chip.dart';
import 'coach_settings_dialog.dart';
import 'start_ollama_button.dart';

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
  // Synchronous in-flight guard, armed BEFORE the async consent gap so two
  // rapid Enters can't both slip through and start overlapping streams.
  bool _sending = false;
  // Bumped on "new chat" so entrance keys change and the fresh greeting
  // re-animates (positional index alone would reuse the completed tween).
  int _chatGeneration = 0;

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
    if (_isTyping || _sending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _sending = true;

    final coachConfig = ref.read(coachConfigProvider);
    // The EFFECTIVE engine: in Private mode a stored Standard choice is BYOK,
    // and gating on the persisted value would skip the key check for a user who
    // very much needs it.
    final kind = ref.read(effectiveCoachBackendProvider);
    // Only the BYOK engine needs a key of the user's. Standard is unlocked by
    // the subscription and has nothing to paste; local has no credential at all.
    final needsOwnKey = kind == CoachBackendKind.cloud;
    // Both remote engines send the conversation off this Mac. This used to read
    // `isCloud`, which was true of the only remote engine there was — with two,
    // the question the consent gate is actually asking is "does this leave the
    // device", so ask that.
    final leavesDevice = kind != CoachBackendKind.local;

    // Await the Keychain read (rather than reading the possibly still-loading
    // snapshot) so a send during the first frames can't be mistaken for "no key"
    // — then send the user to the setup dialog instead of posting a message that
    // can only fail.
    //
    // The read can throw (a rotated keychain access-group prefix locks the item
    // out). It MUST NOT escape: `_sending` is already latched, and an uncaught
    // throw here would leave it latched for the page's lifetime, silently
    // blocking every later send. An unreadable key is treated as no key.
    if (needsOwnKey) {
      String? apiKey;
      try {
        apiKey = await ref.read(coachApiKeyProvider.future);
      } catch (_) {
        apiKey = null;
      }
      if (apiKey == null) {
        _sending = false;
        if (mounted) showCoachSettingsDialog(context);
        return;
      }
    }
    if (!mounted) {
      _sending = false;
      return;
    }

    // Remote sends leave the device, so in Private mode they require explicit
    // consent. Local sends never leave the device → no consent gate, no
    // internet check.
    //
    // The consent check reads the private DB (`_ensurePrivateAiConsent` →
    // `hasPrivateAiExternalConsent`), whose `database` getter throws
    // `PrivateDatabaseLockedException` when the SQLCipher key is locked out. As
    // with the key read above, that throw MUST NOT escape: `_sending` is
    // already latched, so an uncaught throw would leave it latched for the
    // page's lifetime, silently blocking every later send. A failed check is
    // treated as "consent not granted" (the send does not proceed).
    if (leavesDevice) {
      bool consented;
      try {
        consented = await _ensurePrivateAiConsent();
      } catch (_) {
        consented = false;
      }
      if (!consented) {
        _sending = false;
        return;
      }
    }
    // The consent dialog is async; bail if the page went away meanwhile.
    if (!mounted) {
      _sending = false;
      return;
    }

    // Read AFTER the awaits: the key that just resolved rebuilds this provider.
    final backend = ref.read(activeCoachBackendProvider);

    _controller.clear();
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });
    // _isTyping now serves as the in-flight guard.
    _sending = false;

    _animateToBottom();

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

    // Stream the recent conversation (user + assistant turns) so follow-ups keep
    // context. Capped to the last N messages so a long chat doesn't grow
    // unboundedly into the model's context-length limit.
    final stream = backend.streamResponse(
      trimHistory(_messages),
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
        final follow = _isPinnedToBottom();
        currentResponse += chunk;
        setState(() {
          _messages[responseIndex] = ChatMessage(
            text: currentResponse,
            isUser: false,
            timestamp: DateTime.now(),
          );
        });
        if (follow) _followBottom();
      },
      onError: (Object error) {
        if (!mounted) return;
        // Surface the failure in the current bubble and via a toast so the user
        // is never left staring at an empty/partial reply.
        final follow = _isPinnedToBottom();
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
        if (follow) _followBottom();
        showEvolveToast(
          context,
          message: errorText,
          kind: EvolveToastKind.error,
        );
      },
      onDone: () {
        if (!mounted) return;
        final follow = _isPinnedToBottom();
        setState(() {
          _isTyping = false;
          _responseSub = null;
        });
        if (follow) _followBottom();
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

  /// Whether the thread is currently pinned near the bottom. MUST be read
  /// BEFORE a new chunk grows the list — otherwise a single tall chunk inflates
  /// maxScrollExtent and gets mistaken for the user having scrolled up, which
  /// would permanently detach auto-follow for the rest of the reply.
  bool _isPinnedToBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return isNearBottom(position.pixels, position.maxScrollExtent);
  }

  /// Jumps to the bottom once the grown content is laid out. Only call when
  /// [_isPinnedToBottom] was true before the growth (so re-reading isn't
  /// interrupted). jumpTo (not a per-chunk animation) avoids overlapping-anim jank.
  void _followBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  /// Smoothly scrolls to the bottom after the user sends (they expect to follow
  /// their own message + the reply). Respects Reduce Motion.
  void _animateToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (MediaQuery.of(context).disableAnimations) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Clears the conversation and starts fresh (header "new chat" button).
  /// Confirms first only when there's a real conversation beyond the greeting.
  Future<void> _newChat() async {
    if (_messages.length > 1) {
      final confirmed = await showEvolveDialog<bool>(
        context: context,
        builder: (context) => EvolveAlertDialog(
          icon: LucideIcons.messageSquarePlus,
          title: Text(t.aiCoach.clearConfirmTitle),
          content: Text(
            t.aiCoach.clearConfirmBody,
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
              child: Text(t.aiCoach.clearConfirmCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.aiCoach.clearConfirmAccept),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _responseSub?.cancel();
    _responseSub = null;
    _controller.clear();
    setState(() {
      _messages
        ..clear()
        ..add(
          ChatMessage(
            text: t.aiCoach.greeting,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      _isTyping = false;
      _sending = false;
      _chatGeneration++;
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
              const SizedBox(width: 10),
              EvolveSquareIconButton(
                icon: LucideIcons.messageSquarePlus,
                tooltip: t.aiCoach.newChatTooltip,
                onTap: _newChat,
                size: 40,
                iconSize: 18,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _CloudKeyMissingBanner(),
          _LocalDetectedBanner(
            dismissed: _localNudgeDismissed,
            onDismiss: _dismissLocalNudge,
          ),
          const _LocalOfflineBanner(),
          // Pinned chat surface: the panel absorbs all remaining viewport
          // height (no page scroll). The thread scrolls internally and the
          // message column is centered at max 900 so bubbles never span an
          // ultra-wide window; the panel and the bottom input dock stay full
          // width so the composer grows with the window on wide desktops.
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
                      // Suppress the platform auto-scrollbar so only the
                      // panel-edge Scrollbar above shows.
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(24),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isStreaming =
                                _isTyping &&
                                !msg.isUser &&
                                index == _messages.length - 1;
                            return _MessageEntrance(
                              key: ValueKey('$_chatGeneration:$index'),
                              child: _MessageBubble(
                                message: msg,
                                isStreaming: isStreaming,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // Bottom dock (fixed below the thread): typing status or
                  // suggestion pills, then the input bar. Spans the full panel
                  // width (only the 20px side padding on each row) so the
                  // composer and the suggestion strip stretch edge to edge on
                  // wide windows instead of being pinned to a fixed column.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The "answering" feedback now lives in the assistant
                      // bubble (animated dots → text). The suggestion strip
                      // hides while a reply streams; AnimatedSize smooths the
                      // height change so the input bar doesn't jump.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        alignment: Alignment.bottomCenter,
                        child: Builder(
                          builder: (context) {
                            if (_isTyping) return const SizedBox.shrink();
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
                                  padding: const EdgeInsetsDirectional.fromSTEB(
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
                                    color: colors.panel.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colors.border.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  // Enter sends; Shift+Enter inserts a
                                  // newline (intercepted before the
                                  // multiline field treats Enter as one).
                                  child: Focus(
                                    // Pure key interceptor — not a focus
                                    // stop of its own.
                                    canRequestFocus: false,
                                    skipTraversal: true,
                                    onKeyEvent: (node, event) {
                                      final isEnter =
                                          event.logicalKey ==
                                              LogicalKeyboardKey.enter ||
                                          event.logicalKey ==
                                              LogicalKeyboardKey.numpadEnter;
                                      if (!isEnter) {
                                        return KeyEventResult.ignored;
                                      }
                                      if (event is! KeyDownEvent &&
                                          event is! KeyRepeatEvent) {
                                        return KeyEventResult.ignored;
                                      }
                                      // Shift+Enter, an active IME
                                      // composition commit, or a reply
                                      // already streaming → let the field
                                      // insert a newline instead of sending.
                                      if (HardwareKeyboard
                                              .instance
                                              .isShiftPressed ||
                                          _controller.value.composing.isValid ||
                                          _isTyping) {
                                        return KeyEventResult.ignored;
                                      }
                                      _sendMessage();
                                      return KeyEventResult.handled;
                                    },
                                    child: TextField(
                                      controller: _controller,
                                      minLines: 1,
                                      maxLines: 5,
                                      keyboardType: TextInputType.multiline,
                                      textInputAction: TextInputAction.newline,
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
                                    ),
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

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({required this.message, this.isStreaming = false});

  final ChatMessage message;

  /// True for the assistant bubble currently receiving a streamed reply.
  final bool isStreaming;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final accent = context.evolveAccent;
    final message = widget.message;
    final isUser = message.isUser;
    final isWaiting = !isUser && widget.isStreaming && message.text.isEmpty;

    final Widget bubbleChild;
    if (isWaiting) {
      bubbleChild = const _TypingDots();
    } else if (isUser) {
      bubbleChild = Text(
        message.text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
      );
    } else if (widget.isStreaming) {
      // Caret is a separate decorative widget, NOT injected into the markdown
      // source — so it can't trigger reparses, clear a selection, or reflow at
      // block boundaries.
      bubbleChild = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _AssistantMarkdown(text: message.text),
          const SizedBox(height: 3),
          const _StreamingCaret(),
        ],
      );
    } else {
      bubbleChild = _AssistantMarkdown(text: message.text);
    }

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 800),
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
      child: bubbleChild,
    );

    // Assistant bubbles get a hover-revealed copy affordance below them.
    final showCopy = !isUser && !isWaiting && message.text.isNotEmpty;
    final Widget content = isUser
        ? bubble
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              bubble,
              if (showCopy)
                SizedBox(
                  height: 24,
                  // Visually revealed on hover, but always kept in the semantics
                  // tree so screen-reader / keyboard users can reach it too.
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    alwaysIncludeSemantics: true,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _CopyButton(text: message.text),
                    ),
                  ),
                ),
            ],
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
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
            Flexible(child: content),
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
      ),
    );
  }
}

/// One-time fade + slide-up entrance for a newly-added bubble. Uses a
/// TweenAnimationBuilder (end never changes) so it plays exactly once — the
/// streaming bubble's chunk rebuilds don't re-trigger it. Respects Reduce Motion.
class _MessageEntrance extends StatelessWidget {
  const _MessageEntrance({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Assistant markdown with clickable (scheme-checked) links, styled code, and
/// selectable text. The streaming caret is a separate sibling widget so it never
/// touches the markdown source.
class _AssistantMarkdown extends StatelessWidget {
  const _AssistantMarkdown({required this.text});

  final String text;

  static const _allowedSchemes = {'http', 'https', 'mailto'};

  Future<void> _openLink(BuildContext context, String? href) async {
    final uri = href == null ? null : Uri.tryParse(href);
    // LLM output is data, not a command — only ever launch safe web schemes.
    if (uri == null || !_allowedSchemes.contains(uri.scheme.toLowerCase())) {
      return;
    }
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      showEvolveToast(
        context,
        message: t.aiCoach.linkOpenFailed,
        kind: EvolveToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return MarkdownBody(
      data: text,
      selectable: true,
      onTapLink: (linkText, href, title) => _openLink(context, href),
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: colors.foreground, fontSize: 14, height: 1.45),
        a: TextStyle(
          color: context.evolveAccent,
          decoration: TextDecoration.underline,
        ),
        h1: TextStyle(color: colors.foreground, fontWeight: FontWeight.w800),
        h2: TextStyle(color: colors.foreground, fontWeight: FontWeight.w800),
        h3: TextStyle(color: colors.foreground, fontWeight: FontWeight.w800),
        listBullet: TextStyle(
          color: colors.foreground,
          fontSize: 14,
          height: 1.45,
        ),
        strong: TextStyle(
          color: colors.foreground,
          fontWeight: FontWeight.w700,
        ),
        code: TextStyle(
          color: colors.foreground,
          fontSize: 13,
          height: 1.4,
          fontFamily: 'monospace',
          backgroundColor: colors.panelSoft.withValues(alpha: 0.6),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: colors.panelSoft.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

/// Blinking cursor bar at the end of a streaming reply — a decorative sibling of
/// the markdown (never part of the selectable text). Respects Reduce Motion.
class _StreamingCaret extends StatefulWidget {
  const _StreamingCaret();

  @override
  State<_StreamingCaret> createState() => _StreamingCaretState();
}

class _StreamingCaretState extends State<_StreamingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1060),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: 2,
      height: 14,
      decoration: BoxDecoration(
        color: context.evolveColors.foreground.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(1),
      ),
    );
    if (MediaQuery.of(context).disableAnimations) {
      if (_controller.isAnimating) _controller.stop();
      return bar;
    }
    if (!_controller.isAnimating) _controller.repeat(reverse: true);
    return FadeTransition(opacity: _controller, child: bar);
  }
}

/// Animated three-dot "thinking" indicator shown in the assistant bubble while
/// awaiting the first token. Respects Reduce Motion (renders steady dots).
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(double opacity) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: EvolveColors.violet.withValues(alpha: opacity),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Announce the "thinking" state to screen readers.
    final Widget dots;
    if (MediaQuery.of(context).disableAnimations) {
      // Don't drive a ticker for motion nobody renders.
      if (_controller.isAnimating) _controller.stop();
      dots = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            _dot(0.65),
            if (i < 2) const SizedBox(width: 5),
          ],
        ],
      );
    } else {
      if (!_controller.isAnimating) _controller.repeat();
      dots = AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                _dot(_opacityFor(i, _controller.value)),
                if (i < 2) const SizedBox(width: 5),
              ],
            ],
          );
        },
      );
    }
    return Semantics(
      liveRegion: true,
      label: t.aiCoach.typing,
      child: ExcludeSemantics(child: dots),
    );
  }

  double _opacityFor(int index, double t) {
    final phase = (t + index * 0.18) % 1.0;
    final wave = (math.sin(phase * 2 * math.pi) + 1) / 2; // 0..1
    return 0.3 + 0.6 * wave;
  }
}

/// Hover-revealed "copy" button under an assistant reply. Copies the raw
/// markdown and confirms with a toast.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    // Keyboard/AT-activatable (InkWell + Semantics button); the visible label
    // makes a tooltip redundant.
    return Semantics(
      button: true,
      label: t.aiCoach.copyTooltip,
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: text));
          if (context.mounted) {
            showEvolveToast(
              context,
              message: t.aiCoach.copiedToast,
              kind: EvolveToastKind.success,
            );
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.copy, size: 12, color: colors.muted),
              const SizedBox(width: 5),
              Text(
                t.aiCoach.copyTooltip,
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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

/// BYOK setup state: the cloud engine ships without a key, so until the user
/// supplies their own this banner says so and opens the dialog that takes it.
/// Renders nothing while the Keychain read is in flight, so a configured key
/// never flashes a spurious setup prompt on open.
class _CloudKeyMissingBanner extends ConsumerWidget {
  const _CloudKeyMissingBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Effective, not persisted: a Private-mode user with Standard stored is on
    // BYOK and needs this prompt — reading `config.backend` would hide it.
    final backend = ref.watch(effectiveCoachBackendProvider);
    if (backend != CoachBackendKind.cloud) return const SizedBox.shrink();
    final key = ref.watch(coachApiKeyProvider);
    if (key.isLoading || key.asData?.value != null) {
      return const SizedBox.shrink();
    }

    final colors = context.evolveColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: EvolveColors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EvolveColors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const EvolveIconChip(
              icon: LucideIcons.keyRound,
              color: EvolveColors.amber,
              size: 34,
              iconSize: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.ai.apiKey.setupTitle,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.ai.apiKey.setupBody,
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
            FilledButton(
              onPressed: () => showCoachSettingsDialog(context),
              child: Text(t.ai.apiKey.setupAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// First-run privacy nudge: when the coach is on a remote engine and a local AI
/// server is detected on this machine, offer a one-tap switch to running 100%
/// privately. Only probes while it could actually show (remote + not yet
/// dismissed).
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
    // Worth offering on either remote engine, not just BYOK: "your messages
    // never leave this Mac" is as true a win for a subscriber as for someone
    // paying OpenRouter directly.
    final backend = ref.watch(effectiveCoachBackendProvider);
    if (backend == CoachBackendKind.local) return const SizedBox.shrink();
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

/// Shown when the coach is on the local Ollama backend but the server is down:
/// offers a one-tap "Start Ollama" (or "Get Ollama" if it isn't installed),
/// with a soft hint if a launch takes too long. Hides itself the moment the
/// server becomes reachable.
class _LocalOfflineBanner extends ConsumerStatefulWidget {
  const _LocalOfflineBanner();

  @override
  ConsumerState<_LocalOfflineBanner> createState() =>
      _LocalOfflineBannerState();
}

class _LocalOfflineBannerState extends ConsumerState<_LocalOfflineBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // While the coach page is open, re-probe the local server (and install
    // state) every few seconds so the banner self-heals when Ollama comes up
    // out-of-band or is installed mid-session. Cheap and idle unless we're on
    // the local Ollama backend AND not already connected.
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      final config = ref.read(coachConfigProvider);
      if (config.backend != CoachBackendKind.local) return;
      if (LocalServerPreset.match(config.localBaseUrl) !=
          LocalServerPreset.ollama) {
        return;
      }
      final reachable = ref
          .read(coachLocalReachableProvider(config.localBaseUrl))
          .asData
          ?.value;
      if (reachable == true) return; // already connected — nothing to heal
      ref.invalidate(coachLocalReachableProvider(config.localBaseUrl));
      ref.invalidate(ollamaInstalledProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(coachConfigProvider);
    // Gate on backend/preset BEFORE touching the reachability probe, so cloud
    // (or a non-Ollama local server) never triggers a localhost probe here.
    if (config.backend != CoachBackendKind.local) {
      return const SizedBox.shrink();
    }
    final preset = LocalServerPreset.match(config.localBaseUrl);
    if (preset != LocalServerPreset.ollama) return const SizedBox.shrink();
    // Don't render until reachability resolves (avoids a flash on open).
    final reachable = ref
        .watch(coachLocalReachableProvider(config.localBaseUrl))
        .asData
        ?.value;
    if (reachable == null || reachable) return const SizedBox.shrink();

    final status = ref.watch(ollamaStartControllerProvider);
    final installed = ref.watch(ollamaInstalledProvider).asData?.value ?? true;

    final colors = context.evolveColors;
    final (title, body) = switch ((installed, status)) {
      (false, _) => (
        t.coachSettings.ollamaNotInstalledTitle,
        t.coachSettings.ollamaNotInstalledBody,
      ),
      (true, OllamaStartStatus.starting) => (
        t.coachSettings.startingOllama,
        t.coachSettings.ollamaStartingBody,
      ),
      (true, OllamaStartStatus.timedOut) => (
        t.coachSettings.ollamaOfflineTitle,
        t.coachSettings.ollamaStartTimeout,
      ),
      (true, OllamaStartStatus.failed) => (
        t.coachSettings.ollamaOfflineTitle,
        t.coachSettings.ollamaStartFailed,
      ),
      _ => (
        t.coachSettings.ollamaOfflineTitle,
        t.coachSettings.ollamaOfflineBody,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: EvolveColors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: EvolveColors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const EvolveIconChip(
              icon: LucideIcons.serverOff,
              color: EvolveColors.amber,
              size: 34,
              iconSize: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.foreground,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
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
            const StartOllamaButton(),
          ],
        ),
      ),
    );
  }
}
