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
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../providers/tutorial_provider.dart';

class MacroGoalsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onFinishTutorial;
  final GlobalKey? statsNavKey;
  const MacroGoalsScreen({super.key, this.onFinishTutorial, this.statsNavKey});

  @override
  ConsumerState<MacroGoalsScreen> createState() => _MacroGoalsScreenState();
}

class _MacroGoalsScreenState extends ConsumerState<MacroGoalsScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isForward = true;
  bool _showStats = false;

  final GlobalKey _planSelectorKey = GlobalKey();
  final GlobalKey _addGoalKey = GlobalKey();
  final GlobalKey _goalsListKey = GlobalKey();
  final GlobalKey _performanceToggleKey = GlobalKey();
  final GlobalKey _tutorialCheckboxKey = GlobalKey();
  final GlobalKey _tutorialCategoryKey = GlobalKey();
  final GlobalKey _tutorialRescheduleKey = GlobalKey();
  final GlobalKey _tutorialEditKey = GlobalKey();
  final GlobalKey _tutorialDeleteKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGoalsTutorial();
    });
  }

  void _checkGoalsTutorial() {
    final mainTutorialSeen = ref.read(tutorialProvider);
    final goalsTutorialSeen = ref.read(goalsTutorialProvider);
    
    // Only show if main tutorial is finished but goals tutorial isn't
    if (mainTutorialSeen && !goalsTutorialSeen) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _showGoalsTutorial();
      });
    }
  }

  Widget _buildTutorialContent(
    String title,
    String description,
    TutorialCoachMarkController controller, {
    bool isFirst = false,
    bool isLast = false,
    VoidCallback? onNextPressed,
    String? nextButtonLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), 
          width: 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.info, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18.0,
                  fontFamily: 'Inter',
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Text(
            description,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isFirst)
                TextButton(
                  onPressed: () {
                    ref.hapticSelection();
                    controller.previous();
                  },
                  child: Text("Indietro", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.bold)),
                )
              else
                const SizedBox.shrink(),
              ElevatedButton(
                onPressed: () {
                  ref.hapticSelection();
                  if (onNextPressed != null) {
                    onNextPressed();
                  } else if (isLast) {
                    controller.skip();
                  } else {
                    controller.next();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(nextButtonLabel ?? (isLast ? "Fine" : "Avanti"), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGoalsTutorial() {
    List<TargetFocus> targets = [
      TargetFocus(
        identify: "Tipo Pianificazione",
        keyTarget: _planSelectorKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTutorialContent(
                "Tipo di Pianificazione",
                "Qui puoi selezionare la visione temporale: Lifetime (per tutta la vita), Annuale, Trimestrale, Mensile o Settimanale.",
                controller,
                isFirst: true,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Aggiungi Goal",
        keyTarget: _addGoalKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialContent(
                "Nuovo Obiettivo",
                "Da qui puoi inserire un nuovo obiettivo. Potrai anche personalizzare le Categorie a tuo piacimento per organizzare tutto al meglio.",
                controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Tutorial Completare",
        keyTarget: _tutorialCheckboxKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialContent("Completare o Fallire", "Clicca qui per segnare l'obiettivo come completato. Cliccandolo di nuovo verrà segnato come fallito.", controller),
          ),
        ],
      ),
      TargetFocus(
        identify: "Tutorial Categoria",
        keyTarget: _tutorialCategoryKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialContent("Categoria", "Usa questo pulsante per assegnare rapidamente una categoria all'obiettivo.", controller),
          ),
        ],
      ),
      TargetFocus(
        identify: "Tutorial Posticipare",
        keyTarget: _tutorialRescheduleKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialContent("Posticipare", "Se non hai fatto in tempo o i piani sono cambiati, puoi spostare questo obiettivo alla settimana / mese o anno successivo ( in base a dove hai inserito l'obiettivo).", controller),
          ),
        ],
      ),
      TargetFocus(
        identify: "Tutorial Modifica",
        keyTarget: _tutorialEditKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialContent("Modifica", "Se devi semplicemente rinominare l'obiettivo, usa la matita.", controller),
          ),
        ],
      ),
      TargetFocus(
        identify: "Tutorial Elimina",
        keyTarget: _tutorialDeleteKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        paddingFocus: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _showStats) {
                  setState(() => _showStats = false);
                }
              });
              return _buildTutorialContent("Elimina", "Infine, questo pulsante elimina definitivamente l'obiettivo.", controller);
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Analisi Performance",
        keyTarget: _performanceToggleKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_showStats) {
                  setState(() => _showStats = true);
                }
              });
              return _buildTutorialContent(
                "Analisi e Statistiche",
                "Passa a questa scheda per visualizzare grafici e performance dettagliate selezionando l'anno corrente o tutti gli anni.",
                controller,
                isLast: false,
                nextButtonLabel: "Continua",
              );
            },
          ),
        ],
      ),
      if (widget.statsNavKey != null)
        TargetFocus(
          identify: "Tutorial Statistiche Tab",
          keyTarget: widget.statsNavKey!,
          enableTargetTab: false,
          enableOverlayTab: false,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return _buildTutorialContent(
                  "Statistiche Abitudini",
                  "Per vedere le statistiche delle tue abitudini giornaliere, puoi spostarti in questa sezione.",
                  controller,
                  isLast: false,
                  nextButtonLabel: "Passa alle Statistiche",
                  onNextPressed: () {
                    ref.read(goalsTutorialProvider.notifier).setTutorialSeen(true);
                    if (widget.onFinishTutorial != null) {
                      widget.onFinishTutorial!();
                    }
                    controller.skip();
                  },
                );
              },
            ),
          ],
        ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      hideSkip: true,
      paddingFocus: 10,
      opacityShadow: 0.85,
      focusAnimationDuration: const Duration(milliseconds: 400),
      unFocusAnimationDuration: Duration.zero,
      pulseEnable: false,
      onFinish: () {
        ref.read(goalsTutorialProvider.notifier).setTutorialSeen(true);
        if (widget.onFinishTutorial != null) {
          widget.onFinishTutorial!();
        }
      },
    ).show(context: context);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final viewState = ref.watch(macroGoalsViewProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    // Force re-compute on state change
    ref.watch(macroGoalsProvider);

    // Ascolta anche i cambiamenti dello stato del main tutorial (es. se viene resettato)
    ref.listen(tutorialProvider, (prev, next) {
      if (next == true && !ref.read(goalsTutorialProvider)) {
        // Se il tutorial main finisce, controlla se bisogna lanciare questo (es. navigazione dalla tab)
        // Diamo tempo al cambio tab di terminare l'animazione
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _checkGoalsTutorial();
        });
      }
    });

    final filteredGoals = ref.read(macroGoalsProvider.notifier).getFilteredGoals(
          type: viewState.selectedType,
          year: viewState.selectedYear,
          quarter: viewState.selectedQuarter,
          month: viewState.selectedMonth,
          weekNumber: viewState.selectedWeek,
        );

    final mainTutorialSeen = ref.watch(tutorialProvider);
    final goalsTutorialSeen = ref.watch(goalsTutorialProvider);
    
    List<MacroGoal> displayGoals = List.from(filteredGoals);
    if (mainTutorialSeen && !goalsTutorialSeen) {
      displayGoals.insert(0, MacroGoal(
        id: 'tutorial_fake_goal',
        title: 'Obiettivo Tutorial',
        status: GoalStatus.active,
        type: viewState.selectedType,
        year: viewState.selectedYear,
        quarter: viewState.selectedQuarter,
        month: viewState.selectedMonth,
        weekNumber: viewState.selectedWeek,
        createdAt: DateTime.now(),
      ));
    }

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
                    goals: displayGoals,
                    viewState: viewState,
                    emptyStateKey: _goalsListKey,
                    tutorialCheckboxKey: _tutorialCheckboxKey,
                    tutorialCategoryKey: _tutorialCategoryKey,
                    tutorialRescheduleKey: _tutorialRescheduleKey,
                    tutorialEditKey: _tutorialEditKey,
                    tutorialDeleteKey: _tutorialDeleteKey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(key: _addGoalKey, child: AddGoalBar(viewState: viewState)),
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
          Container(key: _performanceToggleKey, child: _buildModeToggle()),
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
        key: _planSelectorKey,
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
  final GlobalKey emptyStateKey;
  final GlobalKey? tutorialCheckboxKey;
  final GlobalKey? tutorialCategoryKey;
  final GlobalKey? tutorialRescheduleKey;
  final GlobalKey? tutorialEditKey;
  final GlobalKey? tutorialDeleteKey;

  const _GoalsList({
    super.key, 
    required this.goals, 
    required this.viewState, 
    required this.emptyStateKey,
    this.tutorialCheckboxKey,
    this.tutorialCategoryKey,
    this.tutorialRescheduleKey,
    this.tutorialEditKey,
    this.tutorialDeleteKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (goals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            key: emptyStateKey,
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
        if (goal.id == 'tutorial_fake_goal') {
          return GoalItemWidget(
            key: ValueKey(goal.id), 
            goal: goal,
            checkboxKey: tutorialCheckboxKey,
            categoryKey: tutorialCategoryKey,
            rescheduleKey: tutorialRescheduleKey,
            editKey: tutorialEditKey,
            deleteKey: tutorialDeleteKey,
          );
        }
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
