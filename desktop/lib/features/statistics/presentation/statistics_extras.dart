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

/// [d] shifted by [n] calendar days, landing on local midnight. Mirrors
/// `_shiftDays` in `features/statistics/data/private_analytics.dart` and
/// `core/streak_utils.dart`. Replaces `d.add(Duration(days: n))`, which steps a
/// fixed 24h and so lands on the wrong calendar day across a DST transition: a
/// 23h day is skipped entirely and a 25h day is visited twice.
DateTime _shiftDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// The 365 calendar days ending on [today], oldest → newest — the window every
/// year heatmap renders. Shared so the grids cannot drift apart, and so the
/// walk matches `computeYearlyGrid`, which keys the same window server-side.
@visibleForTesting
List<DateTime> yearHeatmapDays(DateTime today) {
  final start = _shiftDays(today, -364);
  return [for (var i = 0; i < 365; i++) _shiftDays(start, i)];
}

/// Mean completion across every habit active on each of [yearHeatmapDays] — the
/// GitHub-style contribution grid's data.
@visibleForTesting
List<double> yearContributionValues(
  DashboardSnapshot snapshot,
  DateTime today,
) => [for (final day in yearHeatmapDays(today)) snapshot.completionFor(day)];

Color _momentumColor(double score) {
  if (score >= 66) return EvolveColors.success;
  if (score >= 40) return EvolveColors.amber;
  return EvolveColors.destructive;
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
    final values = yearContributionValues(snapshot, today);
    final leadPad = _shiftDays(today, -364).weekday - 1; // Monday-aligned rows
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
          color: _habitColor(snapshot, id, EvolveColors.destructive),
          title: title,
          valueLabel: drop > 0 ? '-$drop%' : t.stats.criticalStalled(days: neg),
          valueColor: EvolveColors.destructive,
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
      iconColor: EvolveColors.destructive,
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
      sum += snapshot.completionFor(
        DateTime(today.year, today.month, today.day - ago),
      );
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
      sum += snapshot.completionFor(
        DateTime(today.year, today.month, today.day - i),
      );
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
                          fillColor: Colors.transparent,
                          borderColor: context.evolveAccent.withValues(alpha: 0.3),
                          borderWidth: 8,
                          entryRadius: 0,
                        ),
                        RadarDataSet(
                          dataEntries: [
                            for (final v in values) RadarEntry(value: v),
                          ],
                          fillColor: context.evolveAccent.withValues(alpha: 0.15),
                          borderColor: context.evolveAccent,
                          borderWidth: 2.5,
                          entryRadius: 3,
                        ),
                      ],
                      radarBackgroundColor: Colors.transparent,
                      radarBorderData: BorderSide.none,
                      gridBorderData: BorderSide(
                        color: context.evolveColors.border.withValues(
                          alpha: 0.15,
                        ),
                        width: 1,
                      ),
                      tickBorderData: BorderSide.none,
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
      glowColor: EvolveColors.destructive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EvolveIconChip(
                icon: LucideIcons.triangleAlert,
                color: EvolveColors.destructive,
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
                color: EvolveColors.destructive,
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
  // Rank by the SAME best-vs-worst-streak gap that's displayed (mobile parity),
  // and clamp a negative gap (worst > best) to 0 rather than surfacing a
  // nonsensical negative percentage.
  final scored = <({DashboardHabit habit, int best, int worst, int gap})>[];
  for (final row in stats) {
    final id = row['goal_id'] as String?;
    if (id == null) continue;
    final habit = snapshot.habits.where((h) => h.id == id).firstOrNull;
    if (habit == null) continue;
    final best = ((row['best_streak'] as num?) ?? 0).toInt();
    final worst = ((row['worst_streak'] as num?) ?? 0).toInt();
    if (best <= 0) continue;
    final gap = (((best - worst) / best) * 100).round().clamp(0, 100);
    scored.add((habit: habit, best: best, worst: worst, gap: gap));
  }
  scored.sort((a, b) => b.gap.compareTo(a.gap));
  return [
    for (final s in scored.take(3))
      _PerformanceComparisonCard(
        title: s.habit.title,
        best: s.best,
        worst: s.worst,
        gap: s.gap,
        color: s.habit.color,
      ),
  ];
}

