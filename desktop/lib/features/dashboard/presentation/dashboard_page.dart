import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'dart:async';

import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/coach_tutorial.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/verified_habit_badge.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/features/dashboard/presentation/create_goal_dialog.dart';
import 'package:evolve_desktop/features/habits/presentation/habits_page.dart';
import 'package:evolve_desktop/features/dashboard/presentation/sync_off_banner.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isRunningStartupOnboardingFlow = false;
  bool _isNameDialogOpen = false;
  bool _isWelcomeDialogOpen = false;

  // Overview segment of the continuous product tour. The central
  // [tourControllerProvider] owns whether this segment is active; the page only
  // owns the target keys and the step index within the segment.
  int _tourIndex = 0;
  final _checkInKey = GlobalKey();
  final _habitsKey = GlobalKey();
  final _focusGoalsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupOnboardingFlow();
    });
  }

  Future<void> _runStartupOnboardingFlow() async {
    if (_isRunningStartupOnboardingFlow || !mounted) return;
    // Run the first-launch flow (name capture + tour welcome) at most ONCE per
    // app session. The dashboard remounts every time the user returns to
    // Overview — and again while the biometric gate resolves at startup — so
    // without this guard the name prompt / welcome dialog re-fire on every
    // mount (the reported "pop-up every time / twice" bug). Claimed up-front so
    // a concurrent remount can't stack a second prompt; released below if we
    // couldn't complete (name still needed).
    if (ref.read(startupOnboardingHandledProvider)) return;
    _isRunningStartupOnboardingFlow = true;
    ref.read(startupOnboardingHandledProvider.notifier).set(true);
    try {
      final isProfileReady = await _ensureProfileNameReady();
      if (!mounted) return;
      if (!isProfileReady) {
        // Didn't finish (name still required) — release so a later mount can
        // retry rather than silently skipping the prompt for the whole session.
        ref.read(startupOnboardingHandledProvider.notifier).set(false);
        return;
      }
      _checkTutorial();
    } finally {
      _isRunningStartupOnboardingFlow = false;
    }
  }

  Future<bool> _ensureProfileNameReady() async {
    final authState = ref.read(desktopAuthControllerProvider);
    if (authState.user != null) return true; // Logged in user

    // Reachable only with no Supabase user AND not Private mode — a state the
    // real app never shows the dashboard in (the router gates it behind auth /
    // private mode). Don't run the name/tutorial onboarding here.
    if (!ref.read(activeDesktopDataModeProvider).isPrivate) return false;

    // Private mode: the name lives in the encrypted profiles row.
    final profile = await ref.read(privateProfileProvider.future);
    final hasName = profile.fullName?.trim().isNotEmpty ?? false;
    if (hasName) return true;

    return _showNameDialog();
  }

  Future<bool> _showNameDialog() async {
    if (_isNameDialogOpen || !mounted) return false;
    _isNameDialogOpen = true;

    bool result = false;
    try {
      result =
          await showEvolveDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => const _NamePromptDialog(),
          ) ??
          false;
    } finally {
      _isNameDialogOpen = false;
    }
    return result;
  }

  void _checkTutorial() {
    if (!mounted || _isWelcomeDialogOpen || _isNameDialogOpen) return;

    final tour = ref.read(tourControllerProvider);
    if (!tour.shouldOnboard) return;
    if (tour.segmentIndex == 0) {
      // Fresh start: welcome dialog gates the tour.
      _showWelcomeScreen();
    } else {
      // Resume an interrupted run at the incomplete segment — no welcome.
      // activate() jumps navigation straight to that segment's page.
      ref.read(tourControllerProvider.notifier).activate();
    }
  }

  Future<void> _showWelcomeScreen() async {
    if (_isWelcomeDialogOpen || !mounted) return;
    _isWelcomeDialogOpen = true;

    try {
      await showEvolveDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => EvolveAlertDialog(
          icon: LucideIcons.sparkles,
          title: Text(t.tour.welcomeTitle),
          subtitle: t.dashboard.welcomeSubtitle,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.tour.welcomeBody),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Start the continuous tour: locks navigation and shows the
                    // Overview segment.
                    ref.read(tourControllerProvider.notifier).activate();
                  },
                  child: Text(t.tour.welcomeStart),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(tourControllerProvider.notifier).complete();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.evolveColors.subtle,
                  ),
                  child: Text(t.tour.welcomeSkip),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      _isWelcomeDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(dashboardControllerProvider);

    final page = DesktopPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Data-loss warning for Private-mode users on macOS who haven't turned
          // on iCloud sync. Collapses to zero height when not applicable.
          const SyncOffBanner(),
          KeyedSubtree(
            key: _checkInKey,
            child: _ProtocolloSection(checkIn: snapshot.checkIn),
          ),
          const SizedBox(height: 22),
          _MetricGrid(snapshot: snapshot),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumns = constraints.maxWidth >= 1120;
              final primary = Column(
                children: [
                  _TrendPanel(
                    points: snapshot.trend,
                    weeklyMomentum: snapshot.weeklyMomentum,
                  ),
                  const SizedBox(height: 18),
                  KeyedSubtree(
                    key: _habitsKey,
                    child: _HabitPanel(snapshot: snapshot),
                  ),
                ],
              );
              final secondary = Column(
                children: [
                  KeyedSubtree(
                    key: _focusGoalsKey,
                    child: _FocusGoalsPanel(goals: snapshot.goals),
                  ),
                  const SizedBox(height: 18),
                  _WeeklyReviewPanel(snapshot: snapshot),
                ],
              );

              if (!useColumns) {
                return Column(
                  children: [primary, const SizedBox(height: 18), secondary],
                );
              }

              // Rail scales with the window instead of staying a fixed 350,
              // so ultra-wide screens don't leave it looking skinny.
              final railWidth = (constraints.maxWidth * 0.26).clamp(
                350.0,
                440.0,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: primary),
                  const SizedBox(width: 18),
                  SizedBox(width: railWidth, child: secondary),
                ],
              );
            },
          ),
        ],
      ),
    );

    final showTour = ref
        .watch(tourControllerProvider)
        .isSegmentActive(TourSegment.overview);

    return Stack(
      children: [
        page,
        if (showTour)
          CoachTutorialOverlay(
            steps: _overviewTourSteps(),
            index: _tourIndex,
            onIndexChanged: (i) => setState(() => _tourIndex = i),
            // Last Overview step advances the tour to the Habits segment.
            onFinish: () => ref.read(tourControllerProvider.notifier).advance(),
            backLabel: t.tour.back,
            nextLabel: t.tour.next,
            finishLabel: t.tour.continueLabel,
          ),
      ],
    );
  }

  List<CoachStep> _overviewTourSteps() => [
    // Orientation-first: a centered card (no spotlight) announcing the page.
    CoachStep(
      title: t.tour.overviewOrientationTitle,
      description: t.tour.overviewOrientationDesc,
    ),
    CoachStep(
      targetKey: _checkInKey,
      title: t.tour.overviewCheckinTitle,
      description: t.tour.overviewCheckinDesc,
    ),
    CoachStep(
      targetKey: _habitsKey,
      title: t.tour.overviewHabitsTitle,
      description: t.tour.overviewHabitsDesc,
    ),
    CoachStep(
      targetKey: _focusGoalsKey,
      title: t.tour.overviewGoalsTitle,
      description: t.tour.overviewGoalsDesc,
    ),
  ];
}

