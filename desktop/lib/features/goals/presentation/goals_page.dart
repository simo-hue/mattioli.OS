import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
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
  Widget build(BuildContext context) {
    ref.watch(desktopGoalCategoriesControllerProvider);
    final allGoals = ref.watch(dashboardControllerProvider).goals;
    final goals = allGoals.where(_matchesPeriod).toList()..sort(_sortGoals);

    return DesktopPage(
      title: 'Obiettivi',
      subtitle:
          'Trasforma la direzione di lungo periodo in traguardi chiari e misurabili.',
      trailing: PageActionButton(
        label: 'Nuovo obiettivo',
        icon: Icons.add_rounded,
        primary: true,
        onPressed: _openGoalEditor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GoalOverview(goals: allGoals),
          const SizedBox(height: 18),
          _GoalToolbar(
            selectedType: _selectedType,
            showStats: _showStats,
            periodLabel: _periodLabel,
            selectedYear: _selectedYear,
            selectedQuarter: _selectedQuarter,
            selectedMonth: _selectedMonth,
            selectedWeek: _selectedWeek,
            onTypeChanged: (type) => setState(() => _selectedType = type),
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
            onToggleStats: () => setState(() => _showStats = !_showStats),
            onPrevious: () => _movePeriod(-1),
            onNext: () => _movePeriod(1),
            onManageCategories: _openCategoryManager,
          ),
          const SizedBox(height: 14),
          if (_showStats)
            _GoalStats(goals: allGoals)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final useColumns = constraints.maxWidth >= 1080;
                final active = _GoalList(
                  title: 'In corso',
                  subtitle: 'Traguardi che richiedono attenzione',
                  goals: goals
                      .where((goal) => goal.state == GoalState.active)
                      .toList(),
                  onEdit: _openGoalEditorFor,
                );
                final history = Column(
                  children: [
                    _GoalList(
                      title: 'Completati',
                      subtitle: 'Progressi consolidati',
                      goals: goals
                          .where((goal) => goal.state == GoalState.completed)
                          .toList(),
                      onEdit: _openGoalEditorFor,
                    ),
                    const SizedBox(height: 18),
                    _GoalList(
                      title: 'Da ripianificare',
                      subtitle: 'Obiettivi non completati nel periodo',
                      goals: goals
                          .where((goal) => goal.state == GoalState.failed)
                          .toList(),
                      onEdit: _openGoalEditorFor,
                    ),
                  ],
                );
                return useColumns
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: active),
                          const SizedBox(width: 18),
                          Expanded(flex: 4, child: history),
                        ],
                      )
                    : Column(
                        children: [active, const SizedBox(height: 18), history],
                      );
              },
            ),
        ],
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

  Future<void> _openGoalEditor() async {
    final draft = await showDialog<_GoalDraft>(
      context: context,
      builder: (context) => _GoalEditorDialog(
        categories: _availableCategories,
        initialType: _selectedType,
      ),
    );
    if (draft == null) return;
    await ref
        .read(dashboardControllerProvider.notifier)
        .addGoal(
          title: draft.title,
          category: draft.category.key ?? '',
          color: draft.category.color,
          type: draft.type,
          dueLabel: draft.dueLabel,
          categoryId: draft.category.id,
          year: _selectedYear,
          quarter: _selectedQuarter,
          month: _selectedMonth,
          weekNumber: _selectedWeek,
        );
  }

  Future<void> _openGoalEditorFor(DashboardGoal goal) async {
    final categories = _availableCategories;
    final category = _categoryForGoal(goal, categories);
    final draft = await showDialog<_GoalDraft>(
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
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
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
                  final category = await showDialog<_GoalCategory>(
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
    final updated = await showDialog<_GoalCategory>(
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
    required this.periodLabel,
    required this.selectedYear,
    required this.selectedQuarter,
    required this.selectedMonth,
    required this.selectedWeek,
    required this.onTypeChanged,
    required this.onYearChanged,
    required this.onQuarterChanged,
    required this.onMonthChanged,
    required this.onWeekChanged,
    required this.onToggleStats,
    required this.onPrevious,
    required this.onNext,
    required this.onManageCategories,
  });

  final GoalType selectedType;
  final bool showStats;
  final String periodLabel;
  final int selectedYear;
  final int selectedQuarter;
  final int selectedMonth;
  final int selectedWeek;
  final ValueChanged<GoalType> onTypeChanged;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onQuarterChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onToggleStats;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<GoalType>(
              segments: [
                for (final type in GoalType.values)
                  ButtonSegment(value: type, label: Text(type.label)),
              ],
              selected: {selectedType},
              onSelectionChanged: (selection) =>
                  onTypeChanged(selection.single),
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (selectedType != GoalType.lifetime) ...[
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
                    if (selectedType == GoalType.quarterly)
                      _PeriodDropdown(
                        value: selectedQuarter,
                        values: const [1, 2, 3, 4],
                        labelFor: (value) => 'Q$value',
                        onChanged: onQuarterChanged,
                      ),
                    if (selectedType == GoalType.monthly ||
                        selectedType == GoalType.weekly)
                      _PeriodDropdown(
                        value: selectedMonth,
                        values: [
                          for (var month = 1; month <= 12; month++) month,
                        ],
                        labelFor: (value) => _months[value - 1],
                        onChanged: onMonthChanged,
                      ),
                    if (selectedType == GoalType.weekly)
                      _PeriodDropdown(
                        value: selectedWeek,
                        values: [
                          for (
                            var week = 1;
                            week <=
                                logicalWeeksInMonth(
                                  selectedYear,
                                  selectedMonth,
                                );
                            week++
                          )
                            week,
                        ],
                        labelFor: (value) => 'Settimana $value',
                        onChanged: onWeekChanged,
                      ),
                    IconButton(
                      tooltip: 'Periodo precedente',
                      onPressed: onPrevious,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    IconButton(
                      tooltip: 'Periodo successivo',
                      onPressed: onNext,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                  Text(
                    periodLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onManageCategories,
                    icon: const Icon(Icons.category_outlined, size: 17),
                    label: const Text('Categorie'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onToggleStats,
                    icon: Icon(
                      showStats
                          ? Icons.view_list_outlined
                          : Icons.insights_outlined,
                      size: 17,
                    ),
                    label: Text(showStats ? 'Lista' : 'Statistiche'),
                  ),
                ],
              ),
            ],
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
    return DropdownButton<int>(
      value: value,
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(labelFor(item))),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(10),
      style: Theme.of(context).textTheme.bodyMedium,
      dropdownColor: EvolveColors.panelRaised,
    );
  }
}

class _GoalOverview extends StatelessWidget {
  const _GoalOverview({required this.goals});

  final List<DashboardGoal> goals;

  @override
  Widget build(BuildContext context) {
    final active = goals
        .where((goal) => goal.state == GoalState.active)
        .toList();
    final progress = active.isEmpty
        ? 0.0
        : active.fold<double>(0, (sum, goal) => sum + goal.progress) /
              active.length;

    return EvolvePanel(
      color: context.evolveColors.panelRaised,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: context.evolveAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.explore_outlined,
              color: context.evolveAccent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Direzione annuale',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  'Procedi con una priorita alla volta. Il progresso medio degli obiettivi attivi e al ${(progress * 100).round()}%.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          StatusPill(
            label: '${goals.length} obiettivi monitorati',
            icon: Icons.flag_outlined,
          ),
        ],
      ),
    );
  }
}

