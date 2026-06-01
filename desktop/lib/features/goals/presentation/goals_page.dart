import 'package:evolve_desktop/app/theme/evolve_theme.dart';
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
  GoalType? _filter;
  bool _showStats = false;
  int _periodOffset = 0;
  final _categories = [..._defaultGoalCategories];
  final _archivedCategoryIds = <String>{};

  @override
  Widget build(BuildContext context) {
    ref.watch(desktopGoalCategoriesControllerProvider);
    final allGoals = ref.watch(dashboardControllerProvider).goals;
    final goals = allGoals.where(_matchesPeriod).toList();

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
            filter: _filter,
            showStats: _showStats,
            periodLabel: _periodLabel,
            onFilterChanged: (type) => setState(() => _filter = type),
            onToggleStats: () => setState(() => _showStats = !_showStats),
            onPrevious: () => setState(() => _periodOffset--),
            onNext: () => setState(() => _periodOffset++),
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
                );
                final history = Column(
                  children: [
                    _GoalList(
                      title: 'Completati',
                      subtitle: 'Progressi consolidati',
                      goals: goals
                          .where((goal) => goal.state == GoalState.completed)
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    _GoalList(
                      title: 'Da ripianificare',
                      subtitle: 'Obiettivi non completati nel periodo',
                      goals: goals
                          .where((goal) => goal.state == GoalState.failed)
                          .toList(),
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
    final now = DateTime.now();
    final year = now.year + _periodOffset;
    return switch (_filter) {
      null || GoalType.lifetime => 'Tutti i periodi',
      GoalType.annual => '$year',
      GoalType.quarterly => 'Q${((now.month - 1) ~/ 3) + 1} $year',
      GoalType.monthly => '${now.month}/$year',
      GoalType.weekly =>
        'Settimana ${((now.day - 1) ~/ 7) + 1}, ${now.month}/$year',
    };
  }

  bool _matchesPeriod(DashboardGoal goal) {
    final type = _filter;
    if (type == null) return true;
    if (goal.type != type) return false;
    if (type == GoalType.lifetime) return true;

    final now = DateTime.now();
    final year = now.year + _periodOffset;
    if (goal.year != null && goal.year != year) return false;
    return switch (type) {
      GoalType.quarterly =>
        goal.quarter == null || goal.quarter == ((now.month - 1) ~/ 3) + 1,
      GoalType.monthly => goal.month == null || goal.month == now.month,
      GoalType.weekly =>
        (goal.month == null || goal.month == now.month) &&
            (goal.weekNumber == null ||
                goal.weekNumber == ((now.day - 1) ~/ 7) + 1),
      _ => true,
    };
  }

  Future<void> _openGoalEditor() async {
    final draft = await showDialog<_GoalDraft>(
      context: context,
      builder: (context) => _GoalEditorDialog(categories: _availableCategories),
    );
    if (draft == null) return;
    await ref
        .read(dashboardControllerProvider.notifier)
        .addGoal(
          title: draft.title,
          category: draft.category.label,
          color: draft.category.color,
          type: draft.type,
          dueLabel: draft.dueLabel,
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
                          : IconButton(
                              tooltip: 'Archivia categoria',
                              onPressed: () {
                                _archiveCategory(category);
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.archive_outlined),
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
}

class _GoalToolbar extends StatelessWidget {
  const _GoalToolbar({
    required this.filter,
    required this.showStats,
    required this.periodLabel,
    required this.onFilterChanged,
    required this.onToggleStats,
    required this.onPrevious,
    required this.onNext,
    required this.onManageCategories,
  });

  final GoalType? filter;
  final bool showStats;
  final String periodLabel;
  final ValueChanged<GoalType?> onFilterChanged;
  final VoidCallback onToggleStats;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          PopupMenuButton<String>(
            tooltip: 'Filtra per orizzonte',
            initialValue: filter?.name ?? 'all',
            onSelected: (value) {
              onFilterChanged(
                value == 'all' ? null : GoalType.values.byName(value),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('Tutti gli orizzonti'),
              ),
              for (final type in GoalType.values)
                PopupMenuItem(value: type.name, child: Text(type.label)),
            ],
            child: StatusPill(
              label: filter?.label ?? 'Tutti gli orizzonti',
              icon: Icons.filter_list_rounded,
            ),
          ),
          const SizedBox(width: 13),
          IconButton(
            tooltip: 'Periodo precedente',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(periodLabel, style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            tooltip: 'Periodo successivo',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onManageCategories,
            icon: const Icon(Icons.category_outlined, size: 17),
            label: const Text('Categorie'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onToggleStats,
            icon: Icon(
              showStats ? Icons.view_list_outlined : Icons.insights_outlined,
              size: 17,
            ),
            label: Text(showStats ? 'Lista' : 'Statistiche'),
          ),
        ],
      ),
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
      color: const Color(0xFF11191E),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: EvolveColors.primaryStrong.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.explore_outlined,
              color: EvolveColors.primaryStrong,
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
  });

  final String title;
  final String subtitle;
  final List<DashboardGoal> goals;

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
              _GoalCard(goal: goals[index]),
              if (index != goals.length - 1) const SizedBox(height: 11),
            ],
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});

  final DashboardGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(dashboardControllerProvider.notifier);
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
                  color: goal.color,
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
              color: goal.color,
              backgroundColor: EvolveColors.panelSoft,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${goal.category} · ${goal.type.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                goal.state == GoalState.active
                    ? goal.dueLabel
                    : goal.state.label,
                style: TextStyle(
                  color: goal.state == GoalState.completed
                      ? EvolveColors.primaryStrong
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
  const _GoalEditorDialog({required this.categories});

  final List<_GoalCategory> categories;

  @override
  State<_GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends State<_GoalEditorDialog> {
  final _title = TextEditingController();
  GoalType _type = GoalType.annual;
  late _GoalCategory _category;

  @override
  void initState() {
    super.initState();
    _category = widget.categories.first;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuovo obiettivo'),
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
          child: const Text('Crea'),
        ),
      ],
    );
  }
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog();

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  final _name = TextEditingController();
  Color _color = EvolveColors.cyan;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuova categoria'),
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
          child: const Text('Aggiungi'),
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
    required this.label,
    required this.color,
    this.isDefault = false,
  });

  final String? id;
  final String label;
  final Color color;
  final bool isDefault;
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
  _GoalCategory(label: 'Lavoro', color: EvolveColors.cyan, isDefault: true),
  _GoalCategory(
    label: 'Salute',
    color: EvolveColors.primaryStrong,
    isDefault: true,
  ),
  _GoalCategory(label: 'Finanza', color: EvolveColors.amber, isDefault: true),
  _GoalCategory(label: 'Relazioni', color: EvolveColors.rose, isDefault: true),
  _GoalCategory(
    label: 'Formazione',
    color: EvolveColors.violet,
    isDefault: true,
  ),
];
