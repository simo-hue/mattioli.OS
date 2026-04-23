import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../core/theme.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';

class HabitManagementModal extends ConsumerStatefulWidget {
  const HabitManagementModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HabitManagementModal(),
    );
  }

  @override
  ConsumerState<HabitManagementModal> createState() => _HabitManagementModalState();
}

class _HabitManagementModalState extends ConsumerState<HabitManagementModal> {
  final TextEditingController _nameController = TextEditingController();
  Color _selectedColor = const Color(0xFF30A661);
  Goal? _editingHabit;

  final List<Color> _presetColors = [
    const Color(0xFF30A661),
    const Color(0xFF3B82F6),
    const Color(0xFF7C3AED),
    const Color(0xFFEC4899),
    const Color(0xFFEF4444),
    const Color(0xFFF59E0B),
    const Color(0xFF10B981),
  ];


  void _onSave() {
    if (_nameController.text.trim().isEmpty) return;

    if (_editingHabit != null) {
      final updated = Goal(
        id: _editingHabit!.id,
        title: _nameController.text.trim(),
        description: _editingHabit!.description,
        icon: _editingHabit!.icon,
        color: _selectedColor,
        startDate: _editingHabit!.startDate,
        endDate: _editingHabit!.endDate,
      );
      ref.read(goalsProvider.notifier).updateHabit(updated);
    } else {
      final newHabit = Goal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _nameController.text.trim(),
        description: '',
        icon: 'circle',
        color: _selectedColor,
        startDate: DateTime.now().toIso8601String().split('T')[0],
      );
      ref.read(goalsProvider.notifier).addHabit(newHabit);
    }

    _nameController.clear();
    setState(() {
      _editingHabit = null;
      _selectedColor = _presetColors[0];
    });
    HapticFeedback.mediumImpact();
  }

  void _onEdit(Goal habit) {
    setState(() {
      _editingHabit = habit;
      _nameController.text = habit.title;
      _selectedColor = habit.color;
    });
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Scegli un colore', style: TextStyle(color: AppColors.foreground)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) => setState(() => _selectedColor = color),
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ok', style: TextStyle(color: AppColors.foreground)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(goalsProvider);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 20),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              const Text(
                'Gestisci Abitudini',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: AppColors.mutedForeground, size: 20),
              ),
            ],
          ),
          const Text(
            'Aggiungi, modifica o riordina le abitudini che vuoi tracciare. Trascina per riordinare.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),

          // Add/Edit Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.muted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.plus, size: 14, color: AppColors.foreground),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _editingHabit != null ? 'Modifica Abitudine' : 'Nuova Abitudine',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'NOME',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedForeground, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.foreground, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Es. Bere acqua, Leggere...',
                    hintStyle: TextStyle(color: AppColors.mutedForeground.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.2),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.mutedForeground),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'COLORE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedForeground, letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ..._presetColors.map((color) {
                      final isSelected = _selectedColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = color),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 0)
                            ] : null,
                          ),
                        ),
                      );
                    }),
                    // Custom Color Picker Button
                    GestureDetector(
                      onTap: _showColorPicker,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: !_presetColors.contains(_selectedColor) ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: const Icon(LucideIcons.plus, size: 14, color: AppColors.foreground),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.muted,
                      foregroundColor: AppColors.foreground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      _editingHabit != null ? 'Salva Modifiche' : 'Aggiungi al Protocollo',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (_editingHabit != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 8),
                     child: TextButton(
                       onPressed: () => setState(() {
                         _editingHabit = null;
                         _nameController.clear();
                       }),
                       child: const Text('Annulla', style: TextStyle(color: AppColors.mutedForeground)),
                     ),
                   )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Habits List Section
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Le tue Abitudini',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ReorderableListView.builder(
              onReorder: (oldIndex, newIndex) {
                ref.read(goalsProvider.notifier).reorder(oldIndex, newIndex);
                HapticFeedback.lightImpact();
              },
              itemCount: habits.length,
              itemBuilder: (context, index) {
                final habit = habits[index];
                return _HabitListItem(
                  key: ValueKey(habit.id),
                  habit: habit,
                  onEdit: () => _onEdit(habit),
                  onDelete: () {
                    ref.read(goalsProvider.notifier).deleteHabit(habit.id);
                    HapticFeedback.mediumImpact();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitListItem extends StatelessWidget {
  final Goal habit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HabitListItem({
    super.key,
    required this.habit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.gripVertical, size: 16, color: AppColors.mutedForeground),
          const SizedBox(width: 12),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: habit.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: habit.color.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 0)
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              habit.title,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(LucideIcons.pencil, size: 16, color: AppColors.mutedForeground),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.destructive),
          ),
        ],
      ),
    );
  }
}