class _GoalList extends StatelessWidget {
  const _GoalList({
    required this.title,
    required this.subtitle,
    required this.goals,
    required this.onEdit,
  });

  final String title;
  final String subtitle;
  final List<DashboardGoal> goals;
  final ValueChanged<DashboardGoal> onEdit;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        children: [
          SectionHeading(title: title, subtitle: subtitle),
          const SizedBox(height: 16),
          if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text(
                'Nessun obiettivo in questa sezione.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (var index = 0; index < goals.length; index++) ...[
              _GoalCard(goal: goals[index], onEdit: onEdit),
              if (index != goals.length - 1) const SizedBox(height: 11),
            ],
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.onEdit});

  final DashboardGoal goal;
  final ValueChanged<DashboardGoal> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(dashboardControllerProvider.notifier);
    final remoteCategories =
        ref.watch(desktopGoalCategoriesControllerProvider).value ?? const [];
    final category = _categoryForGoal(goal, [
      ..._defaultGoalCategories,
      for (final remote in remoteCategories)
        _GoalCategory(id: remote.id, label: remote.label, color: remote.color),
    ]);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EvolveColors.panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EvolveColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  goal.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Azioni obiettivo',
                onSelected: (action) {
                  switch (action) {
                    case 'complete':
                      controller.completeGoal(goal.id);
                    case 'fail':
                      controller.updateGoalState(goal.id, GoalState.failed);
                    case 'reschedule':
                      controller.rescheduleGoal(goal.id);
                    case 'edit':
                      onEdit(goal);
                    case 'delete':
                      controller.deleteGoal(goal.id);
                  }
                },
                itemBuilder: (context) => [
                  if (goal.state == GoalState.active) ...[
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Segna completato'),
                    ),
                    const PopupMenuItem(
                      value: 'fail',
                      child: Text('Segna non completato'),
                    ),
                  ],
                  if (goal.state == GoalState.failed)
                    const PopupMenuItem(
                      value: 'reschedule',
                      child: Text('Ripianifica'),
                    ),
                  const PopupMenuItem(value: 'edit', child: Text('Modifica')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: Text('Elimina')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 6,
              color: category.color,
              backgroundColor: EvolveColors.panelSoft,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${category.label} · ${goal.type.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                goal.state == GoalState.active
                    ? goal.dueLabel
                    : goal.state.label,
                style: TextStyle(
                  color: goal.state == GoalState.completed
                      ? context.evolveAccent
                      : goal.state == GoalState.failed
                      ? EvolveColors.rose
                      : EvolveColors.subtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
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
                    'Sintesi locale con arricchimento RPC quando disponibile',
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
            style: const TextStyle(
              color: EvolveColors.foreground,
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
            backgroundColor: EvolveColors.panelSoft,
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
    return AlertDialog(
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
    return AlertDialog(
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
