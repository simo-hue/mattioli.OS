import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/core/macro_targets_config.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/shared/widgets/target_ring.dart';
import 'package:evolve_targets/evolve_targets.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/search/application/goal_nav_target.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CreateGoalDialog extends ConsumerStatefulWidget {
  const CreateGoalDialog({
    super.key,
    this.initialTitle,
    this.jumpAfterCreate = false,
  });

  /// Pre-fills the title field — used by the ⌘K "Create goal “…”" row.
  final String? initialTitle;

  /// When true, after a successful save the Goals page jumps to the new goal's
  /// period. The palette sets this; the dashboard's own + button leaves it off.
  final bool jumpAfterCreate;

  @override
  ConsumerState<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends ConsumerState<CreateGoalDialog> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController(
    text: t.createGoal.defaultCategory,
  );
  final _amountController = TextEditingController();

  /// Optional numeric target (behind [DesktopMacroTargetsConfig]). Null unit ⇒
  /// a plain boolean macro goal, as today. Null [_linkedGoalId] ⇒ manual entry.
  TargetUnit? _targetUnit;
  String? _linkedGoalId;

  /// Sentinel option value for "no numeric target" in the unit picker.
  static const _kNoTarget = '__evolve_no_target__';

  /// Sentinel option value for "manual entry" in the link picker.
  static const _kManual = '__evolve_manual__';

  GoalType _selectedType = GoalType.monthly;
  bool _isLoading = false;
  bool _isNewCategory = false;
  String? _selectedCategoryLabel;

  // The exact period the goal is filed under. Defaults to the current period
  // (initState) but the user can now pick any year/quarter/month/week.
  late int _selectedYear;
  late int _selectedQuarter;
  late int _selectedMonth;
  late int _selectedWeek;

  /// Sentinel option value for the "create new category" row in the picker.
  static const _kNewCategory = '__evolve_new_category__';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedQuarter = ((now.month - 1) ~/ 3) + 1;
    _selectedMonth = now.month;
    _selectedWeek = logicalWeekOfMonth(now);
    final initial = widget.initialTitle?.trim() ?? '';
    if (initial.isNotEmpty) _titleController.text = initial;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  List<DesktopGoalCategory> _activeCategories() =>
      (ref.read(desktopGoalCategoriesControllerProvider).value ??
              const <DesktopGoalCategory>[])
          .where((c) => !c.isArchived)
          .toList();

  /// The goal category as a plain string for `addGoal`: the typed name in
  /// "create new" mode (or when there are no saved categories yet), otherwise
  /// the selected existing category's label.
  String _resolveCategory() {
    final categories = _activeCategories();
    if (categories.isEmpty || _isNewCategory) {
      final typed = _categoryController.text.trim();
      return typed.isEmpty ? t.createGoal.defaultCategory : typed;
    }
    return _selectedCategoryLabel ?? categories.first.label;
  }

  /// A goal has no colour of its own — [DashboardGoal] re-derives it from its
  /// category on every load (`dashboardGoalColor`), so the goal's colour IS its
  /// category's colour. Mirror the quick-add bar (`goals_page`): use the selected
  /// category's colour, else the built-in mapping for a typed/new category.
  Color _resolveGoalColor() {
    final categories = _activeCategories();
    if (!(categories.isEmpty || _isNewCategory)) {
      final label = _selectedCategoryLabel ?? categories.first.label;
      for (final category in categories) {
        if (category.label == label) return category.color;
      }
    }
    return dashboardGoalColor(_resolveCategory());
  }

  /// Category picker — an [EvolveSelect] of the saved categories plus a
  /// "create new category" row that reveals an inline text field (so a brand
  /// new category can still be typed), matching the goal editor's control. Falls
  /// back to a plain text field when there are no saved categories yet.
  Widget _categoryField(
    BuildContext context,
    List<DesktopGoalCategory> categories,
  ) {
    if (categories.isEmpty) {
      return TextField(
        controller: _categoryController,
        decoration: InputDecoration(hintText: t.createGoal.categoryHint),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EvolveSelect<String>(
          value: _isNewCategory
              ? _kNewCategory
              : (_selectedCategoryLabel ?? categories.first.label),
          expand: true,
          height: 46,
          fillColor: context.evolveColors.background.withValues(alpha: 0.5),
          options: [
            for (final category in categories)
              EvolveSelectOption(
                value: category.label,
                label: category.label,
                leading: CircleAvatar(
                  radius: 4,
                  backgroundColor: category.color,
                ),
              ),
            EvolveSelectOption(
              value: _kNewCategory,
              label: t.goalsPage.newCategory,
              leading: Icon(
                LucideIcons.plus,
                size: 13,
                color: context.evolveAccent,
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              if (value == _kNewCategory) {
                _isNewCategory = true;
                _categoryController.clear();
              } else {
                _isNewCategory = false;
                _selectedCategoryLabel = value;
              }
            });
          },
        ),
        if (_isNewCategory) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _categoryController,
            autofocus: true,
            decoration: InputDecoration(hintText: t.createGoal.categoryHint),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
        ],
      ],
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final category = _resolveCategory();

    setState(() => _isLoading = true);

    // Only the sub-fields meaningful for the chosen type are sent; the rest stay
    // null (the controller normalises anyway).
    final type = _selectedType;
    final year = type == GoalType.lifetime ? null : _selectedYear;
    final quarter = type == GoalType.quarterly ? _selectedQuarter : null;
    final month = (type == GoalType.monthly || type == GoalType.weekly)
        ? _selectedMonth
        : null;
    final weekNumber = type == GoalType.weekly ? _selectedWeek : null;
    final dueLabel = dashboardGoalDueLabel(
      type: type,
      year: year,
      quarter: quarter,
      month: month,
      weekNumber: weekNumber,
    );

    // Attach the numeric target only when the feature is live AND a unit was
    // chosen; otherwise the goal is exactly the boolean goal shipped today.
    final unit = DesktopMacroTargetsConfig.enabled ? _targetUnit : null;
    final typedAmount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    final targetAmount =
        unit == null ? null : (typedAmount == null || typedAmount <= 0
            ? 1.0
            : typedAmount);

    try {
      await ref
          .read(dashboardControllerProvider.notifier)
          .addGoal(
            title: title,
            category: category,
            color: _resolveGoalColor(),
            type: type,
            dueLabel: dueLabel,
            year: year,
            quarter: quarter,
            month: month,
            weekNumber: weekNumber,
            targetAmount: targetAmount,
            targetUnit: unit?.wireName,
            linkedGoalId: unit == null ? null : _linkedGoalId,
          );
      if (widget.jumpAfterCreate) {
        // Land the Goals page on exactly the period we just filed under (no id
        // highlight — the created goal's id can be swapped by the server sync).
        ref
            .read(goalNavTargetProvider.notifier)
            .set(
              GoalNavTarget(
                type: type,
                year: year,
                quarter: quarter,
                month: month,
                week: weekNumber,
              ),
            );
        ref
            .read(navigationControllerProvider.notifier)
            .select(DesktopSection.goals);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Period selectors, shown only for time-bound goal types. Which selectors
  /// appear depends on the chosen [GoalType]: annual→year, quarterly→year+Q,
  /// monthly→year+month, weekly→year+month+week.
  Widget _periodPicker(BuildContext context) {
    if (_selectedType == GoalType.lifetime) return const SizedBox.shrink();
    final now = DateTime.now();
    final years = [for (var y = now.year - 1; y <= now.year + 5; y++) y];
    final fill = context.evolveColors.background.withValues(alpha: 0.5);

    final row = <Widget>[
      Expanded(
        child: EvolveSelect<int>(
          value: _selectedYear,
          expand: true,
          height: 46,
          fillColor: fill,
          options: [
            for (final y in years) EvolveSelectOption(value: y, label: '$y'),
          ],
          onChanged: (y) => setState(() {
            _selectedYear = y;
            _clampWeek();
          }),
        ),
      ),
    ];
    if (_selectedType == GoalType.quarterly) {
      row.add(const SizedBox(width: 8));
      row.add(
        Expanded(
          child: EvolveSelect<int>(
            value: _selectedQuarter,
            expand: true,
            height: 46,
            fillColor: fill,
            options: [
              for (var q = 1; q <= 4; q++)
                EvolveSelectOption(value: q, label: 'Q$q'),
            ],
            onChanged: (q) => setState(() => _selectedQuarter = q),
          ),
        ),
      );
    }
    if (_selectedType == GoalType.monthly || _selectedType == GoalType.weekly) {
      row.add(const SizedBox(width: 8));
      row.add(
        Expanded(
          child: EvolveSelect<int>(
            value: _selectedMonth,
            expand: true,
            height: 46,
            fillColor: fill,
            options: [
              for (var m = 1; m <= 12; m++)
                EvolveSelectOption(value: m, label: t.common.months[m - 1]),
            ],
            onChanged: (m) => setState(() {
              _selectedMonth = m;
              _clampWeek();
            }),
          ),
        ),
      );
    }
    if (_selectedType == GoalType.weekly) {
      final weeks = logicalWeeksInMonth(_selectedYear, _selectedMonth);
      row.add(const SizedBox(width: 8));
      row.add(
        Expanded(
          child: EvolveSelect<int>(
            value: _selectedWeek,
            expand: true,
            height: 46,
            fillColor: fill,
            options: [
              for (var w = 1; w <= weeks; w++)
                EvolveSelectOption(
                  value: w,
                  label: '${t.common.calendarView.week} $w',
                ),
            ],
            onChanged: (w) => setState(() => _selectedWeek = w),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        EvolveFieldLabel(t.createGoal.periodWhen),
        const SizedBox(height: 8),
        Row(children: row),
      ],
    );
  }

  void _clampWeek() {
    final weeks = logicalWeeksInMonth(_selectedYear, _selectedMonth);
    if (_selectedWeek > weeks) _selectedWeek = weeks;
  }

  String _unitLabel(TargetUnit unit) => unit == TargetUnit.count
      ? t.macroTargets.unitCount
      : targetUnitShortLabel(unit);

  /// Optional numeric-target section — a unit picker ("None" + each
  /// [TargetUnit]), an amount field, and a "track with a habit" picker (Manual +
  /// the user's habits). Only shown behind [DesktopMacroTargetsConfig]; while
  /// dark the dialog is exactly today's boolean-goal creator.
  Widget _targetSection(BuildContext context) {
    if (!DesktopMacroTargetsConfig.enabled) return const SizedBox.shrink();
    final fill = context.evolveColors.background.withValues(alpha: 0.5);
    final habits = ref.watch(dashboardControllerProvider).habits;
    final unitSet = _targetUnit != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        EvolveFieldLabel(t.macroTargets.sectionTitle),
        const SizedBox(height: 8),
        EvolveSelect<String>(
          value: _targetUnit?.wireName ?? _kNoTarget,
          expand: true,
          height: 46,
          fillColor: fill,
          options: [
            EvolveSelectOption(value: _kNoTarget, label: t.macroTargets.none),
            for (final unit in TargetUnit.values)
              EvolveSelectOption(value: unit.wireName, label: _unitLabel(unit)),
          ],
          onChanged: (value) => setState(() {
            _targetUnit =
                value == _kNoTarget ? null : TargetUnit.fromWire(value);
            if (_targetUnit == null) _linkedGoalId = null;
          }),
        ),
        if (unitSet) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    hintText: t.macroTargets.amountLabel,
                  ),
                ),
              ),
              if (_unitLabel(_targetUnit!).isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  _unitLabel(_targetUnit!),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.evolveColors.foreground,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          EvolveFieldLabel(t.macroTargets.linkLabel),
          const SizedBox(height: 8),
          EvolveSelect<String>(
            value: _linkedGoalId ?? _kManual,
            expand: true,
            height: 46,
            fillColor: fill,
            options: [
              EvolveSelectOption(value: _kManual, label: t.macroTargets.manual),
              for (final habit in habits)
                EvolveSelectOption(value: habit.id, label: habit.title),
            ],
            onChanged: (value) => setState(
              () => _linkedGoalId = value == _kManual ? null : value,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        (ref.watch(desktopGoalCategoriesControllerProvider).value ??
                const <DesktopGoalCategory>[])
            .where((c) => !c.isArchived)
            .toList();
    return EvolveAlertDialog(
      maxWidth: 480,
      icon: LucideIcons.trophy,
      title: Text(t.createGoal.title),
      subtitle: t.createGoal.subtitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EvolveFieldLabel(t.form.title),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(hintText: t.createGoal.titleHint),
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          EvolveFieldLabel(t.form.category),
          const SizedBox(height: 8),
          _categoryField(context, categories),
          const SizedBox(height: 20),
          EvolveFieldLabel(t.createGoal.timeline),
          const SizedBox(height: 8),
          EvolveSelect<GoalType>(
            value: _selectedType,
            expand: true,
            height: 46,
            fillColor: context.evolveColors.background.withValues(alpha: 0.5),
            options: [
              EvolveSelectOption(
                value: GoalType.weekly,
                label: t.createGoal.thisWeek,
              ),
              EvolveSelectOption(
                value: GoalType.monthly,
                label: t.createGoal.thisMonth,
              ),
              EvolveSelectOption(
                value: GoalType.quarterly,
                label: t.createGoal.thisQuarter,
              ),
              EvolveSelectOption(
                value: GoalType.annual,
                label: t.createGoal.thisYear,
              ),
              EvolveSelectOption(
                value: GoalType.lifetime,
                label: t.createGoal.longTerm,
              ),
            ],
            onChanged: (val) => setState(() => _selectedType = val),
          ),
          _periodPicker(context),
          _targetSection(context),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(t.common.actions.cancel),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox.square(
                  dimension: 16,
                  child: EvolveSpinner(radius: 8),
                )
              : Text(t.form.add),
        ),
      ],
    );
  }
}
