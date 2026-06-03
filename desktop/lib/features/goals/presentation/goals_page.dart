import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  late GoalType _selectedType;
  late int _selectedYear;
  late int _selectedQuarter;
  late int _selectedMonth;
  late int _selectedWeek;
  bool _showStats = false;
  final _quickGoalController = TextEditingController();
  _GoalCategory? _quickGoalCategory;
  final _categories = [..._defaultGoalCategories];
  final _archivedCategoryIds = <String>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedType = GoalType.weekly;
    _selectedYear = now.year;
    _selectedQuarter = ((now.month - 1) ~/ 3) + 1;
    _selectedMonth = now.month;
    _selectedWeek = logicalWeekOfMonth(now);
  }

  @override
  void dispose() {
    _quickGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(desktopGoalCategoriesControllerProvider);
    final allGoals = ref.watch(dashboardControllerProvider).goals;
    final goals = allGoals.where(_matchesPeriod).toList()..sort(_sortGoals);

    final activeGoals = goals
        .where((goal) => goal.state == GoalState.active)
        .toList();
    final completedGoals = goals
        .where((goal) => goal.state == GoalState.completed)
        .toList();
    final failedGoals = goals
        .where((goal) => goal.state == GoalState.failed)
        .toList();

    return DesktopPage(
      title: 'Macro Obiettivi',
      subtitle: 'Pianificazione a lungo termine.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.evolveColors.panel.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.evolveColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GoalToolbar(
                selectedType: _selectedType,
                showStats: _showStats,
                onTypeChanged: (type) => setState(() {
                  _selectedType = type;
                  _showStats = false;
                }),
                onShowStats: () => setState(() => _showStats = true),
              ),
              const SizedBox(height: 30),
              _GoalPeriodBar(
                selectedType: _selectedType,
                selectedYear: _selectedYear,
                selectedQuarter: _selectedQuarter,
                selectedMonth: _selectedMonth,
                selectedWeek: _selectedWeek,
                onYearChanged: (year) => setState(() {
                  _selectedYear = year;
                  _selectedWeek = _selectedWeek.clamp(
                    1,
                    logicalWeeksInMonth(_selectedYear, _selectedMonth),
                  );
                }),
                onQuarterChanged: (quarter) =>
                    setState(() => _selectedQuarter = quarter),
                onMonthChanged: (month) => setState(() {
                  _selectedMonth = month;
                  _selectedWeek = 1;
                }),
                onWeekChanged: (week) => setState(() => _selectedWeek = week),
                onPrevious: () => _movePeriod(-1),
                onNext: () => _movePeriod(1),
                onManageCategories: _openCategoryManager,
              ),
              const SizedBox(height: 30),
              if (_showStats)
                _GoalStats(goals: allGoals)
              else
                _GoalBoard(
                  periodTitle: _periodTitle,
                  periodSubtitle: _periodSubtitle,
                  quickGoalController: _quickGoalController,
                  quickGoalCategory: _quickGoalCategory,
                  categories: _availableCategories,
                  activeGoals: activeGoals,
                  completedGoals: completedGoals,
                  failedGoals: failedGoals,
                  onQuickCategoryChanged: (category) =>
                      setState(() => _quickGoalCategory = category),
                  onQuickSubmit: _submitQuickGoal,
                  onToggleStatus: _cycleGoalStatus,
                  onEdit: _openGoalEditorFor,
                  onReschedule: (goal) => ref
                      .read(dashboardControllerProvider.notifier)
                      .rescheduleGoal(goal.id),
                  onDelete: (goal) => ref
                      .read(dashboardControllerProvider.notifier)
                      .deleteGoal(goal.id),
                  quickGoalHint: _quickGoalHint,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _periodLabel {
    return switch (_selectedType) {
      GoalType.lifetime => 'Obiettivi di vita',
      GoalType.annual => '$_selectedYear',
      GoalType.quarterly => 'Q$_selectedQuarter $_selectedYear',
      GoalType.monthly => '${_months[_selectedMonth - 1]} $_selectedYear',
      GoalType.weekly =>
        'Settimana $_selectedWeek, ${_months[_selectedMonth - 1]} $_selectedYear',
    };
  }

  String get _periodTitle {
    return switch (_selectedType) {
      GoalType.lifetime => 'Lifetime',
      GoalType.annual => '$_selectedYear',
      GoalType.quarterly => 'Trimestre $_selectedQuarter',
      GoalType.monthly => _months[_selectedMonth - 1],
      GoalType.weekly => 'Settimana $_selectedWeek',
    };
  }

  String get _periodSubtitle {
    return switch (_selectedType) {
      GoalType.lifetime => 'Obiettivi Lifetime',
      GoalType.annual => 'Obiettivi Annuali',
      GoalType.quarterly => 'Obiettivi Trimestrali',
      GoalType.monthly => 'Obiettivi Mensili',
      GoalType.weekly => 'Obiettivi Settimanali',
    };
  }

  String get _quickGoalHint {
    return switch (_selectedType) {
      GoalType.lifetime => 'Aggiungi macro obiettivo lifetime...',
      GoalType.annual => 'Aggiungi obiettivo annuale...',
      GoalType.quarterly => 'Aggiungi obiettivo trimestrale...',
      GoalType.monthly => 'Aggiungi obiettivo mensile...',
      GoalType.weekly => 'Aggiungi obiettivo settimanale...',
    };
  }

  bool _matchesPeriod(DashboardGoal goal) {
    final type = _selectedType;
    if (goal.type != type) return false;
    if (type == GoalType.lifetime) return true;
    if (goal.year != _selectedYear) return false;
    return switch (type) {
      GoalType.quarterly => goal.quarter == _selectedQuarter,
      GoalType.monthly => goal.month == _selectedMonth,
      GoalType.weekly =>
        goal.month == _selectedMonth && goal.weekNumber == _selectedWeek,
      _ => true,
    };
  }

  void _movePeriod(int direction) {
    setState(() {
      switch (_selectedType) {
        case GoalType.lifetime:
          return;
        case GoalType.annual:
          _selectedYear += direction;
        case GoalType.quarterly:
          _selectedQuarter += direction;
          if (_selectedQuarter > 4) {
            _selectedQuarter = 1;
            _selectedYear++;
          } else if (_selectedQuarter < 1) {
            _selectedQuarter = 4;
            _selectedYear--;
          }
        case GoalType.monthly:
          _selectedMonth += direction;
          if (_selectedMonth > 12) {
            _selectedMonth = 1;
            _selectedYear++;
          } else if (_selectedMonth < 1) {
            _selectedMonth = 12;
            _selectedYear--;
          }
        case GoalType.weekly:
          _selectedWeek += direction;
          if (_selectedWeek >
              logicalWeeksInMonth(_selectedYear, _selectedMonth)) {
            _selectedWeek = 1;
            _selectedMonth++;
            if (_selectedMonth > 12) {
              _selectedMonth = 1;
              _selectedYear++;
            }
          } else if (_selectedWeek < 1) {
            _selectedMonth--;
            if (_selectedMonth < 1) {
              _selectedMonth = 12;
              _selectedYear--;
            }
            _selectedWeek = logicalWeeksInMonth(_selectedYear, _selectedMonth);
          }
      }
    });
  }

  int _sortGoals(DashboardGoal a, DashboardGoal b) {
    final stateComparison = a.state.index.compareTo(b.state.index);
    if (stateComparison != 0) return stateComparison;
    return (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0));
  }

  Future<void> _submitQuickGoal() async {
    final title = _quickGoalController.text.trim();
    if (title.isEmpty) return;

    final category = _quickGoalCategory;
    await ref
        .read(dashboardControllerProvider.notifier)
        .addGoal(
          title: title,
          category: category?.key ?? '',
          color: category?.color ?? dashboardGoalColor(category?.key),
          type: _selectedType,
          dueLabel: _periodLabel,
          categoryId: category?.id,
          year: _selectedYear,
          quarter: _selectedQuarter,
          month: _selectedMonth,
          weekNumber: _selectedWeek,
        );
    _quickGoalController.clear();
  }

  Future<void> _cycleGoalStatus(DashboardGoal goal) async {
    final next = switch (goal.state) {
      GoalState.active => GoalState.completed,
      GoalState.completed => GoalState.failed,
      GoalState.failed => GoalState.active,
    };
    await ref
        .read(dashboardControllerProvider.notifier)
        .updateGoalState(goal.id, next);
  }

  Future<void> _openGoalEditorFor(DashboardGoal goal) async {
    final categories = _availableCategories;
    final category = _categoryForGoal(goal, categories);
    final draft = await showEvolveDialog<_GoalDraft>(
      context: context,
      builder: (context) => _GoalEditorDialog(
        categories: categories,
        initialType: goal.type,
        goal: goal,
        initialCategory: category,
      ),
    );
    if (draft == null) return;
    await ref
        .read(dashboardControllerProvider.notifier)
        .updateGoal(
          id: goal.id,
          title: draft.title,
          category: draft.category.key ?? '',
          color: draft.category.color,
          categoryId: draft.category.id,
        );
  }

  Future<void> _openCategoryManager() async {
    await showEvolveDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return EvolveAlertDialog(
            icon: Icons.category_outlined,
            title: const Text('Categorie obiettivi'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final category in _availableCategories)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 7,
                        backgroundColor: category.color,
                      ),
                      title: Text(category.label),
                      trailing: category.isDefault
                          ? const StatusPill(label: 'Predefinita')
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Modifica categoria',
                                  onPressed: () async {
                                    await _editCategory(category);
                                    setDialogState(() {});
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Archivia categoria',
                                  onPressed: () {
                                    _archiveCategory(category);
                                    setDialogState(() {});
                                  },
                                  icon: const Icon(Icons.archive_outlined),
                                ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  final category = await showEvolveDialog<_GoalCategory>(
                    context: context,
                    builder: (context) => const _CategoryEditorDialog(),
                  );
                  if (category == null) return;
                  DesktopGoalCategory? cloudCategory;
                  try {
                    cloudCategory = await ref
                        .read(desktopGoalCategoriesControllerProvider.notifier)
                        .addCategory(category.label, category.color);
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Creazione categoria non riuscita.'),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _categories.add(
                      cloudCategory == null
                          ? category
                          : _GoalCategory(
                              id: cloudCategory.id,
                              label: cloudCategory.label,
                              color: cloudCategory.color,
                            ),
                    );
                  });
                  setDialogState(() {});
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Aggiungi categoria'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Chiudi'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_GoalCategory> get _availableCategories {
    final categories = [..._categories];
    final remote =
        ref.read(desktopGoalCategoriesControllerProvider).value ?? const [];
    for (final category in remote) {
      if (category.isArchived) continue;
      if (_archivedCategoryIds.contains(category.id)) continue;
      if (categories.any((item) => item.id == category.id)) continue;
      categories.add(
        _GoalCategory(
          id: category.id,
          label: category.label,
          color: category.color,
        ),
      );
    }
    return categories;
  }

  Future<void> _archiveCategory(_GoalCategory category) async {
    setState(() {
      _categories.remove(category);
      if (category.id != null) _archivedCategoryIds.add(category.id!);
    });
    final id = category.id;
    if (id == null) return;
    try {
      await ref
          .read(desktopGoalCategoriesControllerProvider.notifier)
          .archiveCategory(id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _archivedCategoryIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archivio categoria non riuscito.')),
      );
    }
  }

  Future<void> _editCategory(_GoalCategory category) async {
    final updated = await showEvolveDialog<_GoalCategory>(
      context: context,
      builder: (context) => _CategoryEditorDialog(category: category),
    );
    if (updated == null) return;

    final id = category.id;
    if (id != null) {
      try {
        await ref
            .read(desktopGoalCategoriesControllerProvider.notifier)
            .updateCategory(id, updated.label, updated.color);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modifica categoria non riuscita.')),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      final index = _categories.indexOf(category);
      if (index != -1) {
        _categories[index] = updated.copyWith(id: id);
      }
    });
  }
}

