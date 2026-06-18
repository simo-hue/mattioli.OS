import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/macro_goal_calendar.dart';
import '../../core/theme.dart';
import '../../models/macro_goal.dart';
import '../../providers/macro_goals_provider.dart';
import '../widgets/macro_goals/goal_item_widget.dart';
import '../widgets/macro_goals/add_goal_bar.dart';
import '../widgets/macro_goals/macro_goals_stats_view.dart';
import '../../core/haptics.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../providers/tutorial_provider.dart';
import '../../core/localization.dart';
import '../../core/app_logger.dart';

class MacroGoalsScreen extends ConsumerStatefulWidget {
  final bool isActive;
  final VoidCallback? onFinishTutorial;
  final GlobalKey? statsNavKey;
  const MacroGoalsScreen({
    super.key,
    required this.isActive,
    this.onFinishTutorial,
    this.statsNavKey,
  });

  @override
  ConsumerState<MacroGoalsScreen> createState() => _MacroGoalsScreenState();
}

class _MacroGoalsScreenState extends ConsumerState<MacroGoalsScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  static const Duration _tutorialStartDelay = Duration(milliseconds: 400);
  static const Duration _tutorialMetricsRestartDelay = Duration(
    milliseconds: 350,
  );
  static const int _performanceTutorialIndex = 7;

  bool _isForward = true;
  bool _showStats = false;
  bool _isShowingGoalsTutorial = false;
  int _goalsTutorialIndex = 0;
  Timer? _goalsTutorialStartTimer;
  Timer? _goalsTutorialMetricsTimer;
  TutorialCoachMark? _goalsTutorial;

  final GlobalKey _planSelectorKey = GlobalKey();
  final GlobalKey _addGoalKey = GlobalKey();
  final GlobalKey _goalsListKey = GlobalKey();
  final GlobalKey _performanceToggleKey = GlobalKey();
  final GlobalKey _tutorialCheckboxKey = GlobalKey();
  final GlobalKey _tutorialCategoryKey = GlobalKey();
  final GlobalKey _tutorialRescheduleKey = GlobalKey();
  final GlobalKey _tutorialEditKey = GlobalKey();
  final GlobalKey _tutorialDeleteKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGoalsTutorial();
    });
  }

  @override
  void didUpdateWidget(covariant MacroGoalsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkGoalsTutorial();
      });
    }
    if (oldWidget.isActive && !widget.isActive && _isShowingGoalsTutorial) {
      _clearGoalsTutorialState(removeOverlay: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _goalsTutorialStartTimer?.cancel();
    _goalsTutorialMetricsTimer?.cancel();
    _goalsTutorial?.removeOverlayEntry();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!_isShowingGoalsTutorial) return;

    _goalsTutorialMetricsTimer?.cancel();
    _goalsTutorial?.removeOverlayEntry();
    _goalsTutorial = null;

    _goalsTutorialMetricsTimer = Timer(_tutorialMetricsRestartDelay, () {
      if (!mounted || !_isShowingGoalsTutorial) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isShowingGoalsTutorial) return;
        _showGoalsTutorial(initialFocus: _goalsTutorialIndex, replace: true);
      });
    });
  }

  void _checkGoalsTutorial() {
    if (!widget.isActive) return;

    final mainTutorialSeen = ref.read(tutorialProvider);
    final goalsTutorialSeen = ref.read(goalsTutorialProvider);

    // Only show if main tutorial is finished but goals tutorial isn't
    if (mainTutorialSeen && !goalsTutorialSeen) {
      if (_isShowingGoalsTutorial) return;
      _goalsTutorialStartTimer?.cancel();
      _goalsTutorialStartTimer = Timer(_tutorialStartDelay, () {
        if (mounted && widget.isActive) _showGoalsTutorial();
      });
    }
  }

  Widget _buildTutorialContent(
    String title,
    String description,
    TutorialCoachMarkController controller, {
    bool isFirst = false,
    bool isLast = false,
    VoidCallback? onNextPressed,
    String? nextButtonLabel,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isLandscape = size.width > size.height;
    final horizontalMargin = isLandscape ? 16.0 : 20.0;
    final availableWidth = math.max(240.0, size.width - (horizontalMargin * 2));
    final maxWidth = math.min(availableWidth, isLandscape ? 480.0 : 520.0);
    final availableHeight = math.max(
      160.0,
      size.height - mediaQuery.padding.vertical,
    );
    final maxHeight = isLandscape
        ? math.min(220.0, math.max(160.0, availableHeight - 48.0))
        : math.min(360.0, math.max(220.0, availableHeight - 96.0));
    final cardPadding = isLandscape
        ? const EdgeInsets.all(16)
        : const EdgeInsets.all(22);

    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: maxWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            padding: cardPadding,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.info,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: isLandscape ? 17.0 : 18.0,
                            fontFamily: 'Inter',
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isLandscape ? 10.0 : 12.0),
                  Text(
                    description,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontFamily: 'Inter',
                      fontSize: isLandscape ? 13 : 14,
                      height: isLandscape ? 1.38 : 1.5,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 14.0 : 20.0),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (!isFirst)
                        TextButton(
                          onPressed: () {
                            ref.hapticSelection();
                            controller.previous();
                          },
                          child: Text(
                            context.l10n.translate("Indietro"),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton(
                        onPressed: () {
                          ref.hapticSelection();
                          if (onNextPressed != null) {
                            onNextPressed();
                          } else if (isLast) {
                            controller.skip();
                          } else {
                            controller.next();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor:
                              Theme.of(
                                    context,
                                  ).colorScheme.primary.computeLuminance() >
                                  0.5
                              ? Colors.black
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          nextButtonLabel != null
                              ? context.l10n.translate(nextButtonLabel)
                              : (isLast
                                    ? context.l10n.translate("Fine")
                                    : context.l10n.translate("Avanti")),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ContentAlign _goalActionTutorialAlign() {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height || size.height < 560
        ? ContentAlign.top
        : ContentAlign.bottom;
  }

  EdgeInsets _tutorialTargetPadding() {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    return EdgeInsets.symmetric(
      horizontal: isLandscape ? 16 : 20,
      vertical: isLandscape ? 8 : 12,
    );
  }

  List<TargetFocus> _buildGoalsTutorialTargets() {
    final goalActionAlign = _goalActionTutorialAlign();
    final targetPadding = _tutorialTargetPadding();

    return [
      TargetFocus(
        identify: "Tipo Pianificazione",
        keyTarget: _planSelectorKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: targetPadding,
            builder: (context, controller) {
              return _buildTutorialContent(
                context.l10n.translate("Tipo di Pianificazione"),
                context.l10n.translate(
                  "Qui puoi selezionare la visione temporale: Lifetime (per tutta la vita), Annuale, Trimestrale, Mensile o Settimanale.",
                ),
                controller,
                isFirst: true,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Aggiungi Goal",
        keyTarget: _addGoalKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            padding: targetPadding,
            builder: (context, controller) {
              return _buildTutorialContent(
                context.l10n.translate("Nuovo Obiettivo"),
                context.l10n.translate(
                  "Da qui puoi inserire un nuovo obiettivo. Potrai anche personalizzare le Categorie a tuo piacimento per organizzare tutto al meglio.",
                ),
                controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Tutorial Completare",
        keyTarget: _tutorialCheckboxKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: goalActionAlign,
            padding: targetPadding,
            builder: (context, controller) => _buildTutorialContent(
              context.l10n.translate("Completare o Fallire"),
              context.l10n.translate(
                "Clicca qui per segnare l'obiettivo come completato. Cliccandolo di nuovo verrà segnato come fallito.",
              ),
              controller,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Tutorial Categoria",
        keyTarget: _tutorialCategoryKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: goalActionAlign,
            padding: targetPadding,
            builder: (context, controller) => _buildTutorialContent(
              context.l10n.translate("Categoria"),
              context.l10n.translate(
                "Usa questo pulsante per assegnare rapidamente una categoria all'obiettivo.",
              ),
              controller,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Tutorial Posticipare",
        keyTarget: _tutorialRescheduleKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: goalActionAlign,
            padding: targetPadding,
            builder: (context, controller) => _buildTutorialContent(
              context.l10n.translate("Posticipare"),
              context.l10n.translate(
                "Se non hai fatto in tempo o i piani sono cambiati, puoi spostare questo obiettivo alla settimana / mese o anno successivo ( in base a dove hai inserito l'obiettivo).",
              ),
              controller,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Tutorial Modifica",
        keyTarget: _tutorialEditKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: goalActionAlign,
            padding: targetPadding,
            builder: (context, controller) => _buildTutorialContent(
              context.l10n.translate("Modifica"),
              context.l10n.translate(
                "Se devi semplicemente rinominare l'obiettivo, usa la matita.",
              ),
              controller,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Tutorial Elimina",
        keyTarget: _tutorialDeleteKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: goalActionAlign,
            padding: targetPadding,
            builder: (context, controller) {
              return _buildTutorialContent(
                context.l10n.translate("Elimina"),
                context.l10n.translate(
                  "Infine, questo pulsante elimina definitivamente l'obiettivo.",
                ),
                controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Analisi Performance",
        keyTarget: _performanceToggleKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: targetPadding,
            builder: (context, controller) {
              return _buildTutorialContent(
                context.l10n.translate("Analisi e Statistiche"),
                context.l10n.translate(
                  "Passa a questa scheda per visualizzare grafici e performance dettagliate selezionando l'anno corrente o tutti gli anni.",
                ),
                controller,
                isLast: false,
                nextButtonLabel: "Continua",
              );
            },
          ),
        ],
      ),
      if (widget.statsNavKey != null)
        TargetFocus(
          identify: "Tutorial Statistiche Tab",
          keyTarget: widget.statsNavKey!,
          enableTargetTab: false,
          enableOverlayTab: false,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              padding: targetPadding,
              builder: (context, controller) {
                return _buildTutorialContent(
                  context.l10n.translate("Statistiche Abitudini"),
                  context.l10n.translate(
                    "Per vedere le statistiche delle tue abitudini giornaliere, puoi spostarti in questa sezione.",
                  ),
                  controller,
                  isLast: false,
                  nextButtonLabel: "Passa alle Statistiche",
                  onNextPressed: () {
                    _completeGoalsTutorial();
                    controller.skip();
                  },
                );
              },
            ),
          ],
        ),
    ];
  }

  Future<void> _beforeGoalsTutorialFocus(
    TargetFocus target,
    List<TargetFocus> targets,
  ) async {
    final index = targets.indexOf(target);
    if (index < 0 || !mounted) return;

    _goalsTutorialIndex = index;
    final shouldShowStats = index >= _performanceTutorialIndex;
    if (_showStats != shouldShowStats) {
      setState(() => _showStats = shouldShowStats);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  bool _areGoalsTutorialTargetsReady() {
    return [
      _planSelectorKey,
      _addGoalKey,
      _performanceToggleKey,
      _tutorialCheckboxKey,
      _tutorialCategoryKey,
      _tutorialRescheduleKey,
      _tutorialEditKey,
      _tutorialDeleteKey,
      if (widget.statsNavKey != null) widget.statsNavKey!,
    ].every((key) => key.currentContext != null);
  }

  void _clearGoalsTutorialState({bool removeOverlay = false}) {
    _goalsTutorialMetricsTimer?.cancel();
    if (removeOverlay) {
      _goalsTutorial?.removeOverlayEntry();
    }
    _goalsTutorial = null;
    _isShowingGoalsTutorial = false;
    _goalsTutorialIndex = 0;
  }

  void _completeGoalsTutorial() {
    ref.read(goalsTutorialProvider.notifier).setTutorialSeen(true);
    if (widget.onFinishTutorial != null) {
      widget.onFinishTutorial!();
    }
  }

  void _showGoalsTutorial({int initialFocus = 0, bool replace = false}) {
    if (!widget.isActive) return;
    if (_isShowingGoalsTutorial && !replace) return;
    if (!_areGoalsTutorialTargetsReady()) {
      AppLogger.warning(
        '[Tutorial] Goals tutorial targets are not ready; delaying start',
      );
      _goalsTutorialStartTimer?.cancel();
      _goalsTutorialStartTimer = Timer(_tutorialStartDelay, () {
        if (mounted && widget.isActive) {
          _showGoalsTutorial(initialFocus: initialFocus);
        }
      });
      return;
    }

    _goalsTutorialStartTimer?.cancel();
    _goalsTutorial?.removeOverlayEntry();
    final targets = _buildGoalsTutorialTargets();
    final resolvedInitialFocus = initialFocus
        .clamp(0, targets.length - 1)
        .toInt();
    _goalsTutorialIndex = resolvedInitialFocus;
    _isShowingGoalsTutorial = true;

    final tutorial = TutorialCoachMark(
      targets: targets,
      initialFocus: resolvedInitialFocus,
      beforeFocus: (target) => _beforeGoalsTutorialFocus(target, targets),
      colorShadow: Colors.black,
      hideSkip: true,
      paddingFocus: 10,
      opacityShadow: 0.85,
      focusAnimationDuration: const Duration(milliseconds: 400),
      unFocusAnimationDuration: Duration.zero,
      pulseEnable: false,
      onFinish: () {
        _completeGoalsTutorial();
        _clearGoalsTutorialState();
      },
      onSkip: () {
        _clearGoalsTutorialState();
        return true;
      },
    );

    _goalsTutorial = tutorial;
    try {
      tutorial.show(context: context);
    } catch (e, stack) {
      _clearGoalsTutorialState();
      AppLogger.warning('[Tutorial] Unable to start goals tutorial', e, stack);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final viewState = ref.watch(macroGoalsViewProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    // Force re-compute on state change
    ref.watch(macroGoalsProvider);

    // Ascolta anche i cambiamenti dello stato del main tutorial (es. se viene resettato)
    ref.listen(tutorialProvider, (prev, next) {
      if (next == true && widget.isActive && !ref.read(goalsTutorialProvider)) {
        // Se il tutorial main finisce, controlla se bisogna lanciare questo (es. navigazione dalla tab)
        // Diamo tempo al cambio tab di terminare l'animazione
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && widget.isActive) _checkGoalsTutorial();
        });
      }
    });

    final filteredGoals = ref
        .read(macroGoalsProvider.notifier)
        .getFilteredGoals(
          type: viewState.selectedType,
          year: viewState.selectedYear,
          quarter: viewState.selectedQuarter,
          month: viewState.selectedMonth,
          weekNumber: viewState.selectedWeek,
        );

    final mainTutorialSeen = ref.watch(tutorialProvider);
    final goalsTutorialSeen = ref.watch(goalsTutorialProvider);

    List<MacroGoal> displayGoals = List.from(filteredGoals);
    if (mainTutorialSeen && !goalsTutorialSeen) {
      displayGoals.insert(
        0,
        MacroGoal(
          id: 'tutorial_fake_goal',
          title: context.l10n.translate('Obiettivo Tutorial'),
          status: GoalStatus.active,
          type: viewState.selectedType,
          year: viewState.selectedYear,
          quarter: viewState.selectedQuarter,
          month: viewState.selectedMonth,
          weekNumber: viewState.selectedWeek,
          createdAt: DateTime.now(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Unified Native Header ─────────────────────────────────────
            _buildUnifiedHeader(context, ref, viewState, primaryColor),

            if (_showStats)
              const Expanded(child: MacroGoalsStatsView())
            else ...[
              // ── Native Period Navigator Stepper ───────────────────────────
              _buildPeriodNavigator(context, ref, viewState),

              const SizedBox(height: 16),

              // ── Goals list ────────────────────────────────────────────────
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) {
                    if (viewState.selectedType == GoalType.lifetime) return;
                    const velocityThreshold = 300.0;
                    final vx = details.primaryVelocity ?? 0.0;
                    if (vx < -velocityThreshold) {
                      setState(() => _isForward = true);
                      ref.read(macroGoalsViewProvider.notifier).nextPeriod();
                      ref.hapticLight();
                    } else if (vx > velocityThreshold) {
                      setState(() => _isForward = false);
                      ref.read(macroGoalsViewProvider.notifier).prevPeriod();
                      ref.hapticLight();
                    }
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    switchInCurve: Curves.easeOutQuart,
                    switchOutCurve: Curves.easeOutQuart,
                    transitionBuilder: (child, animation) {
                      final isIncoming =
                          child.key ==
                          ValueKey(
                            '${viewState.selectedType}-${viewState.selectedYear}-${viewState.selectedMonth}-${viewState.selectedWeek}-${viewState.selectedQuarter}',
                          );
                      final dir = _isForward ? 1 : -1;

                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          double pageOffset = 0.0;
                          if (isIncoming) {
                            pageOffset = (1.0 - animation.value) * dir;
                          } else {
                            pageOffset = (animation.value - 1.0) * dir;
                          }

                          final absOffset = pageOffset.abs();

                          // Premium Parallax & Scale Effect (simulating Calendar PageView)
                          final double scale =
                              1.0 - (absOffset * 0.05).clamp(0.0, 0.05);
                          final double opacity = (1.0 - absOffset).clamp(
                            0.0,
                            1.0,
                          );

                          // We use the screen width to simulate the PageView horizontal scroll
                          final double width = MediaQuery.of(
                            context,
                          ).size.width;
                          final double translation = pageOffset * width;

                          return Transform.scale(
                            scale: scale,
                            child: Transform.translate(
                              offset: Offset(translation, 0),
                              child: Opacity(opacity: opacity, child: child),
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    child: _GoalsList(
                      key: ValueKey(
                        '${viewState.selectedType}-${viewState.selectedYear}-${viewState.selectedMonth}-${viewState.selectedWeek}-${viewState.selectedQuarter}',
                      ),
                      goals: displayGoals,
                      viewState: viewState,
                      emptyStateKey: _goalsListKey,
                      tutorialCheckboxKey: _tutorialCheckboxKey,
                      tutorialCategoryKey: _tutorialCategoryKey,
                      tutorialRescheduleKey: _tutorialRescheduleKey,
                      tutorialEditKey: _tutorialEditKey,
                      tutorialDeleteKey: _tutorialDeleteKey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                key: _addGoalKey,
                child: AddGoalBar(viewState: viewState),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedHeader(
    BuildContext context,
    WidgetRef ref,
    MacroGoalsViewState vs,
    Color primaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.translate('Obiettivi'),
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.foreground,
                  letterSpacing: -1,
                ),
              ),
              if (!_showStats) _buildTypePicker(context, ref, vs, primaryColor),
            ],
          ),
          const SizedBox(height: 16),
          Container(key: _performanceToggleKey, child: _buildModeToggle()),
        ],
      ),
    );
  }

  Widget _buildTypePicker(
    BuildContext context,
    WidgetRef ref,
    MacroGoalsViewState vs,
    Color primaryColor,
  ) {
    final typeLabel = _goalTypeLabel(context, vs.selectedType);

    return GestureDetector(
      onTap: () {
        ref.hapticLight();
        _showTypePicker(context, ref, vs, primaryColor);
      },
      child: Container(
        key: _planSelectorKey,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.appColors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.target, size: 12, color: primaryColor),
            const SizedBox(width: 6),
            Text(
              typeLabel,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appColors.foreground,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 12,
              color: context.appColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.appColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildToggleItem(false, context.l10n.translate('I miei obiettivi')),
          _buildToggleItem(true, context.l10n.translate('Analisi Performance')),
        ],
      ),
    );
  }

  Widget _buildToggleItem(bool stats, String label) {
    final active = _showStats == stats;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_showStats != stats) {
            setState(() => _showStats = stats);
            ref.hapticSelection();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active
                  ? context.appColors.background
                  : context.appColors.mutedForeground,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  void _showTypePicker(
    BuildContext context,
    WidgetRef ref,
    MacroGoalsViewState vs,
    Color primaryColor,
  ) {
    final types = [
      (t: GoalType.lifetime, i: LucideIcons.infinity),
      (t: GoalType.annual, i: LucideIcons.calendar),
      (t: GoalType.quarterly, i: LucideIcons.calendarRange),
      (t: GoalType.monthly, i: LucideIcons.calendarDays),
      (t: GoalType.weekly, i: LucideIcons.clock),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  context.l10n.planningTypeHeader,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                    color: context.appColors.mutedForeground,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            ...types.map((type) {
              final isSel = type.t == vs.selectedType;
              return ListTile(
                leading: Icon(
                  type.i,
                  size: 20,
                  color: isSel
                      ? primaryColor
                      : context.appColors.mutedForeground.withValues(
                          alpha: 0.6,
                        ),
                ),
                title: Text(
                  _goalTypeLabel(context, type.t).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: isSel
                        ? context.appColors.foreground
                        : context.appColors.mutedForeground,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: isSel
                    ? Icon(LucideIcons.check, color: primaryColor, size: 20)
                    : null,
                onTap: () {
                  ref.read(macroGoalsViewProvider.notifier).setType(type.t);
                  Navigator.pop(context);
                  ref.hapticSelection();
                },
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodNavigator(
    BuildContext context,
    WidgetRef ref,
    MacroGoalsViewState vs,
  ) {
    if (vs.selectedType == GoalType.lifetime) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Text(
          context.l10n.lifetimeGoalsDescription,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.appColors.mutedForeground,
          ),
        ),
      );
    }

    String periodTitle = '';
    Color highlightColor = context.appColors.foreground;

    switch (vs.selectedType) {
      case GoalType.annual:
        periodTitle = '${vs.selectedYear}';
        break;
      case GoalType.quarterly:
        periodTitle = 'Q${vs.selectedQuarter} ${vs.selectedYear}';
        highlightColor = const Color(0xFFFBBF24); // amber
        break;
      case GoalType.monthly:
        periodTitle = _capitalizeFirst(
          DateFormat.yMMMM(
            context.l10n.localeName,
          ).format(DateTime(vs.selectedYear, vs.selectedMonth)),
        );
        highlightColor = const Color(0xFF60A5FA); // blue
        break;
      case GoalType.weekly:
        periodTitle = _formatWeeklyRange(
          context,
          vs.selectedYear,
          vs.selectedMonth,
          vs.selectedWeek,
        );
        highlightColor = const Color(0xFFA78BFA); // purple
        break;
      case GoalType.lifetime:
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          GestureDetector(
            onTap: () {
              setState(() => _isForward = false);
              ref.read(macroGoalsViewProvider.notifier).prevPeriod();
              ref.hapticLight();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.appColors.card.withValues(alpha: 0.8),
              ),
              child: Icon(
                LucideIcons.chevronLeft,
                size: 20,
                color: context.appColors.foreground,
              ),
            ),
          ),

          // Central Title representing the context
          Expanded(
            child: Text(
              periodTitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: highlightColor,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // Next Button
          GestureDetector(
            onTap: () {
              setState(() => _isForward = true);
              ref.read(macroGoalsViewProvider.notifier).nextPeriod();
              ref.hapticLight();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.appColors.card.withValues(alpha: 0.8),
              ),
              child: Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: context.appColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _goalTypeLabel(BuildContext context, GoalType type) {
    switch (type) {
      case GoalType.lifetime:
        return context.l10n.goalTypeLifetime;
      case GoalType.annual:
        return context.l10n.goalTypeAnnual;
      case GoalType.quarterly:
        return context.l10n.goalTypeQuarterly;
      case GoalType.monthly:
        return context.l10n.goalTypeMonthly;
      case GoalType.weekly:
        return context.l10n.goalTypeWeekly;
    }
  }

  String _formatWeeklyRange(
    BuildContext context,
    int year,
    int month,
    int week,
  ) {
    final range = logicalWeekRange(year, month, week);
    final locale = context.l10n.localeName;
    final monthFormat = DateFormat.MMMM(locale);
    final startMonth = monthFormat.format(range.start);
    final endMonth = monthFormat.format(range.end);
    final isEnglish = locale.toLowerCase().startsWith('en');

    final sameMonth =
        range.start.year == range.end.year &&
        range.start.month == range.end.month;
    if (sameMonth) {
      if (isEnglish) {
        return '$endMonth ${range.start.day} - ${range.end.day}, ${range.end.year}';
      }
      return '${range.start.day} - ${range.end.day} $endMonth ${range.end.year}';
    }

    final sameYear = range.start.year == range.end.year;
    if (sameYear) {
      if (isEnglish) {
        return '$startMonth ${range.start.day} - $endMonth ${range.end.day}, ${range.end.year}';
      }
      return '${range.start.day} $startMonth - ${range.end.day} $endMonth ${range.end.year}';
    }

    if (isEnglish) {
      return '$startMonth ${range.start.day}, ${range.start.year} - $endMonth ${range.end.day}, ${range.end.year}';
    }
    return '${range.start.day} $startMonth ${range.start.year} - ${range.end.day} $endMonth ${range.end.year}';
  }

  String _capitalizeFirst(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

// ─── Goals list ───────────────────────────────────────────────────────────────

class _GoalsList extends ConsumerWidget {
  final List<MacroGoal> goals;
  final MacroGoalsViewState viewState;
  final GlobalKey emptyStateKey;
  final GlobalKey? tutorialCheckboxKey;
  final GlobalKey? tutorialCategoryKey;
  final GlobalKey? tutorialRescheduleKey;
  final GlobalKey? tutorialEditKey;
  final GlobalKey? tutorialDeleteKey;

  const _GoalsList({
    super.key,
    required this.goals,
    required this.viewState,
    required this.emptyStateKey,
    this.tutorialCheckboxKey,
    this.tutorialCategoryKey,
    this.tutorialRescheduleKey,
    this.tutorialEditKey,
    this.tutorialDeleteKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            key: emptyStateKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.target,
                  color: context.appColors.border,
                  size: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.emptyGoalsTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.emptyGoalsSubtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.appColors.mutedForeground,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final items = _buildItems(goals);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      physics: const BouncingScrollPhysics(),
      proxyDecorator: (child, index, animation) => child,
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {
        // Programmatic reordering is handled by the provider state change
      },
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _SectionHeader) {
          return _buildSectionHeader(
            context,
            item.status,
            ValueKey('header-${item.status.name}'),
          );
        }
        final goal = item as MacroGoal;
        if (goal.id == 'tutorial_fake_goal') {
          return GoalItemWidget(
            key: ValueKey(goal.id),
            goal: goal,
            checkboxKey: tutorialCheckboxKey,
            categoryKey: tutorialCategoryKey,
            rescheduleKey: tutorialRescheduleKey,
            editKey: tutorialEditKey,
            deleteKey: tutorialDeleteKey,
          );
        }
        return GoalItemWidget(key: ValueKey(goal.id), goal: goal);
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, GoalStatus status, Key key) {
    final label = status == GoalStatus.completed
        ? context.l10n.translate('COMPLETATI')
        : context.l10n.translate('FALLITI');
    final color = status == GoalStatus.completed
        ? const Color(0xFF10B981).withValues(alpha: 0.7)
        : context.appColors.destructive.withValues(alpha: 0.7);

    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.2)),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }

  List<dynamic> _buildItems(List<MacroGoal> goals) {
    final result = <dynamic>[];
    bool shownCompleted = false;
    bool shownFailed = false;

    for (final goal in goals) {
      if (goal.status == GoalStatus.completed && !shownCompleted) {
        result.add(_SectionHeader(GoalStatus.completed));
        shownCompleted = true;
      }
      if (goal.status == GoalStatus.failed && !shownFailed) {
        result.add(_SectionHeader(GoalStatus.failed));
        shownFailed = true;
      }
      result.add(goal);
    }
    return result;
  }
}

class _SectionHeader {
  final GoalStatus status;
  _SectionHeader(this.status);
}
