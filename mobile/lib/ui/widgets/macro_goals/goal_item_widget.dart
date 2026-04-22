import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme.dart';
import '../../../models/macro_goal.dart';
import '../../../providers/macro_goals_provider.dart';

class GoalItemWidget extends ConsumerStatefulWidget {
  final MacroGoal goal;

  const GoalItemWidget({super.key, required this.goal});

  @override
  ConsumerState<GoalItemWidget> createState() => _GoalItemWidgetState();
}

class _GoalItemWidgetState extends ConsumerState<GoalItemWidget>
    with SingleTickerProviderStateMixin {

  // ── Status cycle: active → completed → failed → active ──────────────────
  GoalStatus get _nextStatus {
    switch (widget.goal.status) {
      case GoalStatus.active:
        return GoalStatus.completed;
      case GoalStatus.completed:
        return GoalStatus.failed;
      case GoalStatus.failed:
        return GoalStatus.active;
    }
  }

  void _cycleStatus() {
    ref
        .read(macroGoalsProvider.notifier)
        .updateStatus(widget.goal.id, _nextStatus);
    HapticFeedback.lightImpact();
  }

  void _delete() {
    ref.read(macroGoalsProvider.notifier).deleteGoal(widget.goal.id);
    HapticFeedback.mediumImpact();
  }

  void _showEditDialog() {
    final ctrl = TextEditingController(text: widget.goal.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Modifica Obiettivo',
          style: GoogleFonts.inter(
            color: AppColors.foreground,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.inter(color: AppColors.foreground, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Titolo obiettivo...',
            hintStyle: GoogleFonts.inter(color: AppColors.mutedForeground),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.borderHover),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide:
                  const BorderSide(color: AppColors.foreground, width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla',
                style: GoogleFonts.inter(color: AppColors.mutedForeground)),
          ),
          TextButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) {
                ref
                    .read(macroGoalsProvider.notifier)
                    .updateTitle(widget.goal.id, t);
              }
              Navigator.pop(context);
            },
            child: Text(
              'Salva',
              style: GoogleFonts.inter(
                  color: AppColors.foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminare obiettivo?',
          style: GoogleFonts.inter(
            color: AppColors.foreground,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Questa azione non può essere annullata.',
          style: GoogleFonts.inter(
              color: AppColors.mutedForeground, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla',
                style: GoogleFonts.inter(color: AppColors.mutedForeground)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _delete();
            },
            child: Text(
              'Elimina',
              style: GoogleFonts.inter(
                  color: AppColors.destructive, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
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
                  color: AppColors.borderActive,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Cambia categoria',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.borderActive, width: 1.5),
                  ),
                ),
                title: Text('Nessuna',
                    style:
                        GoogleFonts.inter(color: AppColors.mutedForeground)),
                trailing: widget.goal.categoryKey == null
                    ? const Icon(Icons.check,
                        color: Color(0xFF34D399), size: 18)
                    : null,
                onTap: () {
                  ref
                      .read(macroGoalsProvider.notifier)
                      .updateCategory(widget.goal.id, null);
                  Navigator.pop(context);
                },
              ),
              ...kDefaultCategories.map(
                (cat) => ListTile(
                  leading: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: cat.color.withValues(alpha: 0.6), width: 1.5),
                    ),
                  ),
                  title: Text(
                    cat.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.foreground,
                      fontWeight: widget.goal.categoryKey == cat.key
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: widget.goal.categoryKey == cat.key
                      ? const Icon(Icons.check,
                          color: Color(0xFF34D399), size: 18)
                      : null,
                  onTap: () {
                    ref
                        .read(macroGoalsProvider.notifier)
                        .updateCategory(widget.goal.id, cat.key);
                    Navigator.pop(context);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final status = goal.status;
    final catColor = categoryColor(goal.categoryKey);

    final isCompleted = status == GoalStatus.completed;
    final isFailed = status == GoalStatus.failed;
    final isActive = status == GoalStatus.active;

    // ── Card colors based on status / category ─────────────────────────────
    Color borderColor;
    Color bgColor;

    if (isCompleted) {
      borderColor = const Color(0xFF34D399).withValues(alpha: 0.15);
      bgColor = const Color(0xFF34D399).withValues(alpha: 0.05);
    } else if (isFailed) {
      borderColor = AppColors.destructive.withValues(alpha: 0.2);
      bgColor = AppColors.destructive.withValues(alpha: 0.06);
    } else {
      // active
      borderColor = catColor != null
          ? catColor.withValues(alpha: 0.3)
          : AppColors.borderHover;
      bgColor = catColor != null
          ? catColor.withValues(alpha: 0.08)
          : AppColors.card.withValues(alpha: 0.4);
    }

    // ── Checkbox appearance ────────────────────────────────────────────────
    Widget checkbox() {
      Color checkBg;
      Color checkBorder;
      Widget? icon;

      if (isCompleted) {
        checkBg = const Color(0xFF34D399);
        checkBorder = const Color(0xFF34D399);
        icon = const Icon(Icons.check, color: Colors.black, size: 12);
      } else if (isFailed) {
        checkBg = AppColors.destructive;
        checkBorder = AppColors.destructive;
        icon = const Icon(Icons.close, color: Colors.white, size: 12);
      } else {
        checkBg = Colors.transparent;
        checkBorder = AppColors.borderActive;
        icon = null;
      }

      return GestureDetector(
        onTap: _cycleStatus,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: checkBg,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: checkBorder, width: 1.5),
          ),
          child: icon != null ? Center(child: icon) : null,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
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
              checkbox(),
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
                child: GestureDetector(
                  onTap: _cycleStatus,
                  child: Text(
                    goal.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isCompleted
                          ? const Color(0xFF34D399).withValues(alpha: 0.7)
                          : isFailed
                              ? AppColors.destructive.withValues(alpha: 0.7)
                              : AppColors.foreground,
                      decoration: (isCompleted || isFailed)
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: isCompleted
                          ? const Color(0xFF34D399).withValues(alpha: 0.5)
                          : AppColors.destructive.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // ── Action buttons (swipe-reveal via long-press or always shown) ─
              _ActionButtons(
                catColor: catColor,
                onCategory: _showCategorySheet,
                onEdit: _showEditDialog,
                onDelete: _showDeleteConfirm,
              ),
            ],
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionButtons({
    required this.catColor,
    required this.onCategory,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Category dot button
        _IconBtn(
          onTap: onCategory,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color:
                  catColor?.withValues(alpha: 0.7) ?? Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: catColor?.withValues(alpha: 0.9) ??
                    AppColors.borderActive,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        _IconBtn(
          onTap: onEdit,
          child: Icon(LucideIcons.pencil,
              size: 14, color: AppColors.mutedForeground),
        ),
        const SizedBox(width: 2),
        _IconBtn(
          onTap: onDelete,
          child: Icon(LucideIcons.trash2,
              size: 14, color: AppColors.destructive.withValues(alpha: 0.7)),
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
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: child,
      ),
    );
  }
}
