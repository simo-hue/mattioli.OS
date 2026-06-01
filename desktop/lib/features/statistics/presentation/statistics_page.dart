import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dashboardControllerProvider);

    return DesktopPage(
      title: 'Statistiche',
      subtitle:
          'Identifica i pattern che sostengono la tua crescita e intervieni sulle aree critiche.',
      trailing: const StatusPill(
        label: 'Ultimi 30 giorni',
        icon: Icons.date_range_outlined,
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumns = constraints.maxWidth >= 980;
              final trend = _CompletionTrendCard(snapshot: snapshot);
              final distribution = _DistributionCard(snapshot: snapshot);

              return useColumns
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: trend),
                        const SizedBox(width: 18),
                        Expanded(flex: 4, child: distribution),
                      ],
                    )
                  : Column(
                      children: [
                        trend,
                        const SizedBox(height: 18),
                        distribution,
                      ],
                    );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumns = constraints.maxWidth >= 980;
              final habits = _HabitPerformanceCard(snapshot: snapshot);
              const insight = _InsightCard();

              return useColumns
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: habits),
                        const SizedBox(width: 18),
                        const Expanded(flex: 4, child: insight),
                      ],
                    )
                  : Column(
                      children: [habits, const SizedBox(height: 18), insight],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _CompletionTrendCard extends StatelessWidget {
  const _CompletionTrendCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final values = snapshot.trend.map((point) => point.value).toList();

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Wellness vs output',
            subtitle: 'Completamento giornaliero e livello di energia',
            trailing: StatusPill(
              label: 'Trend positivo',
              icon: Icons.trending_up_rounded,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${(values[i] * 100).round()}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: values[i],
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        EvolveColors.primaryStrong,
                                        Color(0x6655C881),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            snapshot.trend[i].label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Distribuzione',
            subtitle: 'Aree del tuo protocollo',
          ),
          const SizedBox(height: 24),
          const _DistributionRow(
            label: 'Benessere',
            value: 0.84,
            color: EvolveColors.primaryStrong,
          ),
          const SizedBox(height: 17),
          const _DistributionRow(
            label: 'Produttivita',
            value: 0.72,
            color: EvolveColors.cyan,
          ),
          const SizedBox(height: 17),
          const _DistributionRow(
            label: 'Formazione',
            value: 0.61,
            color: EvolveColors.violet,
          ),
          const SizedBox(height: 17),
          const _DistributionRow(
            label: 'Mindfulness',
            value: 0.77,
            color: EvolveColors.rose,
          ),
          const SizedBox(height: 23),
          Text(
            '${snapshot.completedHabits} azioni completate oggi',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            color: color,
            backgroundColor: EvolveColors.panelSoft,
          ),
        ),
      ],
    );
  }
}

class _HabitPerformanceCard extends StatelessWidget {
  const _HabitPerformanceCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        children: [
          const SectionHeading(
            title: 'Performance per abitudine',
            subtitle: 'Ordinate per consistenza settimanale',
          ),
          const SizedBox(height: 13),
          for (final habit in snapshot.habits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: habit.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      habit.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value:
                            habit.weeklyProgress
                                .where((value) => value)
                                .length /
                            7,
                        minHeight: 5,
                        color: habit.color,
                        backgroundColor: EvolveColors.panelSoft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${habit.weeklyProgress.where((value) => value).length}/7',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: habit.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      color: const Color(0xFF151522),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            color: EvolveColors.violet,
            size: 22,
          ),
          const SizedBox(height: 16),
          Text(
            'Insight della settimana',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 9),
          Text(
            'Quando completi la routine del mattino, la probabilita di portare a termine il deep work sale del 31%. Mantieni questa sequenza come prima priorita.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 19),
          const StatusPill(
            label: 'Correlazione positiva',
            color: EvolveColors.violet,
            icon: Icons.hub_outlined,
          ),
        ],
      ),
    );
  }
}
