import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/goal_provider.dart';
import '../widgets/statistics/info_tab_widget.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  String _selectedTab = 'Info';
  final List<String> _tabs = ['Info', 'Trend', 'Alert', 'Abitudini', 'Mood'];
  String? _selectedGoalId;

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

  Widget _buildGoalDropdown(List goals) {
    return GestureDetector(
      onTap: () {
        // Here we will show the custom bottom sheet for goal selection
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
              _selectedGoalId == null ? 'Tutti i Goals' : goals.firstWhere((g) => g.id == _selectedGoalId, orElse: () => goals.first).title,
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
    switch (_selectedTab) {
      case 'Info':
        return const InfoTabWidget(key: ValueKey('Info'));
      default:
        return Center(
          key: ValueKey(_selectedTab),
          child: Text('$_selectedTab - Coming Soon', style: const TextStyle(color: AppColors.mutedForeground)),
        );
    }
  }
}
