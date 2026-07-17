import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../i18n/translations.g.dart';

/// A 7-across weekday multi-select for a habit's weekly schedule.
///
/// Values are ISO weekdays (1 = Monday … 7 = Sunday), always sorted; the row is
/// laid out Monday-first and follows the ambient [Directionality] (so it reads
/// right-to-left, Monday on the right, under Arabic). At least one day must stay
/// selected — tapping the last remaining day is a no-op — mirroring the desktop
/// picker (`create_habit_dialog._toggleDay`). `null`/all-7 is *not* represented
/// here; the caller collapses an all-7 selection to `null` via
/// [Goal.canonicalFrequencyDays] before persisting.
class EvolveWeekdaySelector extends ConsumerWidget {
  const EvolveWeekdaySelector({
    super.key,
    required this.selectedDays,
    required this.onChanged,
  });

  /// Currently selected ISO weekdays (1–7). Should be non-empty.
  final List<int> selectedDays;

  /// Emits the new selection (sorted, always ≥1 day) when a chip is toggled.
  final ValueChanged<List<int>> onChanged;

  void _toggle(WidgetRef ref, int day) {
    final next = [...selectedDays];
    if (next.contains(day)) {
      if (next.length <= 1) return; // keep at least one day scheduled
      next.remove(day);
    } else {
      next.add(day);
    }
    next.sort();
    ref.hapticLight();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = context.t.common.weekdayInitials;
    // Full names for the accessibility label, indexed Monday-first.
    final names = [
      context.t.common.weekdays.monday,
      context.t.common.weekdays.tuesday,
      context.t.common.weekdays.wednesday,
      context.t.common.weekdays.thursday,
      context.t.common.weekdays.friday,
      context.t.common.weekdays.saturday,
      context.t.common.weekdays.sunday,
    ];
    final accent = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final day = index + 1; // 1 = Monday … 7 = Sunday
        final isSelected = selectedDays.contains(day);
        return Semantics(
          button: true,
          selected: isSelected,
          label: names[index],
          child: InkWell(
            onTap: () => _toggle(ref, day),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent
                    : context.appColors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : context.appColors.border,
                ),
              ),
              child: Text(
                initials[index],
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (accent.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white)
                      : context.appColors.mutedForeground,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
