import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme.dart';
import '../../../models/macro_goal.dart';
import '../../../providers/macro_goals_provider.dart';

class PeriodSelectorBar extends ConsumerWidget {
  final MacroGoalsViewState viewState;

  const PeriodSelectorBar({super.key, required this.viewState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = viewState.selectedType;
    if (type == GoalType.lifetime) return const SizedBox.shrink();

    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    final years = List.generate(10, (i) => currentYear - 3 + i);

    final months = [
      (v: 1, l: 'Gennaio'), (v: 2, l: 'Febbraio'), (v: 3, l: 'Marzo'),
      (v: 4, l: 'Aprile'), (v: 5, l: 'Maggio'), (v: 6, l: 'Giugno'),
      (v: 7, l: 'Luglio'), (v: 8, l: 'Agosto'), (v: 9, l: 'Settembre'),
      (v: 10, l: 'Ottobre'), (v: 11, l: 'Novembre'), (v: 12, l: 'Dicembre'),
    ];

    final quarters = [
      (v: 1, l: 'Q1 (Gen–Mar)'),
      (v: 2, l: 'Q2 (Apr–Giu)'),
      (v: 3, l: 'Q3 (Lug–Set)'),
      (v: 4, l: 'Q4 (Ott–Dic)'),
    ];

    final numWeeks = weeksInMonth(viewState.selectedYear, viewState.selectedMonth);
    final weeks = List.generate(numWeeks, (i) => i + 1);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // ── Year picker ──────────────────────────────────────────────────
          _PillSelector<int>(
            label: '${viewState.selectedYear}',
            icon: LucideIcons.calendar,
            items: years,
            selected: viewState.selectedYear,
            labelBuilder: (y) => '$y',
            onSelected: (y) {
              ref.read(macroGoalsViewProvider.notifier).setYear(y);
              HapticFeedback.selectionClick();
            },
          ),
          const SizedBox(width: 8),

          // ── Quarter picker ───────────────────────────────────────────────
          if (type == GoalType.quarterly) ...[
            _PillSelector<int>(
              label: quarters
                  .firstWhere((q) => q.v == viewState.selectedQuarter,
                      orElse: () => quarters.first)
                  .l,
              icon: LucideIcons.calendarDays,
              items: quarters.map((q) => q.v).toList(),
              selected: viewState.selectedQuarter,
              labelBuilder: (v) =>
                  quarters.firstWhere((q) => q.v == v).l,
              onSelected: (q) {
                ref.read(macroGoalsViewProvider.notifier).setQuarter(q);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(width: 8),
          ],

          // ── Month picker ─────────────────────────────────────────────────
          if (type == GoalType.monthly || type == GoalType.weekly) ...[
            _PillSelector<int>(
              label: months
                  .firstWhere((m) => m.v == viewState.selectedMonth,
                      orElse: () => months.first)
                  .l,
              icon: LucideIcons.calendarDays,
              items: months.map((m) => m.v).toList(),
              selected: viewState.selectedMonth,
              labelBuilder: (v) =>
                  months.firstWhere((m) => m.v == v).l,
              onSelected: (m) {
                ref.read(macroGoalsViewProvider.notifier).setMonth(m);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(width: 8),
          ],

          // ── Week picker ──────────────────────────────────────────────────
          if (type == GoalType.weekly) ...[
            _PillSelector<int>(
              label: 'Settimana ${viewState.selectedWeek}',
              icon: LucideIcons.calendarRange,
              items: weeks,
              selected: viewState.selectedWeek,
              labelBuilder: (w) => 'Settimana $w',
              onSelected: (w) {
                ref.read(macroGoalsViewProvider.notifier).setWeek(w);
                HapticFeedback.selectionClick();
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Generic pill dropdown ────────────────────────────────────────────────────

class _PillSelector<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<T> items;
  final T selected;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onSelected;

  const _PillSelector({
    required this.label,
    required this.icon,
    required this.items,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderHover, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 13,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderActive,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = item == selected;
                    return ListTile(
                      onTap: () {
                        onSelected(item);
                        Navigator.pop(context);
                      },
                      title: Text(
                        labelBuilder(item),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isSelected
                              ? AppColors.foreground
                              : AppColors.mutedForeground,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check,
                              color: Color(0xFF34D399), size: 18)
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
