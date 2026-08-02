import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme.dart';
import '../../../core/haptics.dart';
import '../../../models/macro_goal.dart';
import '../../../providers/macro_goal_categories_provider.dart';
import '../../../providers/macro_goals_provider.dart';
import '../../../i18n/translations.g.dart';
import '../../kit/evolve_sheet.dart';
import '../../kit/evolve_color_picker.dart';

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
  // Capture the caller's context & notifier BEFORE opening the sheet. These
  // stay valid even after the bottom-sheet's Consumer is disposed (used by the
  // "create new category" path, which pops the sheet first).
  final callerContext = context;
  final callerRef = ref;
  final categoriesNotifier = ref.read(macroGoalCategoriesProvider.notifier);

  return showEvolveSheet<void>(
    context: context,
    title: title,
    itemsBuilder: (sheetContext) {
      return [
        Consumer(
          builder: (context, ref, _) {
            final accent = Theme.of(context).colorScheme.primary;
            final categories =
                ref.watch(macroGoalCategoriesProvider).value ?? [];
            final activeCategories = categories
                .where((category) => !category.isArchived)
                .toList();
            final goals = ref.watch(macroGoalsProvider).goals;

            return EvolveListSection(
              children: [
                // "None" row.
                EvolveListRow(
                  leading: EvolveIconTile(
                    icon: LucideIcons.circle,
                    tint: context.appColors.mutedForeground,
                  ),
                  title: noneLabel,
                  selected: noneSelected,
                  onTap: () {
                    onSelected(null);
                    Navigator.pop(sheetContext);
                  },
                ),
                // Active categories.
                ...activeCategories.map((category) {
                  final linkedGoalsCount = goals
                      .where((goal) => goal.categoryId == category.key)
                      .length;
                  final isSelected = selectedCategoryId == category.key;
                  return EvolveListRow(
                    leading: EvolveColorDotTile(color: category.color),
                    title: category.label,
                    selected: isSelected,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Icon(
                            CupertinoIcons.check_mark,
                            color: accent,
                            size: 20,
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: context.t.macroGoals.editCategory,
                          icon: Icon(
                            LucideIcons.pencil,
                            size: 17,
                            color: context.appColors.mutedForeground,
                          ),
                          onPressed: () => _showCategoryEditor(
                            context: context,
                            ref: ref,
                            notifier: ref.read(
                              macroGoalCategoriesProvider.notifier,
                            ),
                            category: category,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: context.t.macroGoals.archiveCategory,
                          icon: Icon(
                            LucideIcons.trash2,
                            size: 17,
                            color: context.appColors.destructive,
                          ),
                          onPressed: () async {
                            final deleted = await _showDeleteCategory(
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
                        ),
                      ],
                    ),
                    onTap: () {
                      onSelected(category.key);
                      Navigator.pop(sheetContext);
                    },
                  );
                }),
                // Create-new-category row.
                EvolveListRow(
                  leading: EvolveIconTile(
                    icon: LucideIcons.plus,
                    tint: accent,
                  ),
                  title: context.t.macroGoals.createNewCategory,
                  titleColor: accent,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    // Use callerContext & pre-captured notifier so we don't
                    // touch the now-disposed Consumer ref.
                    final categoryId = await _showCategoryEditor(
                      context: callerContext,
                      ref: callerRef,
                      notifier: categoriesNotifier,
                    );
                    if (categoryId != null) {
                      onSelected(categoryId);
                    }
                  },
                ),
              ],
            );
          },
        ),
      ];
    },
  );
}

/// Create/edit a category in an Apple-style form sheet (Cancel / Done).
/// Returns the created/updated category id, or null if cancelled.
Future<String?> _showCategoryEditor({
  required BuildContext context,
  required WidgetRef ref,
  required MacroGoalCategoriesNotifier notifier,
  GoalCategory? category,
}) {
  final nameController = TextEditingController(text: category?.label ?? '');
  Color selectedColor = category?.color ?? kEvolveDefaultPalette[4];
  final isEditing = category != null;

  return showEvolveFormSheet<String?>(
    context: context,
    title: isEditing
        ? context.t.macroGoals.editCategory
        : context.t.macroGoals.createNewCategory,
    leading: EvolveTextAction(
      label: context.t.common.actions.cancel,
      onPressed: () => Navigator.pop(context),
    ),
    trailing: EvolveTextAction(
      label: isEditing
          ? context.t.common.actions.save
          : context.t.macroGoals.create,
      emphasized: true,
      onPressed: () async {
        final name = nameController.text.trim();
        if (name.isEmpty) return;

        final colorHex = _colorToHex(selectedColor);
        String? categoryId;
        if (isEditing) {
          final updated = await notifier.updateCategory(
            category.key,
            name,
            colorHex,
          );
          categoryId = updated ? category.key : null;
        } else {
          categoryId = await notifier.addCategory(name, colorHex);
        }

        if (categoryId != null && context.mounted) {
          Navigator.pop(context, categoryId);
          ref.hapticMedium();
        }
      },
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.appColors.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.appColors.border),
                  ),
                  child: TextField(
                    controller: nameController,
                    autofocus: true,
                    style: TextStyle(fontFamily: 'Inter', 
                      fontSize: 15,
                      color: context.appColors.foreground,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      hintText: context.t.macroGoals.categoryName,
                      hintStyle: TextStyle(fontFamily: 'Inter', 
                        fontSize: 15,
                        color: context.appColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.t.macroGoals.chooseColor,
                  style: TextStyle(fontFamily: 'Inter', 
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 12),
                EvolveColorSwatchGrid(
                  selected: selectedColor,
                  onChanged: (color) =>
                      setState(() => selectedColor = color),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// iOS-style destructive confirm for archiving a category.
Future<bool> _showDeleteCategory({
  required BuildContext context,
  required WidgetRef ref,
  required GoalCategory category,
  required int linkedGoalsCount,
}) async {
  final deleted = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(context.t.macroGoals.archiveCategory2),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          linkedGoalsCount > 0
              ? context.t.macroGoals.categoryUnavailableLinked
                    .replaceFirst('label', category.label)
                    .replaceFirst('count', linkedGoalsCount.toString())
              : context.t.macroGoals.categoryUnavailableArchived.replaceFirst(
                  'label',
                  category.label,
                ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.t.common.actions.cancel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () async {
            final success = await ref
                .read(macroGoalCategoriesProvider.notifier)
                .deleteCategory(category.key);
            if (dialogContext.mounted) {
              Navigator.pop(dialogContext, success);
            }
            if (success && context.mounted) {
              ref.hapticMedium();
            }
          },
          child: Text(context.t.macroGoals.archive),
        ),
      ],
    ),
  );

  return deleted ?? false;
}

String _colorToHex(Color color) {
  return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}
