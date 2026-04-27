import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme.dart';
import '../../../models/macro_goal.dart';
import '../../../providers/macro_goals_provider.dart';

class AddGoalBar extends ConsumerStatefulWidget {
  final MacroGoalsViewState viewState;

  const AddGoalBar({super.key, required this.viewState});

  @override
  ConsumerState<AddGoalBar> createState() => _AddGoalBarState();
}

class _AddGoalBarState extends ConsumerState<AddGoalBar> {
  final _controller = TextEditingController();
  String? _selectedCategory;

  String get _placeholder {
    switch (widget.viewState.selectedType) {
      case GoalType.lifetime:
        return 'Aggiungi obiettivo lifetime...';
      case GoalType.annual:
        return 'Aggiungi obiettivo annuale...';
      case GoalType.quarterly:
        return 'Aggiungi obiettivo trimestrale...';
      case GoalType.monthly:
        return 'Aggiungi obiettivo mensile...';
      case GoalType.weekly:
        return 'Aggiungi obiettivo settimanale...';
    }
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final vs = widget.viewState;
    final id = '${vs.selectedType.name}-${DateTime.now().millisecondsSinceEpoch}';

    final goal = MacroGoal(
      id: id,
      title: title,
      status: GoalStatus.active,
      type: vs.selectedType,
      year: vs.selectedType == GoalType.lifetime ? null : vs.selectedYear,
      quarter: vs.selectedType == GoalType.quarterly ? vs.selectedQuarter : null,
      month: (vs.selectedType == GoalType.monthly ||
              vs.selectedType == GoalType.weekly)
          ? vs.selectedMonth
          : null,
      weekNumber:
          vs.selectedType == GoalType.weekly ? vs.selectedWeek : null,
      categoryKey: _selectedCategory,
      createdAt: DateTime.now(),
    );

    ref.read(macroGoalsProvider.notifier).addGoal(goal);
    _controller.clear();
    setState(() => _selectedCategory = null);
    HapticFeedback.mediumImpact();
  }

  void _showCategoryPicker() {
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
              const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Scegli categoria',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              // No category option
              ListTile(
                leading: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.borderActive, width: 1.5),
                  ),
                ),
                title: Text(
                  'Nessuna categoria',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
                trailing: _selectedCategory == null
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary, size: 18)
                    : null,
                onTap: () {
                  setState(() => _selectedCategory = null);
                  Navigator.pop(context);
                },
              ),
              ...kDefaultCategories.map((cat) => ListTile(
                    leading: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: cat.color.withValues(alpha: 0.6),
                            width: 1.5),
                      ),
                    ),
                    title: Text(
                      cat.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.foreground,
                        fontWeight: _selectedCategory == cat.key
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: _selectedCategory == cat.key
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary, size: 18)
                        : null,
                    onTap: () {
                      setState(() => _selectedCategory = cat.key);
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catColor = categoryColor(_selectedCategory);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // ── Text field ─────────────────────────────────────────────────
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.card.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderHover, width: 1),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.foreground,
                ),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                  hintText: _placeholder,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Category color pill ─────────────────────────────────────────
          GestureDetector(
            onTap: _showCategoryPicker,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.card.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderHover, width: 1),
              ),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: catColor?.withValues(alpha: 0.7) ??
                        Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: catColor?.withValues(alpha: 0.9) ??
                          AppColors.borderActive,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Submit button ───────────────────────────────────────────────
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.plus,
                color: AppColors.background,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
