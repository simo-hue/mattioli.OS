import 'dart:async';
import 'dart:math' as math;
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/goals/application/goals_page_command.dart';
import 'package:evolve_desktop/features/search/application/goal_nav_target.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/rtl.dart';
import 'package:evolve_desktop/shared/widgets/color_picker_button.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'goals_stats_view.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_period_switcher.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/shared/widgets/coach_tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  late GoalType _selectedType;
  late int _selectedYear;
  late int _selectedQuarter;
  late int _selectedMonth;
  late int _selectedWeek;
  bool _showStats = false;
  final _quickGoalController = TextEditingController();
  _GoalCategory? _quickGoalCategory;
  // User-created goal categories only — the previous hard-coded/default preset
  // categories (lavoro, salute, …) were removed; the picker now starts empty and
  // is populated purely from the user's own saved categories (remote), plus the
  // implicit "Default" bucket for goals with no specific category.
  final _categories = <_GoalCategory>[];
  final _archivedCategoryIds = <String>{};

  // Goals segment of the continuous product tour. The central
  // [tourControllerProvider] owns whether this segment is active; the page only
  // owns the step index within the segment and the spotlight target keys.
  int _tourIndex = 0;

  // Tour target keys (one per spotlighted step).
  final _planSelectorKey = GlobalKey();
  final _performanceToggleKey = GlobalKey();
  final _addGoalKey = GlobalKey();
  final _tutorialCheckboxKey = GlobalKey();

  // Holds page-level keyboard focus so ←/→ page through the selected plan's
  // timeline (see [_handlePeriodKey]) the moment the page opens, without the
  // user having to click into it first.
  final _periodFocusNode = FocusNode(debugLabel: 'goals-period-nav');

  // Count of period pickers / menus currently open on the page. While any is
  // open the arrow keys must not page the timeline behind it (the popups keep
  // the page node focused, so this is the only signal that one is up).
  int _openMenus = 0;

  // Last period-navigation direction (+1 next, -1 previous, 0 neutral jump),
  // driving the direction of the goal board's slide+fade transition.
  int _lastDirection = 0;

  // One-shot deep-link support: when the ⌘K command palette jumps here it drops
  // a [GoalNavTarget]. [initState] seeds the period from it and records which
  // goal to spotlight; the board attaches [_highlightRowKey] to that row so it
  // can be glowed + scrolled into view exactly once.
  String? _highlightGoalId;
  final GlobalKey _highlightRowKey = GlobalKey(
    debugLabel: 'goals-highlight-row',
  );

  /// Set when a ⌘K "Edit" jump lands here: after scrolling the goal into view we
  /// open its editor (reusing this page's own editor + category context).
  bool _pendingOpenEditor = false;

  /// Structural identity of the shown period: any visible change (type, year,
  /// quarter, month or week) flips it, which drives the board transition.
  Object get _periodSignature => (
    _selectedType,
    _selectedYear,
    _selectedQuarter,
    _selectedMonth,
    _selectedWeek,
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default to the current week...
    _selectedType = GoalType.weekly;
    _selectedYear = now.year;
    _selectedQuarter = ((now.month - 1) ~/ 3) + 1;
    _selectedMonth = now.month;
    _selectedWeek = logicalWeekOfMonth(now);

    // ...unless the command palette queued a one-shot jump to a specific goal's
    // period. We only READ the target here — clearing a provider while a parent
    // is mid-build would throw — and consume (clear) it in the post-frame
    // callback below, so an ordinary later open still lands on today's week. The
    // already-mounted case (a jump while Goals is already on screen) is handled
    // by the `ref.listen` in [build].
    final target = ref.read(goalNavTargetProvider);
    if (target != null) _seedFrom(target);

    // Claim keyboard focus after the first frame so arrow-key period paging is
    // live immediately — but never yank focus away from the guided tour
    // overlay, which drives the keyboard itself while it runs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Applied — drop the one-shot palette intents so they can't replay.
      ref.read(goalNavTargetProvider.notifier).consume();
      final command = ref.read(goalsPageCommandProvider.notifier).consume();
      if (!ref.read(tourControllerProvider).active) {
        _periodFocusNode.requestFocus();
      }
      _revealHighlightedGoal();
      _maybeOpenPendingEditor();
      if (command != null) _runPageCommand(command);
    });
  }

  /// Copy a [GoalNavTarget]'s period into the page's selection and record what
  /// to do on arrival (spotlight a row, open its editor). Caller is responsible
  /// for the surrounding setState when applied to a live page.
  void _seedFrom(GoalNavTarget target) {
    _selectedType = target.type;
    _selectedYear = target.year ?? _selectedYear;
    _selectedQuarter = target.quarter ?? _selectedQuarter;
    _selectedMonth = target.month ?? _selectedMonth;
    _selectedWeek = target.week ?? _selectedWeek;
    _highlightGoalId = target.highlightGoalId;
    _pendingOpenEditor = target.openEditor;
  }

  /// If a ⌘K "Edit" jump requested it, open the spotlighted goal's editor.
  void _maybeOpenPendingEditor() {
    if (!_pendingOpenEditor) return;
    _pendingOpenEditor = false;
    final id = _highlightGoalId;
    if (id == null) return;
    for (final goal in ref.read(dashboardControllerProvider).goals) {
      if (goal.id == id) {
        _openGoalEditorFor(goal);
        return;
      }
    }
  }

  void _runPageCommand(GoalsPageCommand command) {
    switch (command) {
      case GoalsPageCommand.openCategoryManager:
        _openCategoryManager();
    }
  }

  /// Scrolls the spotlighted goal (if any) into view once the board has laid
  /// out. The row's transient glow is driven by the row widget itself; here we
  /// only make sure it's on screen. Retries a couple of frames in case the
  /// board's slide-in transition hasn't settled its geometry yet.
  void _revealHighlightedGoal([int attempt = 0]) {
    if (_highlightGoalId == null) return;
    final ctx = _highlightRowKey.currentContext;
    if (ctx == null) {
      if (attempt >= 3) return;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revealHighlightedGoal(attempt + 1),
      );
      return;
    }
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.3,
    );
  }

  @override
  void dispose() {
    _quickGoalController.dispose();
    _periodFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(desktopGoalCategoriesControllerProvider);

    // A ⌘K jump/edit that arrives while Goals is ALREADY on screen: [initState]
    // only fires on a fresh mount, so react to the target changing here too.
    ref.listen<GoalNavTarget?>(goalNavTargetProvider, (previous, next) {
      if (next == null) return;
      setState(() {
        _lastDirection = 0; // neutral fade — the jump isn't a ‹ › step
        _seedFrom(next);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(goalNavTargetProvider.notifier).consume();
        _revealHighlightedGoal();
        _maybeOpenPendingEditor();
      });
    });
    ref.listen<GoalsPageCommand?>(goalsPageCommandProvider, (previous, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final command = ref.read(goalsPageCommandProvider.notifier).consume();
        if (command != null) _runPageCommand(command);
      });
    });

    final allGoals = ref.watch(dashboardControllerProvider).goals;
    final goals = allGoals.where(_matchesPeriod).toList()..sort(_sortGoals);

    var activeGoals = goals
        .where((goal) => goal.state == GoalState.active)
        .toList();
    final completedGoals = goals
        .where((goal) => goal.state == GoalState.completed)
        .toList();
    final failedGoals = goals
        .where((goal) => goal.state == GoalState.failed)
        .toList();

    final categories = _availableCategories;
    // The Goals segment of the continuous tour is active. The demo goal below
    // gives the "complete/miss" step something to spotlight when the user has
    // no real goals for the selected period yet.
    final showTour = ref
        .watch(tourControllerProvider)
        .isSegmentActive(TourSegment.goals);

    if (showTour && activeGoals.isEmpty) {
      activeGoals = [
        DashboardGoal(
          id: 'tutorial_fake_goal',
          title: t.goalsPage.sampleGoal,
          category: 'Tutorial',
          color: EvolveColors.cyan,
          state: GoalState.active,
          type: _selectedType,
          createdAt: DateTime.now(),
          dueLabel: _periodLabel,
          year: _selectedYear,
          quarter: _selectedQuarter,
          month: _selectedMonth,
          weekNumber: _selectedWeek,
          progress: 0,
        ),
      ];
    }

    return Focus(
      focusNode: _periodFocusNode,
      onKeyEvent: _handlePeriodKey,
      child: DesktopPage(
        title: t.goalsPage.title,
        subtitle: t.goalsPage.subtitle,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GoalToolbar(
                  statsToggleKey: _performanceToggleKey,
                  selectedType: _selectedType,
                  showStats: _showStats,
                  onTypeChanged: (type) => setState(() {
                    _lastDirection = 0; // plan switch — neutral fade
                    _selectedType = type;
                    _showStats = false;
                  }),
                  onShowStats: () => setState(() => _showStats = true),
                ),
                const SizedBox(height: 22),
                _GoalCommandBar(
                  periodClusterKey: _planSelectorKey,
                  addGoalKey: _addGoalKey,
                  onMenuOpenChanged: _onMenuOpenChanged,
                  selectedType: _selectedType,
                  selectedYear: _selectedYear,
                  selectedQuarter: _selectedQuarter,
                  selectedMonth: _selectedMonth,
                  selectedWeek: _selectedWeek,
                  onYearChanged: (year) => setState(() {
                    _lastDirection = year.compareTo(_selectedYear);
                    _selectedYear = year;
                    _selectedWeek = _selectedWeek.clamp(
                      1,
                      logicalWeeksInMonth(_selectedYear, _selectedMonth),
                    );
                  }),
                  onQuarterChanged: (quarter) => setState(() {
                    _lastDirection = quarter.compareTo(_selectedQuarter);
                    _selectedQuarter = quarter;
                  }),
                  onMonthChanged: (month) => setState(() {
                    _lastDirection = month.compareTo(_selectedMonth);
                    _selectedMonth = month;
                    _selectedWeek = 1;
                  }),
                  onWeekChanged: (week) => setState(() {
                    _lastDirection = week.compareTo(_selectedWeek);
                    _selectedWeek = week;
                  }),
                  onPrevious: () => _movePeriod(-1),
                  onNext: () => _movePeriod(1),
                  onManageCategories: _openCategoryManager,
                  showQuickAdd: !_showStats,
                  quickGoalController: _quickGoalController,
                  quickGoalCategory: _quickGoalCategory,
                  categories: categories,
                  onQuickCategoryChanged: (category) =>
                      setState(() => _quickGoalCategory = category),
                  onCreateCategory: _createCategoryInline,
                  onQuickSubmit: _submitQuickGoal,
                  quickGoalHint: _quickGoalHint,
                ),
                const SizedBox(height: 22),
                if (_showStats)
                  const GoalsStatsView()
                else
                  // Slide+fade the board on every period change so arrow-key /
                  // ‹ › navigation is always visibly reflected. The tutorial
                  // GlobalKey is attached only during the tour so the brief
                  // two-board overlap of a transition can't duplicate it.
                  EvolvePeriodSwitcher(
                    periodKey: _periodSignature,
                    direction: _lastDirection,
                    child: _GoalBoard(
                      periodTitle: _periodTitle,
                      periodSubtitle: _periodSubtitle,
                      tutorialCheckboxKey: showTour
                          ? _tutorialCheckboxKey
                          : null,
                      highlightGoalId: _highlightGoalId,
                      highlightRowKey: _highlightRowKey,
                      categories: categories,
                      activeGoals: activeGoals,
                      completedGoals: completedGoals,
                      failedGoals: failedGoals,
                      onToggleStatus: _cycleGoalStatus,
                      onEdit: _openGoalEditorFor,
                      onReschedule: (goal) => ref
                          .read(dashboardControllerProvider.notifier)
                          .rescheduleGoal(goal.id),
                      onDelete: (goal) => ref
                          .read(dashboardControllerProvider.notifier)
                          .deleteGoal(goal.id),
                    ),
                  ),
              ],
            ),
            if (showTour)
              CoachTutorialOverlay(
                steps: _goalsTourSteps(),
                index: _tourIndex,
                onIndexChanged: (i) => setState(() => _tourIndex = i),
                // The last Goals step advances the tour to the Coach segment.
                onFinish: () =>
                    ref.read(tourControllerProvider.notifier).advance(),
                backLabel: t.tour.back,
                nextLabel: t.tour.next,
                finishLabel: t.tour.continueLabel,
              ),
          ],
        ),
      ),
    );
  }

  /// Left/right arrow keys page through the selected plan's timeline (previous
  /// / next week, month, quarter or year), mirroring the ‹ › buttons in the
  /// command bar via [_movePeriod]. This handler sits on an ancestor [Focus],
  /// so it also fires while a goal row or nav button holds focus — but it
  /// deliberately steps aside (returns [KeyEventResult.ignored]) while a text
  /// field is being edited (so the quick-add caret keeps moving), while a
  /// period picker is open (so it doesn't page behind the menu), while the
  /// guided tour owns the keyboard, and for lifetime goals (no timeline).
  KeyEventResult _handlePeriodKey(FocusNode node, KeyEvent event) {
    // Repeat events let the user hold the key to fly through periods.
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final isLeft = key == LogicalKeyboardKey.arrowLeft;
    final isRight = key == LogicalKeyboardKey.arrowRight;
    if (!isLeft && !isRight) return KeyEventResult.ignored;
    if (_selectedType == GoalType.lifetime) return KeyEventResult.ignored;
    if (_openMenus > 0) return KeyEventResult.ignored;
    if (_isTextFieldFocused()) return KeyEventResult.ignored;
    if (ref.read(tourControllerProvider).active) return KeyEventResult.ignored;
    // RTL flips the arrows: in a right-to-left layout the timeline runs
    // leftwards, so ← advances and → rewinds (the same rule the shell's
    // two-finger trackpad swipe uses).
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final forward = isRight != isRtl;
    _movePeriod(forward ? 1 : -1);
    return KeyEventResult.handled;
  }

  /// True while a text field owns the primary focus, so the arrow keys should
  /// move the caret instead of paging the period.
  bool _isTextFieldFocused() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  /// Tracks how many period pickers / menus are open so [_handlePeriodKey] can
  /// stand down while one is up (the popups don't take focus, so a counter is
  /// the only reliable signal). No [setState]: the value is only read
  /// synchronously inside the key handler.
  void _onMenuOpenChanged(bool open) {
    _openMenus = (_openMenus + (open ? 1 : -1)).clamp(0, 1 << 20);
  }

  String get _periodLabel {
    return switch (_selectedType) {
      GoalType.lifetime => t.goalsPage.periodLifetime,
      GoalType.annual => '$_selectedYear',
      GoalType.quarterly => 'Q$_selectedQuarter $_selectedYear',
      GoalType.monthly =>
        '${t.common.months[_selectedMonth - 1]} $_selectedYear',
      GoalType.weekly => t.goalsPage.weekPeriodLabel(
        week: _selectedWeek,
        month: t.common.months[_selectedMonth - 1],
        year: _selectedYear,
      ),
    };
  }

  String get _periodTitle {
    return switch (_selectedType) {
      GoalType.lifetime => t.macroGoals.types.lifetime,
      GoalType.annual => '$_selectedYear',
      GoalType.quarterly => t.macroGoals.quarterNumber(
        quarter: _selectedQuarter,
      ),
      GoalType.monthly => t.common.months[_selectedMonth - 1],
      GoalType.weekly => '${t.common.calendarView.week} $_selectedWeek',
    };
  }

  String get _periodSubtitle {
    return switch (_selectedType) {
      GoalType.lifetime => t.goalsPage.subtitleLifetime,
      GoalType.annual => t.goalsPage.subtitleAnnual,
      GoalType.quarterly => t.goalsPage.subtitleQuarterly,
      GoalType.monthly => t.goalsPage.subtitleMonthly,
      GoalType.weekly => t.goalsPage.subtitleWeekly,
    };
  }

  String get _quickGoalHint {
    return switch (_selectedType) {
      GoalType.lifetime => t.macroGoals.addLifetimeGoal,
      GoalType.annual => t.macroGoals.addAnnualGoal,
      GoalType.quarterly => t.macroGoals.addQuarterlyGoal,
      GoalType.monthly => t.macroGoals.addMonthlyGoal,
      GoalType.weekly => t.macroGoals.addWeeklyGoal,
    };
  }

  bool _matchesPeriod(DashboardGoal goal) {
    final type = _selectedType;
    if (goal.type != type) return false;
    if (type == GoalType.lifetime) return true;
    if (goal.year != _selectedYear) return false;
    return switch (type) {
      GoalType.quarterly => goal.quarter == _selectedQuarter,
      GoalType.monthly => goal.month == _selectedMonth,
      GoalType.weekly =>
        goal.month == _selectedMonth && goal.weekNumber == _selectedWeek,
      _ => true,
    };
  }

  void _movePeriod(int direction) {
    setState(() {
      _lastDirection = direction;
      switch (_selectedType) {
        case GoalType.lifetime:
          return;
        case GoalType.annual:
          _selectedYear += direction;
        case GoalType.quarterly:
          _selectedQuarter += direction;
          if (_selectedQuarter > 4) {
            _selectedQuarter = 1;
            _selectedYear++;
          } else if (_selectedQuarter < 1) {
            _selectedQuarter = 4;
            _selectedYear--;
          }
        case GoalType.monthly:
          _selectedMonth += direction;
          if (_selectedMonth > 12) {
            _selectedMonth = 1;
            _selectedYear++;
          } else if (_selectedMonth < 1) {
            _selectedMonth = 12;
            _selectedYear--;
          }
        case GoalType.weekly:
          _selectedWeek += direction;
          if (_selectedWeek >
              logicalWeeksInMonth(_selectedYear, _selectedMonth)) {
            _selectedWeek = 1;
            _selectedMonth++;
            if (_selectedMonth > 12) {
              _selectedMonth = 1;
              _selectedYear++;
            }
          } else if (_selectedWeek < 1) {
            _selectedMonth--;
            if (_selectedMonth < 1) {
              _selectedMonth = 12;
              _selectedYear--;
            }
            _selectedWeek = logicalWeeksInMonth(_selectedYear, _selectedMonth);
          }
      }
    });
  }

  int _sortGoals(DashboardGoal a, DashboardGoal b) {
    final stateComparison = a.state.index.compareTo(b.state.index);
    if (stateComparison != 0) return stateComparison;
    return (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0));
  }

  Future<void> _submitQuickGoal() async {
    final title = _quickGoalController.text.trim();
    if (title.isEmpty) return;

    final isPro = ref.read(desktopIsProProvider);
    final totalGoals = ref.read(dashboardControllerProvider).goals.length;
    if (!isPro && totalGoals >= 100) {
      unawaited(showProFeaturesDialog(context, ref));
      return;
    }

    final category = _quickGoalCategory;
    await ref
        .read(dashboardControllerProvider.notifier)
        .addGoal(
          title: title,
          category: category?.key ?? '',
          color: category?.color ?? dashboardGoalColor(category?.key),
          type: _selectedType,
          dueLabel: _periodLabel,
          categoryId: category?.id,
          year: _selectedYear,
          quarter: _selectedQuarter,
          month: _selectedMonth,
          weekNumber: _selectedWeek,
        );
    _quickGoalController.clear();
  }

  Future<void> _cycleGoalStatus(
    DashboardGoal goal,
    GoalState finalState,
  ) async {
    // The tutorial injects a synthetic goal that has no backing entry in the
    // controller; toggling it would throw a StateError. Ignore interactions.
    if (goal.id == 'tutorial_fake_goal') return;
    await ref
        .read(dashboardControllerProvider.notifier)
        .updateGoalState(goal.id, finalState);
  }

  Future<void> _openGoalEditorFor(DashboardGoal goal) async {
    final categories = _availableCategories;
    final category = _categoryForGoal(goal, categories);
    final draft = await showEvolveDialog<_GoalDraft>(
      context: context,
      builder: (context) => _GoalEditorDialog(
        categories: categories,
        goal: goal,
        initialCategory: category,
      ),
    );
    if (draft == null) return;
    await ref
        .read(dashboardControllerProvider.notifier)
        .updateGoal(
          id: goal.id,
          title: draft.title,
          category: draft.category.key ?? '',
          color: draft.category.color,
          categoryId: draft.category.id,
        );
  }

  Future<void> _openCategoryManager() async {
    await showEvolveDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return EvolveAlertDialog(
            icon: LucideIcons.tags,
            title: Text(t.goalsPage.categoriesTitle),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final category in _availableCategories)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 7,
                        backgroundColor: category.color,
                      ),
                      title: Text(_categoryLabel(category)),
                      trailing: category.isDefault
                          ? StatusPill(label: t.goalsPage.defaultPill)
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: t.goalsPage.editCategory,
                                  onPressed: () async {
                                    await _editCategory(category);
                                    setDialogState(() {});
                                  },
                                  icon: const Icon(
                                    LucideIcons.pencil,
                                    size: 16,
                                  ),
                                ),
                                IconButton(
                                  tooltip: t.goalsPage.archiveCategory,
                                  onPressed: () async {
                                    await _archiveCategory(category);
                                    setDialogState(() {});
                                  },
                                  icon: const Icon(
                                    LucideIcons.archive,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  final category = await showEvolveDialog<_GoalCategory>(
                    context: context,
                    builder: (context) => const _CategoryEditorDialog(),
                  );
                  if (category == null) return;
                  DesktopGoalCategory? cloudCategory;
                  try {
                    cloudCategory = await ref
                        .read(desktopGoalCategoriesControllerProvider.notifier)
                        .addCategory(category.label, category.color);
                  } catch (_) {
                    if (!context.mounted) return;
                    showEvolveToast(
                      context,
                      message: t.goalsPage.categoryCreateFailed,
                      kind: EvolveToastKind.error,
                    );
                    return;
                  }
                  if (cloudCategory == null) {
                    // Write didn't persist (e.g. locked private DB); mirror
                    // mobile and surface a failure instead of a phantom add.
                    if (!context.mounted) return;
                    showEvolveToast(
                      context,
                      message: t.goalsPage.categoryCreateFailed,
                      kind: EvolveToastKind.error,
                    );
                    return;
                  }
                  final created = _GoalCategory(
                    id: cloudCategory.id,
                    label: cloudCategory.label,
                    color: cloudCategory.color,
                  );
                  setState(() => _categories.add(created));
                  setDialogState(() {});
                },
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(t.goalsPage.addCategory),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.habitsPage.close),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_GoalCategory> get _availableCategories {
    final categories = [..._categories];
    final remote =
        ref.read(desktopGoalCategoriesControllerProvider).value ?? const [];
    for (final category in remote) {
      if (category.isArchived) continue;
      if (_archivedCategoryIds.contains(category.id)) continue;
      if (categories.any((item) => item.id == category.id)) continue;
      categories.add(
        _GoalCategory(
          id: category.id,
          label: category.label,
          color: category.color,
        ),
      );
    }
    return categories;
  }

  Future<void> _archiveCategory(_GoalCategory category) async {
    // Warn how many goals still reference this category before archiving. Soft
    // archive: linked goals keep their category_id and stay in the history — the
    // category is only hidden from the picker for NEW goals (mirrors mobile).
    final linkedCount = ref
        .read(dashboardControllerProvider)
        .goals
        .where((g) => g.categoryId != null && g.categoryId == category.id)
        .length;
    final message = linkedCount > 0
        ? t.macroGoals.categoryUnavailableLinked(
            label: category.label,
            count: linkedCount,
          )
        : t.macroGoals.categoryUnavailableArchived(label: category.label);
    final confirmed = await showEvolveDialog<bool>(
      context: context,
      builder: (ctx) => EvolveAlertDialog(
        icon: LucideIcons.archive,
        title: Text(t.macroGoals.archiveCategory2),
        subtitle: message,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.actions.cancel),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.macroGoals.archive),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _categories.remove(category);
      if (category.id != null) _archivedCategoryIds.add(category.id!);
    });
    final id = category.id;
    if (id == null) return;
    try {
      await ref
          .read(desktopGoalCategoriesControllerProvider.notifier)
          .archiveCategory(id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _archivedCategoryIds.remove(id));
      showEvolveToast(
        context,
        message: t.goalsPage.categoryArchiveFailed,
        kind: EvolveToastKind.error,
      );
    }
  }

  Future<void> _editCategory(_GoalCategory category) async {
    final updated = await showEvolveDialog<_GoalCategory>(
      context: context,
      builder: (context) => _CategoryEditorDialog(category: category),
    );
    if (updated == null) return;

    final id = category.id;
    if (id != null) {
      try {
        await ref
            .read(desktopGoalCategoriesControllerProvider.notifier)
            .updateCategory(id, updated.label, updated.color);
      } catch (_) {
        if (!mounted) return;
        showEvolveToast(
          context,
          message: t.goalsPage.categoryEditFailed,
          kind: EvolveToastKind.error,
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      final index = _categories.indexOf(category);
      if (index != -1) {
        _categories[index] = updated.copyWith(id: id);
      }
    });
  }

  /// Creates a category inline from the add-goal picker and auto-selects it for
  /// the goal being drafted (mirrors mobile's category_picker_sheet).
  Future<void> _createCategoryInline() async {
    final draft = await showEvolveDialog<_GoalCategory>(
      context: context,
      builder: (context) => const _CategoryEditorDialog(),
    );
    if (draft == null || !mounted) return;
    DesktopGoalCategory? cloud;
    try {
      cloud = await ref
          .read(desktopGoalCategoriesControllerProvider.notifier)
          .addCategory(draft.label, draft.color);
    } catch (_) {
      if (!mounted) return;
      showEvolveToast(
        context,
        message: t.goalsPage.categoryCreateFailed,
        kind: EvolveToastKind.error,
      );
      return;
    }
    if (!mounted) return;
    if (cloud == null) {
      // The write didn't persist (e.g. a locked private DB). Mirror mobile's
      // category_picker_sheet, which only commits on a non-null result — don't
      // optimistically add a category that isn't in the database.
      showEvolveToast(
        context,
        message: t.goalsPage.categoryCreateFailed,
        kind: EvolveToastKind.error,
      );
      return;
    }
    final created =
        _GoalCategory(id: cloud.id, label: cloud.label, color: cloud.color);
    setState(() {
      _categories.add(created);
      _quickGoalCategory = created; // auto-select the new category
    });
  }

  // Goals segment of the continuous tour, trimmed to five steps: an
  // orientation card, then four spotlighted targets. The shared
  // [CoachTutorialOverlay] owns scrim/spotlight/keyboard/tap-blocking.
  List<CoachStep> _goalsTourSteps() => [
    // Orientation-first: a centered card (no spotlight) announcing the page.
    CoachStep(
      title: t.tour.goalsOrientationTitle,
      description: t.tour.goalsOrientationDesc,
    ),
    CoachStep(
      targetKey: _planSelectorKey,
      title: t.tour.goalsPlanTitle,
      description: t.tour.goalsPlanDesc,
    ),
    CoachStep(
      targetKey: _addGoalKey,
      title: t.tour.goalsAddTitle,
      description: t.tour.goalsAddDesc,
    ),
    CoachStep(
      targetKey: _tutorialCheckboxKey,
      title: t.tour.goalsCheckTitle,
      description: t.tour.goalsCheckDesc,
    ),
    CoachStep(
      targetKey: _performanceToggleKey,
      title: t.tour.goalsStatsTitle,
      description: t.tour.goalsStatsDesc,
    ),
  ];
}

