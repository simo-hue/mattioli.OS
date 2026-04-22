import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../models/macro_goal.dart';
import '../../providers/macro_goals_provider.dart';
import '../widgets/macro_goals/goal_item_widget.dart';
import '../widgets/macro_goals/add_goal_bar.dart';
import '../widgets/macro_goals/macro_goals_stats_view.dart';

class MacroGoalsScreen extends ConsumerStatefulWidget {
  const MacroGoalsScreen({super.key});

  @override
  ConsumerState<MacroGoalsScreen> createState() => _MacroGoalsScreenState();
}

class _MacroGoalsScreenState extends ConsumerState<MacroGoalsScreen> {
  bool _isForward = true;
  bool _showStats = false;

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(macroGoalsViewProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    // Force re-compute on state change
    ref.watch(macroGoalsProvider);

    final filteredGoals = ref.read(macroGoalsProvider.notifier).getFilteredGoals(
          type: viewState.selectedType,
          year: viewState.selectedYear,
          quarter: viewState.selectedQuarter,
          month: viewState.selectedMonth,
          weekNumber: viewState.selectedWeek,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Unified Native Header ─────────────────────────────────────
            _buildUnifiedHeader(context, ref, viewState, primaryColor),

            if (_showStats)
              const Expanded(child: MacroGoalsStatsView())
            else ...[
              // ── Native Period Navigator Stepper ───────────────────────────
              _buildPeriodNavigator(context, ref, viewState),

              const SizedBox(height: 16),

            // ── Add goal input ────────────────────────────────────────────
            AddGoalBar(viewState: viewState),

            const SizedBox(height: 12),

            // ── Goals list ────────────────────────────────────────────────
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (details) {
                  if (viewState.selectedType == GoalType.lifetime) return;
                  const velocityThreshold = 300.0;
                  final vx = details.primaryVelocity ?? 0.0;
                  if (vx < -velocityThreshold) {
                    setState(() => _isForward = true);
                    ref.read(macroGoalsViewProvider.notifier).nextPeriod();
                    HapticFeedback.lightImpact();
                  } else if (vx > velocityThreshold) {
                    setState(() => _isForward = false);
                    ref.read(macroGoalsViewProvider.notifier).prevPeriod();
                    HapticFeedback.lightImpact();
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(_isForward ? 0.05 : -0.05, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: _GoalsList(
                    key: ValueKey('${viewState.selectedType}-${viewState.selectedYear}-${viewState.selectedMonth}-${viewState.selectedWeek}-${viewState.selectedQuarter}'),
                    goals: filteredGoals,
                    viewState: viewState,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildUnifiedHeader(BuildContext context, WidgetRef ref, MacroGoalsViewState vs, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Obiettivi',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                  letterSpacing: -1,
                ),
              ),
              if (!_showStats) _buildTypePicker(context, ref, vs, primaryColor),
            ],
          ),
          const SizedBox(height: 16),
          _buildModeToggle(primaryColor),
        ],
      ),
    );
  }

