import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
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
  final _categoryController = TextEditingController(text: 'Obiettivo');
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
        return 'Tutta la vita';
      case GoalType.annual:
        return 'Entro il ${now.year}';
      case GoalType.quarterly:
        final q = (now.month / 3).ceil();
        return 'Q$q ${now.year}';
      case GoalType.monthly:
        const months = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
        return '${months[now.month - 1]} ${now.year}';
      case GoalType.weekly:
        return 'Questa settimana';
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
      final dayOfYear = int.parse(now.difference(DateTime(now.year, 1, 1)).inDays.toString());
      weekNumber = ((dayOfYear - now.weekday + 10) / 7).floor();
    }

    try {
      await ref.read(dashboardControllerProvider.notifier).addGoal(
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
      title: const Text('Nuovo Obiettivo'),
      subtitle: 'Definisci il tuo prossimo traguardo.',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titolo',
              hintText: 'es. Lanciare il nuovo prodotto',
            ),
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              hintText: 'es. Lavoro',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          Text('Timeline', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<GoalType>(
            value: _selectedType,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: GoalType.weekly, child: Text('Questa Settimana')),
              DropdownMenuItem(value: GoalType.monthly, child: Text('Questo Mese')),
              DropdownMenuItem(value: GoalType.quarterly, child: Text('Questo Trimestre')),
              DropdownMenuItem(value: GoalType.annual, child: Text('Quest\'Anno')),
              DropdownMenuItem(value: GoalType.lifetime, child: Text('Lungo termine (Lifetime)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedType = val);
            },
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
