import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/goal_provider.dart';
import '../../../models/goal.dart';
import '../../../i18n/translations.g.dart';
import '../../../core/l10n_dynamic.dart';
import '../../../core/rtl.dart';

class InfoTabWidget extends ConsumerWidget {
  const InfoTabWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(habitStatsProvider);
    final criticalDayAsync = ref.watch(globalCriticalDayProvider);

    return statsAsync.when(
      data: (statsList) {
        return criticalDayAsync.when(
          data: (criticalDayLabel) {
            if (statsList.isEmpty) {
              return _buildEmptyState(context);
            }

            // Calculate Global Completion
            int totalCompletions = 0;
            int totalActiveDays = 0;
            int maxBestStreak = 0;
            Map<String, dynamic>? topPerformerStat;

            for (final stat in statsList) {
              totalCompletions +=
                  (stat['total_completions'] as num?)?.toInt() ?? 0;
              totalActiveDays +=
                  (stat['total_active_days'] as num?)?.toInt() ?? 1;
              final bestStreak = (stat['best_streak'] as num?)?.toInt() ?? 0;
              if (bestStreak > maxBestStreak) {
                maxBestStreak = bestStreak;
              }
              if (topPerformerStat == null ||
                  ((stat['rate'] as num?)?.toDouble() ?? 0) >
                      ((topPerformerStat['rate'] as num?)?.toDouble() ?? 0)) {
                topPerformerStat = stat;
              }
            }

            final globalCompletionRate = totalActiveDays > 0
                ? (totalCompletions / totalActiveDays * 100).round()
                : 0;

            final topPerformerName = topPerformerStat?['title'] ?? 'N/A';
            final topPerformerRate =
                (topPerformerStat?['rate'] as num?)?.round() ?? 0;

            final sortedStats = List<Map<String, dynamic>>.from(statsList);
            sortedStats.sort(
              (a, b) => ((b['rate'] as num?)?.toDouble() ?? 0).compareTo(
                (a['rate'] as num?)?.toDouble() ?? 0,
              ),
            );
            final top3Ids = sortedStats
                .take(3)
                .map((s) => s['goal_id'] as String)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TopStatsGrid(
                  completion: '$globalCompletionRate%',
                  bestStreak: '$maxBestStreak',
                  topPerformer: topPerformerName,
                  topPerformerRate: '$topPerformerRate%',
                  criticalDay: criticalDayLabel,
                ),
                const SizedBox(height: 16),
                const _AttivitaRecenteSection(),
                const SizedBox(height: 16),
                if (top3Ids.isNotEmpty)
                  _TopHabitCorrelationsSection(goalIds: top3Ids),
                const SizedBox(height: 16),
                if (top3Ids.isNotEmpty)
                  _CorrelationsSection(goalId: top3Ids.first, isPositive: true),
                const SizedBox(height: 16),
                if (top3Ids.isNotEmpty)
                  _CorrelationsSection(
                    goalId: top3Ids.first,
                    isPositive: false,
                  ),
                const SizedBox(height: 32),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Text(
              '${context.t.common.status.error}: $err',
              style: TextStyle(color: context.appColors.mutedForeground),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          '${context.t.common.status.error}: $err',
          style: TextStyle(color: context.appColors.mutedForeground),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: AppTheme.glassPanelDecoration(context, radius: 14),
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.chartBar, size: 40, color: primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            context.t.statistics.statsCollectingFirstData,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.appColors.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Le tue statistiche globali appariranno qui non appena inizierai a tracciare le tue abitudini. Completa i tuoi task per sbloccare questa panoramica.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: context.appColors.mutedForeground,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopStatsGrid extends StatelessWidget {
  final String completion;
  final String bestStreak;
  final String topPerformer;
  final String topPerformerRate;
  final String criticalDay;

  const _TopStatsGrid({
    required this.completion,
    required this.bestStreak,
    required this.topPerformer,
    required this.topPerformerRate,
    required this.criticalDay,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6, // Adjusted for better text fit
      children: [
        _StatCard(
          icon: LucideIcons.target,
          title: context.t.statistics.completion,
          value: completion,
          subtitle: context.t.statistics.globalTxt,
          accentColor: Theme.of(context).colorScheme.primary,
        ),
        _StatCard(
          icon: LucideIcons.flame,
          title: context.t.statistics.bestStreak,
          value: bestStreak,
          subtitle: context.t.statistics.days,
          accentColor: Theme.of(context).colorScheme.primary,
        ),
        _StatCard(
          icon: LucideIcons.trophy,
          title: context.t.statistics.topPerformer,
          value: topPerformer,
          subtitle: '$topPerformerRate ${context.t.statistics.rate}',
          accentColor: Theme.of(context).colorScheme.primary,
        ),
        _StatCard(
          icon: LucideIcons.triangleAlert,
          title: context.t.statistics.criticalDay,
          value: tWeekday(context, criticalDay),
          subtitle: context.t.statistics.focusRequired,
          accentColor: const Color(0xFFEF4444),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Subtler Gradient Glow
          PositionedDirectional(
            end: -20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.15),
                    accentColor.withValues(alpha: 0),
                  ],
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 14, color: accentColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.mutedForeground,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.appColors.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: accentColor.withValues(alpha: 0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopHabitCorrelationsSection extends ConsumerStatefulWidget {
  final List<String> goalIds;
  const _TopHabitCorrelationsSection({required this.goalIds});

  @override
  ConsumerState<_TopHabitCorrelationsSection> createState() =>
      _TopHabitCorrelationsSectionState();
}

class _TopHabitCorrelationsSectionState
    extends ConsumerState<_TopHabitCorrelationsSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correlationsAsync = ref.watch(allHabitCorrelationsProvider);

    return correlationsAsync.when(
      data: (allCorrelations) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.crown,
                  size: 16,
                  color: Color(0xFFEAB308),
                ),
                const SizedBox(width: 8),
                Text(
                  context.t.statistics.keyHabits,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.t.statistics.habitsThatPositivelyInfluenceManyOthers,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: context.appColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),

            // Carousel
            SizedBox(
              height: 280, // Height for habit cards
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.goalIds.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final goalId = widget.goalIds[index];
                  final habitCorrelations = allCorrelations
                      .where((c) => c['goal_id'] == goalId)
                      .toList();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _TopHabitCorrelationCard(
                      goalId: goalId,
                      correlationsData: habitCorrelations,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Pagination Dots
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.goalIds.length, (index) {
                  final isActive = _currentPage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFEAB308)
                          : context.appColors.mutedForeground.withValues(
                              alpha: 0.3,
                            ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          '${context.t.common.status.error}: $err',
          style: TextStyle(color: context.appColors.mutedForeground),
        ),
      ),
    );
  }
}

class _TopHabitCorrelationCard extends ConsumerWidget {
  final String goalId;
  final List<Map<String, dynamic>> correlationsData;
  const _TopHabitCorrelationCard({
    required this.goalId,
    required this.correlationsData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);

    final currentGoal = goals.firstWhere(
      (g) => g.id == goalId,
      orElse: () => Goal(
        id: '',
        title: '',
        color: Colors.blue,
        startDate: DateTime.now(),
      ),
    );

    if (currentGoal.id.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<MapEntry<String, String>> correlationEntries = [];
    for (final item in correlationsData.take(4)) {
      final otherGoalId = item['other_goal_id'] as String;
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
        final percentage = (item['percentage'] as num?)?.toInt() ?? 0;
        final strength = percentage / 100.0;
        correlationEntries.add(
          MapEntry(
            otherGoal.title,
            '${strength >= 0 ? '+' : ''}${strength.toStringAsFixed(2)}',
          ),
        );
      }
    }

    final media = correlationEntries.isNotEmpty
        ? (correlationEntries
                      .map((e) => double.tryParse(e.value) ?? 0.0)
                      .reduce((a, b) => a + b) /
                  correlationEntries.length)
              .toStringAsFixed(2)
        : '0.00';

    return _AbitudineChiaveCard(
      title: currentGoal.title,
      dotColor: currentGoal.color,
      correlations: correlationEntries,
      extraConnections: correlationsData.length > 4
          ? correlationsData.length - 4
          : 0,
      media: media,
    );
  }
}

class _AbitudineChiaveCard extends StatelessWidget {
  final String title;
  final Color dotColor;
  final List<MapEntry<String, String>> correlations;
  final int extraConnections;
  final String media;

  const _AbitudineChiaveCard({
    required this.title,
    required this.dotColor,
    required this.correlations,
    required this.extraConnections,
    required this.media,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // width: 280, // Removed fixed width for PageView compatibility
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.background,
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
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.foreground,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Icon(
                LucideIcons.crown,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.t.statistics.highImpact,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${correlations.length + extraConnections} ${context.t.statistics.connections}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...correlations.map((c) {
            final isPositive = c.value.startsWith('+');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    c.key,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                  Text(
                    c.value,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPositive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Center(
            child: Text(
              context.t.statistics.additionalConnections(count: extraConnections),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: context.appColors.mutedForeground,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: context.appColors.border, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.chartSpline,
                    size: 14,
                    color: context.appColors.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.t.statistics.avgImpact,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              Text(
                media,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.appColors.foreground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CorrelationsSection extends ConsumerStatefulWidget {
  final String goalId;
  final bool isPositive;

  const _CorrelationsSection({required this.goalId, required this.isPositive});

  @override
  ConsumerState<_CorrelationsSection> createState() =>
      _CorrelationsSectionState();
}

class _CorrelationsSectionState extends ConsumerState<_CorrelationsSection> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correlationsAsync = ref.watch(
      habitCorrelationsProvider(widget.goalId),
    );
    final goals = ref.watch(goalsProvider);

    return correlationsAsync.when(
      data: (allCorrelations) {
        final currentGoal = goals.firstWhere(
          (g) => g.id == widget.goalId,
          orElse: () => Goal(
            id: '',
            title: '',
            color: Colors.blue,
            startDate: DateTime.now(),
          ),
        );

        if (currentGoal.id.isEmpty) {
          return const SizedBox.shrink();
        }

        final correlationsData = allCorrelations
            .where((c) => c['goal_id'] == widget.goalId)
            .toList();

        final filteredCorrelations = correlationsData.where((item) {
          final percentage = (item['percentage'] as num?)?.toInt() ?? 0;
          return widget.isPositive ? percentage >= 50 : percentage < 50;
        }).toList();

        if (filteredCorrelations.isEmpty) {
          return const SizedBox.shrink();
        }

        final List<Widget> cards = filteredCorrelations.take(4).map((item) {
          final otherGoalId = item['other_goal_id'] as String;
          final otherGoal = goals.firstWhere(
            (g) => g.id == otherGoalId,
            orElse: () => Goal(
              id: '',
              title: '',
              color: Colors.blue,
              startDate: DateTime.now(),
            ),
          );
          final percentage = (item['percentage'] as num?)?.toInt() ?? 0;
          final strength = percentage / 100.0;
          final togetherCount = (item['together_count'] as num?)?.toInt() ?? 0;

          return _CorrelazioneDetailCard(
            tag: widget.isPositive
                ? context.t.statistics.positiveCorrelation
                : context.t.statistics.negativeCorrelation,
            tagColor: widget.isPositive
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            habit1: currentGoal.title,
            habit1Color: currentGoal.color,
            habit2: otherGoal.title,
            habit2Color: otherGoal.color,
            coef: '${strength >= 0 ? '+' : ''}${strength.toStringAsFixed(2)}',
            cooccorrenza: '$percentage%',
            giorni: '$togetherCount',
            desc: widget.isPositive
                ? context.t.statistics.habitPositiveCorrelationDescription(currentGoal: currentGoal.title, percentage: percentage, otherGoal: otherGoal.title)
                : context.t.statistics.habitNegativeCorrelationDescription(currentGoal: currentGoal.title, percentage: percentage, otherGoal: otherGoal.title),
          );
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.isPositive
                      ? LucideIcons.trendingUp
                      : LucideIcons.trendingDown,
                  size: 16,
                  color: widget.isPositive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isPositive
                      ? context.t.statistics.positiveCorrelations
                      : context.t.statistics.negativeCorrelations,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.isPositive
                  ? context.t.statistics.habitsDoneTogether
                  : context.t.statistics.habitsNotDoneTogether,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: context.appColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),

            // Carousel
            SizedBox(
              height: 240,
              child: PageView.builder(
                controller: _pageController,
                itemCount: cards.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: cards[index],
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Pagination Dots
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(cards.length, (index) {
                  final isActive = _currentPage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? (widget.isPositive
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444))
                          : context.appColors.mutedForeground.withValues(
                              alpha: 0.3,
                            ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          '${context.t.common.status.error}: $err',
          style: TextStyle(color: context.appColors.mutedForeground),
        ),
      ),
    );
  }
}

class _CorrelazioneDetailCard extends StatelessWidget {
  final String tag;
  final Color tagColor;
  final String habit1;
  final Color habit1Color;
  final String habit2;
  final Color habit2Color;
  final String coef;
  final String cooccorrenza;
  final String giorni;
  final String desc;

  const _CorrelazioneDetailCard({
    required this.tag,
    required this.tagColor,
    required this.habit1,
    required this.habit1Color,
    required this.habit2,
    required this.habit2Color,
    required this.coef,
    required this.cooccorrenza,
    required this.giorni,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        20,
      ), // Increased padding for a more "airy" feel
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20), // Matched Key Habits
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
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tagColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.trendingUp, size: 10, color: tagColor),
                const SizedBox(width: 4),
                Text(
                  tag,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: tagColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: habit1Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        habit1,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.foreground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.link, size: 14, color: tagColor),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: habit2Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        habit2,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.foreground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DetailBox(
                  title: context.t.statistics.coefficient,
                  value: coef,
                  valueColor: tagColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DetailBox(
                  title: context.t.statistics.coOccurrence,
                  value: cooccorrenza,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DetailBox(
                  title: context.t.statistics.days,
                  value: giorni,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DirectionalIcon(
                LucideIcons.chevronRight,
                LucideIcons.chevronLeft,
                size: 14,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  desc,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: context.appColors.mutedForeground,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailBox extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const _DetailBox({required this.title, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              color: context.appColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? context.appColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttivitaRecenteSection extends ConsumerWidget {
  const _AttivitaRecenteSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final logs = ref.watch(habitLogsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      LucideIcons.calendarRange,
                      size: 18,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t.statistics.recentActivity,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.foreground,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        context.t.statistics.consistencyRecentMonths,
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
          const SizedBox(height: 24),

          // Activity Grid
          Center(child: _buildActivityGrid(context, accentColor, logs)),

          const SizedBox(height: 20),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                context.t.statistics.less,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 8),
              _buildDot(context, 0, accentColor),
              const SizedBox(width: 4),
              _buildDot(context, 1, accentColor),
              const SizedBox(width: 4),
              _buildDot(context, 2, accentColor),
              const SizedBox(width: 4),
              _buildDot(context, 3, accentColor),
              const SizedBox(width: 4),
              _buildDot(context, 4, accentColor),
              const SizedBox(width: 8),
              Text(
                context.t.statistics.more,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(BuildContext context, int intensity, Color accentColor) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _getColor(context, intensity, accentColor),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _getColor(BuildContext context, int intensity, Color accentColor) {
    switch (intensity) {
      case 0:
        return context.appColors.border.withValues(alpha: 0.3);
      case 1:
        return accentColor.withValues(alpha: 0.2);
      case 2:
        return accentColor.withValues(alpha: 0.4);
      case 3:
        return accentColor.withValues(alpha: 0.7);
      case 4:
        return accentColor;
      default:
        return context.appColors.border.withValues(alpha: 0.3);
    }
  }

  Widget _buildActivityGrid(
    BuildContext context,
    Color accentColor,
    HabitLogsMap logs,
  ) {
    const numRows = 7;
    const numCols = 18;

    final pattern = List.generate(
      numRows,
      (_) => List.generate(numCols, (_) => 0),
    );

    final today = DateTime.now();
    final currentDayOfWeek = today.weekday; // 1 = Mon, 7 = Sun
    final currentMonday = today.subtract(Duration(days: currentDayOfWeek - 1));

    for (int col = 0; col < numCols; col++) {
      for (int row = 0; row < numRows; row++) {
        final weeksBack = numCols - 1 - col;
        final date = currentMonday
            .subtract(Duration(days: weeksBack * 7))
            .add(Duration(days: row));

        if (date.isAfter(today)) {
          pattern[row][col] = -1;
          continue;
        }

        final dateStr =
            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

        final habitMap = logs[dateStr];
        if (habitMap != null) {
          int doneCount = 0;
          habitMap.forEach((habitId, status) {
            if (status == 'done') {
              doneCount++;
            }
          });
          pattern[row][col] = doneCount.clamp(0, 4);
        } else {
          pattern[row][col] = 0;
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const spacing = 4.0;
        const totalSpacing = spacing * (numCols - 1);
        final size = ((availableWidth - totalSpacing) / numCols).clamp(
          6.0,
          14.0,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(numCols, (colIndex) {
            return Padding(
              padding: EdgeInsets.only(
                right: colIndex == numCols - 1 ? 0 : spacing,
              ),
              child: Column(
                children: List.generate(numRows, (rowIndex) {
                  final intensity = pattern[rowIndex][colIndex];
                  if (intensity == -1) {
                    return SizedBox(width: size, height: size + spacing);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: spacing),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: _getColor(context, intensity, accentColor),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        );
      },
    );
  }
}
