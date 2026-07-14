// Net-new statistics widgets for the desktop Insights screen. Part of
// statistics_page.dart so they can reuse its private primitives (_Metric,
// _MetricGrid, _InlineInsight, _RaisedCard, _AlertsSection, _railWidth, …) and
// its imports (fl_chart, riverpod, theme, providers, i18n).
//
// Data comes from the net-new providers in statistics_rpc_providers.dart, each
// of which is mode-aware (Private encrypted DB / Cloud snapshot) via the shared
// unifiedAnalyticsDataProvider.
part of 'statistics_page.dart';

// ─── shared helpers ──────────────────────────────────────────────────────────

Color _momentumColor(double score) {
  if (score >= 66) return EvolveColors.success;
  if (score >= 40) return EvolveColors.amber;
  return EvolveColors.rose;
}

Color _habitColor(DashboardSnapshot snapshot, String? goalId, Color fallback) {
  if (goalId == null) return fallback;
  return snapshot.habits.where((h) => h.id == goalId).firstOrNull?.color ??
      fallback;
}

String _weekdayShort(int dow) {
  if (dow < 1 || dow > 7) return '';
  final name = t.common.weekdaysLong[dow - 1];
  return name.characters.take(3).toString();
}

String _monthShort(int month) {
  if (month < 1 || month > 12) return '';
  return t.common.months[month - 1].characters.take(3).toString();
}

/// Top habit by all-time completion rate, resolved to a title + rate.
({String title, int rate})? _topPerformer(
  DashboardSnapshot snapshot,
  List<Map<String, dynamic>> stats,
) {
  Map<String, dynamic>? best;
  for (final row in stats) {
    if (best == null ||
        ((row['rate'] as num?) ?? 0) > ((best['rate'] as num?) ?? 0)) {
      best = row;
    }
  }
  if (best == null) return null;
  final title = _habitTitleFor(snapshot, best['goal_id'] as String? ?? '');
  if (title == null) return null;
  return (title: title, rate: ((best['rate'] as num?) ?? 0).round());
}

int _maxBestStreak(List<Map<String, dynamic>> stats) {
  var max = 0;
  for (final row in stats) {
    final v = ((row['best_streak'] as num?) ?? 0).toInt();
    if (v > max) max = v;
  }
  return max;
}

// ═══ INFO TAB ════════════════════════════════════════════════════════════════

/// Momentum/Form ring: a 0–100 composite gauge with its three factor readouts.
class _MomentumRing extends StatelessWidget {
  const _MomentumRing({required this.momentum});

  final MomentumScore momentum;

