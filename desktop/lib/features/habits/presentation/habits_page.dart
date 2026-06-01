import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HabitsPage extends ConsumerWidget {
  const HabitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dashboardControllerProvider);

    return DesktopPage(
      title: 'Abitudini',
      subtitle:
          'Costruisci il tuo protocollo quotidiano e osserva la consistenza nel tempo.',
      trailing: PageActionButton(
        label: 'Nuova abitudine',
        icon: Icons.add_rounded,
        primary: true,
        onPressed: () => _showAddHabitPreview(context),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _HabitSummaryCard(
                  label: 'Protocollo attivo',
                  value: '${snapshot.totalHabits}',
                  icon: Icons.event_available_outlined,
                  color: EvolveColors.primaryStrong,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _HabitSummaryCard(
                  label: 'Completate oggi',
                  value: '${snapshot.completedHabits}',
                  icon: Icons.check_circle_outline_rounded,
                  color: EvolveColors.cyan,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _HabitSummaryCard(
                  label: 'Serie migliore',
                  value: '${snapshot.bestStreak} gg',
                  icon: Icons.local_fire_department_outlined,
                  color: EvolveColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          EvolvePanel(
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: SectionHeading(
                    title: 'Protocollo quotidiano',
                    subtitle: 'Panoramica settimanale e azioni rapide',
                    trailing: StatusPill(
                      label: 'Settimana corrente',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                ),
                const Divider(height: 1),
                const _HabitTableHeader(),
                for (final habit in snapshot.habits)
                  _HabitTableRow(
                    habit: habit,
                    onToggle: () => ref
                        .read(dashboardControllerProvider.notifier)
                        .toggleHabit(habit.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddHabitPreview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuova abitudine'),
        content: const Text(
          'Il flusso di creazione verra collegato al repository Supabase nel prossimo passaggio di integrazione.',
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

class _HabitSummaryCard extends StatelessWidget {
  const _HabitSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: EvolveColors.foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitTableHeader extends StatelessWidget {
  const _HabitTableHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          SizedBox(width: 32),
          Expanded(child: _ColumnLabel('ABITUDINE')),
          SizedBox(width: 100, child: _ColumnLabel('SERIE')),
          SizedBox(width: 220, child: _ColumnLabel('ULTIMI 7 GIORNI')),
          SizedBox(width: 90, child: _ColumnLabel('STATO')),
        ],
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: EvolveColors.subtle,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.9,
      ),
    );
  }
}

class _HabitTableRow extends StatelessWidget {
  const _HabitTableRow({required this.habit, required this.onToggle});

  final DashboardHabit habit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final completed = habit.state == HabitState.completed;

    return Column(
      children: [
        const Divider(height: 1),
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Icon(
                    completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: completed ? habit.color : EvolveColors.subtle,
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: const TextStyle(
                          color: EvolveColors.foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        habit.category,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    '${habit.streak} giorni',
                    style: const TextStyle(
                      color: EvolveColors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: Row(
                    children: [
                      for (final day in habit.weeklyProgress)
                        Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: day
                                ? habit.color.withValues(alpha: 0.86)
                                : EvolveColors.panelSoft,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: StatusPill(
                    label: completed ? 'Fatto' : 'Da fare',
                    color: completed
                        ? EvolveColors.primaryStrong
                        : EvolveColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
