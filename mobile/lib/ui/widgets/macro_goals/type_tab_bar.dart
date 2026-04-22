import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../models/macro_goal.dart';

class GoalTypeTabBar extends StatelessWidget {
  final GoalType selected;
  final ValueChanged<GoalType> onSelected;

  const GoalTypeTabBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const _tabs = [
    (type: GoalType.lifetime, label: 'Lifetime'),
    (type: GoalType.annual, label: 'Annuale'),
    (type: GoalType.quarterly, label: 'Trimestrale'),
    (type: GoalType.monthly, label: 'Mensile'),
    (type: GoalType.weekly, label: 'Settimanale'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: _tabs.map((tab) {
            final isActive = selected == tab.type;
            return GestureDetector(
              onTap: () {
                onSelected(tab.type);
                HapticFeedback.selectionClick();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.foreground.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: isActive
                      ? Border.all(
                          color: AppColors.foreground.withValues(alpha: 0.2),
                          width: 1,
                        )
                      : Border.all(color: Colors.transparent),
                ),
                child: Text(
                  tab.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? AppColors.foreground
                        : AppColors.mutedForeground,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