class _GoalToolbar extends StatelessWidget {
  const _GoalToolbar({
    this.statsToggleKey,
    required this.selectedType,
    required this.showStats,
    required this.onTypeChanged,
    required this.onShowStats,
  });

  final GlobalKey? statsToggleKey;
  final GoalType selectedType;
  final bool showStats;
  final ValueChanged<GoalType> onTypeChanged;
  final VoidCallback onShowStats;

  @override
  Widget build(BuildContext context) {
    // A `null` segment key stands for the Stats tab so the whole toolbar stays
    // a single signature white-pill segmented control, matching mobile. The
    // control spans the full content width so the six segments share the
    // fluid page width equally.
    return Container(
      key: statsToggleKey,
      child: EvolveSegmentedControl<GoalType?>(
        height: 44,
        segments: {
          GoalType.lifetime: t.macroGoals.types.lifetime,
          GoalType.annual: t.macroGoals.types.annual,
          GoalType.quarterly: t.macroGoals.types.quarterly,
          GoalType.monthly: t.macroGoals.types.monthly,
          GoalType.weekly: t.macroGoals.types.weekly,
          null: t.goalsPage.statsTab,
        },
        selected: showStats ? null : selectedType,
        onSelected: (type) {
          if (type == null) {
            onShowStats();
          } else {
            onTypeChanged(type);
          }
        },
      ),
    );
  }
}

