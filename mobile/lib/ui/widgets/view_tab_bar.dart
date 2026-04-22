import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/goal_provider.dart';

class ViewTabBar extends ConsumerWidget {
  const ViewTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentView = ref.watch(calendarViewProvider);

    final tabs = [
      _TabItem(view: CalendarView.month, icon: LucideIcons.calendar, label: 'Mese'),
      _TabItem(view: CalendarView.week, icon: LucideIcons.layoutGrid, label: 'Settimana'),
      _TabItem(view: CalendarView.year, icon: LucideIcons.listTodo, label: 'Anno'),
      _TabItem(view: CalendarView.vita, icon: LucideIcons.hourglass, label: 'Vita'),
    ];

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderHover, width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: tabs.map((tab) {
          final isActive = currentView == tab.view;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(calendarViewProvider.notifier).setView(tab.view),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab.icon,
                      size: 13,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.mutedForeground,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        tab.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.mutedForeground,
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