class _GoalToolbar extends StatelessWidget {
  const _GoalToolbar({
    required this.selectedType,
    required this.showStats,
    required this.onTypeChanged,
    required this.onShowStats,
  });

  final GoalType selectedType;
  final bool showStats;
  final ValueChanged<GoalType> onTypeChanged;
  final VoidCallback onShowStats;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Container(
          height: 54,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: context.evolveColors.panelRaised.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.evolveColors.border),
          ),
          child: Row(
            children: [
              _GoalModeTab(
                label: 'Lifetime',
                active: !showStats && selectedType == GoalType.lifetime,
                onTap: () => onTypeChanged(GoalType.lifetime),
              ),
              _GoalModeTab(
                label: 'Annuale',
                active: !showStats && selectedType == GoalType.annual,
                onTap: () => onTypeChanged(GoalType.annual),
              ),
              _GoalModeTab(
                label: 'Trimestrale',
                active: !showStats && selectedType == GoalType.quarterly,
                onTap: () => onTypeChanged(GoalType.quarterly),
              ),
              _GoalModeTab(
                label: 'Mensile',
                active: !showStats && selectedType == GoalType.monthly,
                onTap: () => onTypeChanged(GoalType.monthly),
              ),
              _GoalModeTab(
                label: 'Settimanale',
                active: !showStats && selectedType == GoalType.weekly,
                onTap: () => onTypeChanged(GoalType.weekly),
              ),
              _GoalModeTab(
                label: 'Stats',
                icon: Icons.pie_chart_outline_rounded,
                active: showStats,
                onTap: onShowStats,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalModeTab extends StatelessWidget {
  const _GoalModeTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.black.withValues(alpha: 0.72) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 17,
                  color: active ? colors.foreground : colors.muted,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? colors.foreground : colors.muted,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalPeriodBar extends StatelessWidget {
  const _GoalPeriodBar({
    required this.selectedType,
    required this.selectedYear,
    required this.selectedQuarter,
    required this.selectedMonth,
    required this.selectedWeek,
    required this.onYearChanged,
    required this.onQuarterChanged,
    required this.onMonthChanged,
    required this.onWeekChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onManageCategories,
  });

  final GoalType selectedType;
  final int selectedYear;
  final int selectedQuarter;
  final int selectedMonth;
  final int selectedWeek;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onQuarterChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    final showPeriod = selectedType != GoalType.lifetime;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: context.evolveColors.panelRaised.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: Row(
        children: [
          if (showPeriod) ...[
            _PeriodDropdown(
              value: selectedYear,
              values: [
                for (
                  var year = DateTime.now().year - 10;
                  year <= DateTime.now().year + 10;
                  year++
                )
                  year,
              ],
              labelFor: (value) => '$value',
              onChanged: onYearChanged,
            ),
            if (selectedType == GoalType.quarterly) ...[
              const SizedBox(width: 10),
              _PeriodDropdown(
                value: selectedQuarter,
                values: const [1, 2, 3, 4],
                labelFor: (value) => 'Q$value',
                onChanged: onQuarterChanged,
              ),
            ],
            if (selectedType == GoalType.monthly ||
                selectedType == GoalType.weekly) ...[
              const SizedBox(width: 10),
              _PeriodDropdown(
                value: selectedMonth,
                values: [for (var month = 1; month <= 12; month++) month],
                labelFor: (value) => _months[value - 1],
                onChanged: onMonthChanged,
              ),
            ],
            if (selectedType == GoalType.weekly) ...[
              const SizedBox(width: 10),
              _PeriodDropdown(
                value: selectedWeek,
                values: [
                  for (
                    var week = 1;
                    week <= logicalWeeksInMonth(selectedYear, selectedMonth);
                    week++
                  )
                    week,
                ],
                labelFor: (value) => 'Settimana $value',
                onChanged: onWeekChanged,
              ),
            ],
          ] else
            Text(
              'Visione completa',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const Spacer(),
          if (showPeriod) ...[
            _ToolbarIconButton(
              tooltip: 'Periodo precedente',
              icon: Icons.keyboard_arrow_left_rounded,
              onPressed: onPrevious,
            ),
            const SizedBox(width: 8),
            _ToolbarIconButton(
              tooltip: 'Periodo successivo',
              icon: Icons.keyboard_arrow_right_rounded,
              onPressed: onNext,
            ),
            const SizedBox(width: 12),
          ],
          _ToolbarIconButton(
            tooltip: 'Categorie',
            icon: Icons.tune_rounded,
            onPressed: onManageCategories,
          ),
        ],
      ),
    );
  }
}

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown({
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final int value;
  final List<int> values;
  final String Function(int value) labelFor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          items: [
            for (final item in values)
              DropdownMenuItem(value: item, child: Text(labelFor(item))),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          borderRadius: BorderRadius.circular(12),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.evolveColors.muted,
            size: 20,
          ),
          style: Theme.of(context).textTheme.titleMedium,
          dropdownColor: context.evolveColors.panelRaised,
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        foregroundColor: context.evolveColors.foreground,
        backgroundColor: Colors.black.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.evolveColors.borderStrong),
        ),
      ),
    );
  }
}