class _PerformanceComparisonCard extends StatelessWidget {
  const _PerformanceComparisonCard({
    required this.title,
    required this.best,
    required this.worst,
    required this.gap,
    required this.color,
  });

  final String title;
  final int best;
  final int worst;
  final int gap; // pre-clamped best-vs-worst gap %
  final Color color;

  @override
  Widget build(BuildContext context) {
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
  const _HabitsExtras({required this.snapshot, required this.filter});

  final DashboardSnapshot snapshot;
  final StatsHabitFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allStats = ref.watch(habitStatsRpcProvider).value ?? const [];
    if (allStats.isEmpty) return const SizedBox.shrink();
    final habitsById = {for (final h in snapshot.habits) h.id: h};
    final now = DateTime.now();
    final stats = filter.isAll
        ? allStats
        : allStats
              .where(
                (s) =>
                    habitsById[s['goal_id']]?.isActiveOn(now) ?? false,
              )
              .toList();
    if (stats.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 18),
        _twoUp(
          _ConsistencyPanel(snapshot: snapshot, filter: filter),
          _MedalsPanel(snapshot: snapshot, stats: stats),
        ),
        const SizedBox(height: 18),
        _DistributionPanel(stats: stats),
        const SizedBox(height: 18),
        _SynergyMatrixPanel(snapshot: snapshot, filter: filter),
      ],
    );
  }
}

/// Steadiest and most-erratic habits by the regularity (consistency) score.
class _ConsistencyPanel extends ConsumerWidget {
  const _ConsistencyPanel({required this.snapshot, required this.filter});

  final DashboardSnapshot snapshot;
  final StatsHabitFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allScores = ref.watch(consistencyScoresProvider).value ?? const [];
    final habitsById = {for (final h in snapshot.habits) h.id: h};
    final now = DateTime.now();
    final scores = filter.isAll
        ? allScores
        : allScores
              .where((s) => habitsById[s.goalId]?.isActiveOn(now) ?? false)
              .toList();
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
                  color: EvolveColors.destructive,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final s in scores.reversed.take(2))
                row(s, EvolveColors.destructive),
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


/// N×N habit co-completion matrix — which pairs of habits move together.
class _SynergyMatrixPanel extends ConsumerWidget {
  const _SynergyMatrixPanel({required this.snapshot, required this.filter});