  @override
  Widget build(BuildContext context) {
    final color = _momentumColor(momentum.score);
    return EvolvePanel(
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.momentumTitle,
            subtitle: t.stats.momentumSubtitle,
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: CircularProgressIndicator(
                      value: (momentum.score / 100).clamp(0.0, 1.0),
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor: context.evolveColors.panelSoft,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${momentum.score.round()}',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          height: 1,
                          color: color,
                        ),
                      ),
                      Text(
                        t.stats.momentumForm,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: context.evolveColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MomentumFactor(
                  label: t.stats.momentumRate,
                  value: '${(momentum.rate7 * 100).round()}%',
                ),
              ),
              Expanded(
                child: _MomentumFactor(
                  label: t.stats.momentumStreakHealth,
                  value: '${(momentum.streakHealth * 100).round()}%',
                ),
              ),
              Expanded(
                child: _MomentumFactor(
                  label: t.stats.momentumTrend,
                  value: momentum.trend > 0.5
                      ? t.stats.rollingImproving
                      : momentum.trend < 0.5
                      ? t.stats.rollingDeclining
                      : t.stats.rollingSteady,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MomentumFactor extends StatelessWidget {
  const _MomentumFactor({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: context.evolveColors.foreground,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: context.evolveColors.muted.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

/// The Info-tab hero: momentum ring beside the all-time lifetime tiles.
class _InfoHero extends ConsumerWidget {
  const _InfoHero({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final momentum = ref.watch(momentumProvider).value ?? MomentumScore.empty;
    final lifetime =
        ref.watch(lifetimeSummaryProvider).value ?? LifetimeSummary.empty;

    final tiles = _MetricGrid(
      tiles: [
        _Metric(
          label: t.stats.lifetimeConsistency,
          value: '${lifetime.consistency.round()}%',
          detail: t.stats.lifetimeConsistencyDetail,
          color: context.evolveAccent,
          icon: LucideIcons.target,
        ),
        _Metric(
          label: t.stats.lifetimeTotalDone,
          value: '${lifetime.totalCompletions}',
          detail: t.stats.lifetimeTotalDoneDetail,
          color: EvolveColors.success,
          icon: LucideIcons.circleCheck,
        ),
        _Metric(
          label: t.stats.lifetimePerfectDays,
          value: '${lifetime.perfectDays}',
          detail: t.stats.lifetimePerfectDaysDetail,
          color: EvolveColors.amber,
          icon: LucideIcons.star,
        ),
        _Metric(
          label: t.stats.lifetimeDaysTracked,
          value: '${lifetime.trackedDays}',
          detail: t.stats.lifetimeDaysTrackedDetail,
          color: EvolveColors.violet,
          icon: LucideIcons.calendarDays,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final ring = _MomentumRing(momentum: momentum);
        if (constraints.maxWidth < 920) {
          return Column(children: [ring, const SizedBox(height: 18), tiles]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 300, child: ring),
            const SizedBox(width: 18),
            Expanded(child: tiles),
          ],
        );
      },
    );
  }
}

/// The Keystone-habit insight card: the habit whose completion most lifts all
/// others. Hidden entirely when there isn't enough signal.
class _KeystoneCard extends ConsumerWidget {
  const _KeystoneCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keystone = ref.watch(keystoneHabitProvider).value;
    if (keystone == null) return const SizedBox.shrink();
    final title = _habitTitleFor(snapshot, keystone.goalId);
    if (title == null) return const SizedBox.shrink();
    final color = _habitColor(snapshot, keystone.goalId, context.evolveAccent);

    return EvolvePanel(
      glowColor: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EvolveIconChip(
            icon: LucideIcons.key,
            color: color,
            size: 44,
            iconSize: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.stats.keystoneTitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: context.evolveColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t.stats.keystoneImpact(
                    withPct: keystone.withRate.round(),
                    withoutPct: keystone.withoutRate.round(),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusPill(
            label: '+${keystone.lift.round()}%',
            color: EvolveColors.success,
            icon: LucideIcons.trendingUp,
          ),
        ],
      ),
    );
  }
}

/// GitHub-style 365-day contribution grid across every habit (7 weekday rows ×
/// ~53 week columns). Uses [DashboardSnapshot.completionFor], which works in
/// both data modes.
class _YearContributionHeatmap extends StatelessWidget {
  const _YearContributionHeatmap({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 364));
    final values = [
      for (var i = 0; i < 365; i++)
        snapshot.completionFor(start.add(Duration(days: i))),
    ];
    final leadPad = start.weekday - 1; // Monday-aligned rows
    final weeks = ((leadPad + 365) / 7).ceil();
    final accent = context.evolveAccent;
    final activeDays = values.where((v) => v > 0).length;

    Widget cell(int cellIndex) {
      final dataIndex = cellIndex - leadPad;
      if (dataIndex < 0 || dataIndex >= 365) {
        return const SizedBox(width: 14, height: 14);
      }
      final v = values[dataIndex];
      return Container(
        width: 11,
        height: 11,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: v <= 0
              ? context.evolveColors.panelSoft
              : accent.withValues(alpha: 0.2 + v.clamp(0.0, 1.0) * 0.7),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.yearActivity,
            subtitle: t.stats.yearActivitySubtitle,
            trailing: StatusPill(
              label: t.stats.activeDaysCount(count: activeDays),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var w = 0; w < weeks; w++)
                  Column(
                    children: [for (var r = 0; r < 7; r++) cell(w * 7 + r)],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                t.stats.heatmapLess,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              for (final a in const [0.2, 0.4, 0.6, 0.9])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: a),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                t.stats.heatmapMore,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══ TREND TAB ═══════════════════════════════════════════════════════════════

/// A ranked habit list panel (icon + heading, then numbered rows).
class _RankPanel extends StatelessWidget {
  const _RankPanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EvolveIconChip(
                icon: icon,
                color: iconColor,
                size: 34,
                iconSize: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: context.evolveColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.evolveColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              t.stats.moreLogsNeeded,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              items[i],
            ],
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.color,
    required this.title,
    required this.valueLabel,
    required this.valueColor,
    this.subLabel,
  });

  final int rank;
  final Color color;
  final String title;
  final String valueLabel;
  final Color valueColor;
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.evolveColors.muted.withValues(alpha: 0.7),
            ),
          ),
        ),
        _HabitDot(color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: context.evolveColors.foreground,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: valueColor,
              ),
            ),
            if (subLabel != null)
              Text(
                subLabel!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.evolveColors.muted.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The extra Trend-tab content stacked under the hero: best/critical ranked
/// lists, rolling completion, this-week-vs-average, the weekly-rhythm radar,
/// weekday-vs-weekend and seasonality.
class _TrendExtras extends ConsumerWidget {
  const _TrendExtras({required this.snapshot, required this.timeframe});

  final DashboardSnapshot snapshot;
  final _TrendTimeframe timeframe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final best =
        ref.watch(bestHabitsRpcProvider(timeframe.token)).value ?? const [];
    final critical = ref.watch(criticalHabitsRpcProvider).value ?? const [];

    final bestItems = <Widget>[];
    for (final row in best.take(5)) {
      final id = row['goal_id'] as String?;
      final title = id == null ? null : _habitTitleFor(snapshot, id);
      if (title == null) continue;
      bestItems.add(
        _RankRow(
          rank: bestItems.length + 1,
          color: _habitColor(snapshot, id, context.evolveAccent),
          title: title,
          valueLabel: '${((row['rate'] as num?) ?? 0).round()}%',
          valueColor: context.evolveAccent,
          subLabel: t.dashboard.streakDaysShort(
            n: ((row['streak'] as num?) ?? 0).toInt(),
          ),
        ),
      );
    }

    final criticalItems = <Widget>[];
    for (final row in critical.take(5)) {
      final id = row['goal_id'] as String?;
      final title = id == null ? null : _habitTitleFor(snapshot, id);
      if (title == null) continue;
      final drop = ((row['drop'] as num?) ?? 0).round();
      final neg = ((row['neg_streak'] as num?) ?? 0).toInt();
      criticalItems.add(
        _RankRow(
          rank: criticalItems.length + 1,
          color: _habitColor(snapshot, id, EvolveColors.rose),
          title: title,
          valueLabel: drop > 0 ? '-$drop%' : t.stats.criticalStalled(days: neg),
          valueColor: EvolveColors.rose,
          subLabel: drop > 0 ? t.stats.criticalStalled(days: neg) : null,
        ),
      );
    }

    final bestPanel = _RankPanel(
      icon: LucideIcons.trophy,
      iconColor: context.evolveAccent,
      title: t.stats.bestHabitsTitle,
      subtitle: t.stats.bestHabitsSubtitle,
      items: bestItems,
    );
    final criticalPanel = _RankPanel(
      icon: LucideIcons.circleAlert,
      iconColor: EvolveColors.rose,
      title: t.stats.criticalHabitsTitle,
      subtitle: t.stats.criticalHabitsSubtitle,
      items: criticalItems,
    );

    return Column(
      children: [
        _twoUp(bestPanel, criticalPanel),
        const SizedBox(height: 18),
        _twoUp(
          _RollingTrendPanel(snapshot: snapshot),
          _WeekVsAveragePanel(snapshot: snapshot),
        ),
        const SizedBox(height: 18),
        _twoUp(const _WeeklyRadarPanel(), const _WeekdayWeekendPanel()),
        const SizedBox(height: 18),
        const _SeasonalityPanel(),
      ],
    );
  }
}

/// Two panels side by side above 1120px content width, stacked below.
Widget _twoUp(Widget a, Widget b) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 1120) {
        return Column(children: [a, const SizedBox(height: 18), b]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 18),
          Expanded(child: b),
        ],
      );
    },
  );
}