class _GoalBoard extends StatelessWidget {
  const _GoalBoard({
    required this.periodTitle,
    required this.periodSubtitle,
    required this.quickGoalController,
    required this.quickGoalCategory,
    required this.categories,
    required this.activeGoals,
    required this.completedGoals,
    required this.failedGoals,
    required this.onQuickCategoryChanged,
    required this.onQuickSubmit,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
    required this.quickGoalHint,
  });

  final String periodTitle;
  final String periodSubtitle;
  final String quickGoalHint;
  final TextEditingController quickGoalController;
  final _GoalCategory? quickGoalCategory;
  final List<_GoalCategory> categories;
  final List<DashboardGoal> activeGoals;
  final List<DashboardGoal> completedGoals;
  final List<DashboardGoal> failedGoals;
  final ValueChanged<_GoalCategory?> onQuickCategoryChanged;
  final VoidCallback onQuickSubmit;
  final ValueChanged<DashboardGoal> onToggleStatus;
  final ValueChanged<DashboardGoal> onEdit;
  final ValueChanged<DashboardGoal> onReschedule;
  final ValueChanged<DashboardGoal> onDelete;

  @override
  Widget build(BuildContext context) {
    final hasAnyGoal =
        activeGoals.isNotEmpty ||
        completedGoals.isNotEmpty ||
        failedGoals.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              periodTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: context.evolveAccent,
                fontSize: 24,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  periodSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.evolveColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _QuickGoalInput(
          controller: quickGoalController,
          category: quickGoalCategory,
          categories: categories,
          hintText: quickGoalHint,
          onCategoryChanged: onQuickCategoryChanged,
          onSubmit: onQuickSubmit,
        ),
        const SizedBox(height: 12),
        if (activeGoals.isEmpty)
          _GoalEmptyState(hasAnyGoal: hasAnyGoal)
        else
          for (final goal in activeGoals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalRow(
                goal: goal,
                categories: categories,
                onToggleStatus: onToggleStatus,
                onEdit: onEdit,
                onReschedule: onReschedule,
                onDelete: onDelete,
              ),
            ),
        if (completedGoals.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _StatusDivider(label: 'COMPLETATI', color: Color(0xFF10B981)),
          const SizedBox(height: 12),
          for (final goal in completedGoals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalRow(
                goal: goal,
                categories: categories,
                onToggleStatus: onToggleStatus,
                onEdit: onEdit,
                onReschedule: onReschedule,
                onDelete: onDelete,
              ),
            ),
        ],
        if (failedGoals.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _StatusDivider(label: 'FALLITI', color: EvolveColors.rose),
          const SizedBox(height: 12),
          for (final goal in failedGoals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalRow(
                goal: goal,
                categories: categories,
                onToggleStatus: onToggleStatus,
                onEdit: onEdit,
                onReschedule: onReschedule,
                onDelete: onDelete,
              ),
            ),
        ],
      ],
    );
  }
}

