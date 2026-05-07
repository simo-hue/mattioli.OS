import 'dart:math' as math;
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
import '../../core/haptics.dart';

class MacroGoalsScreen extends ConsumerStatefulWidget {
  const MacroGoalsScreen({super.key});

  @override
  ConsumerState<MacroGoalsScreen> createState() => _MacroGoalsScreenState();
}

class _MacroGoalsScreenState extends ConsumerState<MacroGoalsScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isForward = true;
  bool _showStats = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
      backgroundColor: context.appColors.background,
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
                    ref.hapticLight();
                  } else if (vx > velocityThreshold) {
                    setState(() => _isForward = false);
                    ref.read(macroGoalsViewProvider.notifier).prevPeriod();
                    ref.hapticLight();
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutQuart,
                  switchOutCurve: Curves.easeOutQuart,
                  transitionBuilder: (child, animation) {
                    final isIncoming = child.key == ValueKey('${viewState.selectedType}-${viewState.selectedYear}-${viewState.selectedMonth}-${viewState.selectedWeek}-${viewState.selectedQuarter}');
                    final dir = _isForward ? 1 : -1;

                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        // Perspective Fold Logic (3D Flip)
                        final double rotation = isIncoming 
                            ? (1.0 - animation.value) * (math.pi / 2) * dir
                            : animation.value * -(math.pi / 2) * dir;
                        
                        final alignment = isIncoming 
                            ? (dir > 0 ? Alignment.centerRight : Alignment.centerLeft)
                            : (dir > 0 ? Alignment.centerLeft : Alignment.centerRight);

                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0015) 
                            ..rotateY(rotation),
                          alignment: alignment,
                          child: Opacity(
                            opacity: animation.value.clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: child,
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
            const SizedBox(height: 12),
            AddGoalBar(viewState: viewState),
            const SizedBox(height: 12),
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
                  color: context.appColors.foreground,
                  letterSpacing: -1,
                ),
              ),
              if (!_showStats) _buildTypePicker(context, ref, vs, primaryColor),
            ],
          ),
          const SizedBox(height: 16),
          _buildModeToggle(),
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
        ref.hapticLight();
        _showTypePicker(context, ref, vs, primaryColor);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.appColors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appColors.border),
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
                color: context.appColors.foreground,
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronDown, size: 12, color: context.appColors.mutedForeground),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        children: [
          _buildToggleItem(false, 'I miei obiettivi'),
          _buildToggleItem(true, 'Analisi Performance'),
        ],
      ),
    );
  }

  Widget _buildToggleItem(bool stats, String label) {
    final active = _showStats == stats;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_showStats != stats) {
            setState(() => _showStats = stats);
            ref.hapticSelection();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: active ? Theme.of(context).colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? context.appColors.background : context.appColors.mutedForeground,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }

  void _showTypePicker(BuildContext context, WidgetRef ref, MacroGoalsViewState vs, Color primaryColor) {
    final types = [
      (t: GoalType.lifetime, l: 'LIFETIME', i: LucideIcons.infinity),
      (t: GoalType.annual, l: 'ANNUALE', i: LucideIcons.calendar),
      (t: GoalType.quarterly, l: 'TRIMESTRALE', i: LucideIcons.calendarRange),
      (t: GoalType.monthly, l: 'MENSILE', i: LucideIcons.calendarDays),
      (t: GoalType.weekly, l: 'SETTIMANALE', i: LucideIcons.clock),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  'TIPO PIANIFICAZIONE', 
                  style: TextStyle(
                    fontFamily: 'Inter', 
                    fontWeight: FontWeight.w800, 
                    color: context.appColors.mutedForeground, 
                    fontSize: 10,
                    letterSpacing: 1.2,
                  )
                ),
              ),
            ),
            ...types.map((type) {
              final isSel = type.t == vs.selectedType;
              return ListTile(
                leading: Icon(
                  type.i,
                  size: 20,
                  color: isSel ? primaryColor : context.appColors.mutedForeground.withValues(alpha: 0.6),
                ),
                title: Text(
                  type.l,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: isSel ? context.appColors.foreground : context.appColors.mutedForeground,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: isSel ? Icon(LucideIcons.check, color: primaryColor, size: 20) : null,
                onTap: () {
                  ref.read(macroGoalsViewProvider.notifier).setType(type.t);
                  Navigator.pop(context);
                  ref.hapticSelection();
                },
              );
            }),
            const SizedBox(height: 20),
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
          style: GoogleFonts.inter(fontSize: 14, color: context.appColors.mutedForeground),
        ),
      );
    }

    final months = [
      '', 'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
    ];

    String periodTitle = '';
    Color highlightColor = context.appColors.foreground;

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
              ref.hapticLight();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.appColors.card.withValues(alpha: 0.8),
              ),
              child: Icon(LucideIcons.chevronLeft, size: 20, color: context.appColors.foreground),
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
              ref.hapticLight();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.appColors.card.withValues(alpha: 0.8),
              ),
              child: Icon(LucideIcons.chevronRight, size: 20, color: context.appColors.foreground),
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
                color: context.appColors.border,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                'Nessun obiettivo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.appColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aggiungi un obiettivo per questo periodo usando la barra qui sotto.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.appColors.mutedForeground,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final items = _buildItems(goals);

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      physics: const BouncingScrollPhysics(),
      proxyDecorator: (child, index, animation) => child,
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {
        // Programmatic reordering is handled by the provider state change
      },
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _SectionHeader) {
          return _buildSectionHeader(context, item.status, ValueKey('header-${item.status.name}'));
        }
        final goal = item as MacroGoal;
        return GoalItemWidget(key: ValueKey(goal.id), goal: goal);
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, GoalStatus status, Key key) {
    final label = status == GoalStatus.completed ? 'COMPLETATI' : 'FALLITI';
    final color = status == GoalStatus.completed
        ? const Color(0xFF10B981).withValues(alpha: 0.7)
        : context.appColors.destructive.withValues(alpha: 0.7);

    return Padding(
      key: key,
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