  Widget _buildTypePicker(BuildContext context, WidgetRef ref, MacroGoalsViewState vs, Color primaryColor) {
    String typeLabel = '';
    switch (vs.selectedType) {
      case GoalType.lifetime: typeLabel = 'Lifetime'; break;
      case GoalType.annual: typeLabel = 'Annuale'; break;
      case GoalType.quarterly: typeLabel = 'Trimestrale'; break;
      case GoalType.monthly: typeLabel = 'Mensile'; break;
      case GoalType.weekly: typeLabel = 'Settimanale'; break;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showTypePicker(context, ref, vs, primaryColor);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderHover),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.target, size: 12, color: primaryColor),
            const SizedBox(width: 6),
            Text(
              typeLabel,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronDown, size: 12, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle(Color primaryColor) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderHover),
      ),
      child: Row(
        children: [
          _buildToggleItem(primaryColor, false, LucideIcons.listTodo, 'I miei obiettivi'),
          _buildToggleItem(primaryColor, true, LucideIcons.chartBar, 'Analisi Performance'),
        ],
      ),
    );
  }

  Widget _buildToggleItem(Color primaryColor, bool stats, IconData icon, String label) {
    final active = _showStats == stats;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_showStats != stats) {
            setState(() => _showStats = stats);
            HapticFeedback.selectionClick();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? primaryColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? primaryColor : AppColors.mutedForeground,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? primaryColor : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTypePicker(BuildContext context, WidgetRef ref, MacroGoalsViewState vs, Color primaryColor) {
    final types = [
      (t: GoalType.lifetime, l: 'Lifetime'),
      (t: GoalType.annual, l: 'Annuale'),
      (t: GoalType.quarterly, l: 'Trimestrale'),
      (t: GoalType.monthly, l: 'Mensile'),
      (t: GoalType.weekly, l: 'Settimanale'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderActive,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Tipo Pianificazione', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontSize: 13)),
              ),
            ),
            ...types.map((type) {
              final isSel = type.t == vs.selectedType;
              return ListTile(
                title: Text(
                  type.l,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: isSel ? AppColors.foreground : AppColors.mutedForeground,
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: isSel ? Icon(Icons.check, color: primaryColor) : null,
                onTap: () {
                  ref.read(macroGoalsViewProvider.notifier).setType(type.t);
                  Navigator.pop(context);
                  HapticFeedback.selectionClick();
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodNavigator(BuildContext context, WidgetRef ref, MacroGoalsViewState vs) {
    if (vs.selectedType == GoalType.lifetime) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Text(
          'Visione a lungo termine della tua vita.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedForeground),
        ),
      );
    }

    final months = [
      '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
    ];

    String periodTitle = '';
    Color highlightColor = AppColors.foreground;

    switch (vs.selectedType) {
      case GoalType.annual:
        periodTitle = '${vs.selectedYear}';
        break;
      case GoalType.quarterly:
        periodTitle = 'Q${vs.selectedQuarter} ${vs.selectedYear}';
        highlightColor = const Color(0xFFFBBF24); // amber
        break;
      case GoalType.monthly:
        periodTitle = '${months[vs.selectedMonth]} ${vs.selectedYear}';
        highlightColor = const Color(0xFF60A5FA); // blue
        break;
      case GoalType.weekly:
        periodTitle = 'Settimana ${vs.selectedWeek}, ${months[vs.selectedMonth]} ${vs.selectedYear}';
        highlightColor = const Color(0xFFA78BFA); // purple
        break;
      case GoalType.lifetime:
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          GestureDetector(
            onTap: () {
              setState(() => _isForward = false);
              ref.read(macroGoalsViewProvider.notifier).prevPeriod();
              HapticFeedback.lightImpact();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.card.withValues(alpha: 0.8),
              ),
              child: Icon(LucideIcons.chevronLeft, size: 20, color: AppColors.foreground),
            ),
          ),

          // Central Title representing the context
          Expanded(
            child: Text(
              periodTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: highlightColor,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // Next Button
          GestureDetector(
            onTap: () {
              setState(() => _isForward = true);
              ref.read(macroGoalsViewProvider.notifier).nextPeriod();
              HapticFeedback.lightImpact();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.card.withValues(alpha: 0.8),
              ),
              child: Icon(LucideIcons.chevronRight, size: 20, color: AppColors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Goals list ───────────────────────────────────────────────────────────────

class _GoalsList extends ConsumerWidget {
  final List<MacroGoal> goals;
  final MacroGoalsViewState viewState;

  const _GoalsList({super.key, required this.goals, required this.viewState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.target,
                color: AppColors.borderActive,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'Nessun obiettivo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aggiungi un obiettivo per questo periodo usando la barra qui sopra.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: _buildItems(goals).length,
      itemBuilder: (context, index) {
        final item = _buildItems(goals)[index];
        if (item is _SectionHeader) {
          return _buildSectionHeader(item.status);
        }
        return GoalItemWidget(goal: item as MacroGoal);
      },
    );
  }

  Widget _buildSectionHeader(GoalStatus status) {
    final label = status == GoalStatus.completed ? 'COMPLETATI' : 'FALLITI';
    final color = status == GoalStatus.completed
        ? const Color(0xFF34D399).withValues(alpha: 0.7)
        : AppColors.destructive.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: color.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: color.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _buildItems(List<MacroGoal> goals) {
    final result = <dynamic>[];
    bool shownCompleted = false;
    bool shownFailed = false;

    for (final goal in goals) {
      if (goal.status == GoalStatus.completed && !shownCompleted) {
        result.add(_SectionHeader(GoalStatus.completed));
        shownCompleted = true;
      }
      if (goal.status == GoalStatus.failed && !shownFailed) {
        result.add(_SectionHeader(GoalStatus.failed));
        shownFailed = true;
      }
      result.add(goal);
    }
    return result;
  }
}

class _SectionHeader {
  final GoalStatus status;
  _SectionHeader(this.status);
}