class _QuickGoalInput extends StatelessWidget {
  const _QuickGoalInput({
    required this.controller,
    required this.category,
    required this.categories,
    required this.hintText,
    required this.onCategoryChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final _GoalCategory? category;
  final List<_GoalCategory> categories;
  final String hintText;
  final ValueChanged<_GoalCategory?> onCategoryChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final categoryColor = category?.color;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSubmit(),
              style: Theme.of(context).textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: hintText,
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.evolveColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.evolveColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: context.evolveColors.foreground,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<Object>(
          tooltip: 'Scegli categoria',
          onSelected: (value) =>
              onCategoryChanged(value is _GoalCategory ? value : null),
          color: context.evolveColors.panelRaised,
          itemBuilder: (context) => [
            const PopupMenuItem<Object>(
              value: _QuickGoalCategoryAction.clear,
              child: Text('Default'),
            ),
            for (final item in categories)
              PopupMenuItem<Object>(
                value: item,
                child: Row(
                  children: [
                    CircleAvatar(radius: 5, backgroundColor: item.color),
                    const SizedBox(width: 10),
                    Text(item.label),
                  ],
                ),
              ),
          ],
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.evolveColors.border),
            ),
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: categoryColor?.withValues(alpha: 0.25),
                  border: Border.all(
                    color: categoryColor ?? context.evolveColors.borderStrong,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 54,
          height: 54,
          child: FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Icon(Icons.add_rounded, size: 25),
          ),
        ),
      ],
    );
  }
}

