import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    overview => LucideIcons.house,
    habits => LucideIcons.listTodo,
    insights => LucideIcons.activity,
    goals => LucideIcons.chartPie,
    coach => LucideIcons.sparkles,
    settings => LucideIcons.settings,
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