/// Rolling 7-day and 30-day completion, each with an improving/declining arrow
/// relative to the preceding equal window.
class _RollingTrendPanel extends StatelessWidget {
  const _RollingTrendPanel({required this.snapshot});

  final DashboardSnapshot snapshot;

  double _windowRate(int startAgo, int endAgo) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var sum = 0.0;
    var n = 0;
    for (var ago = startAgo; ago <= endAgo; ago++) {
      sum += snapshot.completionFor(today.subtract(Duration(days: ago)));
      n++;
    }
    return n == 0 ? 0 : sum / n;
  }

  @override
  Widget build(BuildContext context) {
    final r7 = _windowRate(0, 6);
    final r7prev = _windowRate(7, 13);
    final r30 = _windowRate(0, 29);
    final r30prev = _windowRate(30, 59);

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.rollingTitle,
            subtitle: t.stats.rollingSubtitle,
          ),
          const SizedBox(height: 18),
          _RollingRow(label: t.stats.rolling7, rate: r7, delta: r7 - r7prev),
          const SizedBox(height: 16),
          _RollingRow(
            label: t.stats.rolling30,
            rate: r30,
            delta: r30 - r30prev,
          ),
        ],
      ),
    );
  }
}

class _RollingRow extends StatelessWidget {
  const _RollingRow({
    required this.label,
    required this.rate,
    required this.delta,
  });

  final String label;
  final double rate;
  final double delta;

