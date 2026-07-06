import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TutorialFlowStep {
  dashboard('has_seen_tutorial'),
  goals('has_seen_goals_tutorial'),
  stats('has_seen_stats_tutorial');

  const TutorialFlowStep(this.legacyKey);

  final String legacyKey;

  String keyFor(DesktopDataMode mode) => '${legacyKey}_${mode.name}';
}

abstract class ModeAwareTutorialNotifier extends Notifier<bool> {
  TutorialFlowStep get step;

  @override
  bool build() {
    final mode = ref.watch(activeDesktopDataModeProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    if (prefs == null) return false;

    final modeSpecificValue = prefs.getBool(step.keyFor(mode));
    if (modeSpecificValue != null) return modeSpecificValue;

    if (!mode.isPrivate) {
      return prefs.getBool(step.legacyKey) ?? false;
    }

    return false;
  }

  Future<void> setTutorialSeen(bool seen) async {
    final mode = ref.read(activeDesktopDataModeProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    if (prefs == null) return;

    state = seen;
    await prefs.setBool(step.keyFor(mode), seen);
    if (!mode.isPrivate) {
      await prefs.setBool(step.legacyKey, seen);
    }
  }
}

class TutorialNotifier extends ModeAwareTutorialNotifier {
  @override
  TutorialFlowStep get step => TutorialFlowStep.dashboard;
}

final tutorialProvider = NotifierProvider<TutorialNotifier, bool>(
  TutorialNotifier.new,
);

class GoalsTutorialNotifier extends ModeAwareTutorialNotifier {
  @override
  TutorialFlowStep get step => TutorialFlowStep.goals;
}

final goalsTutorialProvider = NotifierProvider<GoalsTutorialNotifier, bool>(
  GoalsTutorialNotifier.new,
);

class StatsTutorialNotifier extends ModeAwareTutorialNotifier {
  @override
  TutorialFlowStep get step => TutorialFlowStep.stats;
}

final statsTutorialProvider = NotifierProvider<StatsTutorialNotifier, bool>(
  StatsTutorialNotifier.new,
);
