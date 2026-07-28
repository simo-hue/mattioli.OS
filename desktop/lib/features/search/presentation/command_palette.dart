import 'package:evolve_desktop/app/theme/desktop_appearance_controller.dart';
import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/macro_goal_calendar.dart';
import 'package:evolve_desktop/core/tutorial_provider.dart';
import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/dashboard/presentation/create_goal_dialog.dart';
import 'package:evolve_desktop/features/goals/application/goals_page_command.dart';
import 'package:evolve_desktop/features/habits/presentation/habits_page.dart';
import 'package:evolve_desktop/features/search/application/fuzzy_match.dart';
import 'package:evolve_desktop/features/search/application/goal_nav_target.dart';
import 'package:evolve_desktop/features/search/application/palette_models.dart';
import 'package:evolve_desktop/features/search/application/period_parser.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/pro_features_modal.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_search.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/features/shell/presentation/section_navigation.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The ⌘K command palette: a single bar that fuzzily searches goals, habits and
/// sections, runs actions (create goal/habit, jump to any period, toggle theme,
/// …), and — for a goal — jumps straight to its week/month/year and glows it.
///
/// All data is read from the in-memory [dashboardControllerProvider] snapshot,
/// so search is instant and identical in both Cloud (Supabase) and Private
/// (encrypted local) data modes. Nothing here queries a repository.
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