  @override
  Widget build(BuildContext context) {
    final improving = delta >= 0;
    final deltaColor = delta.abs() < 0.005
        ? context.evolveColors.muted
        : improving
        ? EvolveColors.success
        : EvolveColors.destructive;
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.evolveColors.muted,
            ),
          ),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: rate.clamp(0.0, 1.0),
            minHeight: 8,
            color: context.evolveAccent,
            backgroundColor: context.evolveColors.panelSoft,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 44,
          child: Text(
            '${(rate * 100).round()}%',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.evolveColors.foreground,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          improving ? LucideIcons.trendingUp : LucideIcons.trendingDown,
          size: 15,
          color: deltaColor,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${delta >= 0 ? '+' : ''}${(delta * 100).round()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: deltaColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// This week's completion vs the user's average week.
class _WeekVsAveragePanel extends StatelessWidget {
  const _WeekVsAveragePanel({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final thisWeek = snapshot.currentWeekCompletionRate;
    // Average week = mean of the daily completion over the last 8 weeks.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var sum = 0.0;
    for (var i = 0; i < 56; i++) {
      sum += snapshot.completionFor(today.subtract(Duration(days: i)));
    }
    final average = sum / 56;
    final diff = thisWeek - average;

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.weekVsAvgTitle,
            subtitle: t.stats.weekVsAvgSubtitle,
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(thisWeek * 100).round()}%',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1,
                  color: context.evolveColors.foreground,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: StatusPill(
                  label: '${diff >= 0 ? '+' : ''}${(diff * 100).round()}%',
                  color: diff >= 0
                      ? EvolveColors.success
                      : EvolveColors.destructive,
                  icon: diff >= 0
                      ? LucideIcons.trendingUp
                      : LucideIcons.trendingDown,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LevelBar(
            label: t.stats.thisWeek,
            percentage: (thisWeek * 100).round(),
            color: context.evolveAccent,
          ),
          const SizedBox(height: 14),
          _LevelBar(
            label: t.stats.yourAverage,
            percentage: (average * 100).round(),
            color: EvolveColors.violet,
          ),
        ],
      ),
    );
  }
}

/// The weekly-rhythm radar: completion % across the seven weekdays.
class _WeeklyRadarPanel extends ConsumerWidget {
  const _WeeklyRadarPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(globalWeekdayPerformanceProvider).value ?? const [];
    final byDay = {for (final r in rows) r.dayIndex: r};
    final values = [for (var d = 1; d <= 7; d++) (byDay[d]?.rate ?? 0)];
    final maxVal = values.fold<double>(0, (m, v) => v > m ? v : m);

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.weekdayShapeTitle,
            subtitle: t.stats.weekdayShapeSubtitle,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: maxVal <= 0
                ? _EmptyState(
                    icon: LucideIcons.radar,
                    title: t.stats.moreLogsNeeded,
                  )
                : RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.polygon,
                      dataSets: [
                        RadarDataSet(
                          dataEntries: [
                            for (final v in values) RadarEntry(value: v),
                          ],
                          fillColor: context.evolveAccent.withValues(
                            alpha: 0.18,
                          ),
                          borderColor: context.evolveAccent,
                          borderWidth: 2.5,
                          entryRadius: 2,
                        ),
                      ],
                      radarBackgroundColor: Colors.transparent,
                      radarBorderData: BorderSide(
                        color: context.evolveColors.border.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      gridBorderData: BorderSide(
                        color: context.evolveColors.border.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      tickBorderData: BorderSide(
                        color: context.evolveColors.border.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      tickCount: 4,
                      ticksTextStyle: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 8,
                      ),
                      titlePositionPercentageOffset: 0.14,
                      titleTextStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.evolveColors.muted,
                      ),
                      getTitle: (index, angle) =>
                          RadarChartTitle(text: _weekdayShort(index + 1)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Weekday vs weekend completion comparison.
class _WeekdayWeekendPanel extends ConsumerWidget {
  const _WeekdayWeekendPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final split = ref.watch(weekdayWeekendProvider).value;
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.weekdayWeekendTitle,
            subtitle: t.stats.weekdayWeekendSubtitle,
          ),
          const SizedBox(height: 18),
          if (split == null || !split.hasData)
            _EmptyState(
              icon: LucideIcons.calendar,
              title: t.stats.moreLogsNeeded,
            )
          else ...[
            _LevelBar(
              label: t.stats.weekdaysLabel,
              percentage: split.weekdayRate.round(),
              color: context.evolveAccent,
            ),
            const SizedBox(height: 16),
            _LevelBar(
              label: t.stats.weekendLabel,
              percentage: split.weekendRate.round(),
              color: EvolveColors.violet,
            ),
          ],
        ],
      ),
    );
  }
}