enum _QuickGoalCategoryAction { clear }

class _GoalEmptyState extends StatelessWidget {
  const _GoalEmptyState({required this.hasAnyGoal});

  final bool hasAnyGoal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: Row(
        children: [
          Icon(
            hasAnyGoal
                ? Icons.check_circle_outline_rounded
                : Icons.flag_outlined,
            color: context.evolveColors.subtle,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            hasAnyGoal
                ? 'Nessun obiettivo attivo in questo periodo.'
                : 'Aggiungi il primo obiettivo per questo periodo.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.categories,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
  });

  final DashboardGoal goal;
  final List<_GoalCategory> categories;
  final ValueChanged<DashboardGoal> onToggleStatus;
  final ValueChanged<DashboardGoal> onEdit;
  final ValueChanged<DashboardGoal> onReschedule;
  final ValueChanged<DashboardGoal> onDelete;

  @override
  Widget build(BuildContext context) {
    final category = _categoryForGoal(goal, categories);
    final completed = goal.state == GoalState.completed;
    final failed = goal.state == GoalState.failed;
    final statusColor = completed
        ? const Color(0xFF10B981)
        : failed
        ? EvolveColors.rose
        : category.color;

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: failed ? 0.055 : 0.075),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          _GoalCheckButton(
            state: goal.state,
            onPressed: () => onToggleStatus(goal),
          ),
          const SizedBox(width: 16),
          if (!completed && !failed) ...[
            CircleAvatar(radius: 4, backgroundColor: category.color),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              goal.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: completed
                    ? const Color(0xFF10B981).withValues(alpha: 0.72)
                    : failed
                    ? EvolveColors.rose.withValues(alpha: 0.7)
                    : context.evolveColors.foreground,
                decoration: completed || failed
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationColor: statusColor.withValues(alpha: 0.55),
                decorationThickness: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _GoalActionsMenu(
            goal: goal,
            onEdit: onEdit,
            onReschedule: onReschedule,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _GoalCheckButton extends StatelessWidget {
  const _GoalCheckButton({required this.state, required this.onPressed});

  final GoalState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final completed = state == GoalState.completed;
    final failed = state == GoalState.failed;
    final color = completed
        ? const Color(0xFF10B981)
        : failed
        ? EvolveColors.rose
        : context.evolveColors.borderStrong;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: completed || failed ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1.4),
        ),
        child: completed
            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
            : failed
            ? const Icon(Icons.close_rounded, size: 15, color: Colors.white)
            : null,
      ),
    );
  }
}

