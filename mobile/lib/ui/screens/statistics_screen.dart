import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../providers/tutorial_provider.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../core/haptics.dart';
import '../../core/localization.dart';
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
  final VoidCallback? onFinishTutorial;
  const StatisticsScreen({super.key, this.onFinishTutorial});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with AutomaticKeepAliveClientMixin {
  String _selectedTab = 'Info';
  List<String> _tabs = [
    'Info',
    'Trend',
    'Alert',
    'Abitudini',
    'Mood'
  ];
  String? _selectedGoalId;

  final GlobalKey _goalDropdownKey = GlobalKey();
  final GlobalKey _tabsKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  bool _tutorialTriggered = false;

  @override
  void initState() {
    super.initState();
  }

  void _showStatsTutorial() {
    final targets = [
      TargetFocus(
        identify: "Filtro Goal",
        keyTarget: _goalDropdownKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialContent("Filtra per Habit", "Da qui puoi selezionare una specifica abitudine per vederne i dettagli, oppure 'Tutti gli Habits' per una panoramica globale.", controller),
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
            builder: (context, controller) => _buildTutorialContent("Sezioni Statistiche", "Naviga tra le varie schede per vedere i Trend, gli Alert sulle performance, l'andamento delle Abitudini e il tuo Mood.", controller, isLast: true),
          ),
        ],
      ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      hideSkip: true,
      paddingFocus: 10,
      opacityShadow: 0.85,
      focusAnimationDuration: const Duration(milliseconds: 400),
      unFocusAnimationDuration: Duration.zero,
      pulseEnable: false,
      onFinish: () {
        ref.read(statsTutorialProvider.notifier).setTutorialSeen(true);
        if (widget.onFinishTutorial != null) {
          widget.onFinishTutorial!();
        }
      },
    ).show(context: context);
  }

  Widget _buildTutorialContent(String title, String desc, TutorialCoachMarkController controller, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.appColors.foreground,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.appColors.mutedForeground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => controller.next(),
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: context.appColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isLast ? 'Fine' : 'Avanti',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _selectGoal(String? goalId) {
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

    ref.listen(statsTutorialProvider, (previous, next) {
      if (next == false) {
        _tutorialTriggered = false;
      }
    });

    if (goalsTutorialSeen && !statsTutorialSeen && !_tutorialTriggered) {
      _tutorialTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _showStatsTutorial();
          }
        });
      });
    }

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
                        color: context.appColors.mutedForeground.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),


                    Container(key: _goalDropdownKey, child: _buildGoalDropdown(goals)),
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
          border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1),
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
              child: Icon(LucideIcons.target, size: 16, color: displayColor),
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
            Icon(LucideIcons.chevronDown, size: 16, color: context.appColors.mutedForeground),
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
        border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1),
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
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
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
                    color: isSelected ? context.appColors.background : context.appColors.mutedForeground,
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
          return const GlobalHabitsTabWidget(key: ValueKey('GlobalHabits'));
        case 'Mood':
          return const GlobalMoodTabWidget(key: ValueKey('GlobalMood'));
        default:
          return Center(
            key: ValueKey(_selectedTab),
            child: Text('${context.l10n.translate(_selectedTab)} - Coming Soon', style: TextStyle(color: context.appColors.mutedForeground)),
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
            child: Text('${context.l10n.translate(_selectedTab)} - Coming Soon', style: TextStyle(color: context.appColors.mutedForeground)),
          );
      }
    }
  }

  void _showGoalSelector(List<Goal> goals) {
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
                    child: Icon(LucideIcons.list, size: 14, color: context.appColors.foreground),
                  ),
                  title: Text(context.l10n.translate('Tutti gli Habits'), style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600, color: context.appColors.foreground)),
                  trailing: _selectedGoalId == null ? Icon(LucideIcons.check, color: context.appColors.foreground) : null,
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
                    title: Text(goal.title, style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w500, color: context.appColors.foreground)),
                    trailing: _selectedGoalId == goal.id ? Icon(LucideIcons.check, color: context.appColors.foreground) : null,
                    onTap: () {
                      _selectGoal(goal.id);
                      Navigator.pop(context);
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
