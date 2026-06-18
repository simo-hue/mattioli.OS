import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../providers/tutorial_provider.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/haptics.dart';
import '../../core/localization.dart';
import '../../core/app_logger.dart';
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

  bool _tutorialTriggered = false;
  bool _isShowingStatsTutorial = false;
  bool _didFinishStatsTutorial = false;
  Timer? _statsTutorialStartTimer;
  TutorialCoachMark? _statsTutorial;

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeScheduleStatsTutorial();
      });
    }
    if (oldWidget.isActive && !widget.isActive) {
      _clearStatsTutorialState(removeOverlay: _isShowingStatsTutorial);
    }
  }

  @override
  void dispose() {
    _statsTutorialStartTimer?.cancel();
    _statsTutorial?.removeOverlayEntry();
    super.dispose();
  }

  bool _areStatsTutorialTargetsReady() {
    return [
      _goalDropdownKey,
      _tabsKey,
    ].every((key) => key.currentContext != null);
  }

  void _completeStatsTutorial() {
    unawaited(ref.read(statsTutorialProvider.notifier).setTutorialSeen(true));
  }

  void _clearStatsTutorialState({bool removeOverlay = false}) {
    _statsTutorialStartTimer?.cancel();
    if (removeOverlay) {
      _statsTutorial?.removeOverlayEntry();
    }
    _statsTutorial = null;
    _isShowingStatsTutorial = false;
  }

  void _finishStatsTutorial({bool showCompletionDialog = false}) {
    if (!mounted || _didFinishStatsTutorial) return;

    _didFinishStatsTutorial = true;
    _clearStatsTutorialState(removeOverlay: true);
    _completeStatsTutorial();

    if (!showCompletionDialog || widget.onFinishTutorial == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onFinishTutorial!();
    });
  }

  void _maybeScheduleStatsTutorial() {
    if (!widget.isActive || _tutorialTriggered || _isShowingStatsTutorial) {
      return;
    }

    final goalsTutorialSeen = ref.read(goalsTutorialProvider);
    final statsTutorialSeen = ref.read(statsTutorialProvider);
    if (!statsTutorialSeen) {
      _didFinishStatsTutorial = false;
    }
    if (!goalsTutorialSeen || statsTutorialSeen || _didFinishStatsTutorial) {
      return;
    }

    _tutorialTriggered = true;
    _statsTutorialStartTimer?.cancel();
    _statsTutorialStartTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || !widget.isActive) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.isActive &&
            ref.read(goalsTutorialProvider) &&
            !ref.read(statsTutorialProvider)) {
          _showStatsTutorial();
        }
      });
    });
  }

  void _showStatsTutorial() {
    if (!widget.isActive ||
        _isShowingStatsTutorial ||
        _didFinishStatsTutorial ||
        ref.read(statsTutorialProvider)) {
      return;
    }
    if (!_areStatsTutorialTargetsReady()) {
      AppLogger.warning(
        '[Tutorial] Stats tutorial targets are not ready; delaying start',
      );
      _tutorialTriggered = false;
      _maybeScheduleStatsTutorial();
      return;
    }

    final targets = [
      TargetFocus(
        identify: "Filtro Goal",
        keyTarget: _goalDropdownKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialContent(
              context.l10n.translate("Filtra per Abitudine"),
              context.l10n.translate(
                "Da qui puoi selezionare una specifica abitudine per vederne i dettagli, oppure 'Tutti gli Habits' per una panoramica globale.",
              ),
              controller,
              isFirst: true,
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "Tabs Statistiche",
        keyTarget: _tabsKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialContent(
              context.l10n.translate("Sezioni Statistiche"),
              context.l10n.translate(
                "Naviga tra le varie schede per vedere i Trend, gli Alert sulle performance, l'andamento delle Abitudini e il tuo Mood.",
              ),
              controller,
              isLast: true,
            ),
          ),
        ],
      ),
    ];

    final tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      hideSkip: true,
      paddingFocus: 10,
      opacityShadow: 0.85,
      focusAnimationDuration: const Duration(milliseconds: 400),
      unFocusAnimationDuration: Duration.zero,
      pulseEnable: false,
      onFinish: () {
        _finishStatsTutorial(showCompletionDialog: true);
      },
      onSkip: () {
        _finishStatsTutorial(showCompletionDialog: true);
        return true;
      },
    );

    _statsTutorial = tutorial;
    _isShowingStatsTutorial = true;
    try {
      tutorial.show(context: context);
    } catch (e, stack) {
      _clearStatsTutorialState();
      AppLogger.warning('[Tutorial] Unable to start stats tutorial', e, stack);
    }
  }

  Widget _buildTutorialContent(
    String title,
    String description,
    TutorialCoachMarkController controller, {
    bool isFirst = false,
    bool isLast = false,
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

    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
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
                          if (isLast) {
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
                          isLast
                              ? context.l10n.translate("Fine")
                              : context.l10n.translate("Avanti"),
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
    ref.watch(goalsTutorialProvider);
    ref.watch(statsTutorialProvider);

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
        _tutorialTriggered = false;
        if (_isShowingStatsTutorial) {
          _clearStatsTutorialState(removeOverlay: true);
        }
      }
    });

    _maybeScheduleStatsTutorial();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
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
                      context.l10n.translate('Statistiche'),
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
                      context.l10n.translate('Panoramica Statistiche'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.appColors.mutedForeground.withValues(
                          alpha: 0.7,
                        ),
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
    );
  }

  Widget _buildGoalDropdown(List<Goal> goals) {
    String displayTitle = context.l10n.translate('Tutti gli Habits');
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
                  context.l10n.translate(tab),
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
              '${context.l10n.translate(_selectedTab)} - ${context.l10n.translate('Coming Soon')}',
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
              '${context.l10n.translate(_selectedTab)} - ${context.l10n.translate('Coming Soon')}',
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.translate('SELEZIONA HABIT'),
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
                    context.l10n.translate('Tutti gli Habits'),
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
        );
      },
    );
  }
}