class _GoalActionsMenu extends StatelessWidget {
  const _GoalActionsMenu({
    required this.goal,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
  });

  final DashboardGoal goal;
  final ValueChanged<DashboardGoal> onEdit;
  final ValueChanged<DashboardGoal> onReschedule;
  final ValueChanged<DashboardGoal> onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Azioni obiettivo',
      color: context.evolveColors.panelRaised,
      icon: Icon(
        Icons.more_horiz_rounded,
        color: context.evolveColors.subtle,
        size: 21,
      ),
      onSelected: (action) {
        switch (action) {
          case 'edit':
            onEdit(goal);
          case 'reschedule':
            onReschedule(goal);
          case 'delete':
            onDelete(goal);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Modifica')),
        if (goal.state == GoalState.failed && goal.type != GoalType.lifetime)
          const PopupMenuItem(value: 'reschedule', child: Text('Ripianifica')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('Elimina')),
      ],
    );
  }
}

class _StatusDivider extends StatelessWidget {
  const _StatusDivider({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: color.withValues(alpha: 0.25))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
            ),
          ),
        ),
        Expanded(child: Divider(color: color.withValues(alpha: 0.25))),
      ],
    );
  }
}

class _GoalStats extends ConsumerWidget {
  const _GoalStats({required this.goals});

