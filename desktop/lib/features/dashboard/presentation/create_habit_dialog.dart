import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/color_picker_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CreateHabitDialog extends ConsumerStatefulWidget {
  const CreateHabitDialog({super.key});

  @override
  ConsumerState<CreateHabitDialog> createState() => _CreateHabitDialogState();
}

class _CreateHabitDialogState extends ConsumerState<CreateHabitDialog> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController(
    text: t.createHabit.defaultCategory,
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

  Color _selectedColor = _presetColors[0];
  final List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        if (_selectedDays.length > 1) {
          _selectedDays.remove(day);
        }
      } else {
        _selectedDays.add(day);
        _selectedDays.sort();
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(dashboardControllerProvider.notifier)
          .addHabit(
            title: title,
            category: _categoryController.text.trim(),
            color: _selectedColor,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Error is logged in controller
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = t.common.weekdayInitials;

    return EvolveAlertDialog(
      maxWidth: 480,
      icon: LucideIcons.plus,
      title: Text(t.createHabit.title),
      subtitle: t.createHabit.subtitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(t.form.title),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(hintText: t.createHabit.titleHint),
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _FieldLabel(t.form.category),
          const SizedBox(height: 8),
          TextField(
            controller: _categoryController,
            decoration: InputDecoration(hintText: t.createHabit.categoryHint),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
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
          const SizedBox(height: 20),
          _FieldLabel(t.createHabit.weeklyFrequency),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final day = index + 1; // 1 = Monday, 7 = Sunday
              final isSelected = _selectedDays.contains(day);
              return InkWell(
                onTap: () => _toggleDay(day),
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
                    days[index],
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : context.evolveColors.muted,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
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
