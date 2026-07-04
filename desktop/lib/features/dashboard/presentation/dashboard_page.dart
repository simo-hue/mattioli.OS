import 'dart:math' as math;

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/features/dashboard/presentation/create_goal_dialog.dart';
import 'package:evolve_desktop/features/dashboard/presentation/create_habit_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isRunningStartupOnboardingFlow = false;
  bool _isNameDialogOpen = false;
  bool _isWelcomeDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupOnboardingFlow();
    });
  }

  Future<void> _runStartupOnboardingFlow() async {
    if (_isRunningStartupOnboardingFlow || !mounted) return;
    _isRunningStartupOnboardingFlow = true;
    try {
      final isProfileReady = await _ensureProfileNameReady();
      if (!isProfileReady || !mounted) return;
      _checkTutorial();
    } finally {
      _isRunningStartupOnboardingFlow = false;
    }
  }

  Future<bool> _ensureProfileNameReady() async {
    final authState = ref.read(desktopAuthControllerProvider);
    if (authState.user != null) return true; // Logged in user

    // Privacy mode
    final prefs = ref.read(sharedPreferencesProvider);
    final hasName = prefs?.getString('private_profile_name') != null;
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

    final hasSeenTutorial = ref.read(tutorialProvider);
    if (!hasSeenTutorial) {
      _showWelcomeScreen();
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
          icon: Icons.auto_awesome,
          title: const Text('Benvenuto in Evolve'),
          subtitle: 'Inizia il tuo percorso di crescita personale.',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Questa applicazione ti aiuta a costruire buone abitudini e raggiungere i tuoi obiettivi a lungo termine.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref.read(tutorialProvider.notifier).setTutorialSeen(true);
                    Navigator.pop(context);
                  },
                  child: const Text('Inizia'),
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
    final user = ref.watch(desktopAuthControllerProvider).user;

    return DesktopPage(
      title: _greeting(user?.userMetadata, user?.email),
      subtitle:
          'Mantieni il ritmo. Ogni piccola azione consolida la persona che stai costruendo.',
      trailing: _TodayLabel(date: DateTime.now()),
      child: Column(
        children: [
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
                  _HabitPanel(snapshot: snapshot),
                ],
              );
              final secondary = Column(
                children: [
                  _CheckInPanel(checkIn: snapshot.checkIn),
                  const SizedBox(height: 18),
                  _FocusGoalsPanel(goals: snapshot.goals),
                  const SizedBox(height: 18),
                  _WeeklyReviewPanel(snapshot: snapshot),
                ],
              );

              if (!useColumns) {
                return Column(
                  children: [primary, const SizedBox(height: 18), secondary],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: primary),
                  const SizedBox(width: 18),
                  SizedBox(width: 350, child: secondary),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TodayLabel extends StatelessWidget {
  const _TodayLabel({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    const months = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ];
    const weekdays = [
      'Lunedi',
      'Martedi',
      'Mercoledi',
      'Giovedi',
      'Venerdi',
      'Sabato',
      'Domenica',
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Text(
        '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}',
        style: Theme.of(context).textTheme.bodyMedium,
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
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _MetricCard(
              width: cardWidth,
              label: 'Completamento oggi',
              value: '${(snapshot.completionRate * 100).round()}%',
              detail:
                  '${snapshot.completedHabits}/${snapshot.totalHabits} abitudini',
              color: context.evolveAccent,
              icon: Icons.bolt_rounded,
            ),
            _MetricCard(
              width: cardWidth,
              label: 'Migliore serie',
              value: '${snapshot.bestStreak}',
              detail: 'giorni consecutivi',
              color: EvolveColors.amber,
              icon: Icons.local_fire_department_outlined,
            ),
            _MetricCard(
              width: cardWidth,
              label: 'Obiettivi attivi',
              value: '${snapshot.activeGoals}',
              detail:
                  '${(snapshot.averageGoalProgress * 100).round()}% progresso medio',
              color: EvolveColors.cyan,
              icon: Icons.flag_outlined,
            ),
            _MetricCard(
              width: cardWidth,
              label: 'Momentum',
              value: _signedPercentage(snapshot.weeklyMomentum),
              detail: 'rispetto alla scorsa settimana',
              color: EvolveColors.violet,
              icon: Icons.trending_up_rounded,
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
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
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
            title: 'Andamento settimanale',
            subtitle: 'Percentuale di completamento delle tue abitudini',
            trailing: StatusPill(
              label: '${_signedPercentage(weeklyMomentum)} questa settimana',
              color: context.evolveAccent,
              icon: Icons.north_east_rounded,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 220,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendChartPainter(
                points,
                accent: context.evolveAccent,
                palette: context.evolveColors,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter(
    this.points, {
    required this.accent,
    required this.palette,
  });

  final List<TrendPoint> points;
  final Color accent;
  final EvolvePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const right = 10.0;
    const top = 10.0;
    const bottom = 28.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final gridPaint = Paint()
      ..color = palette.border
      ..strokeWidth = 1;
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i <= 4; i++) {
      final y = chart.bottom - (chart.height * i / 4);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      labelPainter
        ..text = TextSpan(
          text: '${i * 25}%',
          style: TextStyle(color: palette.subtle, fontSize: 10),
        )
        ..layout()
        ..paint(canvas, Offset(0, y - 6));
    }

    if (points.length < 2) return;
    final step = chart.width / (points.length - 1);
    final offsets = <Offset>[
      for (var i = 0; i < points.length; i++)
        Offset(
          chart.left + step * i,
          chart.bottom - chart.height * points[i].value,
        ),
    ];
    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      final previous = offsets[i - 1];
      final current = offsets[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = Path.from(linePath)
      ..lineTo(offsets.last.dx, chart.bottom)
      ..lineTo(offsets.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withValues(alpha: 0.27), accent.withValues(alpha: 0)],
        ).createShader(chart),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = accent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < offsets.length; i++) {
      canvas.drawCircle(offsets[i], 4.5, Paint()..color = palette.panel);
      canvas.drawCircle(offsets[i], 3, Paint()..color = accent);
      labelPainter
        ..text = TextSpan(
          text: points[i].label,
          style: TextStyle(color: palette.muted, fontSize: 11),
        )
        ..layout()
        ..paint(
          canvas,
          Offset(offsets[i].dx - labelPainter.width / 2, chart.bottom + 10),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.accent != accent ||
      oldDelegate.palette != palette;
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
            title: 'Protocollo di oggi',
            subtitle: 'Completa le azioni essenziali prima di aggiungere altro',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusPill(label: '${snapshot.totalHabits} azioni'),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => showEvolveDialog<void>(
                    context: context,
                    builder: (context) => const CreateHabitDialog(),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  tooltip: 'Nuova Abitudine',
                  style: IconButton.styleFrom(
                    backgroundColor: context.evolveColors.border.withValues(
                      alpha: 0.3,
                    ),
                  ),
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
                  'Il tuo canvas è vuoto. Crea la tua prima abitudine.',
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
  const _HabitRow({required this.habit, required this.onTap});

  final DashboardHabit habit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDone = habit.state == HabitState.completed;

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
                      : context.evolveColors.borderStrong,
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: isDone
                  ? const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF092113),
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      color: isDone
                          ? context.evolveColors.muted
                          : context.evolveColors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
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
            for (final completed in habit.weeklyProgress)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 5),
                decoration: BoxDecoration(
                  color: completed
                      ? habit.color
                      : context.evolveColors.panelSoft,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 16),
            SizedBox(
              width: 54,
              child: Text(
                '${habit.streak} gg',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: EvolveColors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInPanel extends StatelessWidget {
  const _CheckInPanel({required this.checkIn});

  final DailyCheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      color: context.evolveColors.panelRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.spa_outlined, size: 23, color: context.evolveAccent),
          const SizedBox(height: 14),
          Text(
            checkIn.isComplete ? 'Check-in registrato' : 'Come ti senti oggi?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            checkIn.isComplete
                ? 'Umore ${checkIn.mood}/10 · Energia ${checkIn.energy}/10'
                : 'Registra umore ed energia per migliorare le analisi dei tuoi pattern.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => showEvolveDialog<void>(
                context: context,
                builder: (context) => const _DailyCheckInDialog(),
              ),
              child: Text(
                checkIn.isComplete ? 'Aggiorna check-in' : 'Fai il check-in',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCheckInDialog extends ConsumerStatefulWidget {
  const _DailyCheckInDialog();

  @override
  ConsumerState<_DailyCheckInDialog> createState() =>
      _DailyCheckInDialogState();
}

class _DailyCheckInDialogState extends ConsumerState<_DailyCheckInDialog> {
  double _mood = 7;
  double _energy = 6;

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      maxWidth: 420,
      icon: Icons.spa_outlined,
      title: const Text('Check-in quotidiano'),
      subtitle:
          'Una rilevazione rapida aiuta Evolve a leggere meglio i tuoi pattern.',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CheckInSlider(
            label: 'Umore',
            value: _mood,
            color: EvolveColors.violet,
            onChanged: (value) => setState(() => _mood = value),
          ),
          const SizedBox(height: 14),
          _CheckInSlider(
            label: 'Energia',
            value: _energy,
            color: EvolveColors.amber,
            onChanged: (value) => setState(() => _energy = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () async {
            await ref
                .read(dashboardControllerProvider.notifier)
                .updateCheckIn(mood: _mood.round(), energy: _energy.round());
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Registra'),
        ),
      ],
    );
  }
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
            title: 'Obiettivi in focus',
            subtitle: 'Priorita correnti',
            trailing: Builder(
              builder: (context) => IconButton(
                onPressed: () {
                  final isPro = ref.read(desktopIsProProvider);
                  if (!isPro && goals.length >= 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Limite di 100 obiettivi raggiunto. Passa a Pro per crearne altri.',
                        ),
                      ),
                    );
                    return;
                  }
                  showEvolveDialog<void>(
                    context: context,
                    builder: (context) => const CreateGoalDialog(),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                tooltip: 'Nuovo Obiettivo',
                style: IconButton.styleFrom(
                  backgroundColor: context.evolveColors.border.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nessun obiettivo in focus. Aggiungine uno.',
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
                      ? 'Settimana da avviare'
                      : momentum >= 0
                      ? 'Settimana in crescita'
                      : 'Settimana da recuperare',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_signedPercentage(momentum)} rispetto alla settimana precedente.',
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

String _greeting(Map<String, dynamic>? metadata, String? email) {
  final fullName = (metadata?['full_name'] as String?)?.trim();
  final name = fullName?.isNotEmpty ?? false
      ? fullName!.split(RegExp(r'\s+')).first
      : email?.split('@').first;
  return name == null || name.isEmpty ? 'Buongiorno' : 'Buongiorno, $name';
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

  void _submit(WidgetRef ref) {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    ref
        .read(sharedPreferencesProvider)
        ?.setString('private_profile_name', name);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return EvolveAlertDialog(
          icon: Icons.person_outline,
          title: const Text('Come ti chiami?'),
          subtitle: 'Inserisci il tuo nome per personalizzare la dashboard.',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Es. Simo',
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
                  child: const Text('Salva e continua'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
