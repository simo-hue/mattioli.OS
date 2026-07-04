import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateHabitDialog extends ConsumerStatefulWidget {
  const CreateHabitDialog({super.key});

  @override
  ConsumerState<CreateHabitDialog> createState() => _CreateHabitDialogState();
}

class _CreateHabitDialogState extends ConsumerState<CreateHabitDialog> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Generale');
  Color _selectedColor = EvolveColors.cyan;
  final List<int> _selectedDays = [1, 2, 3, 4, 5, 6, 7];
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
      await ref.read(dashboardControllerProvider.notifier).addHabit(
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
    const days = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

    return EvolveAlertDialog(
      maxWidth: 480,
      icon: Icons.add_task_rounded,
      title: const Text('Nuova Abitudine'),
      subtitle: 'Definisci la tua nuova abitudine.',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titolo',
              hintText: 'es. Meditazione',
            ),
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              hintText: 'es. Benessere',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          Text('Colore', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _colors.map((color) {
              final isSelected = _selectedColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: context.evolveColors.foreground, width: 2)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('Frequenza settimanale', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final day = index + 1; // 1 = Monday, 7 = Sunday
              final isSelected = _selectedDays.contains(day);
              return InkWell(
                onTap: () => _toggleDay(day),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? context.evolveAccent : context.evolveColors.panelRaised,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    days[index],
                    style: TextStyle(
                      color: isSelected ? Colors.black : context.evolveColors.foreground,
                      fontWeight: FontWeight.w600,
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
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading 
            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Aggiungi'),
        ),
      ],
    );
  }
}
