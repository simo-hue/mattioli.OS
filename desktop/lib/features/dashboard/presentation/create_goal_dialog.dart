import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/color_picker_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Color _selectedColor = EvolveColors.amber;
  GoalType _selectedType = GoalType.monthly;
  bool _isLoading = false;

  final List<Color> _colors = [
    EvolveColors.cyan,
    EvolveColors.violet,
    EvolveColors.amber,
    EvolveColors.rose,
  ];

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
      icon: Icons.emoji_events_outlined,
      title: Text(t.createGoal.title),
      subtitle: t.createGoal.subtitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: t.form.title,
              hintText: t.createGoal.titleHint,
            ),
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _categoryController,
            decoration: InputDecoration(
              labelText: t.form.category,
              hintText: t.createGoal.categoryHint,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          Text(
            t.createGoal.timeline,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<GoalType>(
            initialValue: _selectedType,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: [
              DropdownMenuItem(
                value: GoalType.weekly,
                child: Text(t.createGoal.thisWeek),
              ),
              DropdownMenuItem(
                value: GoalType.monthly,
                child: Text(t.createGoal.thisMonth),
              ),
              DropdownMenuItem(
                value: GoalType.quarterly,
                child: Text(t.createGoal.thisQuarter),
              ),
              DropdownMenuItem(
                value: GoalType.annual,
                child: Text(t.createGoal.thisYear),
              ),
              DropdownMenuItem(
                value: GoalType.lifetime,
                child: Text(t.createGoal.longTerm),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedType = val);
            },
          ),
          const SizedBox(height: 24),
          Text(t.form.color, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in _colors)
                GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _selectedColor == color
                          ? Border.all(
                              color: context.evolveColors.foreground,
                              width: 2,
                            )
                          : null,
                    ),
                  ),
                ),
              CustomColorSwatch(
                initial: _selectedColor,
                isSelected: !_colors.contains(_selectedColor),
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
