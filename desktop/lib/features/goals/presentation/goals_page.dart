import 'dart:async';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/rtl.dart';
import 'package:evolve_desktop/shared/widgets/color_picker_dialog.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'goals_stats_view.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _categories = [..._defaultGoalCategories];
  final _archivedCategoryIds = <String>{};

  // Tutorial State
  bool _didFinishGoalsTutorial = false;
  int _goalsTutorialIndex = 0;
  bool _isRefreshingGoalsTutorialGeometry = false;

  // Tutorial Keys
  final _goalsTutorialOverlayKey = GlobalKey();
  final _planSelectorKey = GlobalKey();
  final _performanceToggleKey = GlobalKey();
  final _addGoalKey = GlobalKey();
  final _tutorialCheckboxKey = GlobalKey();
  final _tutorialCategoryKey = GlobalKey();
  final _tutorialRescheduleKey = GlobalKey();
  final _tutorialEditKey = GlobalKey();
  final _tutorialDeleteKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedType = GoalType.weekly;
    _selectedYear = now.year;
    _selectedQuarter = ((now.month - 1) ~/ 3) + 1;
    _selectedMonth = now.month;
    _selectedWeek = logicalWeekOfMonth(now);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTutorial();
    });
  }

  void _checkTutorial() {
    if (!mounted || _didFinishGoalsTutorial) return;
    final hasSeenTutorial = ref.read(goalsTutorialProvider);
    if (!hasSeenTutorial) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _quickGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(desktopGoalCategoriesControllerProvider);
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

    final hasSeenTutorial = ref.watch(goalsTutorialProvider);
    final showTutorial = !hasSeenTutorial && !_didFinishGoalsTutorial;

    if (showTutorial && activeGoals.isEmpty) {
      activeGoals = [
        DashboardGoal(
          id: 'tutorial_fake_goal',
          title: t.goalsPage.sampleGoal,
          category: 'Tutorial',
          color: Colors.blueAccent,
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

    return DesktopPage(
      title: t.goalsPage.title,
      subtitle: t.goalsPage.subtitle,
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.evolveColors.panel.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.evolveColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GoalToolbar(
                    statsToggleKey: _performanceToggleKey,
                    selectedType: _selectedType,
                    showStats: _showStats,
                    onTypeChanged: (type) => setState(() {
                      _selectedType = type;
                      _showStats = false;
                    }),
                    onShowStats: () => setState(() => _showStats = true),
                  ),
                  const SizedBox(height: 30),
                  _GoalPeriodBar(
                    key: _planSelectorKey,
                    selectedType: _selectedType,
                    selectedYear: _selectedYear,
                    selectedQuarter: _selectedQuarter,
                    selectedMonth: _selectedMonth,
                    selectedWeek: _selectedWeek,
                    onYearChanged: (year) => setState(() {
                      _selectedYear = year;
                      _selectedWeek = _selectedWeek.clamp(
                        1,
                        logicalWeeksInMonth(_selectedYear, _selectedMonth),
                      );
                    }),
                    onQuarterChanged: (quarter) =>
                        setState(() => _selectedQuarter = quarter),
                    onMonthChanged: (month) => setState(() {
                      _selectedMonth = month;
                      _selectedWeek = 1;
                    }),
                    onWeekChanged: (week) =>
                        setState(() => _selectedWeek = week),
                    onPrevious: () => _movePeriod(-1),
                    onNext: () => _movePeriod(1),
                    onManageCategories: _openCategoryManager,
                  ),
                  const SizedBox(height: 30),
                  if (_showStats)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: GoalsStatsView(),
                    )
                  else
                    _GoalBoard(
                      periodTitle: _periodTitle,
                      periodSubtitle: _periodSubtitle,
                      quickGoalController: _quickGoalController,
                      quickGoalCategory: _quickGoalCategory,
                      addGoalKey: _addGoalKey,
                      tutorialCheckboxKey: _tutorialCheckboxKey,
                      tutorialCategoryKey: _tutorialCategoryKey,
                      tutorialRescheduleKey: _tutorialRescheduleKey,
                      tutorialEditKey: _tutorialEditKey,
                      tutorialDeleteKey: _tutorialDeleteKey,
                      categories: _availableCategories,
                      activeGoals: activeGoals,
                      completedGoals: completedGoals,
                      failedGoals: failedGoals,
                      onQuickCategoryChanged: (category) =>
                          setState(() => _quickGoalCategory = category),
                      onCreateCategory: _createCategoryInline,
                      onQuickSubmit: _submitQuickGoal,
                      onToggleStatus: _cycleGoalStatus,
                      onEdit: _openGoalEditorFor,
                      onReschedule: (goal) => ref
                          .read(dashboardControllerProvider.notifier)
                          .rescheduleGoal(goal.id),
                      onDelete: (goal) => ref
                          .read(dashboardControllerProvider.notifier)
                          .deleteGoal(goal.id),
                      quickGoalHint: _quickGoalHint,
                    ),
                ],
              ),
            ),
          ),
          if (showTutorial) _buildGoalsTutorialOverlay(),
        ],
      ),
    );
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
            icon: Icons.category_outlined,
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
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: t.goalsPage.archiveCategory,
                                  onPressed: () async {
                                    await _archiveCategory(category);
                                    setDialogState(() {});
                                  },
                                  icon: const Icon(Icons.archive_outlined),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.goalsPage.categoryCreateFailed)),
                    );
                    return;
                  }
                  setState(() {
                    _categories.add(
                      cloudCategory == null
                          ? category
                          : _GoalCategory(
                              id: cloudCategory.id,
                              label: cloudCategory.label,
                              color: cloudCategory.color,
                            ),
                    );
                  });
                  setDialogState(() {});
                },
                icon: const Icon(Icons.add_rounded),
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
        icon: Icons.archive_outlined,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.goalsPage.categoryArchiveFailed)),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.goalsPage.categoryEditFailed)));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.goalsPage.categoryCreateFailed)));
      return;
    }
    if (!mounted) return;
    final created = cloud == null
        ? draft
        : _GoalCategory(id: cloud.id, label: cloud.label, color: cloud.color);
    setState(() {
      _categories.add(created);
      _quickGoalCategory = created; // auto-select the new category
    });
  }

  // --- Tutorial Methods ---

  Rect? _targetRectForKey(GlobalKey? targetKey) {
    final overlayContext = _goalsTutorialOverlayKey.currentContext;
    final targetContext = targetKey?.currentContext;
    if (overlayContext == null || targetContext == null) return null;

    final overlayObject = overlayContext.findRenderObject();
    final targetObject = targetContext.findRenderObject();
    if (overlayObject is! RenderBox ||
        targetObject is! RenderBox ||
        !overlayObject.attached ||
        !targetObject.attached ||
        !targetObject.hasSize) {
      return null;
    }

    final targetSize = targetObject.size;
    if (targetSize.width <= 1 || targetSize.height <= 1) return null;

    final targetOffset = targetObject.localToGlobal(
      Offset.zero,
      ancestor: overlayObject,
    );
    return targetOffset & targetSize;
  }

  void _clearGoalsTutorialState() {
    _goalsTutorialIndex = 0;
    _showStats = false;
  }

  Widget _buildGoalsTutorialOverlay() {
    final steps = _buildGoalsTutorialSteps();
    final index = _goalsTutorialIndex.clamp(0, steps.length - 1).toInt();
    final step = steps[index];
    final targetRect = _targetRectForKey(step.targetKey);

    if (step.targetKey != null && targetRect == null) {
      _scheduleGoalsTutorialGeometryRefresh();
    }

    return Positioned.fill(
      child: Material(
        key: _goalsTutorialOverlayKey,
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final overlaySize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final showCardAtTop =
                targetRect != null &&
                targetRect.center.dy > overlaySize.height * 0.52;

            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GoalsTutorialScrimPainter(targetRect),
                  ),
                ),
                if (targetRect != null)
                  Positioned.fromRect(
                    rect: targetRect.inflate(8),
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.evolveAccent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: showCardAtTop
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 40,
                    ),
                    child: _buildTutorialContent(
                      step.title,
                      step.description,
                      isFirst: index == 0,
                      isLast: index == steps.length - 1,
                      nextButtonLabel: step.nextButtonLabel,
                      onPreviousPressed: () =>
                          _goToGoalsTutorialStep(index - 1),
                      onNextPressed: () {
                        if (index == steps.length - 1) {
                          _finishGoalsTutorial();
                          return;
                        }
                        _goToGoalsTutorialStep(index + 1);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _finishGoalsTutorial() {
    if (!mounted || _didFinishGoalsTutorial) return;
    _didFinishGoalsTutorial = true;
    _clearGoalsTutorialState();
    ref.read(goalsTutorialProvider.notifier).setTutorialSeen(true);
  }

  void _goToGoalsTutorialStep(int index) {
    if (index < 0) return;
    final steps = _buildGoalsTutorialSteps();
    if (index >= steps.length) {
      _finishGoalsTutorial();
      return;
    }

    setState(() {
      _goalsTutorialIndex = index;
      _showStats = steps[index].showStats;
    });
    _scheduleGoalsTutorialGeometryRefresh();
  }

  void _scheduleGoalsTutorialGeometryRefresh() {
    if (_isRefreshingGoalsTutorialGeometry) return;
    _isRefreshingGoalsTutorialGeometry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isRefreshingGoalsTutorialGeometry = false;
      if (!mounted || _didFinishGoalsTutorial) return;
      setState(() {});
    });
  }

  Widget _buildTutorialContent(
    String title,
    String description, {
    required bool isFirst,
    required bool isLast,
    String? nextButtonLabel,
    required VoidCallback onPreviousPressed,
    required VoidCallback onNextPressed,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.evolveColors.panelRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.evolveColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.evolveColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isFirst)
                    TextButton(
                      onPressed: onPreviousPressed,
                      child: Text(t.goalsPage.back),
                    )
                  else
                    const SizedBox.shrink(),
                  FilledButton(
                    onPressed: onNextPressed,
                    child: Text(
                      nextButtonLabel ??
                          (isLast ? t.goalsPage.finish : t.goalsPage.next),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_GoalsTutorialStep> _buildGoalsTutorialSteps() {
    return [
      _GoalsTutorialStep(
        targetKey: _planSelectorKey,
        title: t.goalsPage.tutPlanningTitle,
        description: t.goalsPage.tutPlanningDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _addGoalKey,
        title: t.goalsPage.newGoal,
        description: t.goalsPage.tutNewGoalDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _tutorialCheckboxKey,
        title: t.goalsPage.tutCompleteTitle,
        description: t.goalsPage.tutCompleteDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _tutorialCategoryKey,
        title: t.form.category,
        description: t.goalsPage.tutCategoryDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _tutorialRescheduleKey,
        title: t.goalsPage.tutRescheduleTitle,
        description: t.goalsPage.tutRescheduleDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _tutorialEditKey,
        title: t.common.actions.edit,
        description: t.goalsPage.tutEditDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _tutorialDeleteKey,
        title: t.common.actions.delete,
        description: t.goalsPage.tutDeleteDesc,
      ),
      _GoalsTutorialStep(
        targetKey: _performanceToggleKey,
        showStats: true,
        title: t.goalsPage.tutStatsTitle,
        description: t.goalsPage.tutStatsDesc,
        nextButtonLabel: t.goalsPage.finish,
      ),
    ];
  }
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Container(
          height: 54,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: context.evolveColors.panelRaised.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.evolveColors.border),
          ),
          child: Row(
            children: [
              _GoalModeTab(
                label: t.macroGoals.types.lifetime,
                active: !showStats && selectedType == GoalType.lifetime,
                onTap: () => onTypeChanged(GoalType.lifetime),
              ),
              _GoalModeTab(
                label: t.macroGoals.types.annual,
                active: !showStats && selectedType == GoalType.annual,
                onTap: () => onTypeChanged(GoalType.annual),
              ),
              _GoalModeTab(
                label: t.macroGoals.types.quarterly,
                active: !showStats && selectedType == GoalType.quarterly,
                onTap: () => onTypeChanged(GoalType.quarterly),
              ),
              _GoalModeTab(
                label: t.macroGoals.types.monthly,
                active: !showStats && selectedType == GoalType.monthly,
                onTap: () => onTypeChanged(GoalType.monthly),
              ),
              _GoalModeTab(
                label: t.macroGoals.types.weekly,
                active: !showStats && selectedType == GoalType.weekly,
                onTap: () => onTypeChanged(GoalType.weekly),
              ),
              _GoalModeTab(
                key: statsToggleKey,
                label: t.goalsPage.statsTab,
                icon: Icons.pie_chart_outline_rounded,
                active: showStats,
                onTap: onShowStats,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalModeTab extends StatelessWidget {
  const _GoalModeTab({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.black.withValues(alpha: 0.72) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 17,
                  color: active ? colors.foreground : colors.muted,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? colors.foreground : colors.muted,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
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

class _GoalPeriodBar extends StatelessWidget {
  const _GoalPeriodBar({
    super.key,
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
  });

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

  @override
  Widget build(BuildContext context) {
    final showPeriod = selectedType != GoalType.lifetime;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: context.evolveColors.panelRaised.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: Row(
        children: [
          if (showPeriod) ...[
            _PeriodDropdown(
              value: selectedYear,
              values: [
                for (
                  var year = DateTime.now().year - 10;
                  year <= DateTime.now().year + 10;
                  year++
                )
                  year,
              ],
              labelFor: (value) => '$value',
              onChanged: onYearChanged,
            ),
            if (selectedType == GoalType.quarterly) ...[
              const SizedBox(width: 10),
              _PeriodDropdown(
                value: selectedQuarter,
                values: const [1, 2, 3, 4],
                labelFor: (value) => 'Q$value',
                onChanged: onQuarterChanged,
              ),
            ],
            if (selectedType == GoalType.monthly ||
                selectedType == GoalType.weekly) ...[
              const SizedBox(width: 10),
              _PeriodDropdown(
                value: selectedMonth,
                values: [for (var month = 1; month <= 12; month++) month],
                labelFor: (value) => t.common.months[value - 1],
                onChanged: onMonthChanged,
              ),
            ],
            if (selectedType == GoalType.weekly) ...[
              const SizedBox(width: 10),
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
              ),
            ],
          ] else
            Text(
              t.goalsPage.fullView,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          const Spacer(),
          if (showPeriod) ...[
            _ToolbarIconButton(
              tooltip: t.habitsPage.prevPeriod,
              icon: directionalIcon(
                context,
                Icons.keyboard_arrow_left_rounded,
                Icons.keyboard_arrow_right_rounded,
              ),
              onPressed: onPrevious,
            ),
            const SizedBox(width: 8),
            _ToolbarIconButton(
              tooltip: t.habitsPage.nextPeriod,
              icon: directionalIcon(
                context,
                Icons.keyboard_arrow_right_rounded,
                Icons.keyboard_arrow_left_rounded,
              ),
              onPressed: onNext,
            ),
            const SizedBox(width: 12),
          ],
          _ToolbarIconButton(
            tooltip: t.goalsPage.categoriesTooltip,
            icon: Icons.tune_rounded,
            onPressed: onManageCategories,
          ),
        ],
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
  });

  final int value;
  final List<int> values;
  final String Function(int value) labelFor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          items: [
            for (final item in values)
              DropdownMenuItem(value: item, child: Text(labelFor(item))),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          borderRadius: BorderRadius.circular(12),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.evolveColors.muted,
            size: 20,
          ),
          style: Theme.of(context).textTheme.titleMedium,
          dropdownColor: context.evolveColors.panelRaised,
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        foregroundColor: context.evolveColors.foreground,
        backgroundColor: Colors.black.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.evolveColors.borderStrong),
        ),
      ),
    );
  }
}

class _GoalBoard extends StatelessWidget {
  const _GoalBoard({
    required this.periodTitle,
    required this.periodSubtitle,
    required this.quickGoalController,
    this.quickGoalCategory,
    this.addGoalKey,
    this.tutorialCheckboxKey,
    this.tutorialCategoryKey,
    this.tutorialRescheduleKey,
    this.tutorialEditKey,
    this.tutorialDeleteKey,
    required this.categories,
    required this.activeGoals,
    required this.completedGoals,
    required this.failedGoals,
    required this.onQuickCategoryChanged,
    required this.onCreateCategory,
    required this.onQuickSubmit,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
    required this.quickGoalHint,
  });

  final String periodTitle;
  final String periodSubtitle;
  final String quickGoalHint;
  final TextEditingController quickGoalController;
  final _GoalCategory? quickGoalCategory;
  final GlobalKey? addGoalKey;
  final GlobalKey? tutorialCheckboxKey;
  final GlobalKey? tutorialCategoryKey;
  final GlobalKey? tutorialRescheduleKey;
  final GlobalKey? tutorialEditKey;
  final GlobalKey? tutorialDeleteKey;
  final List<_GoalCategory> categories;
  final List<DashboardGoal> activeGoals;
  final List<DashboardGoal> completedGoals;
  final List<DashboardGoal> failedGoals;
  final ValueChanged<_GoalCategory?> onQuickCategoryChanged;
  final VoidCallback onCreateCategory;
  final VoidCallback onQuickSubmit;
  final void Function(DashboardGoal, GoalState) onToggleStatus;
  final ValueChanged<DashboardGoal> onEdit;
  final ValueChanged<DashboardGoal> onReschedule;
  final ValueChanged<DashboardGoal> onDelete;

  @override
  Widget build(BuildContext context) {
    final hasAnyGoal =
        activeGoals.isNotEmpty ||
        completedGoals.isNotEmpty ||
        failedGoals.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              periodTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: context.evolveAccent,
                fontSize: 24,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  periodSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.evolveColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _QuickGoalBar(
          key: addGoalKey,
          tutorialCategoryKey: tutorialCategoryKey,
          controller: quickGoalController,
          selectedCategory: quickGoalCategory,
          categories: categories,
          onCategoryChanged: onQuickCategoryChanged,
          onCreateCategory: onCreateCategory,
          onSubmit: onQuickSubmit,
          hintText: quickGoalHint,
        ),
        const SizedBox(height: 12),
        if (activeGoals.isEmpty)
          _GoalEmptyState(hasAnyGoal: hasAnyGoal)
        else
          for (final goal in activeGoals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalItem(
                key: ValueKey(goal.id),
                goal: goal,
                checkboxKey: tutorialCheckboxKey,
                rescheduleKey: tutorialRescheduleKey,
                editKey: tutorialEditKey,
                deleteKey: tutorialDeleteKey,
                categories: categories,
                onToggleStatus: onToggleStatus,
                onEdit: onEdit,
                onReschedule: onReschedule,
                onDelete: onDelete,
              ),
            ),
        if (completedGoals.isNotEmpty) ...[
          const SizedBox(height: 22),
          _StatusDivider(
            label: t.macroGoals.completed,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          for (final goal in completedGoals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalItem(
                key: ValueKey(goal.id),
                goal: goal,
                categories: categories,
                onToggleStatus: onToggleStatus,
                onEdit: onEdit,
                onReschedule: onReschedule,
                onDelete: onDelete,
              ),
            ),
        ],
        if (failedGoals.isNotEmpty) ...[
          const SizedBox(height: 22),
          _StatusDivider(label: t.macroGoals.failed, color: EvolveColors.rose),
          const SizedBox(height: 12),
          for (final goal in failedGoals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalItem(
                key: ValueKey(goal.id),
                goal: goal,
                categories: categories,
                onToggleStatus: onToggleStatus,
                onEdit: onEdit,
                onReschedule: onReschedule,
                onDelete: onDelete,
              ),
            ),
        ],
      ],
    );
  }
}

class _QuickGoalBar extends StatelessWidget {
  const _QuickGoalBar({
    super.key,
    this.tutorialCategoryKey,
    required this.controller,
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
    required this.onCreateCategory,
    required this.onSubmit,
    required this.hintText,
  });

  final GlobalKey? tutorialCategoryKey;
  final TextEditingController controller;
  final _GoalCategory? selectedCategory;
  final List<_GoalCategory> categories;
  final String hintText;
  final ValueChanged<_GoalCategory?> onCategoryChanged;
  final VoidCallback onCreateCategory;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return EvolvePanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              key: tutorialCategoryKey,
              child: _QuickCategoryButton(
                selectedCategory: selectedCategory,
                categories: categories,
                onCategoryChanged: onCategoryChanged,
                onCreateCategory: onCreateCategory,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  hintText: hintText,
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: onSubmit,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCategoryButton extends StatelessWidget {
  const _QuickCategoryButton({
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
    required this.onCreateCategory,
  });

  final _GoalCategory? selectedCategory;
  final List<_GoalCategory> categories;
  final ValueChanged<_GoalCategory?> onCategoryChanged;
  final VoidCallback onCreateCategory;

  @override
  Widget build(BuildContext context) {
    final color = selectedCategory?.color ?? context.evolveColors.borderStrong;
    return PopupMenuButton<_GoalCategory?>(
      onSelected: onCategoryChanged,
      itemBuilder: (context) => [
        PopupMenuItem(value: null, child: Text(t.goalsPage.defaultCategory)),
        for (final item in categories)
          PopupMenuItem(
            value: item,
            child: Row(
              children: [
                CircleAvatar(radius: 5, backgroundColor: item.color),
                const SizedBox(width: 10),
                Text(_categoryLabel(item)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          // Not a category value — create inline via onTap (fires after close),
          // which opens the editor and auto-selects the new category.
          onTap: onCreateCategory,
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 18, color: context.evolveAccent),
              const SizedBox(width: 10),
              Text(t.macroGoals.createNewCategory),
            ],
          ),
        ),
      ],
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color, width: 1.5),
        ),
      ),
    );
  }
}

class _GoalEmptyState extends StatelessWidget {
  const _GoalEmptyState({required this.hasAnyGoal});

  final bool hasAnyGoal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.evolveColors.border),
      ),
      child: Row(
        children: [
          Icon(
            hasAnyGoal
                ? Icons.check_circle_outline_rounded
                : Icons.flag_outlined,
            color: context.evolveColors.subtle,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            hasAnyGoal ? t.goalsPage.emptyActive : t.goalsPage.emptyAdd,
            style: Theme.of(context).textTheme.bodyMedium,
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
    this.checkboxKey,
    this.rescheduleKey,
    this.editKey,
    this.deleteKey,
    required this.categories,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onReschedule,
    required this.onDelete,
  });

  final DashboardGoal goal;
  final GlobalKey? checkboxKey;
  final GlobalKey? rescheduleKey;
  final GlobalKey? editKey;
  final GlobalKey? deleteKey;
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

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final goal = widget.goal;
    final category = _categoryForGoal(goal, widget.categories);
    final currentState = _visualStatusOverride ?? goal.state;
    final completed = currentState == GoalState.completed;
    final failed = currentState == GoalState.failed;
    final statusColor = completed
        ? const Color(0xFF10B981)
        : failed
        ? EvolveColors.rose
        : category.color;

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: failed ? 0.055 : 0.075),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            key: widget.checkboxKey,
            child: _GoalCheckButton(
              state: currentState,
              onPressed: _cycleStatus,
            ),
          ),
          const SizedBox(width: 16),
          if (!completed && !failed) ...[
            CircleAvatar(radius: 4, backgroundColor: category.color),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              goal.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: completed
                    ? const Color(0xFF10B981).withValues(alpha: 0.72)
                    : failed
                    ? EvolveColors.rose.withValues(alpha: 0.7)
                    : context.evolveColors.foreground,
                decoration: completed || failed
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationColor: statusColor.withValues(alpha: 0.55),
                decorationThickness: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (goal.type != GoalType.lifetime)
            IconButton(
              key: widget.rescheduleKey,
              tooltip: t.goalsPage.rescheduleTooltip,
              onPressed: () => widget.onReschedule(goal),
              icon: const Icon(Icons.next_plan_outlined, size: 20),
            ),
          IconButton(
            key: widget.editKey,
            tooltip: t.common.actions.edit,
            onPressed: () => widget.onEdit(goal),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            key: widget.deleteKey,
            tooltip: t.common.actions.delete,
            onPressed: () => widget.onDelete(goal),
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
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
        ? const Color(0xFF10B981)
        : failed
        ? EvolveColors.rose
        : context.evolveColors.borderStrong;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: completed || failed ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1.4),
        ),
        child: completed
            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
            : failed
            ? const Icon(Icons.close_rounded, size: 15, color: Colors.white)
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
        Expanded(child: Divider(color: color.withValues(alpha: 0.25))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
            ),
          ),
        ),
        Expanded(child: Divider(color: color.withValues(alpha: 0.25))),
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
  late _GoalCategory _category;

  @override
  void initState() {
    super.initState();
    _title.text = widget.goal?.title ?? '';
    _category =
        widget.categories
            .where((item) => item == widget.initialCategory)
            .firstOrNull ??
        widget.categories.first;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      icon: Icons.flag_outlined,
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
            const SizedBox(height: 12),
            DropdownButtonFormField<_GoalCategory>(
              initialValue: _category,
              decoration: InputDecoration(labelText: t.form.category),
              items: [
                for (final category in widget.categories)
                  DropdownMenuItem(
                    value: category,
                    child: Text(_categoryLabel(category)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
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
      icon: Icons.palette_outlined,
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
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final color in _goalColors)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: color,
                      child: _color == color
                          ? const Icon(Icons.check_rounded, size: 15)
                          : null,
                    ),
                  ),
                CustomColorSwatch(
                  size: 24,
                  initial: _color,
                  isSelected: !_goalColors.contains(_color),
                  onPicked: (color) => setState(() => _color = color),
                ),
              ],
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

const _defaultGoalCategories = [
  _GoalCategory(
    key: 'lavoro',
    label: 'Lavoro',
    color: EvolveColors.cyan,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'salute',
    label: 'Salute',
    color: EvolveColors.primaryStrong,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'finanza',
    label: 'Finanza',
    color: EvolveColors.amber,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'relazioni',
    label: 'Relazioni',
    color: EvolveColors.rose,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'formazione',
    label: 'Formazione',
    color: EvolveColors.violet,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'hobby',
    label: 'Hobby',
    color: EvolveColors.cyan,
    isDefault: true,
  ),
  _GoalCategory(
    key: 'spirituale',
    label: 'Spirituale',
    color: Color(0xFFF97316),
    isDefault: true,
  ),
  _GoalCategory(
    key: 'altro',
    label: 'Altro',
    color: Color(0xFF6B7280),
    isDefault: true,
  ),
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

class _GoalsTutorialStep {
  const _GoalsTutorialStep({
    this.targetKey,
    this.showStats = false,
    required this.title,
    required this.description,
    this.nextButtonLabel,
  });

  final GlobalKey? targetKey;
  final bool showStats;
  final String title;
  final String description;
  final String? nextButtonLabel;
}

class _GoalsTutorialScrimPainter extends CustomPainter {
  const _GoalsTutorialScrimPainter(this.targetRect);

  final Rect? targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayBounds = Offset.zero & size;
    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.82);
    final target = targetRect;

    if (target == null) {
      canvas.drawRect(overlayBounds, scrimPaint);
      return;
    }

    final highlightedRect = target.inflate(10).intersect(overlayBounds);
    if (highlightedRect.isEmpty) {
      canvas.drawRect(overlayBounds, scrimPaint);
      return;
    }

    final overlayPath = Path()..addRect(overlayBounds);
    final highlightPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(highlightedRect, const Radius.circular(16)),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, overlayPath, highlightPath),
      scrimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoalsTutorialScrimPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