/// Consolidated toolbar row: period selectors + prev/next + category manager
/// on the left and the quick-add composer expanding on the right. On narrow
/// windows the two clusters stack on two lines inside the same panel so the
/// bar keeps fitting the 960px minimum window without overflowing.
class _GoalCommandBar extends StatelessWidget {
  const _GoalCommandBar({
    this.periodClusterKey,
    this.addGoalKey,
    required this.onMenuOpenChanged,
    required this.selectedType,
    required this.selectedYear,
    required this.selectedQuarter,
    required this.selectedMonth,
    required this.selectedWeek,
    required this.onYearChanged,
    required this.onQuarterChanged,
    required this.onMonthChanged,
    required this.onWeekChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onManageCategories,
    required this.showQuickAdd,
    required this.quickGoalController,
    this.quickGoalCategory,
    required this.categories,
    required this.onQuickCategoryChanged,
    required this.onCreateCategory,
    required this.onQuickSubmit,
    required this.quickGoalHint,
  });

  final GlobalKey? periodClusterKey;
  final GlobalKey? addGoalKey;

  /// Reports each period-picker / category-menu open (true) and close (false)
  /// so the page can suspend arrow-key period paging while one is up.
  final ValueChanged<bool> onMenuOpenChanged;
  final GoalType selectedType;
  final int selectedYear;
  final int selectedQuarter;
  final int selectedMonth;
  final int selectedWeek;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onQuarterChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onWeekChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onManageCategories;
  final bool showQuickAdd;
  final TextEditingController quickGoalController;
  final _GoalCategory? quickGoalCategory;
  final List<_GoalCategory> categories;
  final ValueChanged<_GoalCategory?> onQuickCategoryChanged;
  final VoidCallback onCreateCategory;
  final VoidCallback onQuickSubmit;
  final String quickGoalHint;