  final DashboardSnapshot snapshot;
  final StatsHabitFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(allHabitCorrelationsRpcProvider).value ?? const [];
    final now = DateTime.now();
    final habits = filter.isAll
        ? snapshot.habits
        : snapshot.habits.where((h) => h.isActiveOn(now)).toList();
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
                  gridData: const FlGridData(show: false),
                  lineTouchData: LineTouchData(
                    distanceCalculator: (touchPoint, spotPixelCoordinates) =>
                        (touchPoint.dx - spotPixelCoordinates.dx).abs(),
                    touchSpotThreshold: 99999,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => colors.panelSoft,
                      tooltipBorderRadius: BorderRadius.circular(8),
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final color = spot.barIndex == 0 ? EvolveColors.violet : EvolveColors.amber;
                          return LineTooltipItem(
                            spot.y.toStringAsFixed(1),
                            TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          );
                        }).toList();
                      },
                    ),
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes.map((index) {
                        return TouchedSpotIndicatorData(
                          FlLine(
                            color: barData.color?.withValues(alpha: 0.5) ?? colors.muted,
                            strokeWidth: 2,
                          ),
                          FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                              radius: 5,
                              color: barData.color ?? colors.foreground,
                              strokeWidth: 2,
                              strokeColor: colors.panel,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    handleBuiltInTouches: true,
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
                      shadow: Shadow(
                        color: EvolveColors.violet.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            EvolveColors.violet.withValues(alpha: 0.3),
                            EvolveColors.violet.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    LineChartBarData(
                      spots: energySpots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: EvolveColors.amber,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      shadow: Shadow(
                        color: EvolveColors.amber.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            EvolveColors.amber.withValues(alpha: 0.3),
                            EvolveColors.amber.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
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
              color: EvolveColors.destructive,
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

// ═══ PER-HABIT ENRICHMENTS ═══════════════════════════════════════════════════

/// Completion of one habit over an inclusive days-ago window, counting only its
/// scheduled (frequency-matched, non-skipped) days. Snapshot-backed ⇒ works in
/// both data modes.
double _habitWindowRate(
  DashboardSnapshot s,
  DashboardHabit h,
  int startAgo,
  int endAgo,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var done = 0;
  var active = 0;
  for (var ago = startAgo; ago <= endAgo; ago++) {
    final date = DateTime(today.year, today.month, today.day - ago);
    final freqOk =
        h.frequencyDays == null || h.frequencyDays!.contains(date.weekday);
    if (!h.isActiveOn(date) || !freqOk) continue;
    final st = s.habitStatusFor(h.id, date);
    if (st == 'skipped') continue;
    active++;
    if (st == 'done') done++;
  }
  return active > 0 ? done / active : 0;
}

/// Completion of one habit over an inclusive [from]…[to] date range (scheduled,
/// non-skipped days only).
double _habitRangeRate(
  DashboardSnapshot s,
  DashboardHabit h,
  DateTime from,
  DateTime to,
) {
  var done = 0;
  var active = 0;
  var d = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  while (!d.isAfter(end)) {
    final freqOk =
        h.frequencyDays == null || h.frequencyDays!.contains(d.weekday);
    if (h.isActiveOn(d) && freqOk) {
      final st = s.habitStatusFor(h.id, d);
      if (st != 'skipped') {
        active++;
        if (st == 'done') done++;
      }
    }
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return active > 0 ? done / active : 0;
}

/// Overview hero: Momentum ring + an 8-tile stat grid + a "vs your other
/// habits" percentile pill.
class _HabitHero extends ConsumerWidget {
  const _HabitHero({required this.habit});

  final DashboardHabit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(habitStatsRpcProvider).value ?? const [];
    final stat = stats.where((s) => s['goal_id'] == habit.id).firstOrNull ?? {};
    final bundle =
        ref.watch(habitAnalyticsBundleProvider(habit.id)).value ??
        HabitAnalyticsBundle.empty;

    final completion = (stat['rate'] as num?)?.round() ?? 0;
    final current = habit.streak; // reactive current streak (updates on toggle)
    final best = (stat['best_streak'] as num?)?.toInt() ?? 0;
    final totalCompletions = (stat['total_completions'] as num?)?.toInt() ?? 0;
    final missed = (stat['missed_days'] as num?)?.toInt() ?? 0;

    final tiles = _MetricGrid(
      tiles: [
        _Metric(
          label: t.stats.completion,
          value: '$completion%',
          detail: t.stats.actionsFraction(
            done: totalCompletions,
            total: (stat['total_active_days'] as num?)?.toInt() ?? 1,
          ),
          color: habit.color,
          icon: LucideIcons.target,
        ),
        _Metric(
          label: t.stats.currentStreak,
          value: t.dashboard.streakDaysShort(n: current),
          detail: t.stats.currentStreakDetail,
          color: EvolveColors.streakColor(current),
          icon: LucideIcons.flame,
        ),
        _Metric(
          label: t.stats.recordLabel,
          value: t.dashboard.streakDaysShort(n: best),
          detail: t.stats.recordDetail,
          color: EvolveColors.amber,
          icon: LucideIcons.trophy,
        ),
        _Metric(
          label: t.statistics.missed,
          value: '$missed',
          detail: t.stats.trend30Detail,
          color: EvolveColors.destructive,
          icon: LucideIcons.circleAlert,
        ),
        _Metric(
          label: t.stats.lifetimeTotalDone,
          value: '$totalCompletions',
          detail: t.stats.allTimeBest,
          color: EvolveColors.success,
          icon: LucideIcons.circleCheck,
        ),
        _Metric(
          label: t.stats.habitBounceBackShort,
          value: bundle.bounceBack.opportunities > 0
              ? '${bundle.bounceBack.globalRate.round()}%'
              : '—',
          detail: t.stats.bounceBackSubtitle,
          color: EvolveColors.cyan,
          icon: LucideIcons.undo2,
        ),
        _Metric(
          label: t.stats.consistencyTitle,
          value: bundle.consistency != null
              ? '${bundle.consistency!.score.round()}'
              : '—',
          detail: t.stats.habitConsistencyDetail,
          color: EvolveColors.violet,
          icon: LucideIcons.activity,
        ),
        _Metric(
          label: t.stats.lifetimeDaysTracked,
          value: '${bundle.milestones.daysSinceStart}',
          detail: t.stats.lifetimeDaysTrackedDetail,
          color: context.evolveAccent,
          icon: LucideIcons.calendarDays,
        ),
      ],
    );

    final hero = LayoutBuilder(
      builder: (context, constraints) {
        final ring = _MomentumRing(momentum: bundle.momentum);
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

    if (bundle.percentileRank == null) return hero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        hero,
        const SizedBox(height: 12),
        StatusPill(
          label: t.stats.habitPercentile(pct: bundle.percentileRank!),
          color: EvolveColors.success,
          icon: LucideIcons.trendingUp,
        ),
      ],
    );
  }
}

/// Calendar-tab extras: gap analysis, monthly seasonality, this-vs-last month.
class _HabitCalendarExtras extends ConsumerWidget {
  const _HabitCalendarExtras({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle =
        ref.watch(habitAnalyticsBundleProvider(habit.id)).value ??
        HabitAnalyticsBundle.empty;
    return Column(
      children: [
        const SizedBox(height: 18),
        _twoUp(
          _HabitGapPanel(gap: bundle.gap),
          _HabitMonthComparePanel(habit: habit, snapshot: snapshot),
        ),
        const SizedBox(height: 18),
        _HabitSeasonalityPanel(
          seasonality: bundle.seasonality,
          color: habit.color,
        ),
      ],
    );
  }
}

class _HabitGapPanel extends StatelessWidget {
  const _HabitGapPanel({required this.gap});

  final GapStats gap;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.gapTitle,
            subtitle: t.stats.gapSubtitle,
          ),
          const SizedBox(height: 18),
          if (!gap.hasData)
            _EmptyState(
              icon: LucideIcons.calendarClock,
              title: t.stats.moreLogsNeeded,
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MicroStat(
                  label: t.stats.gapAvg,
                  value: '${gap.avgGap.toStringAsFixed(1)}${t.stats.daysUnit}',
                  color: context.evolveColors.foreground,
                ),
                _MicroStat(
                  label: t.stats.gapLongest,
                  value: '${gap.longestGap}${t.stats.daysUnit}',
                  color: EvolveColors.amber,
                ),
                _MicroStat(
                  label: t.stats.gapSince,
                  value: '${gap.daysSinceLastDone}${t.stats.daysUnit}',
                  color: gap.daysSinceLastDone > gap.avgGap * 1.5
                      ? EvolveColors.destructive
                      : EvolveColors.success,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HabitSeasonalityPanel extends StatelessWidget {
  const _HabitSeasonalityPanel({
    required this.seasonality,
    required this.color,
  });

  final List<MonthPerf> seasonality;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final withData = seasonality.where((r) => r.total > 0).toList();
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
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final r in seasonality)
                    Expanded(
                      child: _SeasonBar(
                        month: r.month,
                        rate: r.rate,
                        hasData: r.total > 0,
                        isBest: maxRate > 0 && r.rate == maxRate && r.total > 0,
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

class _HabitMonthComparePanel extends StatelessWidget {
  const _HabitMonthComparePanel({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = thisMonthStart.subtract(const Duration(days: 1));
    final thisRate = _habitRangeRate(snapshot, habit, thisMonthStart, now);
    final lastRate = _habitRangeRate(
      snapshot,
      habit,
      lastMonthStart,
      lastMonthEnd,
    );
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.monthVsTitle,
            subtitle: t.stats.monthVsSubtitle,
          ),
          const SizedBox(height: 18),
          _LevelBar(
            label: t.stats.thisMonthLabel,
            percentage: (thisRate * 100).round(),
            color: habit.color,
          ),
          const SizedBox(height: 14),
          _LevelBar(
            label: t.stats.lastMonthLabel,
            percentage: (lastRate * 100).round(),
            color: EvolveColors.violet,
          ),
        ],
      ),
    );
  }
}

/// Performance-tab extras: weekday/weekend split, rolling rates, week-vs-average.
class _HabitPerformanceExtras extends ConsumerWidget {
  const _HabitPerformanceExtras({required this.habit, required this.snapshot});

  final DashboardHabit habit;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle =
        ref.watch(habitAnalyticsBundleProvider(habit.id)).value ??
        HabitAnalyticsBundle.empty;
    final split = bundle.weekdayWeekend;

    final r7 = _habitWindowRate(snapshot, habit, 0, 6);
    final r7p = _habitWindowRate(snapshot, habit, 7, 13);
    final r30 = _habitWindowRate(snapshot, habit, 0, 29);
    final r30p = _habitWindowRate(snapshot, habit, 30, 59);

    final rolling = EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.rollingTitle,
            subtitle: t.stats.rollingSubtitle,
          ),
          const SizedBox(height: 18),
          _RollingRow(label: t.stats.rolling7, rate: r7, delta: r7 - r7p),
          const SizedBox(height: 16),
          _RollingRow(label: t.stats.rolling30, rate: r30, delta: r30 - r30p),
        ],
      ),
    );

    final weekend = EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.weekdayWeekendTitle,
            subtitle: t.stats.weekdayWeekendSubtitle,
          ),
          const SizedBox(height: 18),
          if (!split.hasData)
            _EmptyState(
              icon: LucideIcons.calendar,
              title: t.stats.moreLogsNeeded,
            )
          else ...[
            _LevelBar(
              label: t.stats.weekdaysLabel,
              percentage: split.weekdayRate.round(),
              color: habit.color,
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

    return Column(
      children: [const SizedBox(height: 18), _twoUp(rolling, weekend)],
    );
  }
}

/// Improvement-tab extras: bounce-back, consistency, danger day, at-risk,
/// streak history and schedule adherence.
class _HabitImprovementExtras extends ConsumerWidget {
  const _HabitImprovementExtras({required this.habit});

  final DashboardHabit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle =
        ref.watch(habitAnalyticsBundleProvider(habit.id)).value ??
        HabitAnalyticsBundle.empty;

    final bounce = bundle.bounceBack;
    final consistency = bundle.consistency;
    final atRisk =
        bundle.gap.hasData &&
        bundle.gap.daysSinceLastDone > bundle.gap.avgGap * 1.5 &&
        bundle.gap.daysSinceLastDone > 2;

    final tiles = _MetricGrid(
      tiles: [
        _Metric(
          label: t.stats.habitBounceBackShort,
          value: bounce.opportunities > 0
              ? '${bounce.globalRate.round()}%'
              : '—',
          detail: t.stats.bounceBackDetail(
            recoveries: bounce.recoveries,
            opportunities: bounce.opportunities,
          ),
          color: EvolveColors.cyan,
          icon: LucideIcons.undo2,
        ),
        _Metric(
          label: t.stats.consistencyTitle,
          value: consistency != null ? '${consistency.score.round()}' : '—',
          detail: t.stats.habitConsistencyDetail,
          color: EvolveColors.violet,
          icon: LucideIcons.activity,
        ),
        _Metric(
          label: t.stats.atRiskTitle,
          value: atRisk ? t.stats.atRiskYes : t.stats.atRiskNo,
          detail: t.stats.atRiskDetail(days: bundle.gap.daysSinceLastDone),
          color: atRisk ? EvolveColors.destructive : EvolveColors.success,
          icon: atRisk ? LucideIcons.triangleAlert : LucideIcons.shieldCheck,
        ),
        _Metric(
          label: t.stats.dangerZoneTitle,
          value: bundle.dangerDay != null
              ? _weekdayShort(bundle.dangerDay!.weekday)
              : '—',
          detail: t.stats.dangerZoneSubtitle,
          color: EvolveColors.amber,
          icon: LucideIcons.calendarX,
        ),
      ],
    );

    return Column(
      children: [
        const SizedBox(height: 18),
        tiles,
        const SizedBox(height: 18),
        _twoUp(
          _HabitStreakHistoryPanel(
            runs: bundle.streakHistory,
            color: habit.color,
          ),
          _HabitAdherencePanel(adherence: bundle.adherence),
        ),
      ],
    );
  }
}

class _HabitStreakHistoryPanel extends StatelessWidget {
  const _HabitStreakHistoryPanel({required this.runs, required this.color});

  final List<StreakRun> runs;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final longest = runs.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    // Show the most recent runs (chronological), capped so the strip fits.
    final shown = runs.length > 24 ? runs.sublist(runs.length - 24) : runs;
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.streakHistoryTitle,
            subtitle: t.stats.streakHistorySubtitle,
          ),
          const SizedBox(height: 18),
          if (runs.isEmpty)
            _EmptyState(icon: LucideIcons.flame, title: t.stats.moreLogsNeeded)
          else ...[
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final r in shown)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: FractionallySizedBox(
                          heightFactor: longest > 0
                              ? (r.length / longest).clamp(0.08, 1.0)
                              : 0.08,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: r.length == longest
                                  ? EvolveColors.success
                                  : color.withValues(alpha: 0.7),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.stats.streakHistoryDetail(count: runs.length, longest: longest),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _HabitAdherencePanel extends StatelessWidget {
  const _HabitAdherencePanel({required this.adherence});

  final Adherence adherence;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.stats.adherenceTitle,
            subtitle: t.stats.adherenceSubtitle,
          ),
          const SizedBox(height: 18),
          if (!adherence.hasData)
            _EmptyState(
              icon: LucideIcons.calendarCheck,
              title: t.stats.moreLogsNeeded,
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${adherence.rate.round()}%',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    height: 1,
                    color: context.evolveAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      t.stats.adherenceDetail(
                        done: adherence.doneOnScheduled,
                        scheduled: adherence.scheduledDays,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (adherence.rate / 100).clamp(0.0, 1.0),
                minHeight: 8,
                color: context.evolveAccent,
                backgroundColor: context.evolveColors.panelSoft,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mood-tab extra: next-day mood/energy impact of doing this habit.
class _HabitMoodExtras extends ConsumerWidget {
  const _HabitMoodExtras({required this.habit});

  final DashboardHabit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle =
        ref.watch(habitAnalyticsBundleProvider(habit.id)).value ??
        HabitAnalyticsBundle.empty;
    final n = bundle.nextDayMood;
    if (!n.hasData) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: EvolvePanel(
        glowColor: EvolveColors.violet,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeading(
              title: t.stats.nextDayMoodTitle,
              subtitle: t.stats.nextDayMoodSubtitle,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _NextDayStat(
                    label: t.stats.nextDayAfterDone,
                    mood: n.moodAfterDone,
                    energy: n.energyAfterDone,
                    highlight: true,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _NextDayStat(
                    label: t.stats.nextDayAfterMissed,
                    mood: n.moodAfterMissed,
                    energy: n.energyAfterMissed,
                    highlight: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            StatusPill(
              label: t.stats.nextDayMoodLift(
                value: n.moodLift.toStringAsFixed(1),
              ),
              color: n.moodLift >= 0
                  ? EvolveColors.success
                  : EvolveColors.destructive,
              icon: n.moodLift >= 0
                  ? LucideIcons.trendingUp
                  : LucideIcons.trendingDown,
            ),
          ],
        ),
      ),
    );
  }
}

class _NextDayStat extends StatelessWidget {
  const _NextDayStat({
    required this.label,
    required this.mood,
    required this.energy,
    required this.highlight,
  });

  final String label;
  final double mood;
  final double energy;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return _RaisedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: context.evolveColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                LucideIcons.smile,
                size: 15,
                color: highlight
                    ? EvolveColors.violet
                    : context.evolveColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                mood.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.evolveColors.foreground,
                ),
              ),
              const SizedBox(width: 14),
              Icon(
                LucideIcons.zap,
                size: 15,
                color: highlight
                    ? EvolveColors.amber
                    : context.evolveColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                energy.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.evolveColors.foreground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
