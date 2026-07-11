import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/goal_provider.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_segmented_control.dart';

class ViewTabBar extends ConsumerWidget {
  const ViewTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentView = ref.watch(calendarViewProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: EvolveSegmentedControl<CalendarView>(
        groupValue: currentView,
        segments: {
          CalendarView.month: context.t.common.calendarView.month,
          CalendarView.week: context.t.common.calendarView.week,
          CalendarView.year: context.t.common.calendarView.year,
          CalendarView.vita: context.t.common.calendarView.life,
        },
        onValueChanged: (view) =>
            ref.read(calendarViewProvider.notifier).setView(view),
      ),
    );
  }
}