  List<Widget> _periodSelectors(BuildContext context) {
    if (selectedType == GoalType.lifetime) {
      return [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EvolveIconChip(
                icon: LucideIcons.infinity,
                color: context.evolveAccent,
                size: 30,
                iconSize: 15,
              ),
              const SizedBox(width: 10),
              Text(
                t.goalsPage.fullView,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ];
    }
    return [
      _PeriodDropdown(
        value: selectedYear,
        // Always include the current selection so paging past the ±10 window
        // (e.g. holding → on the Annual plan) never renders a blank year pill.
        values: _yearOptions(selectedYear),
        labelFor: (value) => '$value',
        onChanged: onYearChanged,
        onOpen: () => onMenuOpenChanged(true),
        onClose: () => onMenuOpenChanged(false),
      ),
      if (selectedType == GoalType.quarterly)
        _PeriodDropdown(
          value: selectedQuarter,
          values: const [1, 2, 3, 4],
          labelFor: (value) => 'Q$value',
          onChanged: onQuarterChanged,
          onOpen: () => onMenuOpenChanged(true),
          onClose: () => onMenuOpenChanged(false),
        ),
      if (selectedType == GoalType.monthly || selectedType == GoalType.weekly)
        _PeriodDropdown(
          value: selectedMonth,
          values: [for (var month = 1; month <= 12; month++) month],
          labelFor: (value) => t.common.months[value - 1],
          onChanged: onMonthChanged,
          onOpen: () => onMenuOpenChanged(true),
          onClose: () => onMenuOpenChanged(false),
        ),
      if (selectedType == GoalType.weekly)
        _PeriodDropdown(
          value: selectedWeek,
          values: [
            for (
              var week = 1;
              week <= logicalWeeksInMonth(selectedYear, selectedMonth);
              week++
            )
              week,
          ],
          labelFor: (value) => '${t.common.calendarView.week} $value',
          onChanged: onWeekChanged,
          onOpen: () => onMenuOpenChanged(true),
          onClose: () => onMenuOpenChanged(false),
        ),
    ];
  }

  /// The ±10-year window around today, guaranteed to contain [selected] so the
  /// year selector always has a matching option to render.
  List<int> _yearOptions(int selected) {
    final base = DateTime.now().year;
    final years = <int>{
      for (var year = base - 10; year <= base + 10; year++) year,
      selected,
    }.toList()..sort();
    return years;
  }

  List<Widget> _navButtons(BuildContext context) {
    return [
      if (selectedType != GoalType.lifetime) ...[
        EvolveSquareIconButton(
          tooltip: t.habitsPage.prevPeriod,
          icon: directionalIcon(
            context,
            LucideIcons.chevronLeft,
            LucideIcons.chevronRight,
          ),
          onTap: onPrevious,
        ),
        const SizedBox(width: 8),
        EvolveSquareIconButton(
          tooltip: t.habitsPage.nextPeriod,
          icon: directionalIcon(
            context,
            LucideIcons.chevronRight,
            LucideIcons.chevronLeft,
          ),
          onTap: onNext,
        ),
        const SizedBox(width: 12),
      ],
      EvolveSquareIconButton(
        tooltip: t.goalsPage.categoriesTooltip,
        icon: LucideIcons.slidersHorizontal,
        onTap: onManageCategories,
      ),
    ];
  }

  /// Full-width line: selectors flow (and wrap if ever needed) on the leading
  /// side while the nav cluster stays pinned to the trailing edge.
  Widget _periodLine(BuildContext context) {
    return Container(
      key: periodClusterKey,
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: _periodSelectors(context),
            ),
          ),
          const SizedBox(width: 12),
          ..._navButtons(context),
        ],
      ),
    );
  }

  /// Intrinsic-width cluster used when the quick-add composer shares the row.
  Widget _periodCluster(BuildContext context) {
    return Container(
      key: periodClusterKey,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _periodSelectors(context),
          ),
          const SizedBox(width: 12),
          ..._navButtons(context),
        ],
      ),
    );
  }

  Widget _quickBar() {
    return _QuickGoalBar(
      key: addGoalKey,
      controller: quickGoalController,
      selectedCategory: quickGoalCategory,
      categories: categories,
      onCategoryChanged: onQuickCategoryChanged,
      onCreateCategory: onCreateCategory,
      onSubmit: onQuickSubmit,
      hintText: quickGoalHint,
      onMenuOpenChanged: onMenuOpenChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: !showQuickAdd
          ? _periodLine(context)
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1000) {
                  return Row(
                    children: [
                      _periodCluster(context),
                      const SizedBox(width: 14),
                      Expanded(child: _quickBar()),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _periodLine(context),
                    const SizedBox(height: 10),
                    _quickBar(),
                  ],
                );
              },
            ),
    );
  }
}

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown({
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
    this.onOpen,
    this.onClose,
  });

  final int value;
  final List<int> values;
  final String Function(int value) labelFor;
  final ValueChanged<int> onChanged;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return EvolveSelect<int>(
      value: value,
      height: 44,
      textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      options: [
        for (final item in values)
          EvolveSelectOption(value: item, label: labelFor(item)),
      ],
      onChanged: onChanged,
      onOpen: onOpen,
      onClose: onClose,
    );
  }
}

