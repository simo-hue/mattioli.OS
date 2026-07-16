import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme.dart';
import '../../../models/macro_goal.dart';
import '../../../providers/macro_goals_provider.dart';
import '../../../providers/macro_goal_categories_provider.dart';
import '../../../core/haptics.dart';
import '../../../providers/settings_provider.dart';
import 'category_picker_sheet.dart';
import '../pro_features_modal.dart';
import '../../../i18n/translations.g.dart';
import '../../kit/evolve_dialog.dart';
import '../../kit/evolve_sheet.dart';

class GoalItemWidget extends ConsumerStatefulWidget {
  final MacroGoal goal;
  final GlobalKey? checkboxKey;
  final GlobalKey? categoryKey;
  final GlobalKey? rescheduleKey;
  final GlobalKey? editKey;
  final GlobalKey? deleteKey;

  const GoalItemWidget({
    super.key,
    required this.goal,
    this.checkboxKey,
    this.categoryKey,
    this.rescheduleKey,
    this.editKey,
    this.deleteKey,
  });

  @override
  ConsumerState<GoalItemWidget> createState() => _GoalItemWidgetState();
}

class _GoalItemWidgetState extends ConsumerState<GoalItemWidget>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  GoalStatus? _visualStatusOverride;
  Timer? _debounceTimer;
  ProviderContainer? _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured for dispose(): `ref` throws once the element is unmounted, but
    // the container outlives this widget.
    _container = ProviderScope.containerOf(context, listen: false);
  }

  // ── Status cycle: active → completed → failed → active ──────────────────
  GoalStatus get _nextStatus {
    final currentStatus = _visualStatusOverride ?? widget.goal.status;
    switch (currentStatus) {
      case GoalStatus.active:
        return GoalStatus.completed;
      case GoalStatus.completed:
        return GoalStatus.failed;
      case GoalStatus.failed:
        return GoalStatus.active;
    }
  }

  void _cycleStatus() {
    // Start by giving haptic feedback
    ref.hapticAction();

    // Immediate visual feedback (Optimistic Update)
    setState(() {
      _visualStatusOverride = _nextStatus;
    });

    // Debounce the actual provider update and reorder animation
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      // Actually update the status in the provider (triggers reorder)
      ref
          .read(macroGoalsProvider.notifier)
          .updateStatus(widget.goal.id, _visualStatusOverride!);

      setState(() {
        _visualStatusOverride = null;
      });
    });
  }

  @override
  void dispose() {
    // The debounced timer is the only persistence path for a status tap, so a
    // teardown inside the window must flush it rather than drop it: the user
    // already got haptic + visual confirmation that the change applied.
    final pendingStatus = _visualStatusOverride;
    final container = _container;
    if ((_debounceTimer?.isActive ?? false) &&
        pendingStatus != null &&
        container != null) {
      container
          .read(macroGoalsProvider.notifier)
          .updateStatus(widget.goal.id, pendingStatus);
    }
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _delete() {
    ref.read(macroGoalsProvider.notifier).deleteGoal(widget.goal.id);
    ref.hapticMedium();
  }

  void _reschedule() {
    final settings = ref.read(settingsProvider);
    final isPro = settings.isPro;
    final currentGoalsCount = ref.read(macroGoalsProvider).goals.length;

    if (!isPro && currentGoalsCount >= 100) {
      ref.hapticHeavy();
      ProFeaturesModal.show(context);
      return;
    }

    ref.read(macroGoalsProvider.notifier).rescheduleGoal(widget.goal);
    ref.hapticSuccess();
  }

  void _showEditDialog() {
    final ctrl = TextEditingController(text: widget.goal.title);
    showEvolveFormSheet<void>(
      context: context,
      title: context.t.macroGoals.editGoal,
      leading: EvolveTextAction(
        label: context.t.common.actions.cancel,
        onPressed: () => Navigator.pop(context),
      ),
      trailing: EvolveTextAction(
        label: context.t.common.actions.save,
        emphasized: true,
        onPressed: () {
          final t = ctrl.text.trim();
          if (t.isNotEmpty) {
            ref
                .read(macroGoalsProvider.notifier)
                .updateTitle(widget.goal.id, t);
          }
          Navigator.pop(context);
        },
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: context.appColors.cardElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appColors.border),
            ),
            child: TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: context.appColors.foreground,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: InputBorder.none,
                hintText: context.t.macroGoals.goalTitle,
                hintStyle: GoogleFonts.inter(
                  fontSize: 15,
                  color: context.appColors.mutedForeground,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirm() async {
    final confirmed = await showEvolveConfirm(
      context: context,
      title: context.t.macroGoals.deleteGoal,
      message: context.t.macroGoals.thisActionCannotBeUndone,
      confirmLabel: context.t.common.actions.delete,
      isDestructive: true,
      ref: ref,
    );
    if (confirmed && mounted) _delete();
  }

  void _showCategorySheet() {
    showMacroGoalCategoryPicker(
      context: context,
      ref: ref,
      title: context.t.macroGoals.changeCategory,
      noneLabel: context.t.macroGoals.none,
      noneSelected:
          widget.goal.categoryId == null && widget.goal.categoryKey == null,
      selectedCategoryId: widget.goal.categoryId,
      onSelected: (categoryId) {
        ref
            .read(macroGoalsProvider.notifier)
            .updateCategory(widget.goal.id, categoryId);
        ref.hapticSelection();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final status = _visualStatusOverride ?? goal.status;
    final categoriesAsync = ref.watch(macroGoalCategoriesProvider);
    final categories = categoriesAsync.value ?? [];

    Color? catColor;
    if (goal.categoryId != null) {
      try {
        catColor = categories.firstWhere((c) => c.key == goal.categoryId).color;
      } catch (_) {
        // Fallback
      }
    } else if (goal.categoryKey != null) {
      catColor = categoryColor(goal.categoryKey);
    }

    final isCompleted = status == GoalStatus.completed;
    final isFailed = status == GoalStatus.failed;
    final isActive = status == GoalStatus.active;

    // ── Card colors based on status / category ─────────────────────────────
    Color borderColor;
    Color bgColor;

    if (isCompleted) {
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.15);
      bgColor = const Color(0xFF10B981).withValues(alpha: 0.05);
    } else if (isFailed) {
      borderColor = context.appColors.destructive.withValues(alpha: 0.2);
      bgColor = context.appColors.destructive.withValues(alpha: 0.06);
    } else {
      // active
      borderColor = catColor != null
          ? catColor.withValues(alpha: 0.3)
          : context.appColors.border;
      bgColor = catColor != null
          ? catColor.withValues(alpha: 0.08)
          : context.appColors.card.withValues(alpha: 0.4);
    }

    // ── Checkbox appearance ────────────────────────────────────────────────
    Widget checkbox() {
      Color checkBg;
      Color checkBorder;
      Widget? icon;

      if (isCompleted) {
        checkBg = const Color(0xFF10B981);
        checkBorder = const Color(0xFF10B981);
        icon = Icon(Icons.check, color: context.appColors.background, size: 12);
      } else if (isFailed) {
        checkBg = context.appColors.destructive;
        checkBorder = context.appColors.destructive;
        icon = const Icon(Icons.close, color: Colors.white, size: 12);
      } else {
        checkBg = Colors.transparent;
        checkBorder = context.appColors.border;
        icon = null;
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: checkBg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: checkBorder, width: 1.5),
        ),
        child: icon != null ? Center(child: icon) : null,
      );
    }

    final a11yStatus = isCompleted
        ? context.t.a11y.statusCompleted
        : isFailed
        ? context.t.a11y.statusFailed
        : context.t.a11y.statusActive;

    return AnimatedScale(
      duration: const Duration(milliseconds: 300),
      scale: _isPressed ? 0.98 : 1.0,
      curve: Curves.easeOutBack,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Semantics(
          button: true,
          container: true,
          excludeSemantics: true,
          label: '${goal.title}, $a11yStatus',
          hint: context.t.a11y.toggleHint,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: _cycleStatus,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                children: [
                  // Checkbox
                  Container(key: widget.checkboxKey, child: checkbox()),
                  const SizedBox(width: 12),

                  // Category dot (if set)
                  if (catColor != null && isActive) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: catColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Title
                  Expanded(
                    child: Text(
                      goal.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isCompleted
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.7)
                            : isFailed
                            ? context.appColors.destructive.withValues(
                                alpha: 0.7,
                              )
                            : context.appColors.foreground,
                        decoration: (isCompleted || isFailed)
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: isCompleted
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.5)
                            : context.appColors.destructive.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ── Action buttons (swipe-reveal via long-press or always shown) ─
                  _ActionButtons(
                    catColor: catColor,
                    onCategory: _showCategorySheet,
                    onReschedule: _reschedule,
                    onEdit: _showEditDialog,
                    onDelete: _showDeleteConfirm,
                    categoryKey: widget.categoryKey,
                    rescheduleKey: widget.rescheduleKey,
                    editKey: widget.editKey,
                    deleteKey: widget.deleteKey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Compact action buttons ─────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final Color? catColor;
  final VoidCallback onCategory;
  final VoidCallback onReschedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final GlobalKey? categoryKey;
  final GlobalKey? rescheduleKey;
  final GlobalKey? editKey;
  final GlobalKey? deleteKey;

  const _ActionButtons({
    required this.catColor,
    required this.onCategory,
    required this.onReschedule,
    required this.onEdit,
    required this.onDelete,
    this.categoryKey,
    this.rescheduleKey,
    this.editKey,
    this.deleteKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Category dot button
        Container(
          key: categoryKey,
          child: _IconBtn(
            onTap: onCategory,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: catColor?.withValues(alpha: 0.7) ?? Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      catColor?.withValues(alpha: 0.9) ??
                      context.appColors.border,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          key: rescheduleKey,
          child: _IconBtn(
            onTap: onReschedule,
            child: Icon(
              LucideIcons.calendarClock,
              size: 14,
              color: context.appColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          key: editKey,
          child: _IconBtn(
            onTap: onEdit,
            child: Icon(
              LucideIcons.pencil,
              size: 14,
              color: context.appColors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          key: deleteKey,
          child: _IconBtn(
            onTap: onDelete,
            child: Icon(
              LucideIcons.trash2,
              size: 14,
              color: context.appColors.destructive.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _IconBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.all(6), child: child),
    );
  }
}
