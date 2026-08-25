import 'package:flutter/material.dart';
import '../../kit/evolve_async_error.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/goal_provider.dart';
import '../../../models/goal.dart';
import '../../../i18n/translations.g.dart';

class HabitStats {
  final int currentStreak;
  final int bestStreak;
  final int completionRate;
  final int totalCompletions;
  final int totalActiveDays;
  final int missedDays;
  final List<int> trend30Days;

  HabitStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.completionRate,
    required this.totalCompletions,
    required this.totalActiveDays,
    required this.missedDays,
    required this.trend30Days,
  });
}

class HabitOverviewTabWidget extends ConsumerWidget {
  final String goalId;

  const HabitOverviewTabWidget({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final statsAsync = ref.watch(habitStatsProvider);
    final gridAsync = ref.watch(habitYearlyGridProvider(goalId));
    final correlationsAsync = ref.watch(habitCorrelationsProvider(goalId));

    final goal = goals.firstWhere(
      (g) => g.id == goalId,
      orElse: () => Goal(
        id: '',
        title: '',
        color: Colors.blue,
        startDate: DateTime.now(),
      ),
    );

    return statsAsync.when(
      data: (statsList) {
        final stat = statsList.firstWhere(
          (s) => s['goal_id'] == goalId,
          orElse: () => {},
        );

        final habitStats = HabitStats(
          currentStreak: stat['current_streak'] ?? 0,
          bestStreak: stat['best_streak'] ?? 0,
          completionRate: (stat['rate'] as num?)?.round() ?? 0,
          totalCompletions: stat['total_completions'] ?? 0,
          totalActiveDays: stat['total_active_days'] ?? 1,
          missedDays: stat['missed_days'] ?? 0,
          trend30Days: [], // Will be filled below
        );

        return gridAsync.when(
          data: (grid) {
            // Take last 30 items
            final trend30Days = grid.length >= 30
                ? grid.sublist(grid.length - 30)
                : grid;

            return correlationsAsync.when(
              data: (correlationsData) {
                final correlations = <Map<String, dynamic>>[];
                for (final item in correlationsData) {
                  final otherGoalId = item['goal_id'] as String;
                  final otherGoal = goals.firstWhere(
                    (g) => g.id == otherGoalId,
                    orElse: () => Goal(
                      id: '',
                      title: '',
                      color: Colors.blue,
                      startDate: DateTime.now(),
                    ),
                  );
                  if (otherGoal.id.isNotEmpty) {
                    correlations.add({
                      'goal': otherGoal,
                      'percentage': (item['percentage'] as num?)?.toInt() ?? 0,
                      'strength':
                          ((item['percentage'] as num?)?.toDouble() ?? 0.0) /
                          100.0,
                      'togetherCount':
                          (item['together_count'] as num?)?.toInt() ?? 0,
                    });
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopStatsGrid(stats: habitStats),
                    const SizedBox(height: 16),
                    _TrendUltimi30Giorni(trend: trend30Days),
                    const SizedBox(height: 16),
                    _CorrelazioniSection(
                      goalId: goalId,
                      correlations: correlations,
                      currentGoalTitle: goal.title,
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: EvolveAsyncError(
                  error: err,
                  stackTrace: stack,
                  context: '[Stats] habit overview',
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: EvolveAsyncError(
              error: err,
              stackTrace: stack,
              context: '[Stats] habit overview',
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: EvolveAsyncError(
          error: err,
          stackTrace: stack,
          context: '[Stats] habit overview',
        ),
      ),
    );
  }
}

class _TopStatsGrid extends StatelessWidget {
  final HabitStats stats;
  const _TopStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _StatCard(
          title: context.t.statistics.currentStreak,
          value: '${stats.currentStreak}',
          subtitle: context.t.common.days,
          valueColor: const Color(0xFFEF4444), // Red
        ),
        _StatCard(
          title: context.t.statistics.record,
          value: '${stats.bestStreak}',
          subtitle: context.t.common.days,
          valueColor: const Color(0xFFEAB308), // Yellow
        ),
        _StatCard(
          title: context.t.statistics.completation,
          value: '${stats.completionRate}%',
          subtitle:
              '${stats.totalCompletions}/${stats.totalActiveDays} ${context.t.statistics.daysShortUnit}',
          valueColor: context.appColors.foreground,
        ),
        _StatCard(
          title: context.t.statistics.missed,
          value: '${stats.missedDays}',
          subtitle: context.t.common.days,
          valueColor: const Color(0xFFEF4444), // Red
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color valueColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.appColors.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              color: context.appColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendUltimi30Giorni extends StatelessWidget {
  final List<int> trend;
  const _TrendUltimi30Giorni({required this.trend});

  @override
  Widget build(BuildContext context) {
    final List<int> statuses = trend;

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t.statistics.last30DaysTrend,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: 30,
            itemBuilder: (context, index) {
              final status = statuses[index];
              Color color;
              if (status == 1) {
                color = Colors.green;
              } else if (status == 2) {
                color = const Color(0xFFFF0000); // Red
              } else {
                color = context.appColors.muted.withValues(
                  alpha: 0.3,
                ); // Dynamic Grey
              }

              return Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.t.statistics.completed2,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF0000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.t.statistics.notCompleted,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: context.appColors.muted.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.t.statistics.skipped,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: context.appColors.mutedForeground,
                    ),
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

class _CorrelazioniSection extends StatefulWidget {
  final String goalId;
  final List<Map<String, dynamic>> correlations;
  final String currentGoalTitle;
  const _CorrelazioniSection({
    required this.goalId,
    required this.correlations,
    required this.currentGoalTitle,
  });

  @override
  State<_CorrelazioniSection> createState() => _CorrelazioniSectionState();
}

class _CorrelazioniSectionState extends State<_CorrelazioniSection> {
  late PageController _positiveController;
  late PageController _negativeController;
  int _positiveIndex = 0;
  int _negativeIndex = 0;

  @override
  void initState() {
    super.initState();
    _positiveController = PageController(viewportFraction: 0.9);
    _negativeController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _positiveController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positiveCorrelations = widget.correlations
        .where((c) => c['percentage'] >= 50)
        .toList();
    final negativeCorrelations = widget.correlations
        .where((c) => c['percentage'] < 50)
        .toList();

    final displayPositives = positiveCorrelations.isNotEmpty
        ? positiveCorrelations.take(3).toList()
        : [];
    final displayNegatives = negativeCorrelations.isNotEmpty
        ? negativeCorrelations.take(3).toList()
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.t.statistics.correlationsWith} "${widget.currentGoalTitle}"',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.appColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.t.statistics.howThisHabitRelatesToOthers,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: context.appColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 24),

        // POSITIVE CORRELATIONS
        Row(
          children: [
            const Icon(
              LucideIcons.trendingUp,
              size: 16,
              color: Color(0xFF10B981),
            ),
            const SizedBox(width: 8),
            Text(
              context.t.statistics.positiveCorrelations,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: displayPositives.isEmpty
              ? Center(
                  child: Text(
                    context.t.statistics.noSignificantPositiveCorrelation,
                    style: TextStyle(color: context.appColors.mutedForeground),
                  ),
                )
              : PageView.builder(
                  controller: _positiveController,
                  itemCount: displayPositives.length,
                  onPageChanged: (i) => setState(() => _positiveIndex = i),
                  itemBuilder: (context, index) {
                    final c = displayPositives[index];
                    final goal = c['goal'] as Goal;
                    return _buildPaddedCard(
                      _CorrelazioneCard(
                        habitName: goal.title,
                        habitColor: goal.color,
                        strengthText: context.t.statistics
                            .strongCorrelationStrength(
                              value:
                                  '+${(c['percentage'] / 100).toStringAsFixed(2)}',
                            ),
                        strengthColor: const Color(0xFF10B981),
                        subtitle: context.t.statistics.habitTogetherPercent(
                          percentage: c['percentage'] as int,
                        ),
                        description: context.t.statistics
                            .habitPositiveCorrelationDescription(
                              currentGoal: widget.currentGoalTitle,
                              percentage: c['percentage'] as int,
                              otherGoal: goal.title,
                            ),
                        borderColor: const Color(0xFF10B981),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        if (displayPositives.isNotEmpty)
          _buildDots(
            displayPositives.length,
            _positiveIndex,
            const Color(0xFF10B981),
          ),

        const SizedBox(height: 32),

        // NEGATIVE CORRELATIONS
        Row(
          children: [
            const Icon(
              LucideIcons.trendingDown,
              size: 16,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(width: 8),
            Text(
              context.t.statistics.negativeCorrelations,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: displayNegatives.isEmpty
              ? Center(
                  child: Text(
                    context.t.statistics.noSignificantNegativeCorrelation,
                    style: TextStyle(color: context.appColors.mutedForeground),
                  ),
                )
              : PageView.builder(
                  controller: _negativeController,
                  itemCount: displayNegatives.length,
                  onPageChanged: (i) => setState(() => _negativeIndex = i),
                  itemBuilder: (context, index) {
                    final c = displayNegatives[index];
                    final goal = c['goal'] as Goal;
                    return _buildPaddedCard(
                      _CorrelazioneCard(
                        habitName: goal.title,
                        habitColor: goal.color,
                        strengthText: context.t.statistics.weakCorrelationStrength(
                          value:
                              '+${(c['percentage'] / 100).toStringAsFixed(2)}',
                        ),
                        strengthColor: const Color(0xFFEF4444),
                        subtitle: context.t.statistics.habitTogetherPercent(
                          percentage: c['percentage'] as int,
                        ),
                        description: context.t.statistics
                            .habitNegativeCorrelationDescription(
                              currentGoal: widget.currentGoalTitle,
                              percentage: c['percentage'] as int,
                              otherGoal: goal.title,
                            ),
                        borderColor: const Color(0xFFEF4444),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        if (displayNegatives.isNotEmpty)
          _buildDots(
            displayNegatives.length,
            _negativeIndex,
            const Color(0xFFEF4444),
          ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPaddedCard(Widget card) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: card,
    );
  }

  Widget _buildDots(int count, int current, Color color) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final isActive = current == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive
                  ? color
                  : context.appColors.mutedForeground.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

class _CorrelazioneCard extends StatelessWidget {
  final String habitName;
  final Color habitColor;
  final String strengthText;
  final Color strengthColor;
  final String subtitle;
  final String description;
  final Color borderColor;

  const _CorrelazioneCard({
    required this.habitName,
    required this.habitColor,
    required this.strengthText,
    required this.strengthColor,
    required this.subtitle,
    required this.description,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: habitColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  habitName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                strengthText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: strengthColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '•',
                style: TextStyle(
                  color: context.appColors.mutedForeground,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: context.appColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: context.appColors.mutedForeground,
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