class _GoalBoard extends StatelessWidget {
  const _GoalBoard({
    required this.periodTitle,
    required this.periodSubtitle,
    this.tutorialCheckboxKey,
    this.highlightGoalId,
    this.highlightRowKey,
    required this.categories,
    required this.activeGoals,
    required this.completedGoals,
    required this.failedGoals,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
  });

  final String periodTitle;
  final String periodSubtitle;
  final GlobalKey? tutorialCheckboxKey;

  /// Id of the goal to spotlight (glow + scroll-into-view) after a ⌘K jump, or
  /// null for an ordinary open. [highlightRowKey] is attached to that one row so
  /// the page can scroll it into view.
  final String? highlightGoalId;
  final GlobalKey? highlightRowKey;
  final List<_GoalCategory> categories;
  final List<DashboardGoal> activeGoals;
  final List<DashboardGoal> completedGoals;
  final List<DashboardGoal> failedGoals;
  final void Function(DashboardGoal, GoalState) onToggleStatus;
  final ValueChanged<DashboardGoal> onEdit;
  final ValueChanged<DashboardGoal> onReschedule;
  final ValueChanged<DashboardGoal> onDelete;

  /// Active goal item. The tutorial checkbox GlobalKey attaches to the FIRST
  /// active item only so the spotlight has a single stable target (and the tree
  /// never holds duplicate GlobalKeys when several goals are visible).
  Widget _activeItem(DashboardGoal goal, {required bool isFirst}) {
    return _GoalItem(
      key: ValueKey(goal.id),
      goal: goal,
      highlight: goal.id == highlightGoalId,
      checkboxKey: isFirst ? tutorialCheckboxKey : null,
      categories: categories,
      onToggleStatus: onToggleStatus,
      onEdit: onEdit,
      onReschedule: onReschedule,
      onDelete: onDelete,
    );
  }

