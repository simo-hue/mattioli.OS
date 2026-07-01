import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/tutorial_provider.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/haptics.dart';
import '../widgets/pro_features_modal.dart';
import '../widgets/statistics/info_tab_widget.dart';
import '../widgets/statistics/global_trend_tab_widget.dart';
import '../widgets/statistics/habit_overview_tab_widget.dart';
import '../widgets/statistics/habit_calendario_tab_widget.dart';
import '../widgets/statistics/habit_performance_tab_widget.dart';
import '../widgets/statistics/habit_miglioramento_tab_widget.dart';
import '../widgets/statistics/habit_mood_tab_widget.dart';
import '../widgets/statistics/global_alerts_tab_widget.dart';
import '../widgets/statistics/global_habits_tab_widget.dart';
import '../widgets/statistics/global_mood_tab_widget.dart';
import '../../i18n/translations.g.dart';
import '../../core/l10n_dynamic.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  final bool isActive;
  final VoidCallback? onFinishTutorial;
  const StatisticsScreen({
    super.key,
    required this.isActive,
    this.onFinishTutorial,
  });

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with AutomaticKeepAliveClientMixin {
  String _selectedTab = 'Info';
  List<String> _tabs = ['Info', 'Trend', 'Alert', 'Abitudini', 'Mood'];
  String? _selectedGoalId;

  final GlobalKey _goalDropdownKey = GlobalKey();
  final GlobalKey _tabsKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  bool _didFinishStatsTutorial = false;
  int _statsTutorialIndex = 0;
  bool _isRefreshingStatsTutorialGeometry = false;

  final GlobalKey _statsTutorialOverlayKey = GlobalKey();

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      setState(() {});
    }
    if (oldWidget.isActive && !widget.isActive) {
      _clearStatsTutorialState();
    }
  }

  void _completeStatsTutorial() {
    unawaited(ref.read(statsTutorialProvider.notifier).setTutorialSeen(true));
  }

  void _clearStatsTutorialState() {
    _statsTutorialIndex = 0;
  }

  void _finishStatsTutorial({bool showCompletionDialog = false}) {
    if (!mounted || _didFinishStatsTutorial) return;

    _didFinishStatsTutorial = true;
    _clearStatsTutorialState();
    _completeStatsTutorial();

    if (!showCompletionDialog || widget.onFinishTutorial == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onFinishTutorial!();
    });
  }

  List<_StatsTutorialStep> _buildStatsTutorialSteps() {
    return [
      _StatsTutorialStep(
        targetKey: _goalDropdownKey,
        title: context.t.tutorial.filterByHabit,
        description: context.t.tutorial.filterHabitDesc,
      ),
      _StatsTutorialStep(
        targetKey: _tabsKey,
        title: context.t.tutorial.statisticsSections,
        description: context.t.tutorial.statsSectionsDesc,
      ),
    ];
  }

  int get _statsTutorialStepCount => 2;

  int get _clampedStatsTutorialIndex {
    return _statsTutorialIndex.clamp(0, _statsTutorialStepCount - 1).toInt();
  }

  void _goToStatsTutorialStep(int index) {
    if (index < 0) return;
    final steps = _buildStatsTutorialSteps();
    if (index >= steps.length) {
      _finishStatsTutorial(showCompletionDialog: true);
      return;
    }

    setState(() {
      _statsTutorialIndex = index;
    });
    _scheduleStatsTutorialGeometryRefresh();
  }

  void _scheduleStatsTutorialGeometryRefresh() {
    if (_isRefreshingStatsTutorialGeometry) return;
    _isRefreshingStatsTutorialGeometry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isRefreshingStatsTutorialGeometry = false;
      if (!mounted || !_isStatsTutorialActive) return;
      setState(() {});
    });
  }

  bool get _isStatsTutorialActive {
    if (!mounted || !widget.isActive || _didFinishStatsTutorial) return false;
    return ref.read(goalsTutorialProvider) && !ref.read(statsTutorialProvider);
  }

  Rect? _targetRectForKey(GlobalKey? targetKey) {
    final overlayContext = _statsTutorialOverlayKey.currentContext;
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

  Widget _buildStatsTutorialOverlay() {
    final steps = _buildStatsTutorialSteps();
    final index = _clampedStatsTutorialIndex;
    final step = steps[index];
    final targetRect = _targetRectForKey(step.targetKey);
    if (targetRect == null) {
      _scheduleStatsTutorialGeometryRefresh();
    }

    return Positioned.fill(
      child: Material(
        key: _statsTutorialOverlayKey,
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
                    painter: _StatsTutorialScrimPainter(targetRect),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
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
                      onPreviousPressed: () =>
                          _goToStatsTutorialStep(index - 1),
                      onNextPressed: () {
                        if (index == steps.length - 1) {
                          _finishStatsTutorial(showCompletionDialog: true);
                          return;
                        }
                        _goToStatsTutorialStep(index + 1);
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

  Widget _buildTutorialContent(
    String title,
    String description, {
    bool isFirst = false,
    bool isLast = false,
    required VoidCallback onPreviousPressed,
    required VoidCallback onNextPressed,
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

    return SizedBox(
      width: maxWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          padding: EdgeInsets.all(isLandscape ? 16 : 22),
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
                        isLast
                            ? context.t.tutorial.finish
                            : context.t.tutorial.next,
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

  void _selectGoal(String? goalId) {
    final settings = ref.read(settingsProvider);
    if (goalId != null && !settings.isPro) {
      ref.hapticHeavy();
      ProFeaturesModal.show(context).then((_) {
        if (mounted) {
          _selectGoal(null);
        }
      });
      return;
    }
    setState(() {
      _selectedGoalId = goalId;
      if (_selectedGoalId == null) {
        _tabs = ['Info', 'Trend', 'Alert', 'Abitudini', 'Mood'];
        _selectedTab = 'Info';
      } else {
        _tabs = ['Info', 'Trend', 'Stats', 'Alert', 'Mood'];
        _selectedTab = 'Info';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final goals = ref.watch(goalsProvider);
    final goalsTutorialSeen = ref.watch(goalsTutorialProvider);
    final statsTutorialSeen = ref.watch(statsTutorialProvider);

    final settings = ref.watch(settingsProvider);
    if (!settings.isPro && _selectedGoalId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectGoal(null);
        }
      });
    }

    ref.listen(statsTutorialProvider, (previous, next) {
      if (next == false) {
        _didFinishStatsTutorial = false;
        _clearStatsTutorialState();
      }
    });

    final isStatsTutorialPending =
        widget.isActive &&
        !_didFinishStatsTutorial &&
        goalsTutorialSeen &&
        !statsTutorialSeen;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: isStatsTutorialPending,
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            context.t.statistics.statistics,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: context.appColors.foreground,
                              letterSpacing: -1.2,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.t.statistics.statisticsOverview,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.appColors.mutedForeground
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 24),

                          Container(
                            key: _goalDropdownKey,
                            child: _buildGoalDropdown(goals),
                          ),
                          const SizedBox(height: 16),

                          Container(key: _tabsKey, child: _buildTabs()),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _buildTabContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isStatsTutorialPending) _buildStatsTutorialOverlay(),
        ],
      ),
    );
  }

  Widget _buildGoalDropdown(List<Goal> goals) {
    String displayTitle = context.t.statistics.allHabits;
    Color displayColor = context.appColors.foreground;

    if (_selectedGoalId != null) {
      final match = goals.where((g) => g.id == _selectedGoalId).toList();
      if (match.isNotEmpty) {
        displayTitle = match.first.title;
        displayColor = match.first.color;
      }
    }

    final settings = ref.watch(settingsProvider);
    final isPro = settings.isPro;

    return GestureDetector(
      onTap: () {
        ref.hapticAction();
        _showGoalSelector(goals);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.appColors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.appColors.border.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: displayColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _selectedGoalId != null && !isPro
                    ? LucideIcons.lock
                    : LucideIcons.target,
                size: 16,
                color: displayColor,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              displayTitle,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: context.appColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
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
        children: _tabs.map((tab) {
          final isSelected = _selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  ref.hapticSelection();
                  setState(() => _selectedTab = tab);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
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
                  tStatTab(context, tab),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? context.appColors.background
                        : context.appColors.mutedForeground,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedGoalId == null) {
      switch (_selectedTab) {
        case 'Info':
          return const InfoTabWidget(key: ValueKey('Info'));
        case 'Trend':
          return const GlobalTrendTabWidget(key: ValueKey('GlobalTrend'));
        case 'Alert':
          return const GlobalAlertsTabWidget(key: ValueKey('GlobalAlert'));
        case 'Abitudini':
          return GlobalHabitsTabWidget(
            key: const ValueKey('GlobalHabits'),
            onGoalSelected: _selectGoal,
          );
        case 'Mood':
          return const GlobalMoodTabWidget(key: ValueKey('GlobalMood'));
        default:
          return Center(
            key: ValueKey(_selectedTab),
            child: Text(
              '${tStatTab(context, _selectedTab)} - ${context.t.statistics.comingSoon}',
              style: TextStyle(color: context.appColors.mutedForeground),
            ),
          );
      }
    } else {
      switch (_selectedTab) {
        case 'Info':
          return HabitOverviewTabWidget(
            key: ValueKey('Info_$_selectedGoalId'),
            goalId: _selectedGoalId!,
          );
        case 'Trend':
          return HabitCalendarioTabWidget(
            key: ValueKey('Trend_$_selectedGoalId'),
            goalId: _selectedGoalId!,
          );
        case 'Stats':
          return HabitPerformanceTabWidget(
            key: ValueKey('Stats_$_selectedGoalId'),
            goalId: _selectedGoalId!,
          );
        case 'Alert':
          return HabitMiglioramentoTabWidget(
            key: ValueKey('Alert_$_selectedGoalId'),
            goalId: _selectedGoalId!,
          );
        case 'Mood':
          return HabitMoodTabWidget(
            key: ValueKey('Mood_$_selectedGoalId'),
            goalId: _selectedGoalId!,
          );
        default:
          return Center(
            key: ValueKey('$_selectedTab$_selectedGoalId'),
            child: Text(
              '${tStatTab(context, _selectedTab)} - ${context.t.statistics.comingSoon}',
              style: TextStyle(color: context.appColors.mutedForeground),
            ),
          );
      }
    }
  }

  void _showGoalSelector(List<Goal> goals) {
    final settings = ref.read(settingsProvider);
    final isPro = settings.isPro;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t.statistics.selectHabit,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.mutedForeground,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: context.appColors.muted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      LucideIcons.list,
                      size: 14,
                      color: context.appColors.foreground,
                    ),
                  ),
                  title: Text(
                    context.t.statistics.allHabits,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.foreground,
                    ),
                  ),
                  trailing: _selectedGoalId == null
                      ? Icon(
                          LucideIcons.check,
                          color: context.appColors.foreground,
                        )
                      : null,
                  onTap: () {
                    _selectGoal(null);
                    Navigator.pop(context);
                  },
                ),
                ...goals.map((goal) {
                  return ListTile(
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: goal.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: goal.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      goal.title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isPro
                            ? context.appColors.foreground
                            : context.appColors.mutedForeground,
                      ),
                    ),
                    trailing: isPro
                        ? (_selectedGoalId == goal.id
                              ? Icon(
                                  LucideIcons.check,
                                  color: context.appColors.foreground,
                                )
                              : null)
                        : Icon(
                            LucideIcons.lock,
                            color: context.appColors.mutedForeground,
                            size: 14,
                          ),
                    onTap: () {
                      if (!isPro) {
                        Navigator.pop(context);
                        ref.hapticHeavy();
                        ProFeaturesModal.show(context).then((_) {
                          if (mounted) {
                            _selectGoal(null);
                          }
                        });
                      } else {
                        _selectGoal(goal.id);
                        Navigator.pop(context);
                      }
                    },
                  );
                }),
                const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatsTutorialStep {
  const _StatsTutorialStep({
    required this.targetKey,
    required this.title,
    required this.description,
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
}

class _StatsTutorialScrimPainter extends CustomPainter {
  const _StatsTutorialScrimPainter(this.targetRect);

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
  bool shouldRepaint(covariant _StatsTutorialScrimPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
