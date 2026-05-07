import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/goal_provider.dart';
import '../../core/haptics.dart';
import '../../core/localization.dart';

class ViewTabBar extends ConsumerWidget {
  const ViewTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentView = ref.watch(calendarViewProvider);

    final tabs = [
      _TabItem(view: CalendarView.month, label: context.l10n.translate('month')),
      _TabItem(view: CalendarView.week, label: context.l10n.translate('week')),
      _TabItem(view: CalendarView.year, label: context.l10n.translate('year')),
      _TabItem(view: CalendarView.vita, label: context.l10n.translate('life')),
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: tabs.map((tab) {
          final isActive = currentView == tab.view;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                ref.hapticSelection();
                ref.read(calendarViewProvider.notifier).setView(tab.view);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isActive
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
                  tab.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? context.appColors.background : context.appColors.mutedForeground,
                    letterSpacing: -0.2,
                  ),
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
  final String label;
  const _TabItem({required this.view, required this.label});
}