// Per-group result caps so a large library can't flood the list.
const int _kMaxGoals = 6;
const int _kMaxHabits = 4;
const int _kMaxThisWeek = 5;
const int _kMaxSettings = 5;

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _controller = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'command-palette-search');
  final _scrollController = ScrollController();

  /// Key on the currently highlighted row, so ↑/↓ can scroll it into view.
  final _highlightRowKey = GlobalKey();

  /// Flattened, in-display-order list of selectable entries — the target of the
  /// keyboard highlight. Rebuilt every frame from the groups.
  List<PaletteEntry> _flat = const [];
  int _highlightIndex = 0;

  /// The menu controller of the highlighted goal/habit row, captured during
  /// build so ⌘↵ can open that row's action menu.
  MenuController? _highlightedMenu;

  /// Guards against a primary action firing twice (e.g. Enter routed through
  /// both the shortcut and the field), which could open a dialog twice.
  bool _activated = false;

  String get _query => _controller.text.trim();

  @override
  void dispose() {
    _controller.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Building the grouped result set ──────────────────────────────────────

  List<PaletteGroup> _buildGroups(
    List<DashboardGoal> goals,
    List<DashboardHabit> habits, {
    required bool isDark,
    required bool isPrivateMode,
  }) {
    final query = _query;
    return query.isEmpty
        ? _launchpadGroups(goals)
        : _searchGroups(
            query,
            goals,
            habits,
            isDark: isDark,
            isPrivateMode: isPrivateMode,
          );
  }

  /// The empty-query launchpad: quick actions, this week's active goals, and
  /// the section shortcuts.
  List<PaletteGroup> _launchpadGroups(List<DashboardGoal> goals) {
    final now = DateTime.now();
    final week = logicalWeekOfMonth(now);
    final thisWeek = goals
        .where(
          (g) =>
              g.state == GoalState.active &&
              g.type == GoalType.weekly &&
              g.year == now.year &&
              g.month == now.month &&
              g.weekNumber == week,
        )
        .take(_kMaxThisWeek)
        .map(
          (g) => GoalEntry(goal: g, periodLabel: _goalPeriodLabel(g), score: 0),
        )
        .toList();

    return [
      PaletteGroup(
        kind: PaletteGroupKind.suggested,
        title: t.palette.groupSuggested,
        entries: [
          ActionEntry(
            kind: PaletteActionKind.goToThisWeek,
            label: t.palette.goToThisWeek,
            icon: LucideIcons.calendarDays,
            score: 0,
            navTarget: GoalNavTarget(
              type: GoalType.weekly,
              year: now.year,
              month: now.month,
              week: week,
            ),
          ),
          ActionEntry(
            kind: PaletteActionKind.createGoal,
            label: t.palette.createGoalBlank,
            icon: LucideIcons.trophy,
            score: 0,
          ),
          // The RENDERED brightness — under ThemeMode.system the stored mode
          // does not say which theme is on screen.
          _themeAction(
            Theme.of(context).brightness == Brightness.dark,
            score: 0,
          ),
        ],
      ),
      if (thisWeek.isNotEmpty)
        PaletteGroup(
          kind: PaletteGroupKind.thisWeek,
          title: t.palette.groupThisWeek,
          entries: thisWeek,
        ),
      PaletteGroup(
        kind: PaletteGroupKind.sections,
        title: t.palette.groupSections,
        entries: [
          for (final section in DesktopSection.values)
            SectionEntry(section: section, score: 0),
        ],
      ),
    ];
  }

  List<PaletteGroup> _searchGroups(
    String query,
    List<DashboardGoal> goals,
    List<DashboardHabit> habits, {
    required bool isDark,
    required bool isPrivateMode,
  }) {
    // Goals — match title and category; rank by score, then active-first, then
    // period nearest to today.
    final now = DateTime.now();
    final goalMatches = <(DashboardGoal, int)>[];
    for (final g in goals) {
      final m = fuzzyMatchBest(query, [g.title, g.category]);
      if (m != null) goalMatches.add((g, m.score));
    }
    goalMatches.sort((a, b) {
      if (a.$2 != b.$2) return b.$2.compareTo(a.$2);
      final sa = _stateRank(a.$1.state);
      final sb = _stateRank(b.$1.state);
      if (sa != sb) return sa.compareTo(sb);
      return _periodDistance(a.$1, now).compareTo(_periodDistance(b.$1, now));
    });
    final goalEntries = goalMatches
        .take(_kMaxGoals)
        .map(
          (e) => GoalEntry(
            goal: e.$1,
            periodLabel: _goalPeriodLabel(e.$1),
            score: e.$2,
          ),
        )
        .toList();

    // Habits — match title and description.
    final habitMatches = <(DashboardHabit, int)>[];
    for (final h in habits) {
      final m = fuzzyMatchBest(query, [
        h.title,
        if (h.description != null) h.description!,
      ]);
      if (m != null) habitMatches.add((h, m.score));
    }
    habitMatches.sort((a, b) => b.$2.compareTo(a.$2));
    final habitEntries = habitMatches
        .take(_kMaxHabits)
        .map((e) => HabitEntry(habit: e.$1, score: e.$2))
        .toList();

    // Sections — match label and synonyms.
    final sectionEntries = <SectionEntry>[];
    for (final section in DesktopSection.values) {
      final m = fuzzyMatchBest(query, [
        section.label,
        ..._sectionSynonyms(section),
      ]);
      if (m != null) {
        sectionEntries.add(SectionEntry(section: section, score: m.score));
      }
    }
    sectionEntries.sort((a, b) => b.score.compareTo(a.score));

    // Individual settings — read from the Settings sidebar's own index, so the
    // two searches can never disagree about what exists, and gated by the SAME
    // data-mode rule the sidebar applies: a Private-mode user is not offered
    // "Send crash reports", which their build has no consent switch for.
    final settingsHits = searchSettingsRanked(
      query,
      isPrivateMode: isPrivateMode,
    ).take(_kMaxSettings).toList();
    final settingEntries = [
      for (final (i, hit) in settingsHits.indexed)
        // The index already returned them best-first; the score only has to
        // preserve that order inside the group.
        SettingEntry(setting: hit.entry, score: 100 - i),
    ];

    // Actions — parsed period jumps, the two always-available create rows, plus
    // any command whose label/keywords fuzzily match.
    final actionEntries = <ActionEntry>[];
    for (final target in parsePeriodQuery(
      query,
      now: now,
      monthNames: t.common.months,
    )) {
      actionEntries.add(
        ActionEntry(
          kind: PaletteActionKind.jumpToPeriod,
          label: t.palette.goToPeriod(period: _describe(target)),
          icon: LucideIcons.calendarRange,
          score: 500, // period jumps are a strong intent when they parse
          navTarget: target,
        ),
      );
    }
    actionEntries.add(
      ActionEntry(
        kind: PaletteActionKind.createGoal,
        label: t.palette.createGoal(title: query),
        icon: LucideIcons.trophy,
        score: 40,
        argument: query,
      ),
    );
    actionEntries.add(
      ActionEntry(
        kind: PaletteActionKind.createHabit,
        label: t.palette.createHabit(title: query),
        icon: LucideIcons.repeat,
        score: 30,
        argument: query,
      ),
    );
    for (final candidate in _commandCatalogue(isDark)) {
      final m = fuzzyMatchBest(query, [candidate.label, ...candidate.keywords]);
      if (m != null) {
        actionEntries.add(
          ActionEntry(
            kind: candidate.kind,
            label: candidate.label,
            icon: candidate.icon,
            score: m.score,
          ),
        );
      }
    }
    actionEntries.sort((a, b) => b.score.compareTo(a.score));

    // Where the settings group lands relative to Actions. Actions ALWAYS
    // contains the two catch-all "Create goal/habit “<query>”" rows, so putting
    // settings unconditionally below them would bury a literal "language" under
    // an offer to create a goal called "language". Putting it unconditionally
    // above them is just as wrong the other way: "week" is a keyword of the
    // calendar-view setting, and it must not displace the parsed jump to that
    // week. So: the user typed the setting's NAME → above; anything softer than
    // that (keywords, help text) → below.
    final settingsGroup = settingEntries.isEmpty
        ? null
        : PaletteGroup(
            kind: PaletteGroupKind.settings,
            title: t.palette.groupSettings,
            entries: settingEntries,
          );
    final settingsLeadActions =
        settingsHits.isNotEmpty && settingsHits.first.isLabelMatch;

    return [
      if (goalEntries.isNotEmpty)
        PaletteGroup(
          kind: PaletteGroupKind.goals,
          title: t.palette.groupGoals,
          entries: goalEntries,
        ),
      if (habitEntries.isNotEmpty)
        PaletteGroup(
          kind: PaletteGroupKind.habits,
          title: t.palette.groupHabits,
          entries: habitEntries,
        ),
      if (settingsGroup != null && settingsLeadActions) settingsGroup,
      if (actionEntries.isNotEmpty)
        PaletteGroup(
          kind: PaletteGroupKind.actions,
          title: t.palette.groupActions,
          entries: actionEntries,
        ),
      if (settingsGroup != null && !settingsLeadActions) settingsGroup,
      if (sectionEntries.isNotEmpty)
        PaletteGroup(
          kind: PaletteGroupKind.sections,
          title: t.palette.groupSections,
          entries: sectionEntries,
        ),
    ];
  }

  // ── Ranking / labelling helpers ──────────────────────────────────────────

  int _stateRank(GoalState s) => switch (s) {
    GoalState.active => 0,
    GoalState.completed => 1,
    GoalState.failed => 2,
  };

  /// A rough "months away from now" for a goal's period, so nearer periods rank
  /// first among equally-scored matches. Lifetime sorts as closest.
  int _periodDistance(DashboardGoal g, DateTime now) {
    if (g.type == GoalType.lifetime) return 0;
    final year = g.year ?? now.year;
    final month = switch (g.type) {
      GoalType.monthly || GoalType.weekly => g.month ?? now.month,
      GoalType.quarterly => ((g.quarter ?? 1) - 1) * 3 + 1,
      _ => now.month,
    };
    return ((year * 12 + month) - (now.year * 12 + now.month)).abs();
  }

  String _goalPeriodLabel(DashboardGoal g) =>
      _describe(GoalNavTarget.forGoal(g));

  String _describe(GoalNavTarget target) => describePeriod(
    target,
    monthNames: t.common.months,
    weekWord: t.common.calendarView.week,
    lifetimeWord: t.goalsPage.periodLifetime,
  );

  List<String> _sectionSynonyms(DesktopSection section) => switch (section) {
    DesktopSection.overview => const ['home', 'dashboard', 'today'],
    DesktopSection.habits => const ['routines', 'streaks'],
    DesktopSection.insights => const ['stats', 'statistics', 'analytics'],
    DesktopSection.goals => const ['objectives', 'targets', 'macro'],
    DesktopSection.coach => const ['ai', 'assistant', 'chat'],
    DesktopSection.settings => const ['preferences', 'config', 'options'],
  };

  /// Keyed on the brightness actually being RENDERED, not on the stored mode.
  ///
  /// `mode != ThemeMode.dark` was only ever safe while `ThemeMode.system` was
  /// unreachable. On a "follow system" Mac in dark appearance it makes `toDark`
  /// true, so the palette offers "switch to dark" against an already-dark
  /// screen — and activating it sets the mode it thinks it is leaving, changing
  /// nothing. A command that reports success and does nothing.
  ActionEntry _themeAction(bool isDark, {required int score}) {
    final toDark = !isDark;
    return ActionEntry(
      kind: PaletteActionKind.toggleTheme,
      label: toDark ? t.palette.switchToDark : t.palette.switchToLight,
      icon: toDark ? LucideIcons.moon : LucideIcons.sun,
      score: score,
    );
  }

  List<_Command> _commandCatalogue(bool isDark) {
    final toDark = !isDark;
    return [
      _Command(
        kind: PaletteActionKind.toggleTheme,
        label: toDark ? t.palette.switchToDark : t.palette.switchToLight,
        icon: toDark ? LucideIcons.moon : LucideIcons.sun,
        keywords: const ['theme', 'dark', 'light', 'appearance', 'mode'],
      ),
      _Command(
        kind: PaletteActionKind.manageCategories,
        label: t.palette.manageCategories,
        icon: LucideIcons.tags,
        keywords: const ['categories', 'category', 'tags', 'labels'],
      ),
      _Command(
        kind: PaletteActionKind.replayTour,
        label: t.palette.replayTour,
        icon: LucideIcons.graduationCap,
        keywords: const ['tour', 'tutorial', 'guide', 'onboarding'],
      ),
      _Command(
        kind: PaletteActionKind.goToThisWeek,
        label: t.palette.goToThisWeek,
        icon: LucideIcons.calendarDays,
        keywords: const ['today', 'this week', 'now', 'current'],
      ),
    ];
  }

  // ── Keyboard navigation ──────────────────────────────────────────────────

  void _move(int delta) {
    if (_flat.isEmpty) return;
    setState(() {
      _highlightIndex = (_highlightIndex + delta) % _flat.length;
      if (_highlightIndex < 0) _highlightIndex += _flat.length;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _highlightRowKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 120),
        );
      }
    });
  }

  void _activateHighlighted() {
    if (_flat.isEmpty || _highlightIndex >= _flat.length) return;
    _activate(_flat[_highlightIndex]);
  }

  void _openMenuForHighlighted() => _highlightedMenu?.open();

  // ── Dispatch ─────────────────────────────────────────────────────────────

  void _dismiss() => Navigator.of(context).maybePop();

  /// Runs [after] once the palette route is gone, using the Navigator's own
  /// context so opening a follow-up dialog is safe.
  void _closeThen(void Function(BuildContext navContext) after) {
    final navigator = Navigator.of(context);
    final navContext = navigator.context;
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => after(navContext));
  }

  void _goTo(DesktopSection section) {
    // Gated sections (the Pro-only AI Coach) get the upsell instead, exactly
    // like the sidebar and ⌘5. Decided HERE, while our [WidgetRef] is still
    // alive: `_closeThen` runs after the palette route is popped and this State
    // is disposed, so the shared `openSection` helper cannot be called from
    // inside it — only the predicate, from out here.
    if (sectionNeedsPaywall(ref, section)) {
      _closeThen((ctx) => showProFeaturesDialog(ctx, ref));
      return;
    }
    ref.read(navigationControllerProvider.notifier).select(section);
    _dismiss();
  }

  /// Opens Settings on the pane that owns a settings row.
  ///
  /// The request goes in FIRST, then the navigation: `SettingsPage` reads the
  /// provider in `initState` when it is being mounted, and through a
  /// `ref.listen` when it is already on screen (⌘K works from inside Settings),
  /// so both arrival orders have to find the request already set.
  void _openSetting(SettingEntry entry) {
    // Carries the ROW, not just the pane: the sidebar's own result list scrolls
    // to the setting and tints it, and a ⌘K hit on the same index for the same
    // query has to mean the same thing.
    ref
        .read(settingsSectionRequestProvider.notifier)
        .request(entry.section, rowId: entry.setting.id);
    _goTo(DesktopSection.settings);
  }

  void _jump(GoalNavTarget target) {
    ref.read(goalNavTargetProvider.notifier).set(target);
    ref
        .read(navigationControllerProvider.notifier)
        .select(DesktopSection.goals);
    _dismiss();
  }

  void _activate(PaletteEntry entry) {
    if (_activated) return;
    _activated = true;
    switch (entry) {
      case GoalEntry():
        _jump(GoalNavTarget.forGoal(entry.goal));
      case HabitEntry():
        _goTo(DesktopSection.habits);
      case SectionEntry():
        _goTo(entry.section);
      case SettingEntry():
        _openSetting(entry);
      case ActionEntry():
        _runAction(entry);
    }
  }

  void _runAction(ActionEntry entry) {
    switch (entry.kind) {
      case PaletteActionKind.goToThisWeek:
      case PaletteActionKind.jumpToPeriod:
        if (entry.navTarget != null) _jump(entry.navTarget!);
      case PaletteActionKind.createGoal:
        // Same free-tier cap the dashboard + quick-add enforce (mobile parity).
        final isPro = ref.read(desktopIsProProvider);
        final total = ref.read(dashboardControllerProvider).goals.length;
        if (!isPro && total >= 100) {
          _closeThen((ctx) => showProFeaturesDialog(ctx, ref));
          return;
        }
        _closeThen(
          (ctx) => showEvolveDialog<void>(
            context: ctx,
            builder: (_) => CreateGoalDialog(
              initialTitle: entry.argument,
              jumpAfterCreate: true,
            ),
          ),
        );
      case PaletteActionKind.createHabit:
        _createHabit(entry.argument);
      case PaletteActionKind.toggleTheme:
        // Toggle away from what is on screen, not from the stored mode: for a
        // 'system' user those are different, and toggling from the stored mode
        // is a no-op in exactly the half of the cases where it is reachable.
        // This also pins the result — deliberate. The user asked for the other
        // brightness, which "follow system" cannot express.
        ref
            .read(desktopAppearanceControllerProvider.notifier)
            .setThemeMode(
              Theme.of(context).brightness == Brightness.dark
                  ? ThemeMode.light
                  : ThemeMode.dark,
            );
        _dismiss();
      case PaletteActionKind.manageCategories:
        ref
            .read(goalsPageCommandProvider.notifier)
            .set(GoalsPageCommand.openCategoryManager);
        ref
            .read(navigationControllerProvider.notifier)
            .select(DesktopSection.goals);
        _dismiss();
      case PaletteActionKind.replayTour:
        final tour = ref.read(tourControllerProvider.notifier);
        _dismiss();
        tour.resetForReplay();
        tour.activate();
    }
  }

  /// Opens the habit editor over the palette (so our [WidgetRef] stays valid
  /// through the `await`, unlike the create-goal path which hands off to a
  /// self-contained dialog), then dismisses the palette. The editor navigates
  /// to Habits itself on success.
  Future<void> _createHabit(String? title) async {
    final navigator = Navigator.of(context);
    await showCreateHabitDialog(context, ref, initialTitle: title);
    if (mounted) navigator.pop();
  }

  // Per-row action menus (Slice: full menu, delete confirmed).

  Future<void> _confirmAndDeleteGoal(DashboardGoal goal) async {
    final confirmed = await showEvolveDialog<bool>(
      context: context,
      builder: (ctx) => EvolveAlertDialog(
        icon: LucideIcons.trash2,
        iconColor: EvolveColors.destructive,
        title: Text(t.palette.deleteGoalTitle),
        content: Text(t.palette.deleteGoalMessage(title: goal.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.actions.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: EvolveColors.destructive,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.common.actions.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(dashboardControllerProvider.notifier).deleteGoal(goal.id);
    }
  }

  Future<void> _confirmAndDeleteHabit(DashboardHabit habit) async {
    final confirmed = await showEvolveDialog<bool>(
      context: context,
      builder: (ctx) => EvolveAlertDialog(
        icon: LucideIcons.trash2,
        iconColor: EvolveColors.destructive,
        title: Text(t.palette.deleteHabitTitle),
        content: Text(t.palette.deleteHabitMessage(title: habit.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.actions.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: EvolveColors.destructive,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.common.actions.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(dashboardControllerProvider.notifier)
          .deleteHabit(habit.id);
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(dashboardControllerProvider);
    // Watched so a theme change (including an OS appearance flip under
    // ThemeMode.system) relabels the command.
    ref.watch(desktopAppearanceControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = _buildGroups(
      snapshot.goals,
      snapshot.habits,
      isDark: isDark,
      isPrivateMode: ref.watch(activeDesktopDataModeProvider).isPrivate,
    );
    _flat = [for (final g in groups) ...g.entries];
    if (_highlightIndex >= _flat.length) {
      _highlightIndex = _flat.isEmpty ? 0 : _flat.length - 1;
    }
    if (_highlightIndex < 0) _highlightIndex = 0;
    _highlightedMenu = null;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.enter): _ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter, meta: true): _MenuIntent(),
        SingleActivator(LogicalKeyboardKey.enter, control: true): _MenuIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _DismissIntent(),
      },
      child: Actions(
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (i) {
              _move(i.delta);
              return null;
            },
          ),
          _ActivateIntent: CallbackAction<_ActivateIntent>(
            onInvoke: (_) {
              _activateHighlighted();
              return null;
            },
          ),
          _MenuIntent: CallbackAction<_MenuIntent>(
            onInvoke: (_) {
              _openMenuForHighlighted();
              return null;
            },
          ),
          _DismissIntent: CallbackAction<_DismissIntent>(
            onInvoke: (_) {
              _dismiss();
              return null;
            },
          ),
        },
        child: EvolveDialog(
          alignment: const Alignment(0, -0.62),
          maxWidth: 580,
          autofocus: false,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _searchField(context),
                const SizedBox(height: 8),
                Flexible(child: _resultsList(context, groups)),
                const SizedBox(height: 6),
                _footer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _searchFocus,
      autofocus: true,
      onChanged: (_) => setState(() => _highlightIndex = 0),
      onSubmitted: (_) => _activateHighlighted(),
      decoration: InputDecoration(
        prefixIcon: const Icon(LucideIcons.search, size: 17),
        hintText: t.palette.searchHint,
      ),
    );
  }

  Widget _resultsList(BuildContext context, List<PaletteGroup> groups) {
    if (_flat.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Text(
          t.palette.noResults(query: _query),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.evolveColors.muted),
        ),
      );
    }
    final children = <Widget>[];
    var flatIndex = 0;
    for (final group in groups) {
      children.add(_groupHeader(context, group.title));
      for (final entry in group.entries) {
        final selected = flatIndex == _highlightIndex;
        children.add(
          _entryRow(
            context,
            entry: entry,
            selected: selected,
            rowKey: selected ? _highlightRowKey : null,
          ),
        );
        flatIndex++;
      }
      children.add(const SizedBox(height: 6));
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 420),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _groupHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: context.evolveColors.subtle,
        ),
      ),
    );
  }

  Widget _entryRow(
    BuildContext context, {
    required PaletteEntry entry,
    required bool selected,
    GlobalKey? rowKey,
  }) {
    final accent = context.evolveAccent;
    final bg = selected ? accent.withValues(alpha: 0.14) : Colors.transparent;

    final leading = _entryLeading(context, entry);
    final title = _entryTitle(entry);
    final subtitle = _entrySubtitle(entry);
    final trailing = _entryTrailing(context, entry, selected);

    return Padding(
      key: rowKey,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _activate(entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: context.evolveColors.foreground,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.evolveColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entryLeading(BuildContext context, PaletteEntry entry) {
    IconData icon;
    Color color = context.evolveColors.muted;
    switch (entry) {
      case GoalEntry():
        icon = LucideIcons.target;
        color = entry.goal.color;
      case HabitEntry():
        icon = LucideIcons.repeat;
        color = entry.habit.color;
      case SectionEntry():
        icon = entry.section.icon;
      case SettingEntry():
        // The PANE's icon, not a generic cog: it is the second half of the
        // "which of the eight panes is this in" answer the subtitle gives.
        icon = entry.section.icon;
      case ActionEntry():
        icon = entry.icon;
        color = context.evolveAccent;
    }
    return Icon(icon, size: 18, color: color);
  }

  String _entryTitle(PaletteEntry entry) => switch (entry) {
    GoalEntry() => entry.goal.title,
    HabitEntry() => entry.habit.title,
    SectionEntry() => entry.section.label,
    SettingEntry() => entry.setting.label(),
    ActionEntry() => entry.label,
  };

  /// The second line under the title. A settings row is the only entry that
  /// needs one: "Language" alone does not say where it lives, and the eight
  /// panes are the map users navigate Settings by.
  String? _entrySubtitle(PaletteEntry entry) => switch (entry) {
    SettingEntry() => entry.section.label,
    _ => null,
  };

  Widget? _entryTrailing(
    BuildContext context,
    PaletteEntry entry,
    bool selected,
  ) {
    switch (entry) {
      case GoalEntry():
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stateBadge(entry.goal.state),
            Text(
              entry.periodLabel,
              style: TextStyle(fontSize: 12, color: context.evolveColors.muted),
            ),
            _goalMenu(context, entry.goal),
          ],
        );
      case HabitEntry():
        return _habitMenu(context, entry.habit);
      case SectionEntry():
        return Text(
          entry.section.shortcut,
          style: TextStyle(fontSize: 12, color: context.evolveColors.subtle),
        );
      case SettingEntry():
        // The pane is already on the subtitle line; a ⌘, badge here would only
        // repeat what the group header says.
        return null;
      case ActionEntry():
        return entry.subtitle == null
            ? null
            : Text(
                entry.subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.evolveColors.muted,
                ),
              );
    }
  }

  Widget _stateBadge(GoalState state) {
    return switch (state) {
      GoalState.completed => const Padding(
        padding: EdgeInsets.only(right: 6),
        child: Icon(LucideIcons.check, size: 14, color: EvolveColors.success),
      ),
      GoalState.failed => const Padding(
        padding: EdgeInsets.only(right: 6),
        child: Icon(LucideIcons.x, size: 14, color: EvolveColors.destructive),
      ),
      GoalState.active => const SizedBox.shrink(),
    };
  }

  Widget _goalMenu(BuildContext context, DashboardGoal goal) {
    final controller = ref.read(dashboardControllerProvider.notifier);
    return EvolveMenu(
      minWidth: 190,
      triggerBuilder: (context, menu) {
        // Capture the highlighted row's menu so ⌘↵ can open it.
        if (_highlightIndex < _flat.length) {
          final current = _flat[_highlightIndex];
          if (current is GoalEntry && current.goal.id == goal.id) {
            _highlightedMenu = menu;
          }
        }
        return _menuTrigger(context, menu);
      },
      children: [
        EvolveMenuItem(
          leading: const Icon(LucideIcons.arrowRight, size: 15),
          label: t.palette.rowOpen,
          onTap: () => _jump(GoalNavTarget.forGoal(goal)),
        ),
        if (goal.state != GoalState.completed)
          EvolveMenuItem(
            leading: const Icon(LucideIcons.check, size: 15),
            label: t.palette.rowComplete,
            onTap: () =>
                controller.updateGoalState(goal.id, GoalState.completed),
          ),
        if (goal.type != GoalType.lifetime)
          EvolveMenuItem(
            leading: const Icon(LucideIcons.calendarClock, size: 15),
            label: t.palette.rowReschedule,
            onTap: () => controller.rescheduleGoal(goal.id),
          ),
        EvolveMenuItem(
          leading: const Icon(LucideIcons.pencil, size: 15),
          label: t.common.actions.edit,
          onTap: () => _jump(GoalNavTarget.forGoal(goal, openEditor: true)),
        ),
        const EvolveMenuDivider(),
        EvolveMenuItem(
          leading: const Icon(
            LucideIcons.trash2,
            size: 15,
            color: EvolveColors.destructive,
          ),
          label: t.common.actions.delete,
          onTap: () => _confirmAndDeleteGoal(goal),
        ),
      ],
    );
  }

  Widget _habitMenu(BuildContext context, DashboardHabit habit) {
    return EvolveMenu(
      minWidth: 180,
      triggerBuilder: (context, menu) {
        if (_highlightIndex < _flat.length) {
          final current = _flat[_highlightIndex];
          if (current is HabitEntry && current.habit.id == habit.id) {
            _highlightedMenu = menu;
          }
        }
        return _menuTrigger(context, menu);
      },
      children: [
        EvolveMenuItem(
          leading: const Icon(LucideIcons.arrowRight, size: 15),
          label: t.palette.rowOpen,
          onTap: () => _goTo(DesktopSection.habits),
        ),
        const EvolveMenuDivider(),
        EvolveMenuItem(
          leading: const Icon(
            LucideIcons.trash2,
            size: 15,
            color: EvolveColors.destructive,
          ),
          label: t.common.actions.delete,
          onTap: () => _confirmAndDeleteHabit(habit),
        ),
      ],
    );
  }

  Widget _menuTrigger(BuildContext context, MenuController menu) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () => menu.isOpen ? menu.close() : menu.open(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          LucideIcons.ellipsis,
          size: 16,
          color: context.evolveColors.muted,
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final style = TextStyle(fontSize: 11.5, color: context.evolveColors.subtle);
    Widget hint(String keys, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(keys, style: style.copyWith(color: context.evolveColors.muted)),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      child: Row(
        children: [
          hint('↑↓', t.palette.footerNavigate),
          const SizedBox(width: 14),
          hint('↵', t.palette.footerOpen),
          const SizedBox(width: 14),
          hint('⌘↵', t.palette.footerMenu),
          const Spacer(),
          hint('esc', t.palette.footerClose),
        ],
      ),
    );
  }
}

class _Command {
  const _Command({
    required this.kind,
    required this.label,
    required this.icon,
    required this.keywords,
  });
  final PaletteActionKind kind;
  final String label;
  final IconData icon;
  final List<String> keywords;
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);
  final int delta;
}

class _ActivateIntent extends Intent {
  const _ActivateIntent();
}

class _MenuIntent extends Intent {
  const _MenuIntent();
}

class _DismissIntent extends Intent {
  const _DismissIntent();
}
