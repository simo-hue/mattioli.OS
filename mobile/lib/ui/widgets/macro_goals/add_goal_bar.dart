import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../core/theme.dart';
import '../../../models/macro_goal.dart';
import '../../../providers/macro_goals_provider.dart';
import '../../../providers/macro_goal_categories_provider.dart';

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
      categoryId: _selectedCategory,
      createdAt: DateTime.now(),
    );

    ref.read(macroGoalsProvider.notifier).addGoal(goal);
    _controller.clear();
    setState(() => _selectedCategory = null);
    HapticFeedback.mediumImpact();
  }

  void _showCategoryPicker() {
    final categories = ref.read(macroGoalCategoriesProvider).value ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
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
                  color: context.appColors.border,
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
                    color: context.appColors.foreground,
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
                        color: context.appColors.border, width: 1.5),
                  ),
                ),
                title: Text(
                  'Default',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.appColors.mutedForeground,
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
              ...categories.map((cat) => ListTile(
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
                        color: context.appColors.foreground,
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
              const Divider(height: 1),
              ListTile(
                leading: Icon(LucideIcons.plus, color: Theme.of(context).colorScheme.primary, size: 20),
                title: Text(
                  'Crea nuova categoria',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateCategoryDialog();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showCreateCategoryDialog() {
    final nameController = TextEditingController();
    Color selectedColor = const Color(0xFF3B82F6); // Default blue

    final List<Color> curatedColors = [
      const Color(0xFFEF4444), // Red
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Green
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF8B5CF6), // Purple
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.appColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.appColors.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nuova Categoria',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: context.appColors.card.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.appColors.border, width: 1),
                      ),
                      child: TextField(
                        controller: nameController,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: context.appColors.foreground,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                          hintText: 'Nome categoria...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: context.appColors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Scegli Colore',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.appColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ...curatedColors.map((color) {
                          final isSelected = selectedColor.toARGB32() == color.toARGB32();
                          return GestureDetector(
                            onTap: () => setState(() => selectedColor = color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? context.appColors.foreground
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                              child: isSelected
                                  ? const Center(
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        }),
                        // Custom Color Picker Button
                        GestureDetector(
                          onTap: () {
                            _showColorPickerDialog(context, selectedColor, (color) {
                              setState(() => selectedColor = color);
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: context.appColors.border.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: !curatedColors.any((c) => c.toARGB32() == selectedColor.toARGB32())
                                    ? context.appColors.foreground
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(LucideIcons.plus, size: 16, color: context.appColors.foreground),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Annulla',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: context.appColors.mutedForeground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            if (name.isNotEmpty) {
                              final hexColor = '#${selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                              final categoryId = await ref.read(macroGoalCategoriesProvider.notifier).addCategory(name, hexColor);
                              if (categoryId != null) {
                                this.setState(() => _selectedCategory = categoryId);
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: context.appColors.background,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text(
                            'Crea',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showColorPickerDialog(BuildContext context, Color initialColor, ValueChanged<Color> onColorChanged) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 450,
        color: context.appColors.card,
        child: Column(
          children: [
            Container(
              color: context.appColors.border.withValues(alpha: 0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: Text('Annulla', style: TextStyle(color: context.appColors.mutedForeground)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    child: Text('Conferma', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Material(
                  color: Colors.transparent,
                  child: ColorPicker(
                    pickerColor: initialColor,
                    onColorChanged: onColorChanged,
                    pickerAreaHeightPercent: 0.7,
                    enableAlpha: false,
                    displayThumbColor: true,
                    labelTypes: const [],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
        catColor = categories.firstWhere((c) => c.key == _selectedCategory).color;
      } catch (_) {
        catColor = categoryColor(_selectedCategory); // Fallback to default
      }
    }

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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: InputBorder.none,
                  hintText: _placeholder,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.appColors.mutedForeground,
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
                    color: catColor?.withValues(alpha: 0.7) ??
                        Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: catColor?.withValues(alpha: 0.9) ??
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
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.plus,
                color: context.appColors.background,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
