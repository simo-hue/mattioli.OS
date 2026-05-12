import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../core/theme.dart';
import '../../core/localization.dart';
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
  late Color _selectedColor;
  Goal? _editingHabit;
  String? _reminderTime;

  @override
  void initState() {
    super.initState();
    _selectedColor = _presetColors[0];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default to accent color if not editing
    if (_editingHabit == null) {
      _selectedColor = Theme.of(context).colorScheme.primary;
    }
  }

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
      final updated = _editingHabit!.copyWith(
        title: _nameController.text.trim(),
        color: _selectedColor,
        reminderTime: _reminderTime,
        clearReminderTime: _reminderTime == null,
      );
      ref.read(goalsProvider.notifier).updateHabit(updated);
    } else {
      final newHabit = Goal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _nameController.text.trim(),
        description: '',
        icon: 'circle',
        color: _selectedColor,
        startDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
        reminderTime: _reminderTime,
      );
      ref.read(goalsProvider.notifier).addHabit(newHabit);
    }

    _nameController.clear();
    setState(() {
      _editingHabit = null;
      _selectedColor = _presetColors[0];
      _reminderTime = null;
    });
    HapticFeedback.mediumImpact();
  }

  void _onEdit(Goal habit) {
    setState(() {
      _editingHabit = habit;
      _nameController.text = habit.title;
      _selectedColor = habit.color;
      _reminderTime = habit.reminderTime;
    });
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appColors.card,
        title: Text(context.l10n.translate('Scegli un colore'), style: TextStyle(color: context.appColors.foreground)),
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
            child: Text(context.l10n.translate('confirm'), style: TextStyle(color: context.appColors.foreground)),
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
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 20),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Text(
                      context.l10n.translate('Gestione Abitudini'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.appColors.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(LucideIcons.x, color: context.appColors.mutedForeground, size: 20),
                    ),
                  ],
                ),
                Text(
                  context.l10n.translate('Trascina per riordinare'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: context.appColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 24),
      
                // Add/Edit Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appColors.card.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.appColors.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: context.appColors.border.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(LucideIcons.plus, size: 14, color: context.appColors.foreground),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _editingHabit != null 
                              ? context.l10n.translate('Modifica Abitudine') 
                              : context.l10n.translate('Aggiungi Abitudine'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: context.appColors.foreground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.translate('Nome Abitudine').toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.appColors.mutedForeground, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        style: TextStyle(color: context.appColors.foreground, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: context.l10n.translate('Es. Bere acqua, Leggere...'),
                          hintStyle: TextStyle(color: context.appColors.mutedForeground.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: context.appColors.background.withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.appColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.translate('Colore').toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.appColors.mutedForeground, letterSpacing: 0.5),
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
                                    color: isSelected 
                                      ? (color.computeLuminance() > 0.7 ? Colors.black.withValues(alpha: 0.2) : Colors.white) 
                                      : Colors.transparent,
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
                                color: context.appColors.border.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: !_presetColors.contains(_selectedColor) 
                                    ? (_selectedColor.computeLuminance() > 0.7 ? Colors.black.withValues(alpha: 0.2) : Colors.white) 
                                    : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(LucideIcons.plus, size: 14, color: context.appColors.foreground),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.translate('Promemoria').toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.appColors.mutedForeground, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          TimeOfDay initialTime = const TimeOfDay(hour: 9, minute: 0);
                          if (_reminderTime != null) {
                            final parts = _reminderTime!.split(':');
                            initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                          }
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: initialTime,
                          );
                          if (pickedTime != null) {
                            final timeStr = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                            setState(() => _reminderTime = timeStr);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: context.appColors.background.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.appColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _reminderTime ?? context.l10n.translate('Nessuno'),
                                style: TextStyle(
                                  color: _reminderTime != null ? context.appColors.foreground : context.appColors.mutedForeground,
                                  fontSize: 15,
                                ),
                              ),
                              if (_reminderTime != null)
                                IconButton(
                                  icon: Icon(LucideIcons.x, size: 16, color: context.appColors.mutedForeground),
                                  onPressed: () => setState(() => _reminderTime = null),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                )
                              else
                                Icon(LucideIcons.bell, size: 16, color: context.appColors.mutedForeground),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: _selectedColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            _editingHabit != null 
                              ? context.l10n.translate('Salva') 
                              : context.l10n.translate('Aggiungi Abitudine'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            ),
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
                             child: Text(context.l10n.translate('Annulla'), style: TextStyle(color: context.appColors.mutedForeground)),
                           ),
                         )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
      
                // Habits List Section Header
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.translate('Abitudini'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          SliverReorderableList(
            itemCount: habits.length,
            onReorder: (oldIndex, newIndex) {
              ref.read(goalsProvider.notifier).reorder(oldIndex, newIndex);
              HapticFeedback.lightImpact();
            },
            itemBuilder: (context, index) {
              final habit = habits[index];
              return _HabitListItem(
                key: ValueKey(habit.id),
                index: index,
                habit: habit,
                onEdit: () => _onEdit(habit),
                onDelete: () {
                  ref.read(goalsProvider.notifier).deleteHabit(habit.id);
                  HapticFeedback.mediumImpact();
                },
              );
            },
          ),
          // Extra space at bottom
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),

    );
  }
}

class _HabitListItem extends StatelessWidget {
  final int index;
  final Goal habit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HabitListItem({
    super.key,
    required this.index,
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
        color: context.appColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Icon(LucideIcons.gripVertical, size: 16, color: context.appColors.mutedForeground),
            ),
          ),

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
              style: TextStyle(
                color: context.appColors.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(LucideIcons.pencil, size: 16, color: context.appColors.mutedForeground),
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
