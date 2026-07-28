import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/search/application/goal_nav_target.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_search.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:flutter/widgets.dart';

/// The commands the palette can run, beyond plain search/navigation. The widget
/// dispatches on [ActionEntry.kind]; keeping these as data (not closures) makes
/// the result list trivial to build and reason about.
enum PaletteActionKind {
  createGoal,
  createHabit,
  goToThisWeek,
  jumpToPeriod,
  toggleTheme,
  manageCategories,
  replayTour,
}

/// One selectable row in the palette. [score] ranks entries within their group
/// (higher first); it is the fuzzy-match score for searched entities and a
/// fixed weight for actions/sections.
sealed class PaletteEntry {
  const PaletteEntry({required this.score});
  final int score;
}

/// A goal, disambiguated by its period label (a title can recur across periods).
class GoalEntry extends PaletteEntry {
  const GoalEntry({
    required this.goal,
    required this.periodLabel,
    required super.score,
  });
  final DashboardGoal goal;
  final String periodLabel;
}

class HabitEntry extends PaletteEntry {
  const HabitEntry({required this.habit, required super.score});
  final DashboardHabit habit;
}

class SectionEntry extends PaletteEntry {
  const SectionEntry({required this.section, required super.score});
  final DesktopSection section;
}

/// One row *inside* Settings — "Language", "Focus mode" — as opposed to the
/// Settings section itself, which is a [SectionEntry].
///
/// Wraps the sidebar's own index entry rather than copying its label and pane
/// out of it: the palette and the Settings search field must never disagree
/// about which settings exist, and the only way to guarantee that is for both
/// to read the same list.
class SettingEntry extends PaletteEntry {
  const SettingEntry({required this.setting, required super.score});
  final SettingsSearchEntry setting;

  /// The pane that holds this row — where activating the entry navigates.
  SettingsSection get section => setting.section;
}

class ActionEntry extends PaletteEntry {
  const ActionEntry({
    required this.kind,
    required this.label,
    required this.icon,
    required super.score,
    this.subtitle,
    this.argument,
    this.navTarget,
  });
  final PaletteActionKind kind;
  final String label;
  final IconData icon;

  /// Optional secondary line (e.g. a period label under "Go to …").
  final String? subtitle;

  /// Free-text argument the action consumes — e.g. the goal/habit title to
  /// create for [PaletteActionKind.createGoal]/[PaletteActionKind.createHabit].
  final String? argument;

  /// Period to jump to, for [PaletteActionKind.jumpToPeriod] /
  /// [PaletteActionKind.goToThisWeek].
  final GoalNavTarget? navTarget;
}

/// The display order of groups: goals first (the palette's headline use), then
/// habits, actions, and finally the section shortcuts. The empty-query
/// launchpad reuses [suggested]/[thisWeek].
///
/// [settings] is the one group whose position moves. It sits ABOVE [actions]
/// when the query matched a setting's own label — the user typed "language",
/// and nothing generic should outrank that — and BELOW it otherwise, so a
/// keyword-only hit cannot push past a parsed period jump ("week" is a keyword
/// of the calendar-view setting and also a period the user may want to open).
enum PaletteGroupKind {
  suggested,
  thisWeek,
  goals,
  habits,
  settings,
  actions,
  sections,
}

class PaletteGroup {
  const PaletteGroup({
    required this.kind,
    required this.title,
    required this.entries,
  });
  final PaletteGroupKind kind;
  final String title;
  final List<PaletteEntry> entries;
}
