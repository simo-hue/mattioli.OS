import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(dashboardControllerProvider).goals;

    return DesktopPage(
      title: 'Obiettivi',
      subtitle:
          'Trasforma la direzione di lungo periodo in traguardi chiari e misurabili.',
      trailing: PageActionButton(
        label: 'Nuovo obiettivo',
        icon: Icons.add_rounded,
        primary: true,
        onPressed: () => _showNewGoalPreview(context),
      ),
      child: Column(
        children: [
          _GoalOverview(goals: goals),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumns = constraints.maxWidth >= 1080;
              final activeGoals = _GoalList(
                title: 'In corso',
                subtitle: 'Traguardi che richiedono attenzione',
                goals: goals
                    .where((goal) => goal.state == GoalState.active)
                    .toList(),
              );
              final completedGoals = _GoalList(
                title: 'Completati',
                subtitle: 'Progressi consolidati',
                goals: goals
                    .where((goal) => goal.state == GoalState.completed)
                    .toList(),
              );

              return useColumns
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: activeGoals),
                        const SizedBox(width: 18),
                        Expanded(flex: 4, child: completedGoals),
                      ],
                    )
                  : Column(
                      children: [
                        activeGoals,
                        const SizedBox(height: 18),
                        completedGoals,
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  void _showNewGoalPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuovo obiettivo'),
        content: const Text(
          'Il form desktop verra collegato allo stesso schema Supabase dei macro obiettivi mobile durante l\'integrazione dati.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ho capito'),
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
    final progress = goals.isEmpty
        ? 0.0
        : goals.fold<double>(0, (sum, goal) => sum + goal.progress) /
              goals.length;

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
                  'Procedi con una priorita alla volta. Il progresso medio dei tuoi obiettivi e al ${(progress * 100).round()}%.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
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
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Text(
                'Nessun obiettivo in questa sezione.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (var i = 0; i < goals.length; i++) ...[
              _GoalCard(goal: goals[i]),
              if (i != goals.length - 1) const SizedBox(height: 11),
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
    final completed = goal.state == GoalState.completed;

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
              if (!completed)
                Tooltip(
                  message: 'Segna come completato',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(dashboardControllerProvider.notifier)
                        .completeGoal(goal.id),
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 19,
                      color: EvolveColors.muted,
                    ),
                  ),
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
              Text(goal.category, style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Text(
                completed ? 'Completato' : goal.dueLabel,
                style: TextStyle(
                  color: completed
                      ? EvolveColors.primaryStrong
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
