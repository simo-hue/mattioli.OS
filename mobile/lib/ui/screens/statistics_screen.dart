import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
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
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  String _selectedTab = 'Info';
  List<String> _tabs = ['Info', 'Trend', 'Alert', 'Abitudini', 'Mood'];
  String? _selectedGoalId;

  void _selectGoal(String? goalId) {
    setState(() {
      _selectedGoalId = goalId;
      if (_selectedGoalId == null) {
        _tabs = ['Info', 'Trend', 'Alert', 'Habit', 'Mood'];
        _selectedTab = 'Info';
      } else {
        _tabs = ['Info', 'Trend', 'Stats', 'Alert', 'Mood'];
        _selectedTab = 'Info';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);

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
                    const Text(
                      'Statistiche',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.foreground,
                        letterSpacing: -1.2,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Analisi dettagliata delle tue performance.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedForeground.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),


                    _buildGoalDropdown(goals),
                    const SizedBox(height: 16),

                    _buildTabs(),
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
    String displayTitle = 'Tutti gli Habits';
    Color displayColor = AppColors.foreground;
    
    if (_selectedGoalId != null) {
      final match = goals.where((g) => g.id == _selectedGoalId).toList();
      if (match.isNotEmpty) {
        displayTitle = match.first.title;
        displayColor = match.first.color;
      }
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showGoalSelector(goals);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
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
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.mutedForeground),
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
        color: AppColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        children: _tabs.map((tab) {
          final isSelected = _selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = tab);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.foreground : Colors.transparent,
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
                  tab,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.background : AppColors.mutedForeground,
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
            child: Text('$_selectedTab - Coming Soon', style: const TextStyle(color: AppColors.mutedForeground)),
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
        case '✨ Mood':
          return HabitMoodTabWidget(
            key: ValueKey('Mood_$_selectedGoalId'),
            goalId: _selectedGoalId!,
          );
        default:
          return Center(
            key: ValueKey('$_selectedTab$_selectedGoalId'),
            child: Text('$_selectedTab - Coming Soon', style: const TextStyle(color: AppColors.mutedForeground)),
          );
      }
    }
  }

  void _showGoalSelector(List<Goal> goals) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
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
                const Text(
                  'SELEZIONA HABIT',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mutedForeground,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(LucideIcons.list, size: 14, color: AppColors.foreground),
                  ),
                  title: const Text('Tutti gli Habits', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground)),
                  trailing: _selectedGoalId == null ? const Icon(LucideIcons.check, color: AppColors.foreground) : null,
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
                    title: Text(goal.title, style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                    trailing: _selectedGoalId == goal.id ? const Icon(LucideIcons.check, color: AppColors.foreground) : null,
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