/// Completion by calendar month, with the strongest/weakest month highlighted.
class _SeasonalityPanel extends ConsumerWidget {
  const _SeasonalityPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(seasonalityProvider).value ?? const [];
    final withData = rows.where((r) => r.total > 0).toList();
    final maxRate = withData.fold<double>(0, (m, r) => r.rate > m ? r.rate : m);

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.seasonalityTitle,
            subtitle: t.stats.seasonalitySubtitle,
          ),
          const SizedBox(height: 18),
          if (withData.isEmpty)
            _EmptyState(
              icon: LucideIcons.calendarRange,
              title: t.stats.moreLogsNeeded,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final r in rows)
                      Expanded(
                        child: _SeasonBar(
                          month: r.month,
                          rate: r.rate,
                          hasData: r.total > 0,
                          isBest:
                              maxRate > 0 && r.rate == maxRate && r.total > 0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SeasonBar extends StatelessWidget {
  const _SeasonBar({
    required this.month,
    required this.rate,
    required this.hasData,
    required this.isBest,
  });

  final int month;
  final double rate;
  final bool hasData;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final color = isBest ? EvolveColors.success : context.evolveAccent;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          hasData ? '${rate.round()}' : '',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: context.evolveColors.muted,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FractionallySizedBox(
              heightFactor: hasData ? (rate / 100).clamp(0.02, 1.0) : 0.02,
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: hasData
                      ? color.withValues(alpha: 0.85)
                      : context.evolveColors.panelSoft,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _monthShort(month),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: context.evolveColors.muted.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

// ═══ ALERTS TAB (extras appended under the existing sections) ════════════════

/// Bounce-back (recovery-after-a-miss) + danger-zone, side by side.
class _AlertsExtras extends ConsumerWidget {
  const _AlertsExtras({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bounce = ref.watch(bounceBackProvider).value ?? BounceBackStats.empty;
    final danger = ref.watch(dangerZoneProvider).value;
    if (bounce.opportunities == 0 && danger == null) {
      return const SizedBox.shrink();
    }
    return _twoUp(
      _BounceBackPanel(snapshot: snapshot, stats: bounce),
      _DangerZonePanel(danger: danger),
    );
  }
}

class _BounceBackPanel extends StatelessWidget {
  const _BounceBackPanel({required this.snapshot, required this.stats});

  final DashboardSnapshot snapshot;
  final BounceBackStats stats;

  @override
  Widget build(BuildContext context) {
    final color = stats.globalRate >= 50
        ? EvolveColors.success
        : EvolveColors.amber;
    return EvolvePanel(
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EvolveIconChip(
                icon: LucideIcons.undo2,
                color: color,
                size: 36,
                iconSize: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SectionHeading(
                  title: t.stats.bounceBackTitle,
                  subtitle: t.stats.bounceBackSubtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${stats.globalRate.round()}%',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  t.stats.bounceBackDetail(
                    recoveries: stats.recoveries,
                    opportunities: stats.opportunities,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (stats.habits.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final h in stats.habits.take(3)) ...[
              _InlineInsight(
                title: _habitTitleFor(snapshot, h.goalId) ?? '—',
                value: '${h.rate.round()}%',
                color: h.rate >= 50 ? EvolveColors.success : EvolveColors.amber,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _DangerZonePanel extends StatelessWidget {
  const _DangerZonePanel({required this.danger});

  final DangerZone? danger;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      glowColor: EvolveColors.rose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EvolveIconChip(
                icon: LucideIcons.triangleAlert,
                color: EvolveColors.rose,
                size: 36,
                iconSize: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SectionHeading(
                  title: t.stats.dangerZoneTitle,
                  subtitle: t.stats.dangerZoneSubtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (danger == null)
            _EmptyState(
              icon: LucideIcons.shieldCheck,
              title: t.stats.dangerZoneNone,
            )
          else ...[
            Text(
              _weekdayName(danger!.weekday),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: EvolveColors.rose,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.stats.dangerZoneDetail(
                breaks: danger!.breaks,
                total: danger!.totalBreaks,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// Performance-comparison (best-vs-worst streak gap) cards for the Alerts tab.
List<Widget> _performanceComparisonCards(
  DashboardSnapshot snapshot,
  List<Map<String, dynamic>> stats,
) {
  final rows = [...stats]
    ..sort(
      (a, b) => ((b['best_streak'] as num?) ?? 0).compareTo(
        (a['best_streak'] as num?) ?? 0,
      ),
    );
  final cards = <Widget>[];
  for (final row in rows.take(3)) {
    final id = row['goal_id'] as String?;
    if (id == null) continue;
    final habit = snapshot.habits.where((h) => h.id == id).firstOrNull;
    if (habit == null) continue;
    final best = ((row['best_streak'] as num?) ?? 0).toInt();
    final worst = ((row['worst_streak'] as num?) ?? 0).toInt();
    if (best <= 0) continue;
    cards.add(
      _PerformanceComparisonCard(
        title: habit.title,
        best: best,
        worst: worst,
        color: habit.color,
      ),
    );
  }
  return cards;
}

class _PerformanceComparisonCard extends StatelessWidget {
  const _PerformanceComparisonCard({
    required this.title,
    required this.best,
    required this.worst,
    required this.color,
  });

  final String title;
  final int best;
  final int worst;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final gap = best > 0 ? ((best - worst) / best * 100).round() : 0;
    return _RaisedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HabitDot(color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: context.evolveColors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                t.stats.perfCompGap(pct: gap),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: EvolveColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MicroStat(
                label: t.stats.perfCompBest,
                value: '$best',
                color: EvolveColors.success,
              ),
              _MicroStat(
                label: t.stats.perfCompWorst,
                value: '$worst',
                color: EvolveColors.destructive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══ HABITS TAB (extras appended under the performance table) ════════════════

class _HabitsExtras extends ConsumerWidget {
  const _HabitsExtras({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(habitStatsRpcProvider).value ?? const [];
    if (stats.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 18),
        _twoUp(
          _ConsistencyPanel(snapshot: snapshot),
          _MedalsPanel(snapshot: snapshot, stats: stats),
        ),
        const SizedBox(height: 18),
        _twoUp(
          _DistributionPanel(stats: stats),
          _CategoryBreakdownPanel(snapshot: snapshot, stats: stats),
        ),
        const SizedBox(height: 18),
        _SynergyMatrixPanel(snapshot: snapshot),
      ],
    );
  }
}

/// Steadiest and most-erratic habits by the regularity (consistency) score.
class _ConsistencyPanel extends ConsumerWidget {
  const _ConsistencyPanel({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(consistencyScoresProvider).value ?? const [];
    Widget row(ConsistencyScore s, Color color) {
      final title = _habitTitleFor(snapshot, s.goalId);
      if (title == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _InlineInsight(
          title: title,
          value: '${s.score.round()}',
          color: color,
        ),
      );
    }

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.consistencyTitle,
            subtitle: t.stats.consistencySubtitle,
          ),
          const SizedBox(height: 16),
          if (scores.isEmpty)
            _EmptyState(
              icon: LucideIcons.activity,
              title: t.stats.moreLogsNeeded,
            )
          else ...[
            Text(
              t.stats.consistencySteadiest,
              style: const TextStyle(
                color: EvolveColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final s in scores.take(3)) row(s, EvolveColors.success),
            if (scores.length > 3) ...[
              const SizedBox(height: 6),
              Text(
                t.stats.consistencyErratic,
                style: const TextStyle(
                  color: EvolveColors.rose,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final s in scores.reversed.take(2))
                row(s, EvolveColors.rose),
            ],
          ],
        ],
      ),
    );
  }
}

/// Current-streak medal leaderboard + a "never missed" (100% since start) list.
class _MedalsPanel extends StatelessWidget {
  const _MedalsPanel({required this.snapshot, required this.stats});

  final DashboardSnapshot snapshot;
  final List<Map<String, dynamic>> stats;

  static const _medals = [
    EvolveColors.amber,
    Color(0xFFB8B8C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final byStreak = [...stats]
      ..sort(
        (a, b) => ((b['current_streak'] as num?) ?? 0).compareTo(
          (a['current_streak'] as num?) ?? 0,
        ),
      );
    final leaders = byStreak
        .where((r) => ((r['current_streak'] as num?) ?? 0) > 0)
        .take(3)
        .toList();
    final neverMissed = stats
        .where((r) => ((r['rate'] as num?) ?? 0) >= 100)
        .toList();

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.medalsTitle,
            subtitle: t.stats.medalsSubtitle,
          ),
          const SizedBox(height: 16),
          if (leaders.isEmpty)
            _EmptyState(icon: LucideIcons.medal, title: t.stats.moreLogsNeeded)
          else
            for (var i = 0; i < leaders.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _MedalRow(
                medalColor: _medals[i],
                color: _habitColor(
                  snapshot,
                  leaders[i]['goal_id'] as String?,
                  context.evolveAccent,
                ),
                title:
                    _habitTitleFor(
                      snapshot,
                      leaders[i]['goal_id'] as String? ?? '',
                    ) ??
                    '—',
                streak: ((leaders[i]['current_streak'] as num?) ?? 0).toInt(),
              ),
            ],
          const SizedBox(height: 16),
          Text(
            t.stats.neverMissedTitle,
            style: const TextStyle(
              color: EvolveColors.violet,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (neverMissed.isEmpty)
            Text(
              t.stats.neverMissedEmpty,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in neverMissed)
                  StatusPill(
                    label:
                        _habitTitleFor(
                          snapshot,
                          r['goal_id'] as String? ?? '',
                        ) ??
                        '—',
                    color: EvolveColors.violet,
                    icon: LucideIcons.check,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MedalRow extends StatelessWidget {
  const _MedalRow({
    required this.medalColor,
    required this.color,
    required this.title,
    required this.streak,
  });

  final Color medalColor;
  final Color color;
  final String title;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(LucideIcons.medal, size: 18, color: medalColor),
        const SizedBox(width: 10),
        _HabitDot(color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: context.evolveColors.foreground,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          t.dashboard.streakDaysShort(n: streak),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: EvolveColors.success,
          ),
        ),
      ],
    );
  }
}

/// Histogram of habits bucketed by all-time completion rate.
class _DistributionPanel extends StatelessWidget {
  const _DistributionPanel({required this.stats});

  final List<Map<String, dynamic>> stats;

  @override
  Widget build(BuildContext context) {
    const bucketCount = 5; // 0-20, 20-40, 40-60, 60-80, 80-100
    final buckets = List<int>.filled(bucketCount, 0);
    for (final row in stats) {
      final rate = ((row['rate'] as num?) ?? 0).toDouble().clamp(0.0, 100.0);
      var idx = (rate / 20).floor();
      if (idx >= bucketCount) idx = bucketCount - 1;
      buckets[idx]++;
    }
    final maxCount = buckets.fold<int>(0, (m, c) => c > m ? c : m);

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.distributionTitle,
            subtitle: t.stats.distributionSubtitle,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < bucketCount; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${buckets[i]}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.evolveColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: FractionallySizedBox(
                              heightFactor: maxCount == 0
                                  ? 0.02
                                  : (buckets[i] / maxCount).clamp(0.02, 1.0),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.evolveAccent.withValues(
                                    alpha: 0.35 + 0.14 * i,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${i * 20}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: context.evolveColors.muted.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
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

/// Completion rate per habit category. Hidden unless ≥2 distinct categories.
class _CategoryBreakdownPanel extends StatelessWidget {
  const _CategoryBreakdownPanel({required this.snapshot, required this.stats});

  final DashboardSnapshot snapshot;
  final List<Map<String, dynamic>> stats;

  @override
  Widget build(BuildContext context) {
    final categoryOf = {for (final h in snapshot.habits) h.id: h.category};
    final done = <String, int>{};
    final active = <String, int>{};
    for (final row in stats) {
      final id = row['goal_id'] as String?;
      final cat = id == null ? null : categoryOf[id];
      if (cat == null || cat.isEmpty) continue;
      done[cat] =
          (done[cat] ?? 0) + ((row['total_completions'] as num?) ?? 0).toInt();
      active[cat] =
          (active[cat] ?? 0) +
          ((row['total_active_days'] as num?) ?? 0).toInt();
    }
    if (done.length < 2) return const SizedBox.shrink();

    final entries = done.keys.map((cat) {
      final a = active[cat] ?? 0;
      return (category: cat, rate: a > 0 ? (done[cat]! * 100 / a) : 0.0);
    }).toList()..sort((x, y) => y.rate.compareTo(x.rate));

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.categoryTitle,
            subtitle: t.stats.categorySubtitle,
          ),
          const SizedBox(height: 16),
          for (final e in entries) ...[
            _LevelBar(
              label: e.category,
              percentage: e.rate.round(),
              color: context.evolveAccent,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

/// N×N habit co-completion matrix — which pairs of habits move together.
class _SynergyMatrixPanel extends ConsumerWidget {
  const _SynergyMatrixPanel({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(allHabitCorrelationsRpcProvider).value ?? const [];
    final habits = snapshot.habits;
    if (habits.length < 2) return const SizedBox.shrink();

    // pair percentage lookup
    final pct = <String, Map<String, int>>{};
    for (final row in rows) {
      final a = row['goal_id'] as String?;
      final b = row['other_goal_id'] as String?;
      if (a == null || b == null) continue;
      (pct[a] ??= {})[b] = ((row['percentage'] as num?) ?? 0).toInt();
    }

    const cell = 34.0;
    final accent = context.evolveAccent;
    Widget matrixCell(DashboardHabit rowH, DashboardHabit colH) {
      if (rowH.id == colH.id) {
        return Container(
          width: cell,
          height: cell,
          alignment: Alignment.center,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: context.evolveColors.panelSoft,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            LucideIcons.minus,
            size: 12,
            color: context.evolveColors.subtle,
          ),
        );
      }
      final value = pct[rowH.id]?[colH.id] ?? 0;
      return Container(
        width: cell,
        height: cell,
        alignment: Alignment.center,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: accent.withValues(
            alpha: 0.08 + (value / 100).clamp(0.0, 1.0) * 0.72,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: value > 55 ? Colors.black : context.evolveColors.foreground,
          ),
        ),
      );
    }

    return EvolvePanel(
      glowColor: EvolveColors.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.synergyTitle,
            subtitle: t.stats.synergySubtitle,
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // header row of dots
                Row(
                  children: [
                    const SizedBox(width: 120),
                    for (final colH in habits)
                      SizedBox(
                        width: cell + 2,
                        child: Center(child: _HabitDot(color: colH.color)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                for (final rowH in habits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Row(
                            children: [
                              _HabitDot(color: rowH.color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  rowH.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.evolveColors.foreground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final colH in habits) matrixCell(rowH, colH),
                      ],
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

// ═══ MOOD TAB (parity fills) ═════════════════════════════════════════════════

class _MoodExtras extends ConsumerWidget {
  const _MoodExtras({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final correlations =
        ref.watch(moodCorrelationsRpcProvider).value ?? const [];
    final sensitive = [...correlations]
      ..sort((a, b) => b.sensitivity.compareTo(a.sensitivity));
    final moodSensitive = sensitive
        .where((c) => c.sensitivity > 10)
        .take(3)
        .toList();
    final resilient =
        ([...correlations]
              ..sort((a, b) => b.resilience.compareTo(a.resilience)))
            .where((c) => c.resilience > 50)
            .take(3)
            .toList();
    final analysis = sensitive.take(3).toList();

    return Column(
      children: [
        const SizedBox(height: 18),
        _MoodEnergyLineChart(snapshot: snapshot),
        const SizedBox(height: 18),
        _twoUp(
          _MoodListPanel(
            icon: LucideIcons.heartPulse,
            iconColor: EvolveColors.violet,
            title: t.stats.moodSensitiveTitle,
            subtitle: t.stats.moodSensitiveSubtitle,
            snapshot: snapshot,
            items: moodSensitive,
            valueOf: (c) => '${c.sensitivity}%',
          ),
          _MoodListPanel(
            icon: LucideIcons.shield,
            iconColor: context.evolveAccent,
            title: t.stats.resilientHabitsTitle,
            subtitle: t.stats.resilientHabitsSubtitle,
            snapshot: snapshot,
            items: resilient,
            valueOf: (c) => '${c.resilience}%',
          ),
        ),
        const SizedBox(height: 18),
        _MoodCorrelationAnalysisPanel(snapshot: snapshot, items: analysis),
      ],
    );
  }
}

/// Two fl_chart lines (mood + energy, 0–10) over the last 30 check-in days.
class _MoodEnergyLineChart extends StatelessWidget {
  const _MoodEnergyLineChart({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    const days = 30;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final moodSpots = <FlSpot>[];
    final energySpots = <FlSpot>[];
    for (var i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: days - 1 - i));
      final checkIn = snapshot.moods[dashboardDateKey(date)];
      if (checkIn == null) continue;
      if (checkIn.mood != null) {
        moodSpots.add(FlSpot(i.toDouble(), checkIn.mood!.toDouble()));
      }
      if (checkIn.energy != null) {
        energySpots.add(FlSpot(i.toDouble(), checkIn.energy!.toDouble()));
      }
    }
    final colors = context.evolveColors;

    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.moodEnergyTrendTitle,
            subtitle: t.stats.moodEnergyTrendSubtitle(days: days),
          ),
          const SizedBox(height: 16),
          if (moodSpots.length < 2 && energySpots.length < 2)
            _EmptyState(icon: LucideIcons.smile, title: t.stats.moreLogsNeeded)
          else ...[
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (days - 1).toDouble(),
                  minY: 0,
                  maxY: 10,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 2.5,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: colors.border.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 2.5,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: TextStyle(fontSize: 10, color: colors.muted),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: moodSpots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: EvolveColors.violet,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: energySpots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: EvolveColors.amber,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GridLegend(
                  color: EvolveColors.violet,
                  label: t.statistics.mood2,
                ),
                const SizedBox(width: 16),
                _GridLegend(
                  color: EvolveColors.amber,
                  label: t.statistics.energy,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodListPanel extends StatelessWidget {
  const _MoodListPanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.snapshot,
    required this.items,
    required this.valueOf,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final DashboardSnapshot snapshot;
  final List<MoodCorrelation> items;
  final String Function(MoodCorrelation) valueOf;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EvolveIconChip(
                icon: icon,
                color: iconColor,
                size: 34,
                iconSize: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SectionHeading(title: title, subtitle: subtitle),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            _EmptyState(icon: icon, title: t.stats.moreLogsNeeded)
          else
            for (final c in items) ...[
              _InlineInsight(
                title: _habitTitleFor(snapshot, c.goalId) ?? '—',
                value: valueOf(c),
                color: iconColor,
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

/// Per-habit low-vs-high-mood completion bars for the top mood-swayed habits.
class _MoodCorrelationAnalysisPanel extends StatelessWidget {
  const _MoodCorrelationAnalysisPanel({
    required this.snapshot,
    required this.items,
  });

  final DashboardSnapshot snapshot;
  final List<MoodCorrelation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.correlationAnalysisTitle,
            subtitle: t.stats.correlationAnalysisSubtitle,
          ),
          const SizedBox(height: 18),
          for (final c in items) ...[
            Text(
              _habitTitleFor(snapshot, c.goalId) ?? '—',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: context.evolveColors.foreground,
              ),
            ),
            const SizedBox(height: 10),
            _LevelBar(
              label: t.statistics.withHighMood,
              percentage: c.highMoodPct,
              color: EvolveColors.success,
            ),
            const SizedBox(height: 10),
            _LevelBar(
              label: t.statistics.withLowMood,
              percentage: c.lowMoodPct,
              color: EvolveColors.rose,
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