  final List<DashboardGoal> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rpc = ref.watch(macroGoalsStatsRpcProvider('all')).value ?? const {};
    final completed = goals
        .where((goal) => goal.state == GoalState.completed)
        .length;
    final localSuccess = goals.isEmpty
        ? 0
        : (completed / goals.length * 100).round();
    final total = (rpc['total_goals'] as num?)?.toInt() ?? goals.length;
    final completedTotal =
        (rpc['completed_goals'] as num?)?.toInt() ?? completed;
    final success = (rpc['success_rate'] as num?)?.round() ?? localSuccess;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Kpi(label: 'Totale', value: '$total'),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Kpi(label: 'Completati', value: '$completedTotal'),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _Kpi(label: 'Success rate', value: '$success%'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        EvolvePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                title: 'Distribuzione per orizzonte',
                subtitle:
                    'Sintesi calcolata dai dati sincronizzati con arricchimento RPC',
              ),
              const SizedBox(height: 18),
              for (final type in GoalType.values) ...[
                _TypeProgress(type: type, goals: goals),
                if (type != GoalType.values.last) const SizedBox(height: 13),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 7),
          Text(
            value,
            style: TextStyle(
              color: context.evolveColors.foreground,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeProgress extends StatelessWidget {
  const _TypeProgress({required this.type, required this.goals});

  final GoalType type;
  final List<DashboardGoal> goals;

  @override
  Widget build(BuildContext context) {
    final count = goals.where((goal) => goal.type == type).length;
    final value = goals.isEmpty ? 0.0 : count / goals.length;
    return Row(
      children: [
        SizedBox(width: 110, child: Text(type.label)),
        Expanded(
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            color: EvolveColors.cyan,
            backgroundColor: context.evolveColors.panelSoft,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 24, child: Text('$count')),
      ],
    );
  }
}

class _GoalEditorDialog extends StatefulWidget {
  const _GoalEditorDialog({
    required this.categories,
    required this.initialType,
    this.goal,
    this.initialCategory,
  });

  final List<_GoalCategory> categories;
  final GoalType initialType;
  final DashboardGoal? goal;
  final _GoalCategory? initialCategory;

  @override
  State<_GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends State<_GoalEditorDialog> {
  final _title = TextEditingController();
  late GoalType _type;
  late _GoalCategory _category;

  @override
  void initState() {
    super.initState();
    _title.text = widget.goal?.title ?? '';
    _type = widget.initialType;
    _category =
        widget.categories
            .where((item) => item == widget.initialCategory)
            .firstOrNull ??
        widget.categories.first;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      icon: Icons.flag_outlined,
      title: Text(
        widget.goal == null ? 'Nuovo obiettivo' : 'Modifica obiettivo',
      ),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Titolo'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GoalType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Orizzonte'),
              items: [
                for (final type in GoalType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_GoalCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                for (final category in widget.categories)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(
              context,
              _GoalDraft(
                title: title,
                category: _category,
                type: _type,
                dueLabel: _dueLabelFor(_type),
              ),
            );
          },
          child: Text(widget.goal == null ? 'Crea' : 'Salva'),
        ),
      ],
    );
  }
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({this.category});

  final _GoalCategory? category;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _name;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.label ?? '');
    _color = widget.category?.color ?? EvolveColors.cyan;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      icon: Icons.palette_outlined,
      title: Text(
        widget.category == null ? 'Nuova categoria' : 'Modifica categoria',
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 9,
              children: [
                for (final color in _goalColors)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: color,
                      child: _color == color
                          ? const Icon(Icons.check_rounded, size: 15)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _GoalCategory(label: _name.text.trim(), color: _color),
            );
          },
          child: Text(widget.category == null ? 'Aggiungi' : 'Salva'),
        ),
      ],
    );
  }
}

