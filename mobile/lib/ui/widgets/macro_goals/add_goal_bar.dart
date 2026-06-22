import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme.dart';
import '../../../models/macro_goal.dart';
import '../../../providers/macro_goals_provider.dart';
import '../../../providers/macro_goal_categories_provider.dart';
import '../../../providers/settings_provider.dart';
import 'category_picker_sheet.dart';
import '../pro_features_modal.dart';
import '../../../i18n/translations.g.dart';

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
        return context.t.macroGoals.addLifetimeGoal;
      case GoalType.annual:
        return context.t.macroGoals.addAnnualGoal;
      case GoalType.quarterly:
        return context.t.macroGoals.addQuarterlyGoal;
      case GoalType.monthly:
        return context.t.macroGoals.addMonthlyGoal;
      case GoalType.weekly:
        return context.t.macroGoals.addWeeklyGoal;
    }
  }

  void _submit() {
    final settings = ref.read(settingsProvider);
    final isPro = settings.isPro;
    final currentGoalsCount = ref.read(macroGoalsProvider).goals.length;

    if (!isPro && currentGoalsCount >= 100) {
      FocusScope.of(context).unfocus();
      HapticFeedback.heavyImpact();
      ProFeaturesModal.show(context);
      return;
    }

    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final vs = widget.viewState;
    final id =
        '${vs.selectedType.name}-${DateTime.now().millisecondsSinceEpoch}';

    final goal = MacroGoal(
      id: id,
      title: title,
      status: GoalStatus.active,
      type: vs.selectedType,
      year: vs.selectedType == GoalType.lifetime ? null : vs.selectedYear,
      quarter: vs.selectedType == GoalType.quarterly
          ? vs.selectedQuarter
          : null,
      month:
          (vs.selectedType == GoalType.monthly ||
              vs.selectedType == GoalType.weekly)
          ? vs.selectedMonth
          : null,
      weekNumber: vs.selectedType == GoalType.weekly ? vs.selectedWeek : null,
      categoryId: _selectedCategory,
      createdAt: DateTime.now(),
    );

    ref.read(macroGoalsProvider.notifier).addGoal(goal);
    _controller.clear();
    setState(() => _selectedCategory = null);
    HapticFeedback.mediumImpact();
  }

  void _showCategoryPicker() {
    showMacroGoalCategoryPicker(
      context: context,
      ref: ref,
      title: context.t.macroGoals.chooseCategory,
      noneLabel: 'Default',
      noneSelected: _selectedCategory == null,
      selectedCategoryId: _selectedCategory,
      clearSelectionOnArchive: true,
      onSelected: (categoryId) {
        setState(() => _selectedCategory = categoryId);
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
    // Watch categories to ensure they are fetched
    final categoriesAsync = ref.watch(macroGoalCategoriesProvider);
    final categories = categoriesAsync.value ?? [];

    // Find selected category to get color
    Color? catColor;
    if (_selectedCategory != null) {
      try {
        catColor = categories
            .firstWhere((c) => c.key == _selectedCategory)
            .color;
      } catch (_) {
        catColor = categoryColor(_selectedCategory); // Fallback to default
      }
    }

    final settings = ref.watch(settingsProvider);
    final isPro = settings.isPro;
    final currentGoalsCount = ref.watch(macroGoalsProvider).goals.length;
    final isLimitReached = !isPro && currentGoalsCount >= 100;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // ── Text field ─────────────────────────────────────────────────
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: context.appColors.card.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appColors.border, width: 1),
              ),
              child: TextField(
                controller: _controller,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.appColors.foreground,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                  hintText: isLimitReached
                      ? context.t.macroGoals.limitOf100GoalsReached
                      : _placeholder,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: isLimitReached
                        ? const Color(0xFFEAB308)
                        : context.appColors.mutedForeground,
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
                color: context.appColors.card.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.appColors.border, width: 1),
              ),
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color:
                        catColor?.withValues(alpha: 0.7) ?? Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          catColor?.withValues(alpha: 0.9) ??
                          context.appColors.border,
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
                color: isLimitReached
                    ? const Color(0xFFEAB308)
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isLimitReached ? LucideIcons.sparkles : LucideIcons.plus,
                color: isLimitReached
                    ? Colors.black
                    : context.appColors.background,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
