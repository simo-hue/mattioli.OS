import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/goal_provider.dart';

class ViewTabBar extends ConsumerWidget {
  const ViewTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentView = ref.watch(calendarViewProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    final tabs = [
      _TabItem(view: CalendarView.month, icon: LucideIcons.calendar, label: 'Mese'),
      _TabItem(view: CalendarView.week, icon: LucideIcons.layoutGrid, label: 'Settimana'),
      _TabItem(view: CalendarView.year, icon: LucideIcons.listTodo, label: 'Anno'),
      _TabItem(view: CalendarView.vita, icon: LucideIcons.hourglass, label: 'Vita'),
    ];

    return Container(
      height: 52,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: tabs.map((tab) {
          final isActive = currentView == tab.view;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(calendarViewProvider.notifier).setView(tab.view);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: isActive
                      ? primaryColor.withValues(alpha: 0.9)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab.icon,
                      size: 14,
                      color: isActive
                          ? AppColors.background
                          : AppColors.mutedForeground,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tab.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? AppColors.background
                              : AppColors.mutedForeground,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TabItem {
  final CalendarView view;
  final IconData icon;
  final String label;
  const _TabItem({required this.view, required this.icon, required this.label});
}
