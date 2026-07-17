import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';

/// A 7-across weekday multi-select for a habit's weekly schedule.
///
/// Values are ISO weekdays (1 = Monday … 7 = Sunday), always sorted; the row is
/// laid out Monday-first and follows the ambient [Directionality] (so it reads
/// right-to-left, Monday on the right, under Arabic). At least one day must stay
/// selected — tapping the last remaining day is a no-op. `null`/all-7 is not
/// represented here; the caller collapses an all-7 selection to `null` before
/// persisting (see `DashboardController._canonicalFrequencyDays`).
class EvolveWeekdaySelector extends StatelessWidget {
  const EvolveWeekdaySelector({
    super.key,
    required this.selectedDays,
    required this.onChanged,
  });

  /// Currently selected ISO weekdays (1–7). Should be non-empty.
  final List<int> selectedDays;

  /// Emits the new selection (sorted, always ≥1 day) when a chip is toggled.
  final ValueChanged<List<int>> onChanged;

  void _toggle(int day) {
    final next = [...selectedDays];
    if (next.contains(day)) {
      if (next.length <= 1) return; // keep at least one day scheduled
      next.remove(day);
    } else {
      next.add(day);
    }
    next.sort();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final initials = t.common.weekdayInitials;
    final names = t.common.weekdaysLong; // Monday-first full names for a11y

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
            onTap: () => _toggle(day),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.evolveAccent
                    : context.evolveColors.panel.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : context.evolveColors.border.withValues(alpha: 0.5),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                initials[index],
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : context.evolveColors.muted,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
