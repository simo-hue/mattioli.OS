import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/macro_goal_calendar.dart';
import '../../core/theme.dart';
import '../../core/rtl.dart';
import '../../models/macro_goal.dart';
import '../../providers/macro_goals_provider.dart';
import '../widgets/macro_goals/goal_item_widget.dart';
import '../widgets/macro_goals/add_goal_bar.dart';
import '../widgets/macro_goals/macro_goals_stats_view.dart';
import '../../core/haptics.dart';
import '../../providers/tutorial_provider.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_segmented_control.dart';
import '../kit/evolve_sheet.dart';

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
    with AutomaticKeepAliveClientMixin {
  static const int _performanceTutorialIndex = 7;

  bool _isForward = true;
  bool _showStats = false;
  bool _didFinishGoalsTutorial = false;
  int _goalsTutorialIndex = 0;
  bool _isRefreshingGoalsTutorialGeometry = false;

  final GlobalKey _goalsTutorialOverlayKey = GlobalKey();
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
  void didUpdateWidget(covariant MacroGoalsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      setState(() {});
    }
    if (oldWidget.isActive && !widget.isActive) {
      _clearGoalsTutorialState();
    }
  }

  Widget _buildTutorialContent(
    String title,
    String description, {
    bool isFirst = false,
    bool isLast = false,
    required VoidCallback onPreviousPressed,
    required VoidCallback onNextPressed,
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

    return SizedBox(
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
                          onPreviousPressed();
                        },
                        child: Text(
                          context.t.tutorial.back,
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
                        onNextPressed();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
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
                        nextButtonLabel ?? (isLast
                                  ? context.t.tutorial.finish
                                  : context.t.tutorial.next),
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
    );
  }

  List<_GoalsTutorialStep> _buildGoalsTutorialSteps() {
    return [
      _GoalsTutorialStep(
        targetKey: _planSelectorKey,
        title: context.t.tutorial.planningType,
        description: context.t.tutorial.hereYouCanSelectTheTime,
      ),
      _GoalsTutorialStep(
        targetKey: _addGoalKey,
        title: context.t.tutorial.newGoal,
        description: context.t.tutorial.fromHereYouCanInsertA,
      ),
      _GoalsTutorialStep(
        targetKey: _tutorialCheckboxKey,
        title: context.t.tutorial.completeOrFail,
        description: context.t.tutorial.markGoalDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _tutorialCategoryKey,
        title: context.t.tutorial.category,
        description: context.t.tutorial.assignCategoryDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _tutorialRescheduleKey,
        title: context.t.tutorial.reschedule,
        description: context.t.tutorial.rescheduleGoalDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _tutorialEditKey,
        title: context.t.tutorial.edit,
        description: context.t.tutorial.editGoalDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _tutorialDeleteKey,
        title: context.t.tutorial.delete,
        description: context.t.tutorial.deleteGoalDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _performanceToggleKey,
        showStats: true,
        title: context.t.tutorial.analysisStats,
        description: context.t.tutorial.analyticsTabDesc,
        nextButtonLabel: widget.statsNavKey == null
            ? context.t.tutorial.goToStats
            : context.t.tutorial.continueLabel,
      ),
      if (widget.statsNavKey != null)
        _GoalsTutorialStep(
          showStats: true,
          title: context.t.tutorial.habitStatistics,
          description: context.t.tutorial.toViewStatisticsForYourDaily,
          nextButtonLabel: context.t.tutorial.goToStats,
        ),
    ];
  }

  int get _goalsTutorialStepCount => widget.statsNavKey == null ? 8 : 9;

  int get _clampedGoalsTutorialIndex {
    return _goalsTutorialIndex.clamp(0, _goalsTutorialStepCount - 1).toInt();
  }

  void _goToGoalsTutorialStep(int index) {
    if (index < 0) return;
    final steps = _buildGoalsTutorialSteps();
    if (index >= steps.length) {
      _finishGoalsTutorial(advanceToStats: true);
      return;
    }

    setState(() {
      _goalsTutorialIndex = index;
      _showStats = steps[index].showStats;
    });
    _scheduleGoalsTutorialGeometryRefresh();
  }

  void _scheduleGoalsTutorialGeometryRefresh() {
    if (_isRefreshingGoalsTutorialGeometry) return;
    _isRefreshingGoalsTutorialGeometry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isRefreshingGoalsTutorialGeometry = false;
      if (!mounted || !_isGoalsTutorialActive) return;
      setState(() {});
    });
  }

  bool get _isGoalsTutorialActive {
    if (!mounted || !widget.isActive || _didFinishGoalsTutorial) return false;
    return ref.read(tutorialProvider) && !ref.read(goalsTutorialProvider);
  }

  Rect? _targetRectForKey(GlobalKey? targetKey) {
    final overlayContext = _goalsTutorialOverlayKey.currentContext;
    final targetContext = targetKey?.currentContext;
    if (overlayContext == null || targetContext == null) return null;

    final overlayObject = overlayContext.findRenderObject();
    final targetObject = targetContext.findRenderObject();
    if (overlayObject is! RenderBox ||
        targetObject is! RenderBox ||
        !overlayObject.attached ||
        !targetObject.attached ||
        !targetObject.hasSize) {
      return null;
    }

    final targetSize = targetObject.size;
    if (targetSize.width <= 1 || targetSize.height <= 1) return null;

    final targetOffset = targetObject.localToGlobal(
      Offset.zero,
      ancestor: overlayObject,
    );
    return targetOffset & targetSize;
  }

  void _clearGoalsTutorialState() {
    _goalsTutorialIndex = 0;
    _showStats = false;
  }

  Widget _buildGoalsTutorialOverlay() {
    final steps = _buildGoalsTutorialSteps();
    final index = _clampedGoalsTutorialIndex;
    final step = steps[index];
    final targetRect = _targetRectForKey(step.targetKey);
    if (step.targetKey != null && targetRect == null) {
      _scheduleGoalsTutorialGeometryRefresh();
    }

    return Positioned.fill(
      child: Material(
        key: _goalsTutorialOverlayKey,
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final overlaySize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final showCardAtTop =
                targetRect != null &&
                targetRect.center.dy > overlaySize.height * 0.52;

            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GoalsTutorialScrimPainter(targetRect),
                  ),
                ),
                if (targetRect != null)
                  Positioned.fromRect(
                    rect: targetRect.inflate(8),
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: showCardAtTop
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.paddingOf(context).top + 16,
                      20,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    child: _buildTutorialContent(
                      step.title,
                      step.description,
                      isFirst: index == 0,
                      isLast: index == steps.length - 1,
                      nextButtonLabel: step.nextButtonLabel,
                      onPreviousPressed: () =>
                          _goToGoalsTutorialStep(index - 1),
                      onNextPressed: () {
                        if (index == steps.length - 1 ||
                            (index == _performanceTutorialIndex &&
                                widget.statsNavKey == null)) {
                          _finishGoalsTutorial(advanceToStats: true);
                          return;
                        }
                        _goToGoalsTutorialStep(index + 1);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _completeGoalsTutorial() {
    unawaited(ref.read(goalsTutorialProvider.notifier).setTutorialSeen(true));
  }

  void _finishGoalsTutorial({bool advanceToStats = false}) {
    if (!mounted || _didFinishGoalsTutorial) return;

    _didFinishGoalsTutorial = true;
    _clearGoalsTutorialState();
    _completeGoalsTutorial();

    if (!advanceToStats || widget.onFinishTutorial == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onFinishTutorial!();
    });
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

    ref.listen(goalsTutorialProvider, (previous, next) {
      if (next == false) {
        _didFinishGoalsTutorial = false;
        _clearGoalsTutorialState();
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
    final isGoalsTutorialPending =
        widget.isActive &&
        !_didFinishGoalsTutorial &&
        mainTutorialSeen &&
        !goalsTutorialSeen;

    final List<MacroGoal> displayGoals = List.from(filteredGoals);
    if (isGoalsTutorialPending) {
      displayGoals.insert(
        0,
        MacroGoal(
          id: 'tutorial_fake_goal',
          title: context.t.macroGoals.tutorialGoal,
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
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: isGoalsTutorialPending,
            child: SafeArea(
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
                          if (viewState.selectedType == GoalType.lifetime) {
                            return;
                          }
                          const velocityThreshold = 300.0;
                          final vx = details.primaryVelocity ?? 0.0;
                          if (vx < -velocityThreshold) {
                            setState(() => _isForward = true);
                            ref
                                .read(macroGoalsViewProvider.notifier)
                                .nextPeriod();
                            ref.hapticLight();
                          } else if (vx > velocityThreshold) {
                            setState(() => _isForward = false);
                            ref
                                .read(macroGoalsViewProvider.notifier)
                                .prevPeriod();
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
                                    child: Opacity(
                                      opacity: opacity,
                                      child: child,
                                    ),
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
          ),
          if (isGoalsTutorialPending && widget.isActive)
            _buildGoalsTutorialOverlay(),
        ],
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
                context.t.common.goals,
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
    return EvolveSegmentedControl<bool>(
      groupValue: _showStats,
      segments: {
        false: context.t.macroGoals.myGoals,
        true: context.t.macroGoals.performanceAnalysis,
      },
      onValueChanged: (stats) => setState(() => _showStats = stats),
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

    showEvolveSheet<void>(
      context: context,
      title: context.t.macroGoals.planningTypeHeader,
      itemsBuilder: (sheetContext) => [
        EvolveListSection(
          children: types.map((type) {
            return EvolveListRow(
              leading: EvolveIconTile(
                icon: type.i,
                tint: context.appColors.mutedForeground,
              ),
              title: _goalTypeLabel(context, type.t),
              selected: type.t == vs.selectedType,
              onTap: () {
                ref.read(macroGoalsViewProvider.notifier).setType(type.t);
                Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        ),
      ],
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
          context.t.macroGoals.lifetimeGoalsDescription,
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
            LocaleSettings.currentLocale.languageCode,
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
                directionalIcon(
                  context,
                  LucideIcons.chevronLeft,
                  LucideIcons.chevronRight,
                ),
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
                directionalIcon(
                  context,
                  LucideIcons.chevronRight,
                  LucideIcons.chevronLeft,
                ),
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
        return context.t.macroGoals.types.lifetime;
      case GoalType.annual:
        return context.t.macroGoals.types.annual;
      case GoalType.quarterly:
        return context.t.macroGoals.types.quarterly;
      case GoalType.monthly:
        return context.t.macroGoals.types.monthly;
      case GoalType.weekly:
        return context.t.macroGoals.types.weekly;
    }
  }

  String _formatWeeklyRange(
    BuildContext context,
    int year,
    int month,
    int week,
  ) {
    final range = logicalWeekRange(year, month, week);
    final locale = LocaleSettings.currentLocale.languageCode;
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

class _GoalsTutorialStep {
  const _GoalsTutorialStep({
    this.targetKey,
    this.showStats = false,
    required this.title,
    required this.description,
    this.nextButtonLabel,
  });

  final GlobalKey? targetKey;
  final bool showStats;
  final String title;
  final String description;
  final String? nextButtonLabel;
}

class _GoalsTutorialScrimPainter extends CustomPainter {
  const _GoalsTutorialScrimPainter(this.targetRect);

  final Rect? targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayBounds = Offset.zero & size;
    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.82);
    final target = targetRect;

    if (target == null) {
      canvas.drawRect(overlayBounds, scrimPaint);
      return;
    }

    final highlightedRect = target.inflate(10).intersect(overlayBounds);
    if (highlightedRect.isEmpty) {
      canvas.drawRect(overlayBounds, scrimPaint);
      return;
    }

    final overlayPath = Path()..addRect(overlayBounds);
    final highlightPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(highlightedRect, const Radius.circular(16)),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, overlayPath, highlightPath),
      scrimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoalsTutorialScrimPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
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
                  context.t.macroGoals.emptyGoalsTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t.macroGoals.emptyGoalsSubtitle,
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
      onReorderItem: (oldIndex, newIndex) {
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
        ? context.t.macroGoals.completed
        : context.t.macroGoals.failed;
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