  /// Single-column flavor of [_activeItem] with the list row spacing. The
  /// spotlighted row carries [highlightRowKey] (on the outer Padding) so the
  /// page can scroll it into view after a ⌘K jump.
  Widget _activeListItem(DashboardGoal goal, {required bool isFirst}) {
    return Padding(
      key: goal.id == highlightGoalId ? highlightRowKey : null,
      padding: const EdgeInsets.only(bottom: 10),
      child: _activeItem(goal, isFirst: isFirst),
    );
  }

  Widget _archivedItem(DashboardGoal goal) {
    return Padding(
      key: goal.id == highlightGoalId ? highlightRowKey : null,
      padding: const EdgeInsets.only(bottom: 10),
      child: _GoalItem(
        key: ValueKey(goal.id),
        goal: goal,
        highlight: goal.id == highlightGoalId,
        categories: categories,
        onToggleStatus: onToggleStatus,
        onEdit: onEdit,
        onReschedule: onReschedule,
        onDelete: onDelete,
      ),
    );
  }

  Widget _periodHeading(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          periodTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 3),
        Text(
          periodSubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.evolveColors.muted.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  /// Header band pinned to the top of the box: completion ring on the leading
  /// edge, the period heading in the middle, and the per-status counts as a
  /// single inline strip on the trailing edge. This replaces the old right-rail
  /// summary now that completed and failed goals live at the bottom of this
  /// same box.
  Widget _boardHeader(BuildContext context) {
    final total =
        activeGoals.length + completedGoals.length + failedGoals.length;
    final completion = total == 0 ? 0.0 : completedGoals.length / total;
    return Row(
      children: [
        _PeriodProgressRing(value: completion),
        const SizedBox(width: 16),
        Expanded(child: _periodHeading(context)),
        const SizedBox(width: 16),
        // Counts on one line: COMPLETED n | FAILED n | ACTIVE n, each label in
        // its status color (tying to the green check / red X on the rows below)
        // with a hairline pipe between them.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _countItem(
              context,
              label: t.macroGoals.completed,
              color: EvolveColors.success,
              count: completedGoals.length,
            ),
            _countDivider(context),
            _countItem(
              context,
              label: t.macroGoals.failed,
              color: EvolveColors.destructive,
              count: failedGoals.length,
            ),
            _countDivider(context),
            _countItem(
              context,
              label: t.goalsStats.active,
              color: context.evolveAccent,
              count: activeGoals.length,
            ),
          ],
        ),
      ],
    );
  }

  /// One `LABEL n` unit of the header count strip: colored micro-label + bold
  /// count.
  Widget _countItem(
    BuildContext context, {
    required String label,
    required Color color,
    required int count,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: TextStyle(
            color: context.evolveColors.foreground,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /// Hairline pipe separating two count units.
  Widget _countDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: 1,
        height: 12,
        color: context.evolveColors.border,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyGoal =
        activeGoals.isNotEmpty ||
        completedGoals.isNotEmpty ||
        failedGoals.isNotEmpty;

    // One linear column at every width: the completion ring + heading + counts
    // ride a header band at the top of the box, active goals flow beneath it,
    // and completed/failed goals settle at the bottom under their own labeled
    // dividers (LAYOUT_SPEC status-divider recipe) so each row's check/X reads
    // inline. The old wide-only card grid and right rail are gone.
    return EvolvePanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _boardHeader(context),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: context.evolveColors.border.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          if (activeGoals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalEmptyState(hasAnyGoal: hasAnyGoal),
            )
          else
            for (var i = 0; i < activeGoals.length; i++)
              _activeListItem(activeGoals[i], isFirst: i == 0),
          if (completedGoals.isNotEmpty) ...[
            const SizedBox(height: 22),
            _StatusDivider(
              label: t.macroGoals.completed,
              color: EvolveColors.success,
            ),
            const SizedBox(height: 12),
            for (final goal in completedGoals) _archivedItem(goal),
          ],
          if (failedGoals.isNotEmpty) ...[
            const SizedBox(height: 22),
            _StatusDivider(
              label: t.macroGoals.failed,
              color: EvolveColors.destructive,
            ),
            const SizedBox(height: 12),
            for (final goal in failedGoals) _archivedItem(goal),
          ],
        ],
      ),
    );
  }
}

