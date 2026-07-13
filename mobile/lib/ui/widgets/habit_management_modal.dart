import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:evolve_verification/evolve_verification.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';
import '../../core/verification_config.dart';
import '../../core/verification_providers.dart';
import 'verification_rule_field.dart';
import '../../core/time_formatting.dart';
import '../../models/goal.dart';
import '../../providers/goal_provider.dart';
import '../../providers/settings_provider.dart';
import '../screens/subscription_screen.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_color_picker.dart';
import '../kit/evolve_dialog.dart';
import '../kit/evolve_button.dart';
import '../kit/evolve_section_header.dart';
import '../kit/evolve_sheet.dart';

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
  ConsumerState<HabitManagementModal> createState() =>
      _HabitManagementModalState();
}

class _HabitManagementModalState extends ConsumerState<HabitManagementModal> {
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Color _selectedColor;
  Goal? _editingHabit;
  String? _reminderTime;
  VerificationRule? _verificationRule;

  @override
  void initState() {
    super.initState();
    _selectedColor = kEvolveDefaultPalette[0];
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Default to accent color if not editing
    if (_editingHabit == null) {
      _selectedColor = Theme.of(context).colorScheme.primary;
    }
  }

  void _onSave() {
    if (_nameController.text.trim().isEmpty) return;

    if (_editingHabit != null) {
      final updated = _editingHabit!.copyWith(
        title: _nameController.text.trim(),
        color: _selectedColor,
        reminderTime: _reminderTime,
        clearReminderTime: _reminderTime == null,
        verificationRule: _verificationRule,
        clearVerificationRule: _verificationRule == null,
      );
      ref.read(goalsProvider.notifier).updateHabit(updated);
    } else {
      final settings = ref.read(settingsProvider);
      final isPro = settings.isPro;
      final currentHabitsCount = ref.read(goalsProvider).length;

      if (!isPro && currentHabitsCount >= 5) {
        FocusScope.of(context).unfocus();
        ref.hapticHeavy();
        Navigator.pop(context); // Close the habit management sheet
        Navigator.push(
          context,
          SubscriptionScreen.route(),
        ); // Redirect to payment!
        return;
      }

      final newHabit = Goal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _nameController.text.trim(),
        description: '',
        icon: 'circle',
        color: _selectedColor,
        startDate: DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        ),
        reminderTime: _reminderTime,
        verificationRule: _verificationRule,
      );
      ref.read(goalsProvider.notifier).addHabit(newHabit);
    }

    _nameController.clear();
    setState(() {
      _editingHabit = null;
      _selectedColor = kEvolveDefaultPalette[0];
      _reminderTime = null;
      _verificationRule = null;
    });
    ref.hapticMedium();
  }

  void _onEdit(Goal habit) {
    setState(() {
      _editingHabit = habit;
      _nameController.text = habit.title;
      _selectedColor = habit.color;
      _reminderTime = habit.reminderTime;
      _verificationRule = habit.verificationRule;
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _grantHealthAccess() {
    final rule = _verificationRule;
    if (rule == null || !rule.isHealthKit) return;
    final typeId = rule.template?.healthKitTypeIdentifier ?? rule.metricKey;
    ref.read(healthKitBridgeProvider).requestAuthorization({typeId});
    ref.hapticMedium();
  }

  void _showCupertinoTimePicker() {
    final settings = ref.read(settingsProvider);
    final use24hFormat = settings.timeFormat24h;

    TimeOfDay initialTime = const TimeOfDay(hour: 9, minute: 0);
    if (_reminderTime != null) {
      initialTime = AppTimeFormatting.parseTimeOfDay(_reminderTime!);
    }

    final now = DateTime.now();
    DateTime initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      initialTime.hour,
      initialTime.minute,
    );

    showEvolveFormSheet<void>(
      context: context,
      title: context.t.habits.reminder,
      leading: EvolveTextAction(
        label: context.t.common.actions.cancel,
        onPressed: () => Navigator.pop(context),
      ),
      trailing: EvolveTextAction(
        label: context.t.common.actions.confirm,
        emphasized: true,
        onPressed: () {
          final timeStr = AppTimeFormatting.serializeDateTime(
            initialDateTime,
          );
          setState(() => _reminderTime = timeStr);
          Navigator.pop(context);
        },
      ),
      builder: (sheetContext) => SizedBox(
        height: 216,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          initialDateTime: initialDateTime,
          use24hFormat: use24hFormat,
          onDateTimeChanged: (DateTime newDateTime) {
            initialDateTime = newDateTime;
          },
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(Goal habit) async {
    final confirmed = await showEvolveConfirm(
      context: context,
      title: context.t.habits.deleteHabit,
      message: '${context.t.habits.areYouSureYouWantTo} "${habit.title}"?',
      confirmLabel: context.t.common.actions.delete,
      isDestructive: true,
      ref: ref,
    );
    if (confirmed) {
      unawaited(ref.read(goalsProvider.notifier).deleteHabit(habit.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final habits = ref.watch(goalsProvider).where((g) => g.isActiveOn(now)).toList();
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final settings = ref.watch(settingsProvider);
    final isPro = settings.isPro;
    final currentHabitsCount = habits.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 20),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const EvolveGrabber(),
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Text(
                      context.t.habits.manageHabits,
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
                      icon: Icon(
                        LucideIcons.x,
                        color: context.appColors.mutedForeground,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                Text(
                  context.t.habits.dragToReorder,
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
                    border: Border.all(
                      color: context.appColors.border,
                      width: 1,
                    ),
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
                              color: context.appColors.border.withValues(
                                alpha: 0.3,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.plus,
                              size: 14,
                              color: context.appColors.foreground,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _editingHabit != null
                                ? context.t.habits.editHabit
                                : context.t.habits.addHabit,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: context.appColors.foreground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      EvolveSectionHeader(
                        context.t.habits.habitName,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        style: TextStyle(
                          color: context.appColors.foreground,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: context.t.habits.eGDrinkWaterRead,
                          hintStyle: TextStyle(
                            color: context.appColors.mutedForeground.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          filled: true,
                          fillColor: context.appColors.background.withValues(
                            alpha: 0.5,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.appColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      EvolveSectionHeader(
                        context.t.habits.color,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 10),
                      EvolveColorSwatchGrid(
                        selected: _selectedColor,
                        onChanged: (color) =>
                            setState(() => _selectedColor = color),
                      ),
                      const SizedBox(height: 16),
                      EvolveSectionHeader(
                        context.t.habits.reminder,
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _showCupertinoTimePicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: context.appColors.background.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.appColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _reminderTime != null
                                    ? AppTimeFormatting.formatStoredTime(
                                        _reminderTime!,
                                        use24hFormat: settings.timeFormat24h,
                                      )
                                    : context.t.common.none,
                                style: TextStyle(
                                  color: _reminderTime != null
                                      ? context.appColors.foreground
                                      : context.appColors.mutedForeground,
                                  fontSize: 15,
                                ),
                              ),
                              if (_reminderTime != null)
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.x,
                                    size: 16,
                                    color: context.appColors.mutedForeground,
                                  ),
                                  onPressed: () =>
                                      setState(() => _reminderTime = null),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                )
                              else
                                Icon(
                                  LucideIcons.bell,
                                  size: 16,
                                  color: context.appColors.mutedForeground,
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Auto-verified habits (D5) — rendered only when the
                      // feature is enabled; dark otherwise.
                      if (VerificationConfig.enabled) ...[
                        const SizedBox(height: 16),
                        VerificationRuleField(
                          rule: _verificationRule,
                          onChanged: (r) =>
                              setState(() => _verificationRule = r),
                        ),
                        // Proactive "grant Health access" affordance (D9) for
                        // HealthKit rules — requests read access up front instead
                        // of waiting to infer denial from couldn't-verify days.
                        if (_verificationRule?.isHealthKit ?? false) ...[
                          const SizedBox(height: 8),
                          EvolveButton(
                            label: 'Grant Health access',
                            style: EvolveButtonStyle.secondary,
                            onPressed: _grantHealthAccess,
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),
                      if (_editingHabit != null)
                        Row(
                          children: [
                            Expanded(
                              child: EvolveButton(
                                label: context.t.common.actions.cancel,
                                style: EvolveButtonStyle.secondary,
                                onPressed: () => setState(() {
                                  _editingHabit = null;
                                  _nameController.clear();
                                  _reminderTime = null;
                                  _verificationRule = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: EvolveButton(
                                label: context.t.habits.update,
                                onPressed: _onSave,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        if (!isPro && currentHabitsCount >= 5) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEAB308,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFFEAB308,
                                ).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  LucideIcons.lock,
                                  color: Color(0xFFEAB308),
                                  size: 16,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Hai riempito gli slot abitudini gratuite (5/5). Sblocca slot illimitati con Evolve Pro.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Color(0xFFEAB308),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              if (!isPro && currentHabitsCount >= 5) {
                                ref.hapticHeavy();
                                Navigator.pop(
                                  context,
                                ); // Close the habit management sheet
                                Navigator.push(
                                  context,
                                  SubscriptionScreen.route(),
                                ); // Redirect to payment!
                              } else {
                                _onSave();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  (!isPro && currentHabitsCount >= 5)
                                  ? const Color(0xFFEAB308)
                                  : Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  (!isPro && currentHabitsCount >= 5)
                                  ? Colors.black
                                  : (_selectedColor.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!isPro && currentHabitsCount >= 5) ...[
                                  const Icon(
                                    LucideIcons.sparkles,
                                    size: 16,
                                    color: Colors.black,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  (!isPro && currentHabitsCount >= 5)
                                      ? context.t.common.unlockEvolvePro
                                      : context.t.habits.addHabit,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
                                    color: (!isPro && currentHabitsCount >= 5)
                                        ? Colors.black
                                        : (Theme.of(context).colorScheme.primary
                                                      .computeLuminance() >
                                                  0.5
                                              ? Colors.black
                                              : Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Habits List Section Header
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.t.common.habits,
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
            onReorderItem: (oldIndex, newIndex) {
              ref.read(goalsProvider.notifier).reorder(oldIndex, newIndex);
              ref.hapticLight();
            },
            itemBuilder: (context, index) {
              final habit = habits[index];
              return _HabitListItem(
                key: ValueKey(habit.id),
                index: index,
                habit: habit,
                onEdit: () => _onEdit(habit),
                onDelete: () => unawaited(_showDeleteConfirmation(habit)),
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
              child: Icon(
                LucideIcons.gripVertical,
                size: 16,
                color: context.appColors.mutedForeground,
              ),
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
                BoxShadow(
                  color: habit.color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
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
          if (habit.isVerified) ...[
            const VerificationBadge(),
            const SizedBox(width: 4),
          ],
          IconButton(
            onPressed: onEdit,
            icon: Icon(
              LucideIcons.pencil,
              size: 16,
              color: context.appColors.mutedForeground,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              LucideIcons.trash2,
              size: 16,
              color: AppColors.destructive,
            ),
          ),
        ],
      ),
    );
  }
}
