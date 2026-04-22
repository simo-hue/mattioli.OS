import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../widgets/statistics/info_tab_widget.dart';
import '../widgets/statistics/habit_overview_tab_widget.dart';
import '../widgets/statistics/habit_calendario_tab_widget.dart';
import '../widgets/statistics/habit_performance_tab_widget.dart';
import '../widgets/statistics/habit_miglioramento_tab_widget.dart';
import '../widgets/statistics/habit_mood_tab_widget.dart';

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
      if (goalId == null) {
        _tabs = ['Info', 'Trend', 'Alert', 'Abitudini', 'Mood'];
        _selectedTab = 'Info';
      } else {
        _tabs = ['Overview', 'Calendario', 'Performance', 'Miglioramento', 'Mood'];
        _selectedTab = 'Overview';
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
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Le tue Statistiche',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Analisi dettagliata delle tue performance.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildGoalDropdown(goals),
                    const SizedBox(height: 16),

                    _buildTabs(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
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
    if (_selectedGoalId != null) {
      final match = goals.where((g) => g.id == _selectedGoalId).toList();
      if (match.isNotEmpty) {
        displayTitle = match.first.title;
      } else if (goals.isNotEmpty) {
        displayTitle = goals.first.title;
      }
    }

    return GestureDetector(
      onTap: () {
        _showGoalSelector(goals);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.target, size: 18, color: AppColors.foreground),
            const SizedBox(width: 10),
            Text(
              displayTitle,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
            const Spacer(),
            const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: _tabs.map((tab) {
          final isSelected = _selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = tab),
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.muted : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                margin: const EdgeInsets.all(2),
                alignment: Alignment.center,
                child: Text(
                  tab,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.foreground : AppColors.mutedForeground,
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
        default:
          return Center(
            key: ValueKey(_selectedTab),
            child: Text('$_selectedTab - Coming Soon', style: const TextStyle(color: AppColors.mutedForeground)),
          );
      }
    } else {
      switch (_selectedTab) {
        case 'Overview':
          return HabitOverviewTabWidget(
            key: ValueKey('Overview_$_selectedGoalId'),
            goalId: _selectedGoalId!,
          );
        case 'Calendario':
          return HabitCalendarioTabWidget(
            key: ValueKey('Calendario_$_selectedGoalId'),
            goalId: _selectedGoalId!,
          );
        case 'Performance':
          return HabitPerformanceTabWidget(
            key: ValueKey('Performance_$_selectedGoalId'),
            goalId: _selectedGoalId!,
          );
        case 'Miglioramento':
          return HabitMiglioramentoTabWidget(
            key: ValueKey('Miglioramento_$_selectedGoalId'),
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
                  'Seleziona Habit',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
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