/// The mobile home's "PROTOCOLLO" strip: uppercase label with fading rule and
/// three quick-action tiles (Daily check-in, AI Chat, Manager).
class _ProtocolloSection extends ConsumerWidget {
  const _ProtocolloSection({required this.checkIn});

  final DailyCheckIn checkIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Brand label, deliberately not localized (same on mobile).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Branded home strip — kept uppercase to match the iOS 'PROTOCOLLO'
        // header (EvolveSectionLabel no longer force-uppercases).
        const EvolveSectionLabel('PROTOCOLLO'),
        const SizedBox(height: 14),
        // Guardrail: quick-action tiles cap at ~420px each so an ultra-wide
        // window grows the charts, not the buttons.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1284),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: _ActionTile(
                  icon: LucideIcons.heartPulse,
                  label: t.dashboard.dailyCheckIn,
                  subtitle: t.dashboard.mood,
                  color: EvolveColors.destructive,
                  showPulse: !checkIn.isComplete,
                  showCheckBadge: checkIn.isComplete,
                  onTap: () => showEvolveDialog<void>(
                    context: context,
                    builder: (context) => _DailyCheckInDialog(checkIn: checkIn),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _ActionTile(
                  icon: LucideIcons.sparkles,
                  label: t.dashboard.aiChat,
                  subtitle: t.ai.macroGoals,
                  color: EvolveColors.violet,
                  onTap: () => ref
                      .read(navigationControllerProvider.notifier)
                      .select(DesktopSection.coach),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _ActionTile(
                  icon: LucideIcons.listTodo,
                  label: t.dashboard.manager,
                  subtitle: t.ai.dailyHabits,
                  color: context.evolveAccent,
                  onTap: () => ref
                      .read(navigationControllerProvider.notifier)
                      .select(DesktopSection.habits),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.showPulse = false,
    this.showCheckBadge = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool showPulse;
  final bool showCheckBadge;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.showPulse) _startPulse();
  }

  @override
  void didUpdateWidget(covariant _ActionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showPulse && !oldWidget.showPulse) {
      _startPulse();
    } else if (!widget.showPulse && oldWidget.showPulse) {
      _stopPulse();
    }
  }

