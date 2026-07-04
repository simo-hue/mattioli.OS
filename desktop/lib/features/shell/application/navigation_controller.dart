import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DesktopSection {
  overview,
  habits,
  insights,
  goals,
  coach,
  settings;

  String get label => switch (this) {
    overview => t.nav.overview,
    habits => t.nav.habits,
    insights => t.nav.insights,
    goals => t.nav.goals,
    coach => t.nav.coach,
    settings => t.nav.settings,
  };

  String get shortcut => switch (this) {
    overview => '⌘1',
    habits => '⌘2',
    insights => '⌘3',
    goals => '⌘4',
    coach => '⌘5',
    settings => '⌘,',
  };

  IconData get icon => switch (this) {
    overview => Icons.space_dashboard_outlined,
    habits => Icons.check_circle_outline_rounded,
    insights => Icons.query_stats_rounded,
    goals => Icons.flag_outlined,
    coach => Icons.auto_awesome_outlined,
    settings => Icons.settings_outlined,
  };
}

final navigationControllerProvider =
    NotifierProvider<NavigationController, DesktopSection>(
      NavigationController.new,
    );

class NavigationController extends Notifier<DesktopSection> {
  @override
  DesktopSection build() => DesktopSection.overview;

  void select(DesktopSection section) => state = section;
}
