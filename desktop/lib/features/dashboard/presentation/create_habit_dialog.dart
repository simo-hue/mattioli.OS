import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/color_picker_button.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
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
      final added = await ref
          .read(dashboardControllerProvider.notifier)
          .addHabit(
            title: title,
            color: _selectedColor,
            frequencyDays: _selectedDays,
          );
      if (!added) {
        // Free-tier 5-habit cap reached → present the paywall, keep the dialog.
        if (mounted) {
          setState(() => _isLoading = false);
          await showProFeaturesDialog(context, ref);
        }
        return;
      }
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
          EvolveFieldLabel(t.form.title),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(hintText: t.createHabit.titleHint),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          EvolveFieldLabel(t.form.color),
          const SizedBox(height: 10),
          ColorPickerButton(
            color: _selectedColor,
            onColorChanged: (color) => setState(() => _selectedColor = color),
            presetColors: _presetColors,
          ),
          const SizedBox(height: 20),
          EvolveFieldLabel(t.createHabit.weeklyFrequency),
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
                  child: EvolveSpinner(radius: 8),
                )
              : Text(t.form.add),
        ),
      ],
    );
  }
}