  void _startPulse() {
    _pulseController?.dispose();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController!,
      curve: Curves.easeInOut,
    );
    _pulseController!.repeat(reverse: true);
  }

  void _stopPulse() {
    _pulseController?.stop();
    _pulseController?.dispose();
    _pulseController = null;
    _pulseAnimation = null;
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget tile = _buildTileContent(context);

    if (widget.showPulse && _pulseAnimation != null) {
      tile = AnimatedBuilder(
        animation: _pulseAnimation!,
        builder: (context, child) {
          final value = _pulseAnimation!.value;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: value * 0.40),
                  blurRadius: value * 16,
                  spreadRadius: value * 3,
                ),
              ],
            ),
            child: child,
          );
        },
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildTileContent(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: context.evolveColors.panel.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.evolveColors.border.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              PositionedDirectional(
                top: -20,
                end: -20,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.color.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    EvolveIconChip(icon: widget.icon, color: widget.color),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.evolveColors.foreground,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: context.evolveColors.muted.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.showCheckBadge)
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: EvolveColors.successBright,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: EvolveColors.successBright.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.check,
                      size: 10,
                      color: Colors.white,
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

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080 ? 4 : 2;
        const spacing = 14.0;
        // Guardrail: metric cards stop growing at ~470px; extra width goes to
        // the charts below, not to inflated stat tiles.
        final cardWidth =
            ((constraints.maxWidth - spacing * (columns - 1)) / columns).clamp(
              0.0,
              470.0,
            );

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _MetricCard(
              width: cardWidth,
              label: t.dashboard.completionToday,
              value: '${(snapshot.completionRate * 100).round()}%',
              detail: t.dashboard.habitsCount(
                done: snapshot.completedHabits,
                total: snapshot.totalHabits,
              ),
              color: context.evolveAccent,
              icon: LucideIcons.zap,
            ),
            _MetricCard(
              width: cardWidth,
              label: t.dashboard.bestStreak,
              value: '${snapshot.bestStreak}',
              detail: t.dashboard.consecutiveDays,
              color: EvolveColors.streakColor(snapshot.bestStreak),
              icon: LucideIcons.flame,
            ),
            _MetricCard(
              width: cardWidth,
              label: t.dashboard.activeGoals,
              value: '${snapshot.activeGoals}',
              detail: t.dashboard.avgProgress(
                pct: (snapshot.averageGoalProgress * 100).round(),
              ),
              color: EvolveColors.cyan,
              icon: LucideIcons.target,
            ),
            _MetricCard(
              width: cardWidth,
              label: t.dashboard.momentum,
              value: _signedPercentage(snapshot.weeklyMomentum),
              detail: t.dashboard.vsLastWeek,
              color: EvolveColors.violet,
              icon: LucideIcons.trendingUp,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final String detail;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: EvolvePanel(
        radius: 20,
        glowColor: color,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      color: context.evolveColors.foreground,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            EvolveIconChip(icon: icon, color: color, size: 42, iconSize: 19),
          ],
        ),
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.points, required this.weeklyMomentum});

  final List<TrendPoint> points;
  final double weeklyMomentum;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.dashboard.weeklyTrend,
            subtitle: t.dashboard.weeklyTrendSubtitle,
            trailing: StatusPill(
              label: t.dashboard.thisWeekPill(
                value: _signedPercentage(weeklyMomentum),
              ),
              color: weeklyMomentum >= 0
                  ? EvolveColors.success
                  : EvolveColors.destructive,
              icon: weeklyMomentum >= 0
                  ? LucideIcons.trendingUp
                  : LucideIcons.trendingDown,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: points.length < 2 ? 1.0 : (points.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: context.evolveColors.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: 25,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: context.evolveColors.muted,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: ((points.length + 6) ~/ 7).clamp(1, 1000).toDouble(),
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) return const SizedBox.shrink();
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            points[index].label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: context.evolveColors.muted,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  distanceCalculator: (touchPoint, spotPixelCoordinates) =>
                      (touchPoint.dx - spotPixelCoordinates.dx).abs(),
                  touchSpotThreshold: 99999,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => context.evolveColors.panelSoft,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        final index = s.x.toInt();
                        final label = (index >= 0 && index < points.length) ? points[index].label : '';
                        return LineTooltipItem(
                          '$label\n',
                          TextStyle(
                            color: context.evolveColors.muted,
                            fontSize: 10,
                          ),
                          children: [
                            TextSpan(
                              text: '${s.y.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: context.evolveColors.foreground,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: barData.color?.withValues(alpha: 0.5) ?? context.evolveColors.muted,
                          strokeWidth: 2,
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 5,
                            color: barData.color ?? context.evolveColors.foreground,
                            strokeWidth: 2,
                            strokeColor: context.evolveColors.panel,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  handleBuiltInTouches: true,
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(i.toDouble(), points[i].value.clamp(0.0, 1.0) * 100),
                    ],
                    isCurved: true,
                    color: context.evolveAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          context.evolveAccent.withValues(alpha: 0.3),
                          context.evolveAccent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    shadow: Shadow(
                      color: context.evolveAccent.withValues(alpha: 0.4),
                      blurRadius: 8,
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

class _HabitPanel extends ConsumerWidget {
  const _HabitPanel({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EvolvePanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        children: [
          SectionHeading(
            title: t.dashboard.todayProtocol,
            subtitle: t.dashboard.todayProtocolSubtitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusPill(
                  label: t.dashboard.actionsCount(count: snapshot.totalHabits),
                ),
                const SizedBox(width: 8),
                EvolveSquareIconButton(
                  icon: LucideIcons.plus,
                  tooltip: t.createHabit.title,
                  // Consolidated habit editor (title + color + weekday + reminder),
                  // shared with the Habits page and ⌘K palette. Stays on the
                  // dashboard when the new habit is scheduled today; otherwise
                  // showCreateHabitDialog jumps to Habits so it isn't hidden.
                  onTap: () =>
                      showCreateHabitDialog(context, ref, navigateToHabits: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (snapshot.todayHabits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  t.dashboard.emptyHabits,
                  style: TextStyle(
                    color: context.evolveColors.foreground.withValues(
                      alpha: 0.5,
                    ),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            for (final habit in snapshot.todayHabits)
              _HabitRow(
                habit: habit,
                status: snapshot.habitStatusFor(habit.id, DateTime.now()),
                onTap: () => ref
                    .read(dashboardControllerProvider.notifier)
                    .toggleHabit(habit.id),
              ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.habit, required this.onTap, this.status});

  final DashboardHabit habit;

  /// Today's log status: 'done', 'missed', or null (untracked). Drives the
  /// tri-state indicator (tapping cycles untracked → done → missed → untracked).
  final String? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDone = status == 'done';
    final isMissed = status == 'missed';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone ? habit.color : Colors.transparent,
                border: Border.all(
                  color: isDone
                      ? habit.color
                      : isMissed
                      ? EvolveColors.destructive
                      : context.evolveColors.borderStrong,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: isDone
                  ? const Icon(
                      LucideIcons.check,
                      color: Color(0xFF092113),
                      size: 14,
                    )
                  : isMissed
                  ? const Icon(
                      LucideIcons.x,
                      color: EvolveColors.destructive,
                      size: 13,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          habit.title,
                          style: TextStyle(
                            color: isDone
                                ? context.evolveColors.muted
                                : context.evolveColors.foreground,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      // Read-only marker for iPhone-verified habits (mobile
                      // parity), so they don't look identical to manual ones.
                      if (habit.verificationRule != null) ...[
                        const SizedBox(width: 6),
                        const VerifiedHabitBadge(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            for (final completed in habit.weeklyProgress)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsetsDirectional.only(start: 5),
                decoration: BoxDecoration(
                  color: completed
                      ? habit.color
                      : context.evolveColors.panelSoft,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 16),
            SizedBox(
              width: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    LucideIcons.flame,
                    size: 11,
                    color: EvolveColors.streakColor(habit.streak),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    t.dashboard.streakDaysShort(n: habit.streak),
                    style: TextStyle(
                      color: EvolveColors.streakColor(habit.streak),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyCheckInDialog extends ConsumerStatefulWidget {
  const _DailyCheckInDialog({required this.checkIn});

  final DailyCheckIn checkIn;

  @override
  ConsumerState<_DailyCheckInDialog> createState() =>
      _DailyCheckInDialogState();
}

class _DailyCheckInDialogState extends ConsumerState<_DailyCheckInDialog> {
  late double _mood;
  late double _energy;

  @override
  void initState() {
    super.initState();
    // Seed the sliders from today's already-saved check-in so "Update
    // check-in" reflects the user's current mood/energy instead of resetting.
    _mood = (widget.checkIn.mood ?? 7).toDouble();
    _energy = (widget.checkIn.energy ?? 6).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      maxWidth: 420,
      icon: LucideIcons.heartPulse,
      title: Text(t.dashboard.dailyCheckIn),
      subtitle: t.dashboard.dailyCheckInSubtitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CheckInSlider(
            label: t.dashboard.mood,
            value: _mood,
            color: EvolveColors.violet,
            onChanged: (value) => setState(() => _mood = value),
          ),
          const SizedBox(height: 14),
          _CheckInSlider(
            label: t.dashboard.energy,
            value: _energy,
            color: EvolveColors.amber,
            onChanged: (value) => setState(() => _energy = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.common.actions.cancel),
        ),
        FilledButton(
          onPressed: () async {
            await ref
                .read(dashboardControllerProvider.notifier)
                .updateCheckIn(mood: _mood.round(), energy: _energy.round());
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(t.dashboard.record),
        ),
      ],
    );
  }
}

/// Emoji feedback for a 0–10 mood/energy value (mirrors the mobile check-in).
String _checkInEmoji(int value) {
  if (value <= 2) return '😞';
  if (value <= 4) return '😕';
  if (value <= 6) return '😐';
  if (value <= 8) return '🙂';
  return '😄';
}

class _CheckInSlider extends StatelessWidget {
  const _CheckInSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

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
              _checkInEmoji(value.round()),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 8),
            Text(
              '${value.round()}/10',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Slider(
          value: value,
          max: 10,
          divisions: 10,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FocusGoalsPanel extends ConsumerWidget {
  const _FocusGoalsPanel({required this.goals});

  final List<DashboardGoal> goals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EvolvePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: t.dashboard.focusGoals,
            subtitle: t.dashboard.currentPriorities,
            trailing: Builder(
              builder: (context) => EvolveSquareIconButton(
                icon: LucideIcons.plus,
                tooltip: t.createGoal.title,
                onTap: () {
                  final isPro = ref.read(desktopIsProProvider);
                  if (!isPro && goals.length >= 100) {
                    unawaited(showProFeaturesDialog(context, ref));
                    return;
                  }
                  showEvolveDialog<void>(
                    context: context,
                    builder: (context) => const CreateGoalDialog(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  t.dashboard.emptyFocusGoals,
                  style: TextStyle(
                    color: context.evolveColors.foreground.withValues(
                      alpha: 0.5,
                    ),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            for (final goal in goals.take(3)) ...[
              _GoalProgressRow(goal: goal),
              if (goal != goals.take(3).last) const SizedBox(height: 15),
            ],
        ],
      ),
    );
  }
}

class _GoalProgressRow extends StatelessWidget {
  const _GoalProgressRow({required this.goal});

  final DashboardGoal goal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(goal.progress * 100).round()}%',
              style: TextStyle(
                color: goal.color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: goal.progress,
            minHeight: 5,
            color: goal.color,
            backgroundColor: context.evolveColors.panelSoft,
          ),
        ),
        const SizedBox(height: 5),
        Text(goal.dueLabel, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _WeeklyReviewPanel extends StatelessWidget {
  const _WeeklyReviewPanel({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final momentum = snapshot.weeklyMomentum;
    final completion = snapshot.currentWeekCompletionRate;
    return EvolvePanel(
      child: Row(
        children: [
          _ProgressRing(value: completion),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completion == 0
                      ? t.dashboard.weekToStart
                      : momentum >= 0
                      ? t.dashboard.weekGrowing
                      : t.dashboard.weekToRecover,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  t.dashboard.vsPreviousWeek(
                    value: _signedPercentage(momentum),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: CustomPaint(
        painter: _RingPainter(
          value,
          accent: context.evolveAccent,
          track: context.evolveColors.panelSoft,
        ),
        child: Center(
          child: Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: context.evolveAccent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value, {required this.accent, required this.track});

  final double value;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawArc(
      bounds,
      -math.pi / 2,
      value * math.pi * 2,
      false,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.accent != accent ||
      oldDelegate.track != track;
}

String _signedPercentage(double value) {
  final percentage = (value * 100).round();
  return '${percentage > 0 ? '+' : ''}$percentage%';
}

class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog();

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(WidgetRef ref) async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await ref
        .read(privateProfileProvider.notifier)
        .updateProfile(fullName: name);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return EvolveAlertDialog(
          icon: LucideIcons.user,
          title: Text(t.namePrompt.title),
          subtitle: t.namePrompt.subtitle,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: t.namePrompt.hint,
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _submit(ref),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _submit(ref),
                  child: Text(t.namePrompt.save),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
