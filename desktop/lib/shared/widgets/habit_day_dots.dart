import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';

/// The rolling strip of habit-day marks: the last N calendar days, oldest →
/// newest, with **today as the final mark**.
///
/// Both desktop surfaces that show a week of a habit at a glance (the
/// dashboard's "Today's protocol" row and the Habits › Protocol table) render
/// this. They previously each looped over `DashboardHabit.weeklyProgress`, a
/// Mon..Sun grid — so today was the last mark only on Sundays, and the user
/// could not see the day they were living in at the end of the strip. The grid
/// keeps its weekday meaning (statistics ask "how are Mondays going?"); the
/// window is resolved per-render by `DashboardSnapshot.habitWindowStatuses`,
/// which is also what makes the strip correct again after midnight without a
/// refresh.
///
/// The widget is deliberately dumb: it paints [statuses] and never resolves
/// them. That is what lets the Habits tour hand it a literal pattern for its
/// demo row, which owns no logs.
class HabitDayDots extends StatelessWidget {
  const HabitDayDots({
    super.key,
    required this.statuses,
    required this.dates,
    required this.accent,
    required this.size,
    required this.gap,
    required this.borderRadius,
  }) : assert(
         statuses.length == dates.length,
         'Every mark must know its own day: a status without its date would '
         'label the strip with days it is not colouring.',
       );

  /// One `goal_logs` status per day — `'done'`, `'missed'`, or null for a day
  /// with no record. Oldest first; the LAST entry is today.
  final List<String?> statuses;

  /// The days [statuses] describes, index-aligned, for the per-mark tooltip.
  final List<DateTime> dates;

  /// Fill for a completed day — the habit's own colour, so a row stays
  /// identifiable at a glance. Callers pass it pre-alphaed if their surface
  /// wants a softer mark.
  final Color accent;

  final double size;

  /// Space BETWEEN marks (no outer margin). It belongs to the hit test, so the
  /// hover target for an 8 px dot is comfortably larger than 8 px.
  final double gap;

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < statuses.length; index++)
          // Swallows the tap so it cannot reach the row's own InkWell: the
          // marks are history, and a click on Wednesday's mark used to toggle
          // TODAY. Hover still passes through, so the tooltip works.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Tooltip(
              message: _tooltip(index),
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: index == 0 ? 0 : gap),
                child: _mark(
                  status: statuses[index],
                  isToday: index == statuses.length - 1,
                  colors: colors,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// One day's mark. Today's is haloed rather than bordered: a border is drawn
  /// INSIDE the box, so on an 8 px mark it eats an eighth of the fill and — with
  /// `borderStrong` (#3F3F46) darker than any filled state — the eye reads
  /// "today's dot is smaller", not "today's dot is ringed".
  Widget _mark({
    required String? status,
    required bool isToday,
    required EvolvePalette colors,
  }) {
    final fill = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: switch (status) {
          'done' => accent,
          // An explicit "no" is a contribution too: without this it was
          // pixel-identical to a day never touched.
          'missed' => EvolveColors.destructive,
          _ => colors.panelSoft,
        },
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
    if (!isToday) return fill;

    // Neutral, so it says "this one is now" in every state instead of competing
    // with the habit's colour on a completed day.
    return Container(
      width: size + 4,
      height: size + 4,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderStrong),
        borderRadius: BorderRadius.circular(borderRadius + 2),
      ),
      child: fill,
    );
  }

  String _tooltip(int index) {
    final status = habitStatusLabel(statuses[index]);
    if (index == statuses.length - 1) {
      return t.habitsPage.dayDotTooltipToday(status: status);
    }
    final date = dates[index];
    return t.habitsPage.dayDotTooltip(
      day: date.day,
      month: t.common.months[date.month - 1],
      status: status,
    );
  }
}

/// The user-facing name of a `goal_logs` status, absence included.
String habitStatusLabel(String? status) => switch (status) {
  'done' => t.habitsPage.statusDone,
  'missed' => t.habitsPage.statusSkipped,
  _ => t.habitsPage.statusUnrecorded,
};
