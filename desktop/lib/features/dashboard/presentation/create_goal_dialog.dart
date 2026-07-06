import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/color_picker_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CreateGoalDialog extends ConsumerStatefulWidget {
  const CreateGoalDialog({super.key});

  @override
  ConsumerState<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends ConsumerState<CreateGoalDialog> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController(
    text: t.createGoal.defaultCategory,
  );
  // Mobile "Add Habit" preset palette (habit_management_modal.dart).
  static const _presetColors = [
    Color(0xFF30A661),
    Color(0xFF3B82F6),
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
  ];

  Color _selectedColor = EvolveColors.amber;
  GoalType _selectedType = GoalType.monthly;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  String _getDueLabelFor(GoalType type) {
    final now = DateTime.now();
    switch (type) {
      case GoalType.lifetime:
        return t.createGoal.dueLifetime;
      case GoalType.annual:
        return t.createGoal.dueByYear(year: now.year);
      case GoalType.quarterly:
        final q = (now.month / 3).ceil();
        return 'Q$q ${now.year}';
      case GoalType.monthly:
        return '${t.common.months[now.month - 1]} ${now.year}';
      case GoalType.weekly:
        return t.createGoal.thisWeek;
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isLoading = true);

    final now = DateTime.now();
    int? year = now.year;
    int? quarter;
    int? month;
    int? weekNumber;

    if (_selectedType == GoalType.quarterly) quarter = (now.month / 3).ceil();
    if (_selectedType == GoalType.monthly) month = now.month;
    if (_selectedType == GoalType.weekly) {
      month = now.month;
      weekNumber = logicalWeekOfMonth(now);
    }

    try {
      await ref
          .read(dashboardControllerProvider.notifier)
          .addGoal(
            title: title,
            category: _categoryController.text.trim(),
            color: _selectedColor,
            type: _selectedType,
            dueLabel: _getDueLabelFor(_selectedType),
            year: year,
            quarter: quarter,
            month: month,
            weekNumber: weekNumber,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      maxWidth: 480,
      icon: LucideIcons.trophy,
      title: Text(t.createGoal.title),
      subtitle: t.createGoal.subtitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(t.form.title),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(hintText: t.createGoal.titleHint),
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _FieldLabel(t.form.category),
          const SizedBox(height: 8),
          TextField(
            controller: _categoryController,
            decoration: InputDecoration(hintText: t.createGoal.categoryHint),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),
          _FieldLabel(t.createGoal.timeline),
          const SizedBox(height: 8),
          EvolveSelect<GoalType>(
            value: _selectedType,
            expand: true,
            height: 46,
            fillColor: context.evolveColors.background.withValues(alpha: 0.5),
            options: [
              EvolveSelectOption(
                value: GoalType.weekly,
                label: t.createGoal.thisWeek,
              ),
              EvolveSelectOption(
                value: GoalType.monthly,
                label: t.createGoal.thisMonth,
              ),
              EvolveSelectOption(
                value: GoalType.quarterly,
                label: t.createGoal.thisQuarter,
              ),
              EvolveSelectOption(
                value: GoalType.annual,
                label: t.createGoal.thisYear,
              ),
              EvolveSelectOption(
                value: GoalType.lifetime,
                label: t.createGoal.longTerm,
              ),
            ],
            onChanged: (val) => setState(() => _selectedType = val),
          ),
          const SizedBox(height: 20),
          _FieldLabel(t.form.color),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in _presetColors)
                GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == color
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: _selectedColor == color
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              CustomColorSwatch(
                initial: _selectedColor,
                isSelected: !_presetColors.contains(_selectedColor),
                onPicked: (color) => setState(() => _selectedColor = color),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(t.common.actions.cancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t.form.add),
        ),
      ],
    );
  }
}

/// Uppercase micro-label above a form field ("HABIT NAME" on mobile).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: context.evolveColors.muted,
        letterSpacing: 0.5,
      ),
    );
  }
}
