import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:evolve_desktop/features/search/application/goal_nav_target.dart';
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

/// The stable display order of groups: goals first (the palette's headline use),
/// then habits, actions, and finally the section shortcuts. The empty-query
/// launchpad reuses [suggested]/[thisWeek].
enum PaletteGroupKind { suggested, thisWeek, goals, habits, actions, sections }

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
