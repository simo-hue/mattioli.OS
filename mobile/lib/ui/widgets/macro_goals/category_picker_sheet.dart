import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme.dart';
import '../../../models/macro_goal.dart';
import '../../../providers/macro_goal_categories_provider.dart';
import '../../../providers/macro_goals_provider.dart';

Future<void> showMacroGoalCategoryPicker({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String noneLabel,
  required bool noneSelected,
  required String? selectedCategoryId,
  required ValueChanged<String?> onSelected,
  bool clearSelectionOnArchive = false,
}) {
  // Capture the caller's context & notifier BEFORE opening the sheet.
  // These stay valid even after the bottom‐sheet's Consumer is disposed.
  final callerContext = context;
  final categoriesNotifier = ref.read(macroGoalCategoriesProvider.notifier);

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return Consumer(
        builder: (context, ref, _) {
          final categories = ref.watch(macroGoalCategoriesProvider).value ?? [];
          final activeCategories = categories.where(
            (category) => !category.isArchived,
          );
          final goals = ref.watch(macroGoalsProvider).goals;

          return DraggableScrollableSheet(
            initialChildSize: 0.62,
            minChildSize: 0.36,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return SafeArea(
                child: SingleChildScrollView(
                  controller: scrollController,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appColors.foreground,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.appColors.border,
                              width: 1.5,
                            ),
                          ),
                        ),
                        title: Text(
                          noneLabel,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: context.appColors.mutedForeground,
                          ),
                        ),
                        trailing: noneSelected
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                                size: 18,
                              )
                            : null,
                        onTap: () {
                          onSelected(null);
                          Navigator.pop(sheetContext);
                        },
                      ),
                      ...activeCategories.map((category) {
                        final linkedGoalsCount = goals
                            .where((goal) => goal.categoryId == category.key)
                            .length;
                        return _CategoryListTile(
                          category: category,
                          isSelected: selectedCategoryId == category.key,
                          linkedGoalsCount: linkedGoalsCount,
                          onSelected: () {
                            onSelected(category.key);
                            Navigator.pop(sheetContext);
                          },
                          onEdit: () {
                            _showCategoryEditorDialog(
                              context: context,
                              ref: ref,
                              category: category,
                            );
                          },
                          onDelete: () async {
                            final deleted = await _showDeleteCategoryDialog(
                              context: context,
                              ref: ref,
                              category: category,
                              linkedGoalsCount: linkedGoalsCount,
                            );

                            if (deleted &&
                                clearSelectionOnArchive &&
                                selectedCategoryId == category.key) {
                              onSelected(null);
                            }
                          },
                        );
                      }),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          LucideIcons.plus,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        title: Text(
                          'Crea nuova categoria',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          // Use callerContext & pre-captured notifier so we
                          // don't touch the now-disposed Consumer ref.
                          final categoryId =
                              await _showCategoryEditorDialogSafe(
                            context: callerContext,
                            notifier: categoriesNotifier,
                          );
                          if (categoryId != null) {
                            onSelected(categoryId);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

class _CategoryListTile extends StatelessWidget {
  final GoalCategory category;
  final bool isSelected;
  final int linkedGoalsCount;
  final VoidCallback onSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryListTile({
    required this.category,
    required this.isSelected,
    required this.linkedGoalsCount,
    required this.onSelected,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: category.color.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
      title: Text(
        category.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: context.appColors.foreground,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            Icon(
              Icons.check,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Modifica categoria',
            icon: Icon(
              LucideIcons.pencil,
              size: 17,
              color: context.appColors.mutedForeground,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Archivia categoria',
            icon: Icon(
              LucideIcons.trash2,
              size: 17,
              color: context.appColors.destructive,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
      onTap: onSelected,
    );
  }
}

Future<String?> _showCategoryEditorDialog({
  required BuildContext context,
  required WidgetRef ref,
  GoalCategory? category,
}) {
  // Capture the notifier eagerly so it stays valid if the caller's
  // Consumer is disposed while the dialog is still open.
  final notifier = ref.read(macroGoalCategoriesProvider.notifier);
  return _showCategoryEditorDialogSafe(
    context: context,
    notifier: notifier,
    category: category,
  );
}

/// Variant that takes a pre-captured [notifier] instead of a [WidgetRef],
/// safe to call after the originating sheet / Consumer has been disposed.
Future<String?> _showCategoryEditorDialogSafe({
  required BuildContext context,
  required MacroGoalCategoriesNotifier notifier,
  GoalCategory? category,
}) {
  final nameController = TextEditingController(text: category?.label ?? '');
  Color selectedColor = category?.color ?? const Color(0xFF3B82F6);
  final isEditing = category != null;

  final curatedColors = [
    const Color(0xFFEF4444),
    const Color(0xFFF59E0B),
    const Color(0xFF10B981),
    const Color(0xFF3B82F6),
    const Color(0xFF8B5CF6),
  ];

  return showDialog<String?>(
    context: context,
    builder: (dialogContext) {
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
                    isEditing ? 'Modifica categoria' : 'Nuova categoria',
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
                      border: Border.all(
                        color: context.appColors.border,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: nameController,
                      autofocus: true,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: context.appColors.foreground,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                    'Scegli colore',
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
                        final isSelected =
                            selectedColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = color),
                          child: _ColorSwatch(
                            color: color,
                            isSelected: isSelected,
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: () {
                          _showColorPickerDialog(context, selectedColor, (
                            color,
                          ) {
                            setState(() => selectedColor = color);
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: context.appColors.border.withValues(
                              alpha: 0.3,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  !curatedColors.any(
                                    (c) =>
                                        c.toARGB32() ==
                                        selectedColor.toARGB32(),
                                  )
                                  ? context.appColors.foreground
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            LucideIcons.plus,
                            size: 16,
                            color: context.appColors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
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
                          if (name.isEmpty) return;

                          final colorHex = _colorToHex(selectedColor);
                          String? categoryId;
                          if (isEditing) {
                            final updated = await notifier
                                .updateCategory(category.key, name, colorHex);
                            categoryId = updated ? category.key : null;
                          } else {
                            categoryId = await notifier
                                .addCategory(name, colorHex);
                          }

                          if (categoryId != null && dialogContext.mounted) {
                            Navigator.pop(dialogContext, categoryId);
                            HapticFeedback.mediumImpact();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: context.appColors.background,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: Text(
                          isEditing ? 'Salva' : 'Crea',
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

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;

  const _ColorSwatch({required this.color, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? context.appColors.foreground : Colors.transparent,
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
              child: Icon(Icons.check, color: Colors.white, size: 16),
            )
          : null,
    );
  }
}

Future<bool> _showDeleteCategoryDialog({
  required BuildContext context,
  required WidgetRef ref,
  required GoalCategory category,
  required int linkedGoalsCount,
}) async {
  final deleted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: context.appColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Archiviare categoria?',
        style: GoogleFonts.inter(
          color: context.appColors.foreground,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      content: Text(
        linkedGoalsCount > 0
            ? 'La categoria "${category.label}" non sarà più disponibile per nuovi obiettivi, ma resterà collegata a $linkedGoalsCount obiettivi storici e alle statistiche.'
            : 'La categoria "${category.label}" non sarà più disponibile per nuovi obiettivi, ma resterà nello storico.',
        style: GoogleFonts.inter(
          color: context.appColors.mutedForeground,
          fontSize: 13,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            'Annulla',
            style: GoogleFonts.inter(color: context.appColors.mutedForeground),
          ),
        ),
        TextButton(
          onPressed: () async {
            final success = await ref
                .read(macroGoalCategoriesProvider.notifier)
                .deleteCategory(category.key);
            if (dialogContext.mounted) {
              Navigator.pop(dialogContext, success);
            }
            if (success) {
              HapticFeedback.mediumImpact();
            }
          },
          child: Text(
            'Archivia',
            style: GoogleFonts.inter(
              color: context.appColors.destructive,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  return deleted ?? false;
}

void _showColorPickerDialog(
  BuildContext context,
  Color initialColor,
  ValueChanged<Color> onColorChanged,
) {
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
                  child: Text(
                    'Annulla',
                    style: TextStyle(color: context.appColors.mutedForeground),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: Text(
                    'Conferma',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
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

String _colorToHex(Color color) {
  return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}