/// Page-private copy of the dashboard progress ring (shared widgets are frozen
/// for this pass).
class _PeriodProgressRing extends StatelessWidget {
  const _PeriodProgressRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: CustomPaint(
        painter: _PeriodRingPainter(
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

class _PeriodRingPainter extends CustomPainter {
  const _PeriodRingPainter(
    this.value, {
    required this.accent,
    required this.track,
  });

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
  bool shouldRepaint(covariant _PeriodRingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.accent != accent ||
      oldDelegate.track != track;
}

class _QuickGoalBar extends StatelessWidget {
  const _QuickGoalBar({
    super.key,
    required this.controller,
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
    required this.onCreateCategory,
    required this.onSubmit,
    required this.hintText,
    required this.onMenuOpenChanged,
  });

  final TextEditingController controller;
  final _GoalCategory? selectedCategory;
  final List<_GoalCategory> categories;
  final String hintText;
  final ValueChanged<_GoalCategory?> onCategoryChanged;
  final VoidCallback onCreateCategory;
  final VoidCallback onSubmit;
  final ValueChanged<bool> onMenuOpenChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            // Center the (collapsed) field's glyph line in the pill ourselves.
            // A tight 44px external height makes the InputDecorator ignore
            // textAlignVertical and pin the text to the top, so we let the
            // Container do the centering — which can't drift with font metrics.
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.evolveColors.panel.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.evolveColors.border),
            ),
            // isCollapsed shrinks the field to exactly its text line so the
            // Alignment.center above centers the glyphs, not a padded decorator
            // box; SizedBox keeps it full-width (Container.alignment would
            // otherwise shrink-wrap it and break the left-aligned caret).
            child: SizedBox(
              width: double.infinity,
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSubmit(),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: context.evolveColors.muted.withValues(alpha: 0.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _QuickCategoryButton(
          selectedCategory: selectedCategory,
          categories: categories,
          onCategoryChanged: onCategoryChanged,
          onCreateCategory: onCreateCategory,
          onMenuOpenChanged: onMenuOpenChanged,
        ),
        const SizedBox(width: 8),
        Material(
          color: context.evolveAccent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onSubmit,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                LucideIcons.plus,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickCategoryButton extends StatelessWidget {
  const _QuickCategoryButton({
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
    required this.onCreateCategory,
    required this.onMenuOpenChanged,
  });

  final _GoalCategory? selectedCategory;
  final List<_GoalCategory> categories;
  final ValueChanged<_GoalCategory?> onCategoryChanged;
  final VoidCallback onCreateCategory;
  final ValueChanged<bool> onMenuOpenChanged;

  @override
  Widget build(BuildContext context) {
    final color = selectedCategory?.color;
    return EvolveMenu(
      tooltip: t.form.category,
      onOpen: () => onMenuOpenChanged(true),
      onClose: () => onMenuOpenChanged(false),
      children: [
        EvolveMenuItem(
          label: t.goalsPage.defaultCategory,
          selected: selectedCategory == null,
          onTap: () => onCategoryChanged(null),
        ),
        for (final item in categories)
          EvolveMenuItem(
            label: _categoryLabel(item),
            leading: CircleAvatar(radius: 5, backgroundColor: item.color),
            selected: selectedCategory == item,
            onTap: () => onCategoryChanged(item),
          ),
        const EvolveMenuDivider(),
        EvolveMenuItem(
          // Not a category value — creates inline (fires after close), which
          // opens the editor and auto-selects the new category.
          label: t.macroGoals.createNewCategory,
          accent: true,
          leading: Icon(
            LucideIcons.plus,
            size: 16,
            color: context.evolveAccent,
          ),
          onTap: onCreateCategory,
        ),
      ],
      triggerBuilder: (context, controller) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.evolveColors.panel.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.evolveColors.border),
            ),
            child: Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color?.withValues(alpha: 0.7) ?? Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        color?.withValues(alpha: 0.9) ??
                        context.evolveColors.borderStrong,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified empty-state recipe (LAYOUT_SPEC): centered icon chip + title. The
/// page has a single localized string per case, so it is used as the title
/// and no CTA is shown (the quick-add composer already sits in the command
/// bar above).
class _GoalEmptyState extends StatelessWidget {
  const _GoalEmptyState({required this.hasAnyGoal});

  final bool hasAnyGoal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
      decoration: BoxDecoration(
        color: context.evolveColors.panel.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.evolveColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EvolveIconChip(
            icon: hasAnyGoal ? LucideIcons.circleCheck : LucideIcons.flag,
            color: context.evolveColors.muted,
            size: 44,
            iconSize: 20,
          ),
          const SizedBox(height: 12),
          Text(
            hasAnyGoal ? t.goalsPage.emptyActive : t.goalsPage.emptyAdd,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: context.evolveColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalItem extends StatefulWidget {
  const _GoalItem({
    super.key,
    required this.goal,
    this.highlight = false,
    this.checkboxKey,
    required this.categories,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
  });

  final DashboardGoal goal;

  /// When true this row was just navigated to via ⌘K — pulse a fading accent
  /// ring so the eye lands on it.
  final bool highlight;
  final GlobalKey? checkboxKey;
  final List<_GoalCategory> categories;
  final void Function(DashboardGoal, GoalState) onToggleStatus;
  final ValueChanged<DashboardGoal> onEdit;
  final ValueChanged<DashboardGoal> onReschedule;
  final ValueChanged<DashboardGoal> onDelete;

  @override
  State<_GoalItem> createState() => _GoalItemState();
}

class _GoalItemState extends State<_GoalItem> {
  GoalState? _visualStatusOverride;
  Timer? _debounceTimer;
  bool _hovered = false;

  @override
  void dispose() {
    // If a status toggle is still mid-debounce when this row is torn down —
    // e.g. the board re-keys because the user navigated the period within the
    // 2s window — persist it instead of dropping it on the floor. Deferred to
    // after the frame so we never mutate a provider during the unmount that is
    // disposing us.
    final pending = _visualStatusOverride;
    if ((_debounceTimer?.isActive ?? false) && pending != null) {
      final goal = widget.goal;
      final onToggleStatus = widget.onToggleStatus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Best-effort: if the whole page (not just this row) was torn down, the
        // callback's ref is already dead — there's nothing left to persist to.
        try {
          onToggleStatus(goal, pending);
        } catch (_) {}
      });
    }
    _debounceTimer?.cancel();
    super.dispose();
  }

  GoalState get _nextStatus {
    final currentStatus = _visualStatusOverride ?? widget.goal.state;
    switch (currentStatus) {
      case GoalState.active:
        return GoalState.completed;
      case GoalState.completed:
        return GoalState.failed;
      case GoalState.failed:
        return GoalState.active;
    }
  }

  void _cycleStatus() {
    setState(() {
      _visualStatusOverride = _nextStatus;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final finalState = _visualStatusOverride;
      if (finalState != null) {
        widget.onToggleStatus(widget.goal, finalState);
      }
      setState(() {
        _visualStatusOverride = null;
      });
    });
  }

  TextStyle _titleStyle(
    BuildContext context, {
    required bool completed,
    required bool failed,
    required Color statusColor,
  }) {
    return TextStyle(
      fontSize: 15,
      fontWeight: completed || failed ? FontWeight.w500 : FontWeight.w700,
      letterSpacing: -0.2,
      color: completed
          ? EvolveColors.success.withValues(alpha: 0.72)
          : failed
          ? EvolveColors.destructive.withValues(alpha: 0.7)
          : context.evolveColors.foreground,
      decoration: completed || failed
          ? TextDecoration.lineThrough
          : TextDecoration.none,
      decorationColor: statusColor.withValues(alpha: 0.55),
      decorationThickness: 1.5,
    );
  }

  /// Desktop affordance: the item actions stay tappable at all times but sit
  /// dimmed until the pointer hovers the item.
  Widget _hoverActions(BuildContext context) {
    final goal = widget.goal;
    return AnimatedOpacity(
      opacity: _hovered ? 1 : 0.35,
      duration: const Duration(milliseconds: 120),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (goal.type != GoalType.lifetime)
            IconButton(
              tooltip: t.goalsPage.rescheduleTooltip,
              onPressed: () => widget.onReschedule(goal),
              icon: const Icon(LucideIcons.calendarClock, size: 16),
              style: IconButton.styleFrom(
                foregroundColor: context.evolveColors.muted,
              ),
            ),
          IconButton(
            tooltip: t.common.actions.edit,
            onPressed: () => widget.onEdit(goal),
            icon: const Icon(LucideIcons.pencil, size: 16),
            style: IconButton.styleFrom(
              foregroundColor: context.evolveColors.muted,
            ),
          ),
          IconButton(
            tooltip: t.common.actions.delete,
            onPressed: () => widget.onDelete(goal),
            icon: const Icon(LucideIcons.trash2, size: 16),
            style: IconButton.styleFrom(
              foregroundColor: EvolveColors.destructive.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _checkButton(GoalState currentState) {
    return Container(
      key: widget.checkboxKey,
      child: _GoalCheckButton(state: currentState, onPressed: _cycleStatus),
    );
  }

  /// Compact single-line layout (narrow flow + archive rail).
  Widget _rowLayout(
    BuildContext context, {
    required _GoalCategory category,
    required GoalState currentState,
    required bool completed,
    required bool failed,
    required Color statusColor,
  }) {
    return Row(
      children: [
        _checkButton(currentState),
        const SizedBox(width: 14),
        if (!completed && !failed) ...[
          EvolveIconChip(
            icon: LucideIcons.target,
            color: category.color,
            size: 30,
            iconSize: 15,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            widget.goal.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _titleStyle(
              context,
              completed: completed,
              failed: failed,
              statusColor: statusColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _hoverActions(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final category = _categoryForGoal(goal, widget.categories);
    final currentState = _visualStatusOverride ?? goal.state;
    final completed = currentState == GoalState.completed;
    final failed = currentState == GoalState.failed;
    final statusColor = completed
        ? EvolveColors.success
        : failed
        ? EvolveColors.destructive
        : category.color;

    final row = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: statusColor.withValues(
            alpha: completed
                ? 0.05
                : failed
                ? 0.06
                : 0.08,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(
              alpha: completed
                  ? 0.15
                  : failed
                  ? 0.2
                  : 0.3,
            ),
          ),
        ),
        child: _rowLayout(
          context,
          category: category,
          currentState: currentState,
          completed: completed,
          failed: failed,
          statusColor: statusColor,
        ),
      ),
    );
    if (!widget.highlight) return row;
    // Freshly navigated-to via ⌘K: pulse a one-shot accent ring + glow that
    // fades over ~1.3s, drawing the eye to the goal the user searched for. The
    // foreground border paints over the row edge (no layout shift); the shadow
    // sits behind. TweenAnimationBuilder plays once when the row first mounts.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1, end: 0),
      duration: const Duration(milliseconds: 1300),
      curve: Curves.easeOutCubic,
      builder: (context, glow, child) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.evolveAccent.withValues(alpha: 0.9 * glow),
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: context.evolveAccent.withValues(alpha: 0.5 * glow),
                blurRadius: 24 * glow,
                spreadRadius: 2 * glow,
              ),
            ],
          ),
          child: child,
        ),
      ),
      child: row,
    );
  }
}

class _GoalCheckButton extends StatelessWidget {
  const _GoalCheckButton({required this.state, required this.onPressed});

  final GoalState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final completed = state == GoalState.completed;
    final failed = state == GoalState.failed;
    final color = completed
        ? EvolveColors.success
        : failed
        ? EvolveColors.destructive
        : context.evolveColors.borderStrong;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: completed || failed ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color, width: 1.5),
        ),
        child: completed
            ? Icon(
                LucideIcons.check,
                size: 13,
                color: context.evolveColors.background,
              )
            : failed
            ? const Icon(LucideIcons.x, size: 13, color: Colors.white)
            : null,
      ),
    );
  }
}

class _StatusDivider extends StatelessWidget {
  const _StatusDivider({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.2)),
        ),
      ],
    );
  }
}

