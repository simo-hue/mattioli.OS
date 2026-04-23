import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme.dart';

class GlobalHabitsTabWidget extends StatefulWidget {
  const GlobalHabitsTabWidget({super.key});

  @override
  State<GlobalHabitsTabWidget> createState() => _GlobalHabitsTabWidgetState();
}

class _GlobalHabitsTabWidgetState extends State<GlobalHabitsTabWidget> {
  String _sortBy = 'Rate';

  final List<Map<String, dynamic>> _habits = [
    {
      'name': 'Caviglie',
      'color': const Color(0xFF64748B),
      'best': 9,
      'worst': 1,
      'serie': 4,
      'rate': 87,
    },
    {
      'name': '1 YT-Video',
      'color': const Color(0xFFEF4444),
      'best': 28,
      'worst': 8,
      'serie': 3,
      'rate': 77,
    },
    {
      'name': 'Fitness',
      'color': const Color(0xFF78350F),
      'best': 12,
      'worst': 3,
      'serie': 8,
      'rate': 73,
    },
    {
      'name': 'No Fap',
      'color': const Color(0xFF06B6D4),
      'best': 12,
      'worst': 5,
      'serie': 6,
      'rate': 73,
    },
    {
      'name': 'Alimentazione',
      'color': const Color(0xFF10B981),
      'best': 15,
      'worst': 4,
      'serie': 2,
      'rate': 68,
    },
    {
      'name': 'Lettura',
      'color': const Color(0xFF8B5CF6),
      'best': 10,
      'worst': 6,
      'serie': 0,
      'rate': 62,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Dettagli Abitudini',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
            _buildSortDropdown(),
          ],
        ),
        const SizedBox(height: 20),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _habits.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _HabitDetailCard(habit: _habits[index]);
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSortDropdown() {
    return PopupMenuButton<String>(
      initialValue: _sortBy,
      onSelected: (String value) {
        setState(() => _sortBy = value);
      },
      offset: const Offset(0, 44),
      color: Colors.black, // Pure black for maximum contrast and professionalism
      elevation: 8,

      shadowColor: Colors.black.withValues(alpha: 0.5),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),



      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20), // More rounded
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getSortIcon(_sortBy), size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              _sortBy,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronDown, size: 12, color: AppColors.mutedForeground.withValues(alpha: 0.5)),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        _buildPopupItem('Rate', LucideIcons.trendingUp),
        _buildPopupItem('Best Streak', LucideIcons.trophy),
        _buildPopupItem('Worst Streak', LucideIcons.trendingDown),
        _buildPopupItem('Serie Attuale', LucideIcons.flame),
        _buildPopupItem('Nome', LucideIcons.list),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon) {
    final isSelected = _sortBy == value;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return PopupMenuItem<String>(
      value: value,
      padding: EdgeInsets.zero,
      height: 58, // Slightly taller for more presence
      child: Theme(
        data: Theme.of(context).copyWith(
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Stack(

        children: [
          // Content without background box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.transparent, // Fully transparent background
            ),

            child: Row(
              children: [
                // Icon with Glow
                Container(
                  decoration: BoxDecoration(
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? primaryColor : AppColors.mutedForeground.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.mutedForeground,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                // Selection Indicator (Minimalist Dot or Check)
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Left Accent Bar
          if (isSelected)
            Positioned(
              left: 6,
              top: 14,
              bottom: 14,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }





  IconData _getSortIcon(String sort) {
    switch (sort) {
      case 'Rate': return LucideIcons.trendingUp;
      case 'Best Streak': return LucideIcons.trophy;
      case 'Worst Streak': return LucideIcons.trendingDown;
      case 'Serie Attuale': return LucideIcons.flame;
      case 'Nome': return LucideIcons.list;
      default: return LucideIcons.trendingUp;
    }
  }
}

class _HabitDetailCard extends StatelessWidget {
  final Map<String, dynamic> habit;

  const _HabitDetailCard({required this.habit});

  @override
  Widget build(BuildContext context) {
    final Color habitColor = habit['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          // Habit Icon/Dot
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: habitColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: habitColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Name and small progress bar
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit['name'] as String,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),

                const SizedBox(height: 6),
                Container(
                  width: 60,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (habit['rate'] as int) / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: habitColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Stats
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatColumn('BEST', '${habit['best']}gg', icon: LucideIcons.trophy, iconColor: const Color(0xFFEAB308)),
                _buildStatColumn('WORST', '${habit['worst']}gg', icon: LucideIcons.trendingDown, iconColor: const Color(0xFFEF4444)),
                _buildStatColumn('SERIE', '${habit['serie']}gg'),
                _buildStatColumn('RATE', '${habit['rate']}%', isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, {IconData? icon, Color? iconColor, bool isBold = false}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 10, color: iconColor ?? AppColors.mutedForeground),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: label == 'WORST' ? const Color(0xFFEF4444) : AppColors.foreground,
          ),
        ),
      ],
    );
  }
}