class _GoalDraft {
  const _GoalDraft({
    required this.title,
    required this.category,
    required this.type,
    required this.dueLabel,
  });

  final String title;
  final _GoalCategory category;
  final GoalType type;
  final String dueLabel;
}

class _GoalCategory {
  const _GoalCategory({
    this.id,
    this.key,
    required this.label,
    required this.color,
    this.isDefault = false,
  });

  final String? id;
  final String? key;
  final String label;
  final Color color;
  final bool isDefault;

  _GoalCategory copyWith({
    String? id,
    String? key,
    String? label,
    Color? color,
  }) {
    return _GoalCategory(
      id: id ?? this.id,
      key: key ?? this.key,
      label: label ?? this.label,
      color: color ?? this.color,
      isDefault: isDefault,
    );
  }
}

String _dueLabelFor(GoalType type) => switch (type) {
  GoalType.lifetime => 'Obiettivo di vita',
  GoalType.annual => 'Obiettivo annuale',
  GoalType.quarterly => 'Trimestre corrente',
  GoalType.monthly => 'Mese corrente',
  GoalType.weekly => 'Settimana corrente',
};

const _goalColors = [
  EvolveColors.cyan,
  EvolveColors.primaryStrong,
  EvolveColors.violet,
  EvolveColors.amber,
  EvolveColors.rose,
];

const _defaultGoalCategories = [
  _GoalCategory(
    key: 'lavoro',
    label: 'Lavoro',
    color: EvolveColors.cyan,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'salute',
    label: 'Salute',
    color: EvolveColors.primaryStrong,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'finanza',
    label: 'Finanza',
    color: EvolveColors.amber,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'relazioni',
    label: 'Relazioni',
    color: EvolveColors.rose,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'formazione',
    label: 'Formazione',
    color: EvolveColors.violet,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'hobby',
    label: 'Hobby',
    color: EvolveColors.cyan,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'spirituale',
    label: 'Spirituale',
    color: Color(0xFFF97316),
    isDefault: true,
  ),
  _GoalCategory(
    key: 'altro',
    label: 'Altro',
    color: Color(0xFF6B7280),
    isDefault: true,
  ),
];

_GoalCategory _categoryForGoal(
  DashboardGoal goal,
  List<_GoalCategory> categories,
) {
  for (final category in categories) {
    if (goal.categoryId != null && category.id == goal.categoryId) {
      return category;
    }
  }
  for (final category in categories) {
    if (category.key == goal.category) return category;
  }
  return _GoalCategory(
    key: goal.category.isEmpty ? null : goal.category,
    label: goal.category.isEmpty ? 'Default' : goal.category,
    color: goal.color,
  );
}

const _months = [
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];