class _GoalEditorDialog extends StatefulWidget {
  const _GoalEditorDialog({
    required this.categories,
    this.goal,
    this.initialCategory,
  });

  final List<_GoalCategory> categories;
  final DashboardGoal? goal;
  final _GoalCategory? initialCategory;

  @override
  State<_GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends State<_GoalEditorDialog> {
  final _title = TextEditingController();
  late final List<_GoalCategory> _options;
  late _GoalCategory _category;

  @override
  void initState() {
    super.initState();
    _title.text = widget.goal?.title ?? '';
    // The goal's resolved category may not be part of the picker list: it can be
    // a fallback derived from the goal itself when its own category was archived
    // or removed, and the list can even be empty (categories start empty and are
    // populated only from the user's own saved ones). Guarantee it's always an
    // option so editing never crashes on `first` and the goal keeps its real
    // category selected.
    final initial = widget.initialCategory;
    final options = [...widget.categories];
    if (initial != null && !options.contains(initial)) {
      options.insert(0, initial);
    }
    _options = options;
    _category = initial ?? _options.first;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      icon: LucideIcons.flag,
      title: Text(
        widget.goal == null ? t.goalsPage.newGoal : t.goalsPage.editGoal,
      ),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: InputDecoration(labelText: t.form.title),
            ),
            const SizedBox(height: 14),
            EvolveSelect<_GoalCategory>(
              value: _category,
              label: t.form.category,
              expand: true,
              height: 46,
              fillColor: context.evolveColors.background.withValues(alpha: 0.5),
              options: [
                for (final category in _options)
                  EvolveSelectOption(
                    value: category,
                    label: _categoryLabel(category),
                    leading: CircleAvatar(
                      radius: 4,
                      backgroundColor: category.color,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.common.actions.cancel),
        ),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(
              context,
              _GoalDraft(title: title, category: _category),
            );
          },
          child: Text(
            widget.goal == null ? t.macroGoals.create : t.common.actions.save,
          ),
        ),
      ],
    );
  }
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({this.category});

  final _GoalCategory? category;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _name;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.label ?? '');
    _color = widget.category?.color ?? EvolveColors.cyan;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      icon: LucideIcons.palette,
      title: Text(
        widget.category == null
            ? t.goalsPage.newCategory
            : t.goalsPage.editCategory,
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: t.goalsPage.nameLabel),
            ),
            const SizedBox(height: 14),
            ColorPickerButton(
              size: 24,
              color: _color,
              onColorChanged: (color) => setState(() => _color = color),
              presetColors: _goalColors,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.common.actions.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _GoalCategory(label: _name.text.trim(), color: _color),
            );
          },
          child: Text(
            widget.category == null ? t.form.add : t.common.actions.save,
          ),
        ),
      ],
    );
  }
}

class _GoalDraft {
  const _GoalDraft({required this.title, required this.category});

  final String title;
  final _GoalCategory category;
}

class _GoalCategory {
  const _GoalCategory({
    this.id,
    this.key,
    required this.label,
    required this.color,
    this.isDefault = false,
  });

  final String? id;
  final String? key;
  final String label;
  final Color color;
  final bool isDefault;

  _GoalCategory copyWith({
    String? id,
    String? key,
    String? label,
    Color? color,
  }) {
    return _GoalCategory(
      id: id ?? this.id,
      key: key ?? this.key,
      label: label ?? this.label,
      color: color ?? this.color,
      isDefault: isDefault,
    );
  }
}

// Default category identifiers stay stable (Italian `key`) so they keep
// matching stored data and the color map; only the label is localized.
String _categoryLabel(_GoalCategory category) => switch (category.key) {
  'lavoro' => t.lavoro,
  'salute' => t.salute,
  'finanza' => t.finanza,
  'relazioni' => t.relazioni,
  'formazione' => t.formazione,
  'hobby' => t.hobby,
  'spirituale' => t.spirituale,
  'altro' => t.altro,
  _ => category.label,
};

const _goalColors = [
  EvolveColors.cyan,
  EvolveColors.primaryStrong,
  EvolveColors.violet,
  EvolveColors.amber,
  EvolveColors.rose,
];

_GoalCategory _categoryForGoal(
  DashboardGoal goal,
  List<_GoalCategory> categories,
) {
  for (final category in categories) {
    if (goal.categoryId != null && category.id == goal.categoryId) {
      return category;
    }
  }
  for (final category in categories) {
    if (category.key == goal.category) return category;
  }
  return _GoalCategory(
    key: goal.category.isEmpty ? null : goal.category,
    label: goal.category.isEmpty ? 'Default' : goal.category,
    color: goal.color,
  );
}
